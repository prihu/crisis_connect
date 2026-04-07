"""CrisisConnect: Multi-Agent Disaster Preparedness & Community Resilience Platform.

Architecture:
  root_agent (orchestrator)
    └── crisis_assessment_workflow (SequentialAgent)
          ├── situation_analyzer    [Track 2: BigQuery + GDACS RSS]
          ├── resource_locator      [Track 2: Maps API + Track 3: AlloyDB vectors]
          ├── action_planner        [Track 3: AlloyDB ai.if() vibe checks]
          └── response_coordinator  [Track 1: ADK formatting]
"""

import os
import time
import logging
import feedparser
from dotenv import load_dotenv

from google.adk.agents import Agent, SequentialAgent
from google.adk.tools.tool_context import ToolContext

from . import tools
from . import alloydb_tools

import logging
import asyncio

# Force the ADK to print the actual sub-exception instead of swallowing it
logging.getLogger("google.adk").setLevel(logging.DEBUG)
asyncio.get_event_loop().set_debug(True)

# --- Setup ---
load_dotenv()
model_name = os.getenv("MODEL", "gemini-2.5-flash")
project_id = os.getenv("GOOGLE_CLOUD_PROJECT", "crisis-connect-hackathon")

# --- Track 2: BigQuery MCP or direct API ---
# MCP toolset is available via tools.get_bigquery_mcp_toolset() using
# McpToolset + StreamableHTTPConnectionParams (see tools.py).
# For demo reliability, we use direct API by default since MCP OAuth tokens
# expire after ~60 min. Set USE_BQ_MCP=1 in .env to enable MCP mode.
use_bq_mcp = os.getenv("USE_BQ_MCP", "1") == "1"
bigquery_mcp = None
if use_bq_mcp:
    try:
        bigquery_mcp = tools.get_bigquery_mcp_toolset()
        logging.info("[MCP] BigQuery remote MCP toolset loaded successfully")
    except Exception as e:
        use_bq_mcp = False
        logging.warning(f"[MCP] BigQuery MCP failed, using direct API: {e}")


# ============================================================
# TOOL FUNCTIONS
# ============================================================


def save_user_request(
    tool_context: ToolContext,
    query: str,
    location: str = "",
    crisis_type: str = "",
) -> dict:
    """Parses and saves the user's crisis query, location, and disaster type to shared state.

    Args:
        query: The user's full crisis-related question or request
        location: The geographic location mentioned (city, region, country). Example: "Quezon City, Manila" or "Tokyo"
        crisis_type: The type of disaster. One of: typhoon, earthquake, flood, tsunami, cyclone, wildfire, or empty if unknown
    """
    tool_context.state["user_query"] = query
    tool_context.state["user_location"] = location
    tool_context.state["crisis_type"] = crisis_type
    logging.info(
        f"[State] query={query}, location={location}, crisis_type={crisis_type}"
    )
    return {
        "status": "saved",
        "query": query,
        "location": location,
        "crisis_type": crisis_type,
    }


_gdacs_cache = {"feed": None, "ts": 0}
_GDACS_TTL = 600  # 10 minutes


