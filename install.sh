#!/bin/bash

# ============================================================
#  DDNS.LAND - Automated Installation Script
#  Free Dynamic DNS Service powered by Cloudflare
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Banner
clear
echo -e "${BLUE}${BOLD}"
echo "  ______  ______  _   _  _____   _       ___   _   _  ____  "
echo " |  _  \|  _  \| \ | |/  ___| | |     / _ \ | \ | ||  _ \ "
echo " | | | || | | ||  \| |\ \`--.  | |    / /_\ \|  \| || | | |"
echo " | | | || | | || . \` | \`--. \ | |    |  _  || . \` || | | |"
echo " | |/ / | |/ / | |\  |/\__/ /_| |____| | | || |\  || |/ / "
echo " |___/  |___/  \_| \_/\____/ |______/\_| |_/\_| \_/|___/  "
echo ""
echo "  Free Dynamic DNS Service - Automated Installer"
echo -e "${NC}"
echo ""

# ---- Helper functions ----
print_step() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  STEP $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_ok() {
    echo -e "  ${GREEN}[OK]${NC} $1"
}

print_warn() {
    echo -e "  ${YELLOW}[!!]${NC} $1"
}

print_err() {
    echo -e "  ${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "  ${DIM}$1${NC}"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        print_ok "$1 $(command -v $1)"
        return 0
    else
        return 1
    fi
}

# ---- Step 1: Check Prerequisites ----
print_step "1/9 - Checking prerequisites"

NEED_INSTALL=()

echo ""
echo -e "  ${BOLD}Checking required software...${NC}"
echo ""

# Python
if check_command python3; then
    PY_VER=$(python3 --version 2>&1 | awk '{print $2}')
    print_info "Python $PY_VER"
else
    NEED_INSTALL+=("python3")
    print_err "Python 3 not found"
fi

