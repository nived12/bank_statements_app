# vittio_brain/auditor_agent.py
import os
import httpx
from pydantic_ai import Agent, RunContext
from models import AuditResponse
from dotenv import load_dotenv

load_dotenv()

AI_MODEL = os.getenv("AI_MODEL", "gemini-3.1-flash-lite-preview")
FLASH_MODEL = f"google-gla:{AI_MODEL}"

# 1. Define the Tool to fetch categories from your Rails API
async def fetch_user_categories(ctx: RunContext[int]) -> str:
    """Fetches the available financial categories for the current user from the Rails API."""
    user_id = ctx.deps  # This is the user_id passed during run_audit
    internal_token = os.getenv("BRAIN_API_KEY", "")
    async with httpx.AsyncClient() as client:
        try:
            # We use the internal network address for Rails
            response = await client.get(
                f"http://localhost:3000/api/v1/categories",
                headers={
                    "X-Internal-Service-Token": internal_token,
                    "X-User-Id": str(user_id),
                },
                timeout=10.0
            )
            return response.text
        except Exception as e:
            return f"Error fetching categories: {str(e)}"

# 2. Update the Agent to include dependencies and the tool
auditor_agent = Agent(
    FLASH_MODEL,
    output_type=AuditResponse,
    deps_type=int, # We use the user_id as our dependency
    system_prompt=(
        "You are a Senior Financial Auditor for Vittio. "
        "Your goal is to extract transactions from raw bank statement text. "
        "You MUST ALWAYS call the 'fetch_user_categories' tool before finalizing any transaction, "
        "so you can see the exact list of categories available for this user. "
        "For every transaction, you MUST map it to a numeric category_id taken from that fetched list. "
        "If there is no perfect category match, you MUST use your best reasoning to pick the closest category_id; "
        "only leave category_id null if there is truly no even loosely appropriate category. "
        "Ensure descriptions are cleaned of weird bank codes. "
        "Always set a confidence score from 0 to 1 for each transaction. "
    "If confidence is below 0.8, you MUST set audit_note explaining your reasoning."
    ),
)

# Register the tool with the agent
auditor_agent.tool(fetch_user_categories)

async def run_audit(raw_text: str, user_id: int):
    # Pass the user_id into the run context as 'deps'
    result = await auditor_agent.run(raw_text, deps=user_id)
    return result.output
