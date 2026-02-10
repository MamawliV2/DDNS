from fastapi import FastAPI, APIRouter, HTTPException, Depends, Header
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
from pathlib import Path
from pydantic import BaseModel, Field, EmailStr
from typing import List, Optional
import uuid
from datetime import datetime, timezone, timedelta
import jwt
import bcrypt
import httpx
import re

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# MongoDB
mongo_url = os.environ['MONGO_URL']
mongo_client = AsyncIOMotorClient(mongo_url)
db = mongo_client[os.environ['DB_NAME']]

# Cloudflare config
CF_API_TOKEN = os.environ.get('CLOUDFLARE_API_TOKEN', '')
CF_ZONE_ID = os.environ.get('CLOUDFLARE_ZONE_ID', '')
CF_BASE = "https://api.cloudflare.com/client/v4"
CF_HEADERS = {
    "Authorization": f"Bearer {CF_API_TOKEN}",
    "Content-Type": "application/json"
}

# JWT config
JWT_SECRET = os.environ.get('JWT_SECRET', 'ddns-land-fallback-secret')
JWT_ALGORITHM = "HS256"
JWT_EXPIRY_DAYS = 7

# App config
DOMAIN = "ddns.land"
FREE_RECORD_LIMIT = 2

app = FastAPI(title="DDNS.LAND API")
api_router = APIRouter(prefix="/api")

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


# --- Cloudflare API Helpers ---
async def cf_create_record(record_type: str, name: str, content: str, ttl: int = 1, proxied: bool = False):
    url = f"{CF_BASE}/zones/{CF_ZONE_ID}/dns_records"
    payload = {"type": record_type, "name": name, "content": content, "ttl": ttl, "proxied": proxied}
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(url, headers=CF_HEADERS, json=payload)
        data = resp.json()
        if not data.get("success"):
            errors = data.get("errors", [])
            msg = errors[0].get("message", "Unknown error") if errors else "Unknown error"
            logger.error(f"CF create error: {msg}")
            raise HTTPException(status_code=400, detail=f"Cloudflare: {msg}")
        return data["result"]


async def cf_update_record(record_id: str, record_type: str, name: str, content: str, ttl: int = 1, proxied: bool = False):
    url = f"{CF_BASE}/zones/{CF_ZONE_ID}/dns_records/{record_id}"
    payload = {"type": record_type, "name": name, "content": content, "ttl": ttl, "proxied": proxied}
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.put(url, headers=CF_HEADERS, json=payload)
        data = resp.json()
        if not data.get("success"):
            errors = data.get("errors", [])
            msg = errors[0].get("message", "Unknown error") if errors else "Unknown error"
            raise HTTPException(status_code=400, detail=f"Cloudflare: {msg}")
        return data["result"]


async def cf_delete_record(record_id: str):
    url = f"{CF_BASE}/zones/{CF_ZONE_ID}/dns_records/{record_id}"
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.delete(url, headers=CF_HEADERS)
        data = resp.json()
        if not data.get("success"):
            errors = data.get("errors", [])
            msg = errors[0].get("message", "Unknown error") if errors else "Unknown error"
            raise HTTPException(status_code=400, detail=f"Cloudflare: {msg}")
        return data.get("result", {})


# --- Auth Helpers ---
def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')


def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))