# Node.js
if check_command node; then
    NODE_VER=$(node -v)
    print_info "Node.js $NODE_VER"
    NODE_MAJOR=$(echo $NODE_VER | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_MAJOR" -lt 16 ]; then
        print_warn "Node.js $NODE_VER is old. Recommended: 16+"
    fi
else
    NEED_INSTALL+=("nodejs")
    print_err "Node.js not found"
fi

# Yarn
if ! check_command yarn; then
    echo ""
    print_warn "yarn not found. Installing..."
    npm install -g yarn 2>/dev/null && print_ok "yarn installed" || {
        print_err "Could not install yarn. Run: npm install -g yarn"
        exit 1
    }
fi

# pip
if ! check_command pip3 && ! check_command pip; then
    NEED_INSTALL+=("pip")
    print_err "pip not found"
fi

# MongoDB check
if check_command mongod || check_command mongosh; then
    print_info "MongoDB detected"
elif systemctl is-active --quiet mongod 2>/dev/null; then
    print_ok "MongoDB service running"
else
    print_warn "MongoDB not detected locally."
    print_info "Make sure MongoDB is running and accessible."
fi

# nginx (optional, needed for domain+SSL)
if check_command nginx; then
    print_info "nginx $(nginx -v 2>&1 | awk -F/ '{print $2}')"
fi

# certbot (optional)
if check_command certbot; then
    print_info "certbot available"
fi

if [ ${#NEED_INSTALL[@]} -gt 0 ]; then
    echo ""
    print_err "Missing: ${NEED_INSTALL[*]}"
    echo ""
    echo -e "  Install them first:"
    echo -e "    ${DIM}Ubuntu/Debian: sudo apt install python3 python3-pip python3-venv nodejs npm${NC}"
    echo -e "    ${DIM}CentOS/RHEL:   sudo yum install python3 nodejs npm${NC}"
    echo -e "    ${DIM}macOS:         brew install python3 node${NC}"
    echo ""
    read -p "  Continue anyway? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ---- Step 2: Domain & SSL Configuration ----
print_step "2/9 - Domain & SSL Configuration"

echo ""
echo -e "  ${BOLD}Domain Setup${NC}"
echo -e "  ${DIM}If you have a domain, we'll configure nginx + SSL.${NC}"
echo -e "  ${DIM}Otherwise, the app will run on localhost.${NC}"
echo ""

read -p "  Do you want to use a custom domain? (y/N): " USE_DOMAIN

DOMAIN=""
USE_SSL=false
BACKEND_PORT=8001
FRONTEND_PORT=3000

if [[ "$USE_DOMAIN" =~ ^[Yy]$ ]]; then
    read -p "  Enter your domain (e.g., ddns.land): " DOMAIN
    while [ -z "$DOMAIN" ]; do
        print_err "Domain cannot be empty"
        read -p "  Enter your domain: " DOMAIN
    done

    read -p "  Your email for SSL certificate: " SSL_EMAIL
    while [ -z "$SSL_EMAIL" ]; do
        print_err "Email cannot be empty (needed for Let's Encrypt)"
        read -p "  Your email: " SSL_EMAIL
    done

    USE_SSL=true
    PUBLIC_URL="https://${DOMAIN}"

    # Check and install nginx
    if ! command -v nginx &> /dev/null; then
        echo ""
        print_warn "nginx is required for domain setup. Installing..."
        if command -v apt &> /dev/null; then
            sudo apt update -qq && sudo apt install -y -qq nginx
        elif command -v yum &> /dev/null; then
            sudo yum install -y -q nginx
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y -q nginx
        else
            print_err "Cannot auto-install nginx. Install manually and re-run."
            exit 1
        fi
        print_ok "nginx installed"
    fi

    # Check and install certbot
    if ! command -v certbot &> /dev/null; then
        echo ""
        print_warn "certbot is required for SSL. Installing..."
        if command -v apt &> /dev/null; then
            sudo apt install -y -qq certbot python3-certbot-nginx
        elif command -v yum &> /dev/null; then
            sudo yum install -y -q certbot python3-certbot-nginx
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y -q certbot python3-certbot-nginx
        else
            print_err "Cannot auto-install certbot. Install manually and re-run."
            exit 1
        fi
        print_ok "certbot installed"
    fi
else
    PUBLIC_URL="http://localhost:${BACKEND_PORT}"
    print_info "Running on localhost (no domain)"
fi

# ---- Step 3: Cloudflare Configuration ----
print_step "3/9 - Cloudflare Configuration"

echo ""
echo -e "  ${BOLD}Cloudflare API Credentials${NC}"
echo -e "  ${DIM}Get your API Token & Zone ID from: https://dash.cloudflare.com${NC}"
echo ""
echo -e "  ${DIM}How to get API Token:${NC}"
echo -e "  ${DIM}  1. Profile > API Tokens > Create Token${NC}"
echo -e "  ${DIM}  2. Use 'Edit zone DNS' template${NC}"
echo -e "  ${DIM}  3. Select your zone > Continue > Create Token${NC}"
echo ""

read -p "  Cloudflare API Token: " CF_TOKEN
while [ -z "$CF_TOKEN" ]; do
    print_err "API Token is required"
    read -p "  Cloudflare API Token: " CF_TOKEN
done

read -p "  Cloudflare Zone ID: " CF_ZONE_ID
while [ -z "$CF_ZONE_ID" ]; do
    print_err "Zone ID is required"
    read -p "  Cloudflare Zone ID: " CF_ZONE_ID
done

# ---- Step 4: Database Configuration ----
print_step "4/9 - Database Configuration"

echo ""
read -p "  MongoDB URL [mongodb://localhost:27017]: " MONGO_URL
MONGO_URL=${MONGO_URL:-mongodb://localhost:27017}

read -p "  Database name [ddns_land]: " DB_NAME
DB_NAME=${DB_NAME:-ddns_land}

print_ok "Database: ${DB_NAME} @ ${MONGO_URL}"

# ---- Step 5: Admin Account ----
print_step "5/9 - Admin Account Setup"

echo ""
echo -e "  ${BOLD}Create your admin account${NC}"
echo -e "  ${DIM}Note: Only @gmail.com addresses are allowed.${NC}"
echo ""

read -p "  Admin Email: " ADMIN_EMAIL
while [[ ! "$ADMIN_EMAIL" == *@gmail.com ]]; do
    print_err "Must be a @gmail.com address"
    read -p "  Admin Email: " ADMIN_EMAIL
done

read -sp "  Admin Password (min 6 chars): " ADMIN_PASSWORD
echo ""
while [ ${#ADMIN_PASSWORD} -lt 6 ]; do
    print_err "Password must be at least 6 characters"
    read -sp "  Admin Password: " ADMIN_PASSWORD
    echo ""
done

# Generate JWT secret
JWT_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null || openssl rand -hex 32)

# ---- Step 6: Install Dependencies ----
print_step "6/9 - Installing Dependencies"

cd "$(dirname "$0")"
PROJECT_DIR=$(pwd)

echo ""
echo -e "  ${BOLD}Backend dependencies...${NC}"

# Python venv
if [ ! -d "backend/venv" ]; then
    python3 -m venv backend/venv
fi
source backend/venv/bin/activate
pip install -r backend/requirements.txt -q 2>&1 | tail -1
print_ok "Backend packages installed"

echo ""
echo -e "  ${BOLD}Frontend dependencies...${NC}"
cd frontend
yarn install --silent 2>/dev/null || yarn install
print_ok "Frontend packages installed"
cd "$PROJECT_DIR"

# ---- Step 7: Configure Environment ----
print_step "7/9 - Configuring Environment"

# Backend .env
cat > backend/.env << ENVEOF
MONGO_URL=${MONGO_URL}
DB_NAME=${DB_NAME}
CORS_ORIGINS=*
CLOUDFLARE_API_TOKEN=${CF_TOKEN}
CLOUDFLARE_ZONE_ID=${CF_ZONE_ID}
JWT_SECRET=${JWT_SECRET}
ADMIN_EMAIL=${ADMIN_EMAIL}
ENVEOF
print_ok "backend/.env created"

# Frontend .env
cat > frontend/.env << ENVEOF
REACT_APP_BACKEND_URL=${PUBLIC_URL}
ENVEOF
print_ok "frontend/.env created"

# Build frontend
echo ""
echo -e "  ${BOLD}Building frontend for production...${NC}"
cd frontend
yarn build 2>&1 | tail -3
print_ok "Frontend built to frontend/build/"
cd "$PROJECT_DIR"

# ---- Step 8: Setup Services ----
print_step "8/9 - Setting up Services"

# Create systemd service for backend
echo ""
echo -e "  ${BOLD}Creating backend service...${NC}"

sudo tee /etc/systemd/system/ddns-backend.service > /dev/null << SVCEOF
[Unit]
Description=DDNS.LAND Backend API
After=network.target mongod.service

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=${PROJECT_DIR}/backend
Environment=PATH=${PROJECT_DIR}/backend/venv/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=${PROJECT_DIR}/backend/venv/bin/uvicorn server:app --host 127.0.0.1 --port ${BACKEND_PORT}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

sudo systemctl daemon-reload
sudo systemctl enable ddns-backend --quiet
sudo systemctl restart ddns-backend
sleep 2

if sudo systemctl is-active --quiet ddns-backend; then
    print_ok "Backend service running on port ${BACKEND_PORT}"
else
    print_err "Backend failed to start. Check: sudo journalctl -u ddns-backend -n 20"
fi

# Setup nginx if domain is configured
if [ "$USE_SSL" = true ]; then
    echo ""
    echo -e "  ${BOLD}Configuring nginx...${NC}"

    # Create nginx config
    sudo tee /etc/nginx/sites-available/ddns-land > /dev/null << NGXEOF
server {
    listen 80;
    server_name ${DOMAIN};

    # Frontend - serve static build
    location / {
        root ${PROJECT_DIR}/frontend/build;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    # Backend API proxy
    location /api/ {
        proxy_pass http://127.0.0.1:${BACKEND_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }

    # Static assets caching
    location /static/ {
        root ${PROJECT_DIR}/frontend/build;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
NGXEOF

    # Enable site
    sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null
    sudo ln -sf /etc/nginx/sites-available/ddns-land /etc/nginx/sites-enabled/

    # Test nginx config
    if sudo nginx -t 2>/dev/null; then
        sudo systemctl restart nginx
        print_ok "nginx configured for ${DOMAIN}"
    else
        print_err "nginx config error. Check: sudo nginx -t"
    fi

    # Get SSL certificate
    echo ""
    echo -e "  ${BOLD}Obtaining SSL certificate...${NC}"
    echo -e "  ${DIM}This may take a moment...${NC}"
    echo ""

    sudo certbot --nginx -d "${DOMAIN}" --email "${SSL_EMAIL}" --agree-tos --non-interactive --redirect 2>&1 | while IFS= read -r line; do
        echo -e "  ${DIM}${line}${NC}"
    done

    if [ $? -eq 0 ]; then
        print_ok "SSL certificate obtained for ${DOMAIN}"
        print_ok "Auto-renewal enabled via certbot"
    else
        print_warn "SSL setup had issues. Try manually: sudo certbot --nginx -d ${DOMAIN}"
    fi

    # Setup certbot auto-renewal
    if ! crontab -l 2>/dev/null | grep -q certbot; then
        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
        print_ok "SSL auto-renewal cron job added"
    fi
else
    print_info "No domain configured. Access via http://localhost:${BACKEND_PORT}"
    print_info "To serve frontend: cd frontend && yarn start"
fi

# ---- Step 9: Setup Admin Account ----
print_step "9/9 - Creating Admin Account"

sleep 2
API_BASE="http://127.0.0.1:${BACKEND_PORT}/api"

# Register admin
echo ""
REG_RESP=$(curl -s -X POST "${API_BASE}/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}" 2>/dev/null)

REG_TOKEN=$(echo "$REG_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null)
REG_DETAIL=$(echo "$REG_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('detail',''))" 2>/dev/null)

if [ -n "$REG_TOKEN" ] && [ "$REG_TOKEN" != "" ]; then
    print_ok "Admin user registered: ${ADMIN_EMAIL}"
elif [ "$REG_DETAIL" = "Email already registered" ]; then
    print_warn "Admin user already exists"
else
    print_warn "Registration: $REG_DETAIL"
fi

# Promote to admin
SETUP_RESP=$(curl -s -X POST "${API_BASE}/admin/setup" 2>/dev/null)
SETUP_MSG=$(echo "$SETUP_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message',''))" 2>/dev/null)

if [ -n "$SETUP_MSG" ]; then
    print_ok "$SETUP_MSG"
else
    print_warn "Admin setup response: $SETUP_RESP"
fi

# ---- Done! ----
echo ""
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════╗"
echo "  ║                                                       ║"
echo "  ║     DDNS.LAND Installation Complete!                  ║"
echo "  ║                                                       ║"
echo "  ╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

if [ "$USE_SSL" = true ]; then
    echo -e "  ${BOLD}Website:${NC}        ${GREEN}https://${DOMAIN}${NC}"
    echo -e "  ${BOLD}Admin Panel:${NC}    ${GREEN}https://${DOMAIN}/admin${NC}"
    echo -e "  ${BOLD}API:${NC}            ${GREEN}https://${DOMAIN}/api${NC}"
else
    echo -e "  ${BOLD}Backend API:${NC}    ${GREEN}http://localhost:${BACKEND_PORT}${NC}"
    echo -e "  ${BOLD}Frontend Dev:${NC}   cd frontend && yarn start"
    echo -e "  ${BOLD}Admin Panel:${NC}    ${GREEN}http://localhost:3000/admin${NC} (after yarn start)"
fi

echo ""
echo -e "  ${BOLD}Admin Email:${NC}    ${ADMIN_EMAIL}"
echo -e "  ${BOLD}Admin Panel:${NC}    Login with your admin credentials"
echo ""
echo -e "  ${BOLD}Service Management:${NC}"
echo -e "    ${DIM}sudo systemctl status ddns-backend   # Check status${NC}"
echo -e "    ${DIM}sudo systemctl restart ddns-backend   # Restart backend${NC}"
echo -e "    ${DIM}sudo journalctl -u ddns-backend -f    # View logs${NC}"

if [ "$USE_SSL" = true ]; then
    echo -e "    ${DIM}sudo systemctl restart nginx          # Restart nginx${NC}"
    echo -e "    ${DIM}sudo certbot renew --dry-run          # Test SSL renewal${NC}"
fi

echo ""
echo -e "  ${BOLD}Useful Commands:${NC}"
echo -e "    ${DIM}cd ${PROJECT_DIR}${NC}"
echo -e "    ${DIM}source backend/venv/bin/activate       # Activate Python env${NC}"
echo -e "    ${DIM}cd frontend && yarn build              # Rebuild frontend${NC}"
echo ""
echo -e "  ${MAGENTA}For premium plans & support: ${BOLD}https://t.me/DZ_CT${NC}"
echo ""
