# DNSLAB.BIZ - Product Requirements Document

## Original Problem Statement
Build a beautiful and stylish website for `dnslab.biz` domain. Core functionality: user registration, free DNS record management (A, AAAA, CNAME, NS) via Cloudflare integration. Free plan limited to 2 records, with paid subscription for more. Admin panel for user/record management. Full deployment script for personal server.

## Tech Stack
- **Backend:** FastAPI, PyMongo, JWT Auth, Cloudflare API
- **Frontend:** React 18, Tailwind CSS, Shadcn/UI, i18next
- **Database:** MongoDB
- **Deployment:** systemd, Nginx, Certbot (SSL)

## Completed Features
- [x] Full-stack DNS management app (FastAPI + React + MongoDB)
- [x] Cloudflare integration for A, AAAA, CNAME, NS records
- [x] User registration/login (JWT, Gmail-only)
- [x] Admin panel (user management, record management, unlimited records for admins)
- [x] Custom SVG logo, mobile-responsive UI
- [x] Bilingual support (English/Persian with RTL)
- [x] Dark/Light theme toggle
- [x] README.md documentation
- [x] Domain rebranding to dnslab.biz
- [x] Removed external branding
- [x] **install.sh** - Fully automated deployment script with auto-install of all prerequisites (P0 - COMPLETED Feb 2026)
- [x] Duplicate record check against Cloudflare (not just local DB)
- [x] **Multi-domain support** - Admin can add/remove/toggle domains, users select domain when creating records (COMPLETED Mar 2026)
- [x] **Email Verification** - 6-digit code sent via Gmail SMTP, unverified users blocked from login (COMPLETED Mar 2026)

## Multi-Domain Architecture (Mar 2026)
- `domains` collection in MongoDB: { id, name, zone_id, active, created_at }
- All CF helpers accept zone_id as parameter (not hardcoded)
- Default domain (dnslab.biz) auto-seeded on startup from CLOUDFLARE_ZONE_ID env var
- Records store domain_id, domain_name, zone_id for proper routing
- Admin panel: Tabs (Users | Domains) with full CRUD for domains
- Dashboard: Domain selector dropdown when 2+ active domains exist
- Free plan limit: 2 records total across all domains

## Backlog
- [ ] **(P1)** Paid subscription system (payment gateway integration)
- [ ] **(P2)** UI/UX enhancements

## Key Files
- `install.sh` - Automated deployment script
- `README.md` - Project documentation
- `backend/server.py` - FastAPI backend
- `frontend/src/pages/Dashboard.js` - User DNS dashboard
- `frontend/src/pages/Admin.js` - Admin panel

## Key API Endpoints
- `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me`
- `POST /api/dns`, `GET /api/dns`, `DELETE /api/dns/{record_id}`
- `GET /api/admin/users`, `DELETE /api/admin/users/{user_id}`
- `POST /api/admin/setup`, `GET /api/health`

## DB Schema
- **users:** `{ email, hashed_password, role, plan }`
- **dns_records:** `{ user_id, cloudflare_record_id, type, name, content }`
