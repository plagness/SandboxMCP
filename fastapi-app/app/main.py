import os
from pathlib import Path

import httpx
import yaml
from fastapi import FastAPI, HTTPException

BASE_DIR = Path(__file__).resolve().parent.parent
POLICY_FILE = Path(os.getenv("POLICY_FILE", BASE_DIR.parent / "policy" / "decision.yaml"))
COMPUTER_HOST = os.getenv("COMPUTER_SERVER_HOST", "127.0.0.1")
COMPUTER_PORT = int(os.getenv("COMPUTER_SERVER_PORT", "8000"))
COMPUTER_PATH = os.getenv("COMPUTER_SERVER_HEALTH_ENDPOINT", "/health")

app = FastAPI()


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/cua/health")
async def cua_health():
    url = f"http://{COMPUTER_HOST}:{COMPUTER_PORT}{COMPUTER_PATH}"
    async with httpx.AsyncClient(timeout=5.0) as client:
        try:
            response = await client.get(url)
        except httpx.HTTPError as exc:  # pragma: no cover - network exception path
            raise HTTPException(status_code=503, detail=str(exc)) from exc

    return {
        "up": response.status_code < 500,
        "status": response.status_code,
        "body": response.text,
        "url": url,
    }


@app.get("/policy")
def policy():
    if not POLICY_FILE.exists():
        raise HTTPException(status_code=404, detail=f"Policy file not found: {POLICY_FILE}")

    with POLICY_FILE.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle)

    return _expand_env(data)
def _expand_env(value):
    if isinstance(value, str):
        return os.path.expandvars(value)
    if isinstance(value, list):
        return [_expand_env(item) for item in value]
    if isinstance(value, dict):
        return {key: _expand_env(val) for key, val in value.items()}
    return value