def fetch_gdacs_alerts(tool_context: ToolContext) -> dict:
    """Fetches current disaster alerts from the GDACS (Global Disaster Alert and Coordination System) RSS feed.

    Filters alerts by the user's location and crisis type from shared state.
    Returns up to 5 most relevant current disaster alerts worldwide.
    """
    _GDACS_FEEDS = [
        "https://www.gdacs.org/xml/rss_24h.xml",
        "https://www.gdacs.org/xml/rss_7d.xml",
    ]
    now = time.time()
    if _gdacs_cache["feed"] is None or now - _gdacs_cache["ts"] > _GDACS_TTL:
        all_entries = []
        for feed_url in _GDACS_FEEDS:
            try:
                parsed = feedparser.parse(feed_url)
                all_entries.extend(parsed.entries)
            except Exception:
                pass
        # Deduplicate by link
        seen = set()
        unique = []
        for e in all_entries:
            link = e.get("link", "")
            if link not in seen:
                seen.add(link)
                unique.append(e)
        _gdacs_cache["feed"] = type("Feed", (), {"entries": unique})()
        _gdacs_cache["ts"] = now
    feed = _gdacs_cache["feed"]
    location = tool_context.state.get("user_location", "").lower()
    crisis_type = tool_context.state.get("crisis_type", "").lower()

    # Synonym mapping for broader matching
    _crisis_synonyms = {
        "typhoon": ["typhoon", "tropical cyclone", "cyclone", "hurricane", "storm"],
        "earthquake": ["earthquake", "seismic", "quake"],
        "flood": ["flood", "flooding", "inundation"],
        "tsunami": ["tsunami", "tidal wave"],
        "cyclone": ["cyclone", "tropical cyclone", "typhoon", "hurricane", "storm"],
        "wildfire": ["wildfire", "forest fire", "bushfire", "fire"],
    }
    # Location synonyms (city → country mapping for broader matching)
    _location_countries = {
        "manila": "philippines", "quezon city": "philippines", "cebu": "philippines",
        "tokyo": "japan", "osaka": "japan",
        "mumbai": "india", "delhi": "india", "chennai": "india",
        "jakarta": "indonesia", "dhaka": "bangladesh", "bangkok": "thailand",
    }

    search_terms = []
    if crisis_type:
        search_terms.extend(_crisis_synonyms.get(crisis_type, [crisis_type]))
    if location:
        search_terms.append(location)
        # Also search by country name
        for city, country in _location_countries.items():
            if city in location:
                search_terms.append(country)

    alerts = []
    for entry in feed.entries[:30]:
        alert = {
            "title": entry.get("title", ""),
            "summary": entry.get("summary", ""),
            "published": entry.get("published", ""),
            "link": entry.get("link", ""),
        }
        text_content = (alert["title"] + " " + alert["summary"]).lower()

        if not search_terms:
            alerts.append(alert)  # No filter, return all
        elif any(term in text_content for term in search_terms):
            alerts.append(alert)

    top_alerts = alerts[:5]
    tool_context.state["gdacs_alerts"] = top_alerts
    logging.info(f"[GDACS] Found {len(alerts)} alerts, returning top {len(top_alerts)}")
    return {"alerts_found": len(alerts), "top_alerts": top_alerts}


# ============================================================
# AGENT 1: SITUATION ANALYZER
# [Track 2: BigQuery + GDACS RSS]
# ============================================================
# Build situation_analyzer tools + instruction based on MCP availability
# When MCP is enabled, include BOTH MCP tools and direct API as backup
if use_bq_mcp:
    _sa_tools = [fetch_gdacs_alerts, bigquery_mcp, tools.query_bigquery]
    _sa_bq_instruction = (
        "2. PREFERRED: Use BigQuery MCP tools (execute_sql_readonly, get_table_info, list_table_ids) to query project "
        + project_id + ", dataset crisis_connect.\n"
        "   BACKUP: If MCP tools fail or error, use query_bigquery instead with full SQL.\n"
        '   Example query: "SELECT event_type, severity, description, affected_population, status '
        "FROM `" + project_id + ".crisis_connect.disaster_alerts` "
        "WHERE LOWER(country) LIKE LOWER('%' || '{user_location}' || '%') ORDER BY event_date DESC LIMIT 5\"\n"
        "   Also query: community_demographics (population, hospitals, shelter_capacity) and historical_disasters (lessons learned)."
    )
else:
    _sa_tools = [fetch_gdacs_alerts, tools.query_bigquery]
    _sa_bq_instruction = (
        "2. Use query_bigquery to run SQL. Example queries:\n"
        "   SELECT event_type, severity, description, affected_population, status\n"
        "   FROM `" + project_id + ".crisis_connect.disaster_alerts`\n"
        "   WHERE LOWER(country) LIKE LOWER('%' || '{user_location}' || '%')\n"
        "   ORDER BY event_date DESC LIMIT 5\n"
        "   Also query: community_demographics and historical_disasters tables."
    )

