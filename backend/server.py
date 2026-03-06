from fastapi import FastAPI, APIRouter, HTTPException, Depends, Header
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
from pathlib import Path
from pydantic import BaseModel, Field
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

# Cloudflare config (shared token for all domains)
CF_API_TOKEN = os.environ.get('CLOUDFLARE_API_TOKEN', '')
CF_BASE = "https://api.cloudflare.com/client/v4"
CF_HEADERS = {
    "Authorization": f"Bearer {CF_API_TOKEN}",
    "Content-Type": "application/json"
}

# Default domain (seeded on startup)
DEFAULT_ZONE_ID = os.environ.get('CLOUDFLARE_ZONE_ID', '')
DEFAULT_DOMAIN = "dnslab.biz"

# JWT config
JWT_SECRET = os.environ.get('JWT_SECRET', 'ddns-land-fallback-secret')
JWT_ALGORITHM = "HS256"
JWT_EXPIRY_DAYS = 7

# App config
FREE_RECORD_LIMIT = 2

app = FastAPI(title="DNSLAB.BIZ API")
api_router = APIRouter(prefix="/api")

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


# --- Cloudflare API Helpers (zone_id as parameter) ---
async def cf_create_record(zone_id: str, record_type: str, name: str, content: str, ttl: int = 1, proxied: bool = False):
    url = f"{CF_BASE}/zones/{zone_id}/dns_records"
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


async def cf_update_record(zone_id: str, record_id: str, record_type: str, name: str, content: str, ttl: int = 1, proxied: bool = False):
    url = f"{CF_BASE}/zones/{zone_id}/dns_records/{record_id}"
    payload = {"type": record_type, "name": name, "content": content, "ttl": ttl, "proxied": proxied}
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.put(url, headers=CF_HEADERS, json=payload)
        data = resp.json()
        if not data.get("success"):
            errors = data.get("errors", [])
            msg = errors[0].get("message", "Unknown error") if errors else "Unknown error"
            raise HTTPException(status_code=400, detail=f"Cloudflare: {msg}")
        return data["result"]


async def cf_check_record_exists(zone_id: str, name: str):
    url = f"{CF_BASE}/zones/{zone_id}/dns_records?name={name}"
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get(url, headers=CF_HEADERS)
        data = resp.json()
        if data.get("success") and data.get("result"):
            return True
        return False


async def cf_delete_record(zone_id: str, record_id: str):
    url = f"{CF_BASE}/zones/{zone_id}/dns_records/{record_id}"
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
    email: str
    password: str = Field(min_length=6)


class UserLogin(BaseModel):
    email: str
    password: str


class DNSRecordCreate(BaseModel):
    record_type: str
    name: str
    content: str
    domain_id: str = ""
    ttl: int = 1
    proxied: bool = False


class DNSRecordUpdate(BaseModel):
    content: str
    ttl: int = 1
    proxied: bool = False


class DomainCreate(BaseModel):
    name: str
    zone_id: str


class DomainUpdate(BaseModel):
    active: Optional[bool] = None
    name: Optional[str] = None
    zone_id: Optional[str] = None


# --- Helper: get domain by id ---
async def get_domain(domain_id: str):
    domain = await db.domains.find_one({"id": domain_id}, {"_id": 0})
    if not domain:
        raise HTTPException(status_code=404, detail="Domain not found")
    return domain


# --- Auth Routes ---
@api_router.post("/auth/register")
async def register(data: UserRegister):
    if not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', data.email):
        raise HTTPException(status_code=400, detail="Invalid email format")

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
        "user": {"id": user_id, "email": data.email, "plan": "free", "role": "user"}
    }


