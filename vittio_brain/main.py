# vittio_brain/main.py
from fastapi import FastAPI, HTTPException, Security, Depends
from fastapi.security.api_key import APIKeyHeader
from auditor_agent import run_audit
from models import AuditResponse
from pydantic import BaseModel
import os

app = FastAPI(title="Vittio Brain API")

# Simple API Key for local security
API_KEY = os.getenv("BRAIN_API_KEY", "vittio_secret_dev_key")
api_key_header = APIKeyHeader(name="X-Brain-Token")

def get_api_key(api_key: str = Security(api_key_header)):
    if api_key != API_KEY:
        raise HTTPException(status_code=403, detail="Could not validate credentials")
    return api_key

class AuditRequest(BaseModel):
    raw_text: str
    user_id: int  # Accept user_id from Rails

@app.post("/audit", response_model=AuditResponse)
async def audit_endpoint(request: AuditRequest, api_key: str = Depends(get_api_key)):
    try:
        # Hand off text AND user_id to the agent
        result = await run_audit(request.raw_text, request.user_id)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
