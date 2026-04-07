"""AlloyDB tool functions for semantic resource matching, volunteer search, and ai.if() vibe checks."""

import os
import logging
import sqlalchemy
from sqlalchemy import text

# ---------------------------------------------------------------------------
# Database Connection
# ---------------------------------------------------------------------------

_engine = None
_connector = None


def _get_engine():
    """Get or create SQLAlchemy engine for AlloyDB via AlloyDB Connector (public IP)."""
    global _engine, _connector
    if _engine is not None:
        return _engine

    instance_uri = os.getenv("ALLOYDB_INSTANCE_URI", "")
    direct_url = os.getenv("DATABASE_URL", "")

    if instance_uri:
        from google.cloud.alloydb.connector import Connector

        _connector = Connector()

        def getconn():
            return _connector.connect(
                instance_uri,
                "pg8000",
                user=os.getenv("ALLOYDB_USER", "postgres"),
                password=os.getenv("ALLOYDB_PASSWORD", ""),
                db=os.getenv("ALLOYDB_DB", "postgres"),
                ip_type="PUBLIC",
            )

        _engine = sqlalchemy.create_engine(
            "postgresql+pg8000://", creator=getconn
        )
    elif direct_url:
        # Local dev path: direct connection via public IP
        _engine = sqlalchemy.create_engine(direct_url)
    else:
        raise RuntimeError(
            "Set ALLOYDB_INSTANCE_URI (Cloud Run) or DATABASE_URL (local dev)"
        )

    return _engine


def _run_query(sql_str: str, params: dict) -> list[dict]:
    """Shared helper: execute SQL and return list of row dicts (Decimals converted to float)."""
    from decimal import Decimal

    engine = _get_engine()
    with engine.connect() as conn:
        results = conn.execute(text(sql_str), params)
        rows = []
        for r in results:
            row = {}
            for k, v in r._mapping.items():
                row[k] = float(v) if isinstance(v, Decimal) else v
            rows.append(row)
        return rows


# ---------------------------------------------------------------------------
# Tool Functions (registered as ADK tools in agent.py)
# ---------------------------------------------------------------------------


def search_community_resources(query: str, limit: int = 8) -> dict:
    """Semantic search for community resources using AlloyDB vector embeddings.

    Uses embedding('text-embedding-005', query)::vector and cosine distance
    to find resources matching natural language needs like 'clean water'
    or 'first aid supplies'.

    Args:
        query: Natural language description of what is needed (e.g., "drinking water", "baby formula", "shelter for family")
        limit: Maximum number of results to return

    Returns:
        dict with matched resources including type, description, owner, contact, and relevance score.
    """
    try:
        rows = _run_query("""
            SELECT resource_id, resource_type, description, quantity, unit,
                   owner_name, contact_phone, address, available,
                   1 - (description_embedding <=> embedding('text-embedding-005', :query)::vector) AS relevance_score
            FROM community_resources
            WHERE available = true
              AND description_embedding IS NOT NULL
            ORDER BY relevance_score DESC
            LIMIT :limit
        """, {"query": query, "limit": limit})
        logging.info(f"[AlloyDB] search_community_resources('{query}') -> {len(rows)} results")
        return {"resources": rows, "count": len(rows), "query": query}
    except Exception as e:
        logging.error(f"[AlloyDB] search_community_resources error: {e}")
        return {"status": "error", "message": str(e)}


def find_matching_volunteers(skill_needed: str, limit: int = 5) -> dict:
    """Find volunteers whose skills semantically match the needed skill using vector search.

    Args:
        skill_needed: Description of skills needed (e.g., "medical trauma care", "search and rescue", "flood evacuation")
        limit: Maximum number of volunteers to return

    Returns:
        dict with matched volunteers including name, skills, contact, location, and relevance score.
    """
    try:
        rows = _run_query("""
            SELECT volunteer_id, name, skills, contact_phone,
                   availability_status, location,
                   1 - (skills_embedding <=> embedding('text-embedding-005', :skill)::vector) AS relevance_score
            FROM volunteers
            WHERE availability_status = 'available'
              AND skills_embedding IS NOT NULL
            ORDER BY relevance_score DESC
            LIMIT :limit
        """, {"skill": skill_needed, "limit": limit})
        logging.info(f"[AlloyDB] find_matching_volunteers('{skill_needed}') -> {len(rows)} results")
        return {"volunteers": rows, "count": len(rows), "skill_searched": skill_needed}
    except Exception as e:
        logging.error(f"[AlloyDB] find_matching_volunteers error: {e}")
        return {"status": "error", "message": str(e)}


def get_relevant_tasks_with_vibe_check(
    situation_summary: str, crisis_type: str
) -> dict:
    """Uses AlloyDB ai.if() for semantic filtering - the 'vibe check'.

    Gemini reasons INSIDE the database to determine which emergency tasks
    are actually relevant to THIS specific situation, not just the general
    crisis type. This is the Track 3 highlight feature.

    Args:
        situation_summary: Description of the current situation (e.g., "Typhoon approaching Manila, 150km/h winds, family with infant in coastal area")
        crisis_type: Type of crisis for initial filtering

    Returns:
        dict with only the tasks that Gemini determined are relevant to the specific situation.
    """
    try:
        rows = _run_query("""
            SELECT task_id, task_description, priority, category, phase
            FROM emergency_tasks
            WHERE (LOWER(crisis_type) = LOWER(:crisis_type) OR crisis_type = 'general')
              AND ai.if(
                prompt => 'Given this emergency situation: "' || :situation || '", is this task relevant and actionable right now: "' || task_description || '"? Answer only true or false.',
                model_id => 'gemini-2.5-flash'
              )
            ORDER BY priority ASC
        """, {"crisis_type": crisis_type, "situation": situation_summary})
        logging.info(f"[AlloyDB] vibe_check('{crisis_type}', situation) -> {len(rows)} relevant tasks")
        return {
            "relevant_tasks": rows,
            "count": len(rows),
            "crisis_type": crisis_type,
            "situation": situation_summary,
        }
    except Exception as e:
        logging.error(f"[AlloyDB] vibe_check error: {e}")
        return {"status": "error", "message": str(e)}
