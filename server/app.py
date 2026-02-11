import os
import json
import time
import logging
import secrets
import ipaddress
import io
import zipfile
import pathlib
from pathlib import Path
from threading import Lock

from fastapi import FastAPI, Header, HTTPException, Depends, Request, Form, status
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse, StreamingResponse
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from pydantic import BaseModel

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("yemekbildirimi")

app = FastAPI(docs_url=None, redoc_url=None)

# -----------------------------------------------------------------------------
# Persistent State (prevents ID resets across restarts)
# -----------------------------------------------------------------------------
DATA_DIR = Path(os.getenv("DATA_DIR", "/app/data"))
STATE_FILE = DATA_DIR / "state.json"
_state_lock = Lock()


def _default_state() -> dict:
    return {
        "last_id": 0,
        "latest": {"id": 0, "ts": time.time(), "text": "Sistem başlatıldı."},
    }


def load_state() -> dict:
    try:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        if STATE_FILE.exists():
            return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except Exception as e:
        logger.warning(f"STATE LOAD FAILED: {e}")
    return _default_state()


def save_state(state: dict) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    tmp = STATE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, ensure_ascii=False), encoding="utf-8")
    tmp.replace(STATE_FILE)


STATE = load_state()
try:
    with _state_lock:
        save_state(STATE)
except Exception as e:
    logger.warning(f"STATE INIT SAVE FAILED: {e}")

# -----------------------------------------------------------------------------
# Configuration (backward compatible)
# -----------------------------------------------------------------------------
API_KEY = os.getenv("YEMEK_API_KEY") or os.getenv("API_KEY")  # optional legacy

# Prefer PANEL_*, fallback to AUTH_* (older installs), then defaults
PANEL_USER = os.getenv("PANEL_USER") or os.getenv("AUTH_USER") or "admin"
PANEL_PASS = os.getenv("PANEL_PASS") or os.getenv("AUTH_PASS") or "admin"

PANEL_ALLOWED_IPS_STR = os.getenv("PANEL_ALLOWED_IPS", "").strip()

security = HTTPBasic()


class NotifyRequest(BaseModel):
    text: str


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
last_notification_time: float = 0.0


def get_client_ip(request: Request) -> str:
    return request.client.host


def check_ip_allowed(request: Request):
    if not PANEL_ALLOWED_IPS_STR:
        return

    client_ip = get_client_ip(request)
    allowed_list = [x.strip() for x in PANEL_ALLOWED_IPS_STR.split(",") if x.strip()]
    if not allowed_list:
        return

    try:
        ip_obj = ipaddress.ip_address(client_ip)
    except ValueError:
        logger.warning(f"Access Denied (Invalid IP): {client_ip}")
        raise HTTPException(status_code=403, detail="Access denied")

    for rule in allowed_list:
        try:
            if "/" in rule:
                if ip_obj in ipaddress.ip_network(rule, strict=False):
                    return
            else:
                if str(ip_obj) == rule:
                    return
        except ValueError:
            logger.warning(f"Invalid Allowlist Rule: {rule}")
            continue

    logger.warning(f"Access Denied (IP Blocked): {client_ip} | allowlist={PANEL_ALLOWED_IPS_STR}")
    raise HTTPException(status_code=403, detail="Access denied")


def verify_api_key(x_api_key: str = Header(...)):
    # If API_KEY is not set, fail closed (safer)
    if not API_KEY:
        raise HTTPException(status_code=500, detail="Server API key is not configured")
    if x_api_key != API_KEY:
        logger.warning("Access Denied (Invalid API Key)")
        raise HTTPException(status_code=401, detail="Invalid API Key")
    return x_api_key


def verify_panel_auth(credentials: HTTPBasicCredentials = Depends(security)):
    c_user = credentials.username.encode("utf-8")
    c_pass = credentials.password.encode("utf-8")
    t_user = PANEL_USER.encode("utf-8")
    t_pass = PANEL_PASS.encode("utf-8")

    if not (secrets.compare_digest(c_user, t_user) and secrets.compare_digest(c_pass, t_pass)):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Basic"},
        )
    return credentials.username


def check_spam():
    global last_notification_time
    now = time.time()
    if now - last_notification_time < 2:
        raise HTTPException(status_code=429, detail="Lütfen biraz bekleyin (Rate Limit).")


def do_notify(text: str, source: str) -> int:
    global last_notification_time
    now = time.time()

    with _state_lock:
        if "last_id" not in STATE or "latest" not in STATE:
            STATE.clear()
            STATE.update(_default_state())

        STATE["last_id"] = int(STATE.get("last_id", 0)) + 1
        new_id = STATE["last_id"]
        STATE["latest"] = {"id": new_id, "ts": now, "text": text}
        save_state(STATE)

    last_notification_time = now
    logger.info(f"NOTIFICATION TRIGGERED | Source={source} | ID={new_id} | Text={text}")
    return new_id