@api_router.post("/auth/login")
async def login(data: UserLogin):
    user = await db.users.find_one({"email": data.email}, {"_id": 0})
    if not user or not verify_password(data.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    token = create_token(user["id"], user["email"])
    return {
        "token": token,
        "user": {"id": user["id"], "email": user["email"], "plan": user.get("plan", "free"), "role": user.get("role", "user")}
    }


@api_router.get("/auth/me")
async def get_me(user=Depends(get_current_user)):
    record_count = await db.dns_records.count_documents({"user_id": user["id"]})
    return {
        "id": user["id"],
        "email": user["email"],
        "plan": user.get("plan", "free"),
        "role": user.get("role", "user"),
        "record_count": record_count,
        "record_limit": -1 if user.get("role") == "admin" or user.get("plan") != "free" else FREE_RECORD_LIMIT
    }


# --- Domain Routes (public) ---
@api_router.get("/domains")
async def list_active_domains(user=Depends(get_current_user)):
    domains = await db.domains.find({"active": True}, {"_id": 0}).to_list(100)
    return {"domains": domains}


# --- DNS Routes ---
@api_router.get("/dns/records")
async def list_records(user=Depends(get_current_user)):
    records = await db.dns_records.find({"user_id": user["id"]}, {"_id": 0}).to_list(100)
    return {"records": records}


@api_router.post("/dns/records")
async def create_record(data: DNSRecordCreate, user=Depends(get_current_user)):
    if data.record_type not in ["A", "AAAA", "CNAME", "NS"]:
        raise HTTPException(status_code=400, detail="Record type must be A, AAAA, CNAME, or NS")

    if not re.match(r'^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$', data.name):
        raise HTTPException(status_code=400, detail="Invalid subdomain name. Use only letters, numbers, and hyphens.")

    if len(data.name) > 63:
        raise HTTPException(status_code=400, detail="Subdomain name too long (max 63 characters)")

    record_count = await db.dns_records.count_documents({"user_id": user["id"]})
    is_admin = user.get("role") == "admin"
    if not is_admin and user.get("plan", "free") == "free" and record_count >= FREE_RECORD_LIMIT:
        raise HTTPException(status_code=403, detail="Free plan limit reached. Upgrade to create more records.")

    # Resolve domain
    if data.domain_id:
        domain = await get_domain(data.domain_id)
        if not domain.get("active"):
            raise HTTPException(status_code=400, detail="This domain is not active")
        domain_name = domain["name"]
        zone_id = domain["zone_id"]
    else:
        # Fallback: use default domain
        default_domain = await db.domains.find_one({"name": DEFAULT_DOMAIN}, {"_id": 0})
        if default_domain:
            domain_name = default_domain["name"]
            zone_id = default_domain["zone_id"]
            data.domain_id = default_domain["id"]
        else:
            domain_name = DEFAULT_DOMAIN
            zone_id = DEFAULT_ZONE_ID

    full_name = f"{data.name}.{domain_name}"

    # Check DB
    existing = await db.dns_records.find_one({"full_name": full_name})
    if existing:
        raise HTTPException(status_code=400, detail="This subdomain is already taken")

    # Check Cloudflare
    cf_exists = await cf_check_record_exists(zone_id, full_name)
    if cf_exists:
        raise HTTPException(status_code=400, detail="This subdomain already exists in DNS records")

    # Validate content
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
    elif data.record_type == "NS":
        if not re.match(r'^[a-zA-Z0-9][a-zA-Z0-9.\-]+[a-zA-Z0-9]$', data.content):
            raise HTTPException(status_code=400, detail="Invalid nameserver (e.g. ns1.example.com)")

    cf_result = await cf_create_record(
        zone_id=zone_id,
        record_type=data.record_type,
        name=full_name,
        content=data.content,
        ttl=data.ttl,
        proxied=False if data.record_type == "NS" else data.proxied
    )

    record = {
        "id": str(uuid.uuid4()),
        "cf_id": cf_result["id"],
        "user_id": user["id"],
        "domain_id": data.domain_id,
        "domain_name": domain_name,
        "zone_id": zone_id,
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
        "domain_id": record["domain_id"],
        "domain_name": record["domain_name"],
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
    elif record["record_type"] == "NS":
        if not re.match(r'^[a-zA-Z0-9][a-zA-Z0-9.\-]+[a-zA-Z0-9]$', data.content):
            raise HTTPException(status_code=400, detail="Invalid nameserver (e.g. ns1.example.com)")

    zone_id = record.get("zone_id", DEFAULT_ZONE_ID)

    await cf_update_record(
        zone_id=zone_id,
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

    zone_id = record.get("zone_id", DEFAULT_ZONE_ID)
    await cf_delete_record(zone_id, record["cf_id"])
    await db.dns_records.delete_one({"id": record_id})

    return {"message": "Record deleted successfully"}


# --- Admin Helpers ---
ADMIN_EMAIL = os.environ.get('ADMIN_EMAIL', 'admin@gmail.com')


async def get_admin_user(authorization: Optional[str] = Header(None)):
    user = await get_current_user(authorization)
    if user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return user


# --- Admin Domain Routes ---
@api_router.get("/admin/domains")
async def admin_list_domains(admin=Depends(get_admin_user)):
    domains = await db.domains.find({}, {"_id": 0}).to_list(100)
    for d in domains:
        d["record_count"] = await db.dns_records.count_documents({"domain_id": d["id"]})
    return {"domains": domains}


@api_router.post("/admin/domains")
async def admin_add_domain(data: DomainCreate, admin=Depends(get_admin_user)):
    name = data.name.lower().strip()
    if not re.match(r'^[a-zA-Z0-9][a-zA-Z0-9.\-]+[a-zA-Z]{2,}$', name):
        raise HTTPException(status_code=400, detail="Invalid domain name")

    existing = await db.domains.find_one({"name": name})
    if existing:
        raise HTTPException(status_code=400, detail="Domain already exists")

    domain = {
        "id": str(uuid.uuid4()),
        "name": name,
        "zone_id": data.zone_id.strip(),
        "active": True,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.domains.insert_one(domain)

    return {
        "id": domain["id"],
        "name": domain["name"],
        "zone_id": domain["zone_id"],
        "active": domain["active"],
        "created_at": domain["created_at"]
    }


@api_router.put("/admin/domains/{domain_id}")
async def admin_update_domain(domain_id: str, data: DomainUpdate, admin=Depends(get_admin_user)):
    domain = await db.domains.find_one({"id": domain_id}, {"_id": 0})
    if not domain:
        raise HTTPException(status_code=404, detail="Domain not found")

    update_fields = {}
    if data.active is not None:
        update_fields["active"] = data.active
    if data.name is not None:
        update_fields["name"] = data.name.lower().strip()
    if data.zone_id is not None:
        update_fields["zone_id"] = data.zone_id.strip()

    if not update_fields:
        raise HTTPException(status_code=400, detail="No fields to update")

    update_fields["updated_at"] = datetime.now(timezone.utc).isoformat()
    await db.domains.update_one({"id": domain_id}, {"$set": update_fields})

    updated = await db.domains.find_one({"id": domain_id}, {"_id": 0})
    return updated


@api_router.delete("/admin/domains/{domain_id}")
async def admin_delete_domain(domain_id: str, admin=Depends(get_admin_user)):
    domain = await db.domains.find_one({"id": domain_id}, {"_id": 0})
    if not domain:
        raise HTTPException(status_code=404, detail="Domain not found")

    # Check if domain has records
    record_count = await db.dns_records.count_documents({"domain_id": domain_id})
    if record_count > 0:
        raise HTTPException(status_code=400, detail=f"Cannot delete domain with {record_count} active records. Delete records first.")

    await db.domains.delete_one({"id": domain_id})
    return {"message": f"Domain {domain['name']} deleted"}


# --- Admin User Routes ---
class UpdateUserPlan(BaseModel):
    plan: str


@api_router.get("/admin/users")
async def admin_list_users(admin=Depends(get_admin_user)):
    users = await db.users.find({}, {"_id": 0, "password_hash": 0}).to_list(500)
    for u in users:
        u["record_count"] = await db.dns_records.count_documents({"user_id": u["id"]})
    return {"users": users}


@api_router.put("/admin/users/{user_id}/plan")
async def admin_update_plan(user_id: str, data: UpdateUserPlan, admin=Depends(get_admin_user)):
    if data.plan not in ["free", "premium"]:
        raise HTTPException(status_code=400, detail="Plan must be 'free' or 'premium'")

    result = await db.users.update_one(
        {"id": user_id},
        {"$set": {"plan": data.plan, "updated_at": datetime.now(timezone.utc).isoformat()}}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="User not found")

    return {"message": f"User plan updated to {data.plan}"}


@api_router.delete("/admin/users/{user_id}")
async def admin_delete_user(user_id: str, admin=Depends(get_admin_user)):
    user = await db.users.find_one({"id": user_id}, {"_id": 0})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if user.get("role") == "admin":
        raise HTTPException(status_code=400, detail="Cannot delete admin user")

    user_records = await db.dns_records.find({"user_id": user_id}, {"_id": 0}).to_list(100)
    for rec in user_records:
        try:
            zone_id = rec.get("zone_id", DEFAULT_ZONE_ID)
            await cf_delete_record(zone_id, rec["cf_id"])
        except Exception:
            logger.warning(f"Failed to delete CF record {rec['cf_id']} for user {user_id}")

    await db.dns_records.delete_many({"user_id": user_id})
    await db.users.delete_one({"id": user_id})

    return {"message": "User and all their records deleted"}


@api_router.get("/admin/stats")
async def admin_stats(admin=Depends(get_admin_user)):
    total_users = await db.users.count_documents({})
    total_records = await db.dns_records.count_documents({})
    free_users = await db.users.count_documents({"plan": "free"})
    premium_users = await db.users.count_documents({"plan": "premium"})
    total_domains = await db.domains.count_documents({})
    active_domains = await db.domains.count_documents({"active": True})
    return {
        "total_users": total_users,
        "total_records": total_records,
        "free_users": free_users,
        "premium_users": premium_users,
        "total_domains": total_domains,
        "active_domains": active_domains,
    }


@api_router.get("/admin/users/{user_id}/records")
async def admin_get_user_records(user_id: str, admin=Depends(get_admin_user)):
    user = await db.users.find_one({"id": user_id}, {"_id": 0, "password_hash": 0})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    records = await db.dns_records.find({"user_id": user_id}, {"_id": 0}).to_list(100)
    return {"user": user, "records": records}


@api_router.delete("/admin/records/{record_id}")
async def admin_delete_record(record_id: str, admin=Depends(get_admin_user)):
    record = await db.dns_records.find_one({"id": record_id}, {"_id": 0})
    if not record:
        raise HTTPException(status_code=404, detail="Record not found")
    zone_id = record.get("zone_id", DEFAULT_ZONE_ID)
    await cf_delete_record(zone_id, record["cf_id"])
    await db.dns_records.delete_one({"id": record_id})
    return {"message": "Record deleted successfully"}


@api_router.post("/admin/setup")
async def admin_setup():
    """One-time admin setup: promotes the ADMIN_EMAIL user to admin role."""
    admin_user = await db.users.find_one({"email": ADMIN_EMAIL})
    if not admin_user:
        raise HTTPException(status_code=404, detail=f"User with email {ADMIN_EMAIL} not found. Register first.")

    await db.users.update_one(
        {"email": ADMIN_EMAIL},
        {"$set": {"role": "admin"}}
    )
    return {"message": f"User {ADMIN_EMAIL} is now admin"}


@api_router.get("/health")
async def health():
    return {"status": "healthy", "service": "DNSLAB.BIZ API"}


app.include_router(api_router)

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=os.environ.get('CORS_ORIGINS', '*').split(','),
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def seed_default_domain():
    """Seed the default domain if it doesn't exist yet."""
    if DEFAULT_ZONE_ID:
        existing = await db.domains.find_one({"name": DEFAULT_DOMAIN})
        if not existing:
            domain = {
                "id": str(uuid.uuid4()),
                "name": DEFAULT_DOMAIN,
                "zone_id": DEFAULT_ZONE_ID,
                "active": True,
                "created_at": datetime.now(timezone.utc).isoformat()
            }
            await db.domains.insert_one(domain)
            logger.info(f"Seeded default domain: {DEFAULT_DOMAIN}")


@app.on_event("shutdown")
async def shutdown_db_client():
    mongo_client.close()