situation_analyzer = Agent(
    name="situation_analyzer",
    model=model_name,
    description="Analyzes the current disaster situation using live alerts, historical data, and demographics.",
    instruction=(
        "You are a disaster situation analyst. Call tools, then output ONE brief report.\n\n"
        "Tools:\n"
        "1. fetch_gdacs_alerts - Get live disaster alerts\n"
        + _sa_bq_instruction + "\n\n"
        "RULES:\n"
        "- Call ALL tools FIRST. Do NOT output ANY text between tool calls.\n"
        "- After ALL tools return, output exactly ONE compact data block with sections: ALERTS, HISTORY, DEMOGRAPHICS, LESSONS.\n"
        "- Include ALL GDACS alerts returned (title + severity). If none, say 'None for this area'.\n"
        "- Max 10 lines total. No prose, no explanations. Raw data only.\n\n"
        "USER QUERY: {user_query}\n"
        "LOCATION: {user_location}\n"
        "CRISIS TYPE: {crisis_type}\n"
    ),
    tools=_sa_tools,
    output_key="situation_report",
)


# ============================================================
# AGENT 2: RESOURCE LOCATOR
# [Track 2: Maps API + Track 3: AlloyDB semantic search]
# ============================================================
resource_locator = Agent(
    name="resource_locator",
    model=model_name,
    description="Finds community resources, matching volunteers, shelters, hospitals, and evacuation routes.",
    instruction="""You are a resource locator. You MUST call ALL 4 tool types. Be CONCISE.

MANDATORY steps (call tools in this order):
1. search_community_resources - Search with a query matching the crisis need (e.g. "drinking water", "first aid supplies", "baby formula")
2. find_matching_volunteers - Search with skills matching the crisis (e.g. "flood rescue", "medical care", "search and rescue")
3. search_nearby_places - Search for "emergency shelter near {user_location}" AND "hospital near {user_location}"
4. get_directions - Get route from {user_location} to the nearest shelter found in step 3

OUTPUT FORMAT: One compact data block. Max 10 lines. No prose. Raw data only.

SITUATION REPORT: {situation_report}
USER QUERY: {user_query}
LOCATION: {user_location}
CRISIS TYPE: {crisis_type}
""",
    tools=[
        alloydb_tools.search_community_resources,
        alloydb_tools.find_matching_volunteers,
        tools.search_nearby_places,
        tools.get_directions,
    ],
    output_key="resource_data",
)


# ============================================================
# AGENT 3: ACTION PLANNER
# [Track 3: AlloyDB ai.if() semantic filtering]
# ============================================================
action_planner = Agent(
    name="action_planner",
    model=model_name,
    description="Creates a prioritized emergency action plan using intelligent checklists filtered by AI.",
    instruction="""You are an emergency action planner. Be CONCISE.

Tools:
1. get_relevant_tasks_with_vibe_check - Uses AlloyDB ai.if() to semantically filter relevant tasks (Gemini reasons INSIDE the database)

Steps:
1. Call get_relevant_tasks_with_vibe_check with a 1-sentence situation summary and the crisis_type.
2. Output ONLY a short bullet list grouping the filtered tasks into:
   - IMMEDIATE (1hr): life-safety
   - SHORT-TERM (6hrs): resources, comms
   - ONGOING (48hrs): recovery

OUTPUT FORMAT: One compact data block. Max 8 lines. No prose. Raw task list only.

SITUATION REPORT: {situation_report}
RESOURCE DATA: {resource_data}
CRISIS TYPE: {crisis_type}
USER QUERY: {user_query}
""",
    tools=[
        alloydb_tools.get_relevant_tasks_with_vibe_check,
    ],
    output_key="action_plan",
)


