from fastapi import FastAPI, HTTPException, Depends, Request, Form, Cookie, Response
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.middleware.cors import CORSMiddleware
import secrets
import uvicorn
import json
import logging
import dotenv
import os
import sys
from pathlib import Path
import re
import time
from typing import Optional
import hashlib
from starlette.responses import FileResponse

# Configure logging - avoid sensitive information in logs
logging.basicConfig(
    level=logging.INFO,  # Change from DEBUG to INFO
    format="%(asctime)s - %(levelname)s - %(message)s",  # Remove logger name
    handlers=[logging.StreamHandler()],
)
logger = logging.getLogger(__name__)

# Rate limiting data structure
login_attempts = {}
MAX_ATTEMPTS = 5
LOCKOUT_TIME = 300  # 5 minutes in seconds

# Load environment variables
root_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(root_dir)
env_file = os.path.join(root_dir, ".env")

if os.path.exists(env_file):
    env = dotenv.dotenv_values(env_file)
else:
    logger.error("Environment file not found")
    sys.exit(1)

sing_box_version = str(env.get("SING_BOX_VERSION"))
config_git_repo = str(env.get("CONFIG_GIT_REPO"))
config_git_hash = str(env.get("CONFIG_GIT_HASH"))
web_port = int(env.get("WEB_PORT", 7070))
session_secret = env.get("SESSION_SECRET", secrets.token_hex(32))
allowed_hosts = env.get("ALLOWED_HOSTS", "localhost").split(",")

release_files_dir = Path(f"./releases/sing-box-v{sing_box_version}-{config_git_hash}")
server_config_file = Path(f"./{config_git_repo}/server/trojan-server.json")

# Verify files directory exists and is accessible
if not release_files_dir.exists():
    raise FileNotFoundError("Required directory not found")
if not release_files_dir.is_dir():
    raise NotADirectoryError("Path is not a directory")

app = FastAPI()

# Add security middleware
app.add_middleware(TrustedHostMiddleware, allowed_hosts=allowed_hosts)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


# Custom StaticFiles to prevent directory listing
class SecureStaticFiles(StaticFiles):
    async def get_response(self, path, scope):
        response = await super().get_response(path, scope)
        if response.status_code == 404:
            raise HTTPException(status_code=404, detail="File not found")
        return response


# Mount the files directory with custom handler
app.mount("/files", SecureStaticFiles(directory=release_files_dir), name="files")

app.mount("/static", StaticFiles(directory="./static"), name="static")

# Setup templates
templates = Jinja2Templates(directory="./templates")

security = HTTPBasic()

# Username validation pattern
USERNAME_PATTERN = re.compile(r"^[a-zA-Z0-9_-]{3,32}$")


# Session management
def create_session_token(username: str) -> str:
    timestamp = str(int(time.time()))
    token_data = f"{username}:{timestamp}:{session_secret}"
    token_hash = hashlib.sha256(token_data.encode()).hexdigest()
    return f"{username}:{timestamp}:{token_hash}"


def validate_session_token(token: str) -> Optional[str]:
    try:
        username, timestamp, token_hash = token.split(":", 2)
        current_time = int(time.time())
        token_age = current_time - int(timestamp)

        # Session expires after 1 hour
        if token_age > 3600:
            return None

        expected_data = f"{username}:{timestamp}:{session_secret}"
        expected_hash = hashlib.sha256(expected_data.encode()).hexdigest()

        if secrets.compare_digest(token_hash, expected_hash):
            return username
        return None
    except:
        raise


# Load users with secure password comparison
def load_users():
    try:
        with open(server_config_file, "r") as file:
            data = json.load(file)
            users = {}
            for inbound in data.get("inbounds", []):
                if inbound.get("type") == "trojan":
                    for user in inbound.get("users", []):
                        # Validate username format
                        if USERNAME_PATTERN.match(user["name"]):
                            users[user["name"]] = user["password"]
            return users
    except FileNotFoundError:
        logger.error("Config file not found")
        return {}
    except json.JSONDecodeError:
        logger.error("Invalid config format")
        return {}
    except KeyError:
        logger.error("Unexpected config structure")
        return {}


# Load users when the application starts
USERS = load_users()


# Rate limiting function
def check_rate_limit(username: str, ip_address: str) -> bool:
    key = f"{username}:{ip_address}"
    current_time = time.time()

    if key in login_attempts:
        attempts, lockout_time = login_attempts[key]

        # Check if user is in lockout period
        if lockout_time and current_time < lockout_time:
            return False

        # Reset lockout if it has expired
        if lockout_time and current_time >= lockout_time:
            login_attempts[key] = (0, None)

        # Increment attempts
        login_attempts[key] = (attempts + 1, None)

        # If max attempts reached, set lockout time
        if attempts + 1 >= MAX_ATTEMPTS:
            login_attempts[key] = (attempts + 1, current_time + LOCKOUT_TIME)
            return False

    else:
        # First attempt
        login_attempts[key] = (1, None)

    return True


