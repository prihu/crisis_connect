"""CrisisConnect Tools: BigQuery via MCP Toolbox (Track 2) + Google Maps Direct API.

BigQuery uses MCP Toolbox for Databases (github.com/googleapis/genai-toolbox)
running as a local sidecar server. Handles auth, connection pooling automatically.
Maps uses direct API calls. Direct BigQuery API is kept as fallback.
"""

import os
import logging
import requests
from google.cloud import bigquery

# --- Cached clients ---
_bq_client = None
_maps_api_key = os.getenv("GOOGLE_MAPS_API_KEY", "")


def _get_bq_client():
    global _bq_client
    if _bq_client is None:
        project_id = os.getenv("GOOGLE_CLOUD_PROJECT", "crisis-connect-hackathon")
        _bq_client = bigquery.Client(project=project_id)
    return _bq_client


# ============================================================
# TRACK 2: BigQuery via MCP Toolbox for Databases
# ============================================================
# MCP Toolbox (github.com/googleapis/genai-toolbox) runs as a local
# sidecar server on port 5000. It handles auth, connection pooling,
# and provides prebuilt BigQuery tools (execute_sql, list_tables, etc).
# No manual OAuth token management needed.

_TOOLBOX_URL = os.getenv("TOOLBOX_URL", "http://127.0.0.1:5000")


def get_bigquery_mcp_toolset():
    """Creates an MCP toolset connected to local MCP Toolbox server.

    MCP Toolbox handles BigQuery auth via Application Default Credentials.
    Returns tools: execute_sql, list_tables, get_table_info, etc.
    """
    from google.adk.tools.mcp_tool.mcp_toolset import McpToolset, StreamableHTTPConnectionParams

    logging.info(f"[MCP Toolbox] Connecting to {_TOOLBOX_URL}/mcp")
    return McpToolset(
        connection_params=StreamableHTTPConnectionParams(
            url=f"{_TOOLBOX_URL}/mcp",
        )
    )


# ============================================================
# FALLBACK: Direct BigQuery API (if MCP unavailable)
# ============================================================

def query_bigquery(sql: str) -> dict:
    """Executes a SQL query against BigQuery and returns the results.

    Use this to query the crisis_connect dataset which contains:
    - disaster_alerts: Current and historical disaster events in APAC
    - community_demographics: Population, hospitals, shelters by region
    - historical_disasters: Past disasters with lessons learned

    Args:
        sql: The BigQuery SQL query to execute. Always use fully qualified table names
             like `crisis-connect-hackathon.crisis_connect.table_name`
    """
    try:
        client = _get_bq_client()
        query_job = client.query(sql)
        results = query_job.result()
        rows = [dict(row) for row in results]
        logging.info(f"[BigQuery] Query returned {len(rows)} rows")
        return {"status": "success", "row_count": len(rows), "rows": rows[:20]}
    except Exception as e:
        logging.error(f"[BigQuery] Error: {e}")
        return {"status": "error", "message": str(e)}


# ============================================================
# Google Maps Direct API (Maps MCP server is unstable)
# ============================================================

def search_nearby_places(query: str, location: str) -> dict:
    """Searches for nearby places using Google Maps Places API.

    Use this to find emergency shelters, hospitals, evacuation centers near a location.

    Args:
        query: What to search for. Examples: "emergency shelter", "hospital", "evacuation center"
        location: The location to search near. Examples: "Quezon City, Manila", "Tokyo, Japan"
    """
    try:
        url = "https://places.googleapis.com/v1/places:searchText"
        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": _maps_api_key,
            "X-Goog-FieldMask": "places.displayName,places.formattedAddress,places.location,places.googleMapsUri",
        }
        payload = {"textQuery": f"{query} near {location}", "maxResultCount": 5}
        response = requests.post(url, headers=headers, json=payload, timeout=10)
        response.raise_for_status()
        data = response.json()

        places = [
            {
                "name": p.get("displayName", {}).get("text", "Unknown"),
                "address": p.get("formattedAddress", ""),
                "maps_link": p.get("googleMapsUri", ""),
                "lat": p.get("location", {}).get("latitude"),
                "lng": p.get("location", {}).get("longitude"),
            }
            for p in data.get("places", [])
        ]
        logging.info(f"[Maps] Found {len(places)} places for '{query}' near '{location}'")
        return {"status": "success", "places_found": len(places), "places": places}
    except Exception as e:
        logging.error(f"[Maps] search_nearby_places error: {e}")
        return {"status": "error", "message": str(e)}


def get_directions(origin: str, destination: str) -> dict:
    """Gets driving directions and route information between two locations using Google Maps.

    Returns distance, duration, and a Google Maps link for the route.

    Args:
        origin: Starting location. Example: "Quezon City, Manila"
        destination: Destination. Example: "Philippine International Convention Center, Manila"
    """
    try:
        url = "https://maps.googleapis.com/maps/api/directions/json"
        params = {"origin": origin, "destination": destination, "key": _maps_api_key, "mode": "driving"}
        response = requests.get(url, params=params, timeout=10)
        data = response.json()

        if data.get("status") != "OK" or not data.get("routes"):
            return {"status": "no_route", "message": f"No route found: {data.get('status')}"}

        leg = data["routes"][0]["legs"][0]
        maps_link = f"https://www.google.com/maps/dir/{origin.replace(' ', '+')}/{destination.replace(' ', '+')}"

        return {
            "status": "success",
            "distance": leg.get("distance", {}).get("text", ""),
            "duration": leg.get("duration", {}).get("text", ""),
            "start_address": leg.get("start_address", ""),
            "end_address": leg.get("end_address", ""),
            "maps_link": maps_link,
            "steps_summary": [s.get("html_instructions", "")[:100] for s in leg.get("steps", [])[:5]],
        }
    except Exception as e:
        logging.error(f"[Maps] get_directions error: {e}")
        return {"status": "error", "message": str(e)}
