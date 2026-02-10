# DDNS.LAND - Free Dynamic DNS Service

## Problem Statement
Build a beautiful website for ddns.land domain where users can create accounts and manage DNS records (A, AAAA, CNAME) for free on this domain. Up to 2 records are free, for more users contact via Telegram @DZ_CT.

## Architecture
- **Frontend**: React + Tailwind CSS + Shadcn UI
- **Backend**: FastAPI + MongoDB + Cloudflare API
- **Auth**: JWT with bcrypt password hashing
- **DNS**: Real Cloudflare DNS management via API Token
- **Design**: "The Network Grid" theme with dark/light modes, bilingual (EN/FA + RTL)

## User Personas
1. **Developer**: Needs free subdomain for personal projects
2. **Sysadmin**: Manages dynamic DNS for servers
3. **Tech enthusiast**: Wants easy DNS management

## Core Requirements (Static)
- [x] User registration and login (email/password, JWT)
- [x] DNS record management (A, AAAA, CNAME) via Cloudflare API
- [x] Free tier: 2 records max
- [x] Premium: contact via Telegram @DZ_CT
- [x] Dark/Light mode toggle
- [x] Bilingual: English + Persian (RTL)
- [x] Landing page with hero, features, pricing
- [x] Dashboard with DNS records table

## What's Been Implemented (Feb 2026)
- Full-stack application with React frontend and FastAPI backend
- JWT authentication (register, login, token validation)
- Real Cloudflare DNS integration (create, update, delete records)
- Landing page with hero section, features grid, pricing cards
- Dashboard with stats cards, DNS records table, CRUD dialogs
- Dark/Light theme toggle with system preference detection
- Persian/English language switcher with RTL support
- Telegram contact integration for premium upgrades
- Free plan limit enforcement (2 records)

## Prioritized Backlog
### P0 (Done)
- User auth, DNS CRUD, landing page, dashboard, theme, i18n

### P1 (Next)
- Password reset/forgot password flow
- Email verification on registration
- Admin panel for managing users and plans
- API rate limiting

### P2 (Future)
- User plan upgrade workflow automation
- DNS record history/changelog
- Wildcard DNS support
- API key system for programmatic access
- MX and TXT record support

## Next Tasks
1. Add forgot password functionality
2. Email verification system
3. Admin dashboard for managing users
4. API rate limiting and abuse prevention
