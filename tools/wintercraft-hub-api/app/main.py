from __future__ import annotations

import base64
import hashlib
import hmac
import os
import re
import secrets
import sqlite3
from contextlib import contextmanager
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Iterator, Optional

from fastapi import Depends, FastAPI, Header, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

APP_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = Path(os.getenv("WINTERCRAFT_DATA_DIR", APP_DIR / "data"))
DB_PATH = Path(os.getenv("WINTERCRAFT_DB_PATH", DATA_DIR / "wintercraft-hub.sqlite3"))
PUBLIC_HOST = os.getenv("WINTERCRAFT_PUBLIC_HOST", "192.168.192.143")
PUBLIC_PORT = int(os.getenv("WINTERCRAFT_PUBLIC_PORT", "30000"))
STATIC_API_TOKEN = os.getenv("WINTERCRAFT_API_TOKEN", "").strip()
SESSION_DAYS = int(os.getenv("WINTERCRAFT_SESSION_DAYS", "90"))
PASSWORD_ITERATIONS = 390000
USERNAME_RE = re.compile(r"^[A-Za-z0-9_]{3,24}$")

app = FastAPI(title="Wintercraft Hub API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class AuthPayload(BaseModel):
    username: str = Field(min_length=3, max_length=24)
    password: str = Field(min_length=6, max_length=128)


class HostedServerPayload(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    description: str = Field(default="", max_length=400)
    admin_name: str = Field(min_length=1, max_length=40)
    admin_password: str = Field(min_length=1, max_length=128)
    gameid: str = Field(default="wintercraft_game", max_length=80)


class HostedServerUpdatePayload(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    description: str = Field(default="", max_length=400)
    admin_name: str = Field(min_length=1, max_length=40)
    admin_password: Optional[str] = Field(default=None, max_length=128)


class SessionUser(BaseModel):
    id: int
    username: str
    is_admin: bool = False


def utcnow() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat()


@contextmanager
def db() -> Iterator[sqlite3.Connection]:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db() -> None:
    with db() as conn:
        conn.executescript(
            """
            PRAGMA journal_mode=WAL;

            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL,
                username_norm TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS sessions (
                token TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                created_at TEXT NOT NULL,
                last_used_at TEXT NOT NULL,
                expires_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS hosted_servers (
                id TEXT PRIMARY KEY,
                owner_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                name TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                admin_name TEXT NOT NULL,
                admin_password_hash TEXT NOT NULL,
                gameid TEXT NOT NULL DEFAULT 'wintercraft_game',
                host_address TEXT NOT NULL,
                host_port INTEGER NOT NULL DEFAULT 30000,
                status TEXT NOT NULL DEFAULT 'queued',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
            CREATE INDEX IF NOT EXISTS idx_hosted_servers_owner_id ON hosted_servers(owner_id);
            """
        )


@app.on_event("startup")
def startup() -> None:
    init_db()


def normalize_username(username: str) -> str:
    value = username.strip()
    if not USERNAME_RE.fullmatch(value):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Username must be 3-24 chars and use only letters, numbers or underscore.",
        )
    return value


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, PASSWORD_ITERATIONS)
    return f"pbkdf2_sha256${PASSWORD_ITERATIONS}${salt.hex()}${digest.hex()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        algorithm, iterations_s, salt_hex, digest_hex = stored.split("$", 3)
        if algorithm != "pbkdf2_sha256":
            return False
        iterations = int(iterations_s)
        expected = bytes.fromhex(digest_hex)
        salt = bytes.fromhex(salt_hex)
    except (ValueError, TypeError):
        return False

    actual = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
    return hmac.compare_digest(actual, expected)


def issue_session(conn: sqlite3.Connection, user_id: int) -> str:
    token = secrets.token_urlsafe(48)
    now = datetime.now(UTC)
    expires_at = (now + timedelta(days=SESSION_DAYS)).replace(microsecond=0).isoformat()
    now_iso = now.replace(microsecond=0).isoformat()
    conn.execute(
        "INSERT INTO sessions(token, user_id, created_at, last_used_at, expires_at) VALUES (?, ?, ?, ?, ?)",
        (token, user_id, now_iso, now_iso, expires_at),
    )
    return token


def session_user_from_token(token: str) -> SessionUser:
    if STATIC_API_TOKEN and hmac.compare_digest(token, STATIC_API_TOKEN):
        return SessionUser(id=0, username="service", is_admin=True)

    with db() as conn:
        row = conn.execute(
            """
            SELECT users.id, users.username, sessions.expires_at
            FROM sessions
            JOIN users ON users.id = sessions.user_id
            WHERE sessions.token = ?
            """,
            (token,),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid session.")

        expires_at = datetime.fromisoformat(row["expires_at"])
        if expires_at < datetime.now(UTC):
            conn.execute("DELETE FROM sessions WHERE token = ?", (token,))
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Session expired.")

        conn.execute(
            "UPDATE sessions SET last_used_at = ? WHERE token = ?",
            (utcnow(), token),
        )
        return SessionUser(id=row["id"], username=row["username"], is_admin=False)


def get_bearer_token(authorization: Optional[str]) -> str:
    if not authorization:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token.")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authorization header.")
    return token.strip()


def get_current_user(authorization: Optional[str] = Header(default=None)) -> SessionUser:
    token = get_bearer_token(authorization)
    return session_user_from_token(token)


def server_response(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "name": row["name"],
        "description": row["description"],
        "admin_name": row["admin_name"],
        "host_address": row["host_address"],
        "host_port": row["host_port"],
        "status": row["status"],
        "gameid": row["gameid"],
    }


def get_owned_server(conn: sqlite3.Connection, server_id: str, user: SessionUser) -> sqlite3.Row:
    if user.is_admin:
        row = conn.execute("SELECT * FROM hosted_servers WHERE id = ?", (server_id,)).fetchone()
    else:
        row = conn.execute(
            "SELECT * FROM hosted_servers WHERE id = ? AND owner_id = ?",
            (server_id, user.id),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Hosted server not found.")
    return row


@app.get("/")
def root() -> dict:
    return {
        "service": "wintercraft-hub-api",
        "status": "ok",
        "api_base": "/api",
    }


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "public_host": PUBLIC_HOST, "public_port": PUBLIC_PORT}


@app.post("/auth/register")
def register(payload: AuthPayload) -> dict:
    username = normalize_username(payload.username)
    username_norm = username.lower()
    now = utcnow()

    with db() as conn:
        existing = conn.execute(
            "SELECT id FROM users WHERE username_norm = ?",
            (username_norm,),
        ).fetchone()
        if existing:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Username already exists.")

        cursor = conn.execute(
            "INSERT INTO users(username, username_norm, password_hash, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
            (username, username_norm, hash_password(payload.password), now, now),
        )
        token = issue_session(conn, cursor.lastrowid)

    return {
        "token": token,
        "account": {"id": cursor.lastrowid, "username": username},
    }


@app.post("/auth/login")
def login(payload: AuthPayload) -> dict:
    username = normalize_username(payload.username)
    username_norm = username.lower()

    with db() as conn:
        row = conn.execute(
            "SELECT id, username, password_hash FROM users WHERE username_norm = ?",
            (username_norm,),
        ).fetchone()
        if not row or not verify_password(payload.password, row["password_hash"]):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid username or password.")

        token = issue_session(conn, row["id"])

    return {
        "token": token,
        "account": {"id": row["id"], "username": row["username"]},
    }


@app.get("/auth/me")
def me(user: SessionUser = Depends(get_current_user)) -> dict:
    return {"account": {"id": user.id, "username": user.username}}


@app.post("/auth/logout")
def logout(authorization: Optional[str] = Header(default=None), user: SessionUser = Depends(get_current_user)) -> dict:
    if user.is_admin:
        return {"ok": True}

    token = get_bearer_token(authorization)
    with db() as conn:
        conn.execute("DELETE FROM sessions WHERE token = ?", (token,))
    return {"ok": True}


@app.get("/servers")
def list_servers(user: SessionUser = Depends(get_current_user)) -> dict:
    with db() as conn:
        if user.is_admin:
            rows = conn.execute(
                "SELECT * FROM hosted_servers ORDER BY updated_at DESC, name COLLATE NOCASE ASC"
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM hosted_servers WHERE owner_id = ? ORDER BY updated_at DESC, name COLLATE NOCASE ASC",
                (user.id,),
            ).fetchall()
    return {"servers": [server_response(row) for row in rows]}


@app.post("/servers")
def create_server(payload: HostedServerPayload, user: SessionUser = Depends(get_current_user)) -> dict:
    if user.is_admin and user.id == 0:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Static service token cannot create hosted servers.")

    now = utcnow()
    server_id = f"srv_{secrets.token_hex(6)}"

    with db() as conn:
        conn.execute(
            """
            INSERT INTO hosted_servers(
                id, owner_id, name, description, admin_name, admin_password_hash,
                gameid, host_address, host_port, status, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                server_id,
                user.id,
                payload.name.strip(),
                payload.description.strip(),
                payload.admin_name.strip(),
                hash_password(payload.admin_password),
                payload.gameid.strip() or "wintercraft_game",
                PUBLIC_HOST,
                PUBLIC_PORT,
                "queued",
                now,
                now,
            ),
        )
        row = conn.execute("SELECT * FROM hosted_servers WHERE id = ?", (server_id,)).fetchone()

    return {"server": server_response(row)}


@app.put("/servers/{server_id}")
def update_server(server_id: str, payload: HostedServerUpdatePayload, user: SessionUser = Depends(get_current_user)) -> dict:
    with db() as conn:
        current = get_owned_server(conn, server_id, user)
        password_hash = current["admin_password_hash"]
        if payload.admin_password:
            password_hash = hash_password(payload.admin_password)

        conn.execute(
            """
            UPDATE hosted_servers
            SET name = ?, description = ?, admin_name = ?, admin_password_hash = ?, updated_at = ?
            WHERE id = ?
            """,
            (
                payload.name.strip(),
                payload.description.strip(),
                payload.admin_name.strip(),
                password_hash,
                utcnow(),
                current["id"],
            ),
        )
        row = conn.execute("SELECT * FROM hosted_servers WHERE id = ?", (current["id"],)).fetchone()

    return {"server": server_response(row)}


@app.post("/servers/{server_id}/update")
def update_server_compat(server_id: str, payload: HostedServerUpdatePayload, user: SessionUser = Depends(get_current_user)) -> dict:
    return update_server(server_id, payload, user)


@app.delete("/servers/{server_id}")
def delete_server(server_id: str, user: SessionUser = Depends(get_current_user)) -> dict:
    with db() as conn:
        current = get_owned_server(conn, server_id, user)
        conn.execute("DELETE FROM hosted_servers WHERE id = ?", (current["id"],))
    return {"ok": True}


@app.post("/servers/{server_id}/delete")
def delete_server_compat(server_id: str, user: SessionUser = Depends(get_current_user)) -> dict:
    return delete_server(server_id, user)