# ============================================================
# AGENT 4: RESPONSE COORDINATOR
# [Track 1: ADK Agent - synthesis and formatting]
# ============================================================
response_coordinator = Agent(
    name="response_coordinator",
    model=model_name,
    description="Synthesizes all gathered intelligence into a unified, actionable crisis response.",
    instruction="""You are the CrisisConnect response coordinator. Take ALL the gathered
intelligence and present it as a clear, calm, actionable response.

Format your response EXACTLY as:

## Current Situation
**Live Alerts (GDACS):** [List any active GDACS alerts with severity - this data comes from the situation report]
**Historical Context:** [Past disasters, demographics, lessons learned from situation report]

## Nearby Emergency Services
**Shelters:**
[List shelters with addresses, distances, capacity if available]

**Hospitals:**
[List hospitals with addresses and distances]

**Evacuation Route:**
[Route summary with Google Maps link if available]

## Community Resources Available
[Matched resources from neighbors - what they have, quantity, contact info, address]
[Highlight semantic matches: e.g., if user needs "baby supplies" and match is "infant formula"]

## Volunteers Ready to Help
[Matched volunteers with names, skills, contact info, location]

## Your Action Plan
**DO NOW (next 1 hour):**
- [ ] Task 1 (with matched resource/volunteer if applicable)
- [ ] Task 2

**NEXT 6 HOURS:**
- [ ] Task 3
- [ ] Task 4

**NEXT 48 HOURS:**
- [ ] Task 5
- [ ] Task 6

## Emergency Contacts
- Local Emergency: [country-specific number]
- National Disaster Agency: [if known]
- CrisisConnect Tip: Stay calm, follow your action plan, help your neighbors.

IMPORTANT: Be calm, clear, and action-oriented. Lives may depend on this response.
Include clickable Google Maps links where available.
Present the most critical information FIRST.

SITUATION REPORT: {situation_report}
RESOURCE DATA: {resource_data}
ACTION PLAN: {action_plan}
USER QUERY: {user_query}
LOCATION: {user_location}
""",
)


# ============================================================
# SEQUENTIAL WORKFLOW
# ============================================================
crisis_assessment_workflow = SequentialAgent(
    name="crisis_assessment_workflow",
    description="Full crisis assessment pipeline: analyze situation -> locate resources -> plan actions -> coordinate response.",
    sub_agents=[
        situation_analyzer,
        resource_locator,
        action_planner,
        response_coordinator,
    ],
)


# ============================================================
# ROOT AGENT
# ============================================================
root_agent = Agent(
    name="crisis_connect",
    model=model_name,
    description="CrisisConnect: Multi-Agent Disaster Preparedness & Community Resilience Platform for APAC",
    instruction="""You are CrisisConnect, an AI-powered disaster preparedness and community
resilience assistant built for APAC communities.

You help with THREE phases of disaster management:
- **BEFORE**: Preparedness checklists, community resource mapping, risk assessment
- **DURING**: Real-time alerts, evacuation routes, resource matching, emergency contacts
- **AFTER**: Recovery task tracking, damage assessment, community support coordination

When a user describes a crisis situation or asks for disaster-related help:
1. Use save_user_request to extract and save:
   - query: Their full question/situation description
   - location: The geographic location (city, region, country)
     Examples: "Quezon City, Manila", "Tokyo", "Mumbai", "Jakarta", "Dhaka"
   - crisis_type: The disaster type
     Valid types: typhoon, earthquake, flood, tsunami, cyclone, wildfire
2. After saving, IMMEDIATELY transfer control to the crisis_assessment_workflow.

If the user is just greeting you or asking what you can do:
- Introduce yourself as CrisisConnect
- Explain you can help with disaster preparedness, real-time crisis response, and recovery
- Ask them to describe their situation, location, and what kind of disaster they're facing

Be calm, professional, and action-oriented. In a crisis, clarity saves lives.
""",
    tools=[save_user_request],
    sub_agents=[crisis_assessment_workflow],
)