@app.get("/")
async def login_page(request: Request):
    return templates.TemplateResponse("login.html", {"request": request})


@app.post("/login")
async def handle_login(
    request: Request,
    response: Response,
    username: str = Form(...),
    password: str = Form(...),
):
    client_ip = request.client.host

    # Check rate limiting
    if not check_rate_limit(username, client_ip):
        logger.warning(f"Rate limit exceeded for IP: {client_ip}")
        return templates.TemplateResponse(
            "login.html",
            {"request": request, "error": "Too many attempts. Please try again later."},
        )

    # Validate username format
    if not USERNAME_PATTERN.match(username):
        logger.info("Invalid username format attempt")
        return templates.TemplateResponse(
            "login.html", {"request": request, "error": "Invalid username or password"}
        )

    # Check credentials
    if username in USERS and secrets.compare_digest(
        password.encode("utf8"), USERS[username].encode("utf8")
    ):
        logger.info("Successful login")

        # Create session
        session_token = create_session_token(username)
        response.set_cookie(
            key="session",
            value=session_token,
            httponly=True,
            secure=True,  # Enable in production with HTTPS
            samesite="lax",
            max_age=3600,
        )

        return await show_file_list(request, username)

    logger.info("Failed login attempt")
    return templates.TemplateResponse(
        "login.html", {"request": request, "error": "Invalid username or password"}
    )


async def get_file_list(username: str):
    # Safe pattern matching that avoids path traversal
    valid_files = []
    for f in release_files_dir.iterdir():
        if f.is_file() and f.name.endswith(f"{username}.tar.gz"):
            # Verify no directory traversal is possible in filename
            if ".." not in f.name and "/" not in f.name and "\\" not in f.name:
                valid_files.append({"name": f.name})

    return valid_files


@app.get("/files")
async def show_file_list(
    request: Request, username: str = None, session: Optional[str] = Cookie(None)
):
    # Verify session if username not provided
    if not username:
        if not session:
            return templates.TemplateResponse(
                "login.html", {"request": request, "error": "Session expired"}
            )

        username = validate_session_token(session)
        if not username:
            return templates.TemplateResponse(
                "login.html", {"request": request, "error": "Session expired"}
            )

    files = await get_file_list(username)
    return templates.TemplateResponse(
        "file_list.html", {"request": request, "files": files}
    )


@app.get("/files/{filename:path}")
async def download_file(
    request: Request, filename: str, session: Optional[str] = Cookie(None)
):
    # Verify session
    if not session:
        raise HTTPException(status_code=401, detail="Authentication required")

    username = validate_session_token(session)
    if not username:
        raise HTTPException(status_code=401, detail="Session expired")

    # Verify file belongs to the user
    if not filename.endswith(f"{username}.tar.gz"):
        raise HTTPException(status_code=403, detail="Access denied")

    # Prevent path traversal
    if ".." in filename or filename.startswith("/") or filename.startswith("\\"):
        raise HTTPException(status_code=400, detail="Invalid filename")

    file_path = release_files_dir / filename

    # Verify file exists
    if not file_path.exists() or not file_path.is_file():
        raise HTTPException(status_code=404, detail="File not found")

    return FileResponse(file_path)


@app.get("/auth")
async def authenticate(credentials: HTTPBasicCredentials = Depends(security)):
    username = credentials.username
    password = credentials.password

    # Validate username format
    if not USERNAME_PATTERN.match(username):
        raise HTTPException(
            status_code=401,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Basic"},
        )

    # Check if user exists and password matches
    if username in USERS and secrets.compare_digest(
        password.encode("utf8"), USERS[username].encode("utf8")
    ):
        return {"authenticated": True}

    raise HTTPException(
        status_code=401,
        detail="Invalid credentials",
        headers={"WWW-Authenticate": "Basic"},
    )


@app.get("/logout")
async def logout(response: Response):
    response.delete_cookie(key="session")
    return {"message": "Logged out successfully"}


if __name__ == "__main__":
    if not USERS:
        logger.warning("No users loaded! Authentication will fail for all requests.")
    else:
        logger.info("Authentication service started")

    # Use HTTPS in production
    uvicorn.run(app, host="0.0.0.0", port=web_port)
