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

## install.sh Improvements (Feb 2026)
- Removed aggressive `set -e`, uses explicit error handling
- Auto-installs basic tools (curl, wget, git, gnupg, lsb-release, build-essential)
- Auto-installs Python 3, pip, python3-venv with correct version detection
- Auto-installs Node.js 20.x with NodeSource + fallback methods
- Auto-installs Yarn with 3 fallback methods (npm, corepack, apt repo)
- Auto-installs MongoDB 7.0 with proper codename handling for Ubuntu/Debian
- Root/sudo detection, OS compatibility checks
- `DEBIAN_FRONTEND=noninteractive` to prevent interactive prompts
- 9-step guided installation with clear progress indicators

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