def create_token(user_id: str, email: str) -> str:
    payload = {
        "user_id": user_id,
        "email": email,
        "exp": datetime.now(timezone.utc) + timedelta(days=JWT_EXPIRY_DAYS)
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


async def get_current_user(authorization: Optional[str] = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    token = authorization.split(" ")[1]
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user = await db.users.find_one({"id": payload["user_id"]}, {"_id": 0})
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        return user
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


# --- Pydantic Models ---
class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6)


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class DNSRecordCreate(BaseModel):
    record_type: str
    name: str
    content: str
    ttl: int = 1
    proxied: bool = False


class DNSRecordUpdate(BaseModel):
    content: str
    ttl: int = 1
    proxied: bool = False


# --- Auth Routes ---
@api_router.post("/auth/register")
async def register(data: UserRegister):
    # Only allow Gmail addresses
    if not data.email.lower().endswith("@gmail.com"):
        raise HTTPException(status_code=400, detail="Only Gmail addresses (@gmail.com) are allowed for registration")

    existing = await db.users.find_one({"email": data.email})
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    user_id = str(uuid.uuid4())
    user_doc = {
        "id": user_id,
        "email": data.email,
        "password_hash": hash_password(data.password),
        "plan": "free",
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.users.insert_one(user_doc)

    token = create_token(user_id, data.email)
    return {
        "token": token,
        "user": {"id": user_id, "email": data.email, "plan": "free"}
    }


@api_router.post("/auth/login")
async def login(data: UserLogin):
    user = await db.users.find_one({"email": data.email}, {"_id": 0})
    if not user or not verify_password(data.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    token = create_token(user["id"], user["email"])
    return {
        "token": token,
        "user": {"id": user["id"], "email": user["email"], "plan": user.get("plan", "free")}
    }


@api_router.get("/auth/me")
async def get_me(user=Depends(get_current_user)):
    record_count = await db.dns_records.count_documents({"user_id": user["id"]})
    return {
        "id": user["id"],
        "email": user["email"],
        "plan": user.get("plan", "free"),
        "record_count": record_count,
        "record_limit": FREE_RECORD_LIMIT if user.get("plan") == "free" else -1
    }


# --- DNS Routes ---
@api_router.get("/dns/records")
async def list_records(user=Depends(get_current_user)):
    records = await db.dns_records.find({"user_id": user["id"]}, {"_id": 0}).to_list(100)
    return {"records": records}


@api_router.post("/dns/records")
async def create_record(data: DNSRecordCreate, user=Depends(get_current_user)):
    if data.record_type not in ["A", "AAAA", "CNAME"]:
        raise HTTPException(status_code=400, detail="Record type must be A, AAAA, or CNAME")

    if not re.match(r'^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$', data.name):
        raise HTTPException(status_code=400, detail="Invalid subdomain name. Use only letters, numbers, and hyphens.")

    if len(data.name) > 63:
        raise HTTPException(status_code=400, detail="Subdomain name too long (max 63 characters)")

    record_count = await db.dns_records.count_documents({"user_id": user["id"]})
    if user.get("plan", "free") == "free" and record_count >= FREE_RECORD_LIMIT:
        raise HTTPException(status_code=403, detail="Free plan limit reached. Upgrade to create more records.")

    full_name = f"{data.name}.{DOMAIN}"
    existing = await db.dns_records.find_one({"full_name": full_name})
    if existing:
        raise HTTPException(status_code=400, detail="This subdomain is already taken")

    if data.record_type == "A":
        if not re.match(r'^(\d{1,3}\.){3}\d{1,3}$', data.content):
            raise HTTPException(status_code=400, detail="Invalid IPv4 address")
        parts = data.content.split('.')
        for p in parts:
            if int(p) > 255:
                raise HTTPException(status_code=400, detail="Invalid IPv4 address")
    elif data.record_type == "AAAA":
        if not re.match(r'^[0-9a-fA-F:]+$', data.content):
            raise HTTPException(status_code=400, detail="Invalid IPv6 address")
    elif data.record_type == "CNAME":
        if not re.match(r'^[a-zA-Z0-9][a-zA-Z0-9.\-]+[a-zA-Z0-9]$', data.content):
            raise HTTPException(status_code=400, detail="Invalid CNAME target")

    cf_result = await cf_create_record(
        record_type=data.record_type,
        name=full_name,
        content=data.content,
        ttl=data.ttl,
        proxied=data.proxied
    )

    record = {
        "id": str(uuid.uuid4()),
        "cf_id": cf_result["id"],
        "user_id": user["id"],
        "record_type": data.record_type,
        "name": data.name,
        "full_name": full_name,
        "content": data.content,
        "ttl": data.ttl,
        "proxied": data.proxied,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.dns_records.insert_one(record)

    return {
        "id": record["id"],
        "cf_id": record["cf_id"],
        "record_type": record["record_type"],
        "name": record["name"],
        "full_name": record["full_name"],
        "content": record["content"],
        "ttl": record["ttl"],
        "proxied": record["proxied"],
        "created_at": record["created_at"]
    }


@api_router.put("/dns/records/{record_id}")
async def update_record(record_id: str, data: DNSRecordUpdate, user=Depends(get_current_user)):
    record = await db.dns_records.find_one({"id": record_id, "user_id": user["id"]}, {"_id": 0})
    if not record:
        raise HTTPException(status_code=404, detail="Record not found")

    if record["record_type"] == "A":
        if not re.match(r'^(\d{1,3}\.){3}\d{1,3}$', data.content):
            raise HTTPException(status_code=400, detail="Invalid IPv4 address")
    elif record["record_type"] == "AAAA":
        if not re.match(r'^[0-9a-fA-F:]+$', data.content):
            raise HTTPException(status_code=400, detail="Invalid IPv6 address")
    elif record["record_type"] == "CNAME":
        if not re.match(r'^[a-zA-Z0-9][a-zA-Z0-9.\-]+[a-zA-Z0-9]$', data.content):
            raise HTTPException(status_code=400, detail="Invalid CNAME target")

    await cf_update_record(
        record_id=record["cf_id"],
        record_type=record["record_type"],
        name=record["full_name"],
        content=data.content,
        ttl=data.ttl,
        proxied=data.proxied
    )

    await db.dns_records.update_one(
        {"id": record_id},
        {"$set": {
            "content": data.content,
            "ttl": data.ttl,
            "proxied": data.proxied,
            "updated_at": datetime.now(timezone.utc).isoformat()
        }}
    )

    updated = await db.dns_records.find_one({"id": record_id}, {"_id": 0})
    return updated


@api_router.delete("/dns/records/{record_id}")
async def delete_record(record_id: str, user=Depends(get_current_user)):
    record = await db.dns_records.find_one({"id": record_id, "user_id": user["id"]}, {"_id": 0})
    if not record:
        raise HTTPException(status_code=404, detail="Record not found")

    await cf_delete_record(record["cf_id"])
    await db.dns_records.delete_one({"id": record_id})

    return {"message": "Record deleted successfully"}


@api_router.get("/health")
async def health():
    return {"status": "healthy", "service": "DDNS.LAND API"}


app.include_router(api_router)

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=os.environ.get('CORS_ORIGINS', '*').split(','),
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("shutdown")
async def shutdown_db_client():
    mongo_client.close()