def get_latest_state() -> dict:
    with _state_lock:
        latest = STATE.get("latest") or _default_state()["latest"]
        return {
            "id": int(latest.get("id", 0)),
            "ts": float(latest.get("ts", time.time())),
            "text": str(latest.get("text", "")),
        }


# -----------------------------------------------------------------------------
# Endpoints
# -----------------------------------------------------------------------------
@app.get("/health")
async def health_check():
    return {"ok": True}


@app.get("/latest")
async def get_latest():
    data = get_latest_state()
    return JSONResponse(content=data, media_type="application/json; charset=utf-8")


@app.post("/notify")
async def notify(body: NotifyRequest, api_key: str = Depends(verify_api_key)):
    check_spam()
    new_id = do_notify(body.text, source="API")
    return {"ok": True, "id": new_id}


@app.get("/download/client.zip")
async def download_client():
    client_path = pathlib.Path("client_payload")
    if not client_path.exists() or not client_path.is_dir():
        raise HTTPException(status_code=404, detail="Client files not found on server")

    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as zip_file:
        for root, _, files in os.walk(client_path):
            for file in files:
                file_path = pathlib.Path(root) / file
                relative_path = file_path.relative_to(client_path)
                zip_file.write(file_path, arcname=str(relative_path))

    buffer.seek(0)
    headers = {"Content-Disposition": 'attachment; filename="client.zip"'}
    return StreamingResponse(buffer, media_type="application/zip", headers=headers)


@app.get("/panel", response_class=HTMLResponse)
async def panel(request: Request, username: str = Depends(verify_panel_auth)):
    check_ip_allowed(request)

    latest = get_latest_state()
    current_id = latest["id"]
    current_text = latest["text"]

    html = f"""
    <!DOCTYPE html>
    <html lang="tr">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Yemek Bildirimi</title>
        <style>
            body {{ font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #f7fafc; margin: 0; }}
            .card {{ background: white; padding: 2rem; border-radius: 12px; box-shadow: 0 5px 15px rgba(0,0,0,0.1); width: 100%; max-width: 400px; text-align: center; }}
            h1 {{ color: #2d3748; margin-bottom: 1.5rem; }}
            input[type="text"] {{ width: 100%; padding: 12px; margin-bottom: 1rem; border: 2px solid #edf2f7; border-radius: 8px; font-size: 1rem; box-sizing: border-box; }}
            button {{ width: 100%; padding: 15px; background-color: #e53e3e; color: white; border: none; border-radius: 8px; font-size: 1.2rem; font-weight: bold; cursor: pointer; transition: background 0.2s; }}
            button:hover {{ background-color: #c53030; }}
            .status {{ margin-top: 1.5rem; padding-top: 1rem; border-top: 1px solid #edf2f7; color: #718096; font-size: 0.9rem; }}
            .links {{ margin-top: 1rem; font-size: 0.85rem; }}
            .links a {{ color: #3182ce; text-decoration: none; }}
            .links a:hover {{ text-decoration: underline; }}
        </style>
    </head>
    <body>
        <div class="card">
            <h1>🍽️ Yemek Bildirimi</h1>
            <form action="/panel/notify" method="post">
                <input type="text" name="text" value="🍽️ Yemek geldi! Afiyet olsun." placeholder="Mesajınız...">
                <button type="submit">YEMEK GELDİ! 🔔</button>
            </form>
            <div class="status">
                <div>Son Bildirim (ID: {current_id}):</div>
                <div style="color: #2d3748; font-weight: 500;">{current_text}</div>
            </div>
            <div class="links">
                <a href="/download/client.zip">📥 Client Dosyalarını İndir (.zip)</a>
            </div>
        </div>
    </body>
    </html>
    """
    return html


@app.post("/panel/notify")
async def panel_notify(
    request: Request,
    text: str = Form(...),
    username: str = Depends(verify_panel_auth),
):
    check_ip_allowed(request)
    try:
        check_spam()
        do_notify(text, source="Panel")
        return RedirectResponse(url="/panel", status_code=status.HTTP_303_SEE_OTHER)
    except HTTPException as e:
        if e.status_code == 429:
            return HTMLResponse(
                content=(
                    "<h2 style='text-align:center;font-family:sans-serif'>"
                    f"⏳ Aşırı yüklenme. {e.detail}"
                    "</h2><p style='text-align:center'><a href='/panel'>Geri Dön</a></p>"
                ),
                status_code=429,
            )
        raise e


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8787, log_level="info")
