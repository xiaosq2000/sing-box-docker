from fastapi import FastAPI, HTTPException, Depends, Request, Form
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import secrets
import uvicorn
import json
import logging
import dotenv
import os
import sys
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler()],
)
logger = logging.getLogger(__name__)


root_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(root_dir)
env_file = os.path.join(root_dir, ".env")

if os.path.exists(env_file):
    env = dotenv.dotenv_values(env_file)
else:
    logger.error(f"{env_file} does not exist")
    sys.exit(1)

sing_box_version = str(env.get("SING_BOX_VERSION"))
config_git_repo = str(env.get("CONFIG_GIT_REPO"))
config_git_hash = str(env.get("CONFIG_GIT_HASH"))

release_files_dir = Path(f"./releases/sing-box-v{sing_box_version}-{config_git_hash}")

server_config_file = Path(f"./{config_git_repo}/server/trojan-server.json")

# Verify files directory exists and is accessible
if not release_files_dir.exists():
    raise FileNotFoundError(f"Files directory not found: {release_files_dir}")
if not release_files_dir.is_dir():
    raise NotADirectoryError(f"Path is not a directory: {release_files_dir}")

app = FastAPI()

# Mount the files directory
app.mount("/files", StaticFiles(directory=release_files_dir), name="files")

# Setup templates
templates = Jinja2Templates(directory="./templates")

security = HTTPBasic()


def load_users():
    try:
        with open(
            server_config_file,
            "r",
        ) as file:
            data = json.load(file)
            # Extract users from the inbounds array
            users = {}
            for inbound in data.get("inbounds", []):
                if inbound.get("type") == "trojan":  # Check if it's a trojan inbound
                    for user in inbound.get("users", []):
                        users[user["name"]] = user["password"]
            return users
    except FileNotFoundError:
        logger.error(f"{server_config_file} is not found!")
        return {}
    except json.JSONDecodeError:
        logger.error(f"{server_config_file} is not valid JSON!")
        return {}
    except KeyError as e:
        logger.error(
            f"Unexpected JSON structure! Missing key: {e} for {server_config_file}"
        )
        return {}


# Load users when the application starts
USERS = load_users()


@app.get("/")
async def login_page(request: Request):
    return templates.TemplateResponse("login.html", {"request": request})


@app.post("/login")
async def handle_login(
    request: Request, username: str = Form(...), password: str = Form(...)
):
    logger.info(f"Login attempt for user: {username}")

    if username in USERS and secrets.compare_digest(
        password.encode("utf8"), USERS[username].encode("utf8")
    ):
        logger.info(f"Successful login for user: {username}")
        return await show_file_list(request, username)

    logger.info(f"Failed login attempt for user: {username}")
    return templates.TemplateResponse(
        "login.html", {"request": request, "error": "Invalid username or password"}
    )


async def get_file_list(username: str):
    pattern = f"*.{username}.tar.gz"
    logger.debug(
        f"Searching for files matching pattern: {pattern} in {release_files_dir}"
    )

    # List all files in directory for debugging
    all_files = [f.name for f in release_files_dir.iterdir() if f.is_file()]
    logger.debug(f"All files in directory: {all_files}")

    # Get matching files with full debug info
    matching_files = []
    for f in release_files_dir.iterdir():
        if f.is_file():
            # More precise matching
            matches = f.name.endswith(f"{username}.tar.gz")
            logger.debug(f"Checking file: {f.name} - matches pattern: {matches}")
            if matches:
                matching_files.append({"name": f.name})

    if not matching_files:
        logger.warning(f"No files found for user {username} in {release_files_dir}")
    else:
        logger.debug(f"Found files for user {username}: {matching_files}")

    return matching_files


@app.get("/files")
async def show_file_list(request: Request, username: str):
    files = await get_file_list(username)
    return templates.TemplateResponse(
        "file_list.html", {"request": request, "files": files}
    )


@app.get("/auth")
async def authenticate(credentials: HTTPBasicCredentials = Depends(security)):
    is_username_valid = secrets.compare_digest(
        credentials.username, credentials.username
    )
    is_password_valid = False

    if is_username_valid and credentials.username in USERS:
        is_password_valid = secrets.compare_digest(
            credentials.password.encode("utf8"),
            USERS[credentials.username].encode("utf8"),
        )

    if not (is_username_valid and is_password_valid):
        raise HTTPException(
            status_code=401,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Basic"},
        )

    return {"authenticated": True}


if __name__ == "__main__":
    if not USERS:
        logger.warning("No users loaded! Authentication will fail for all requests.")
    else:
        logger.info(f"Loaded {len(USERS)} users successfully")
    uvicorn.run(app, host="0.0.0.0", port=7070)
