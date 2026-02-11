#!/bin/bash

# ============================================================
#  DNSLAB.BIZ - Automated Installation Script
#  Free Dynamic DNS Service powered by Cloudflare
#  https://github.com/MamawliV2/DDNS
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

# Get project directory (where this script is located)
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---- Step 1: Check Prerequisites ----
print_step "1/9 - Checking prerequisites"

echo ""
echo -e "  ${BOLD}Checking required software...${NC}"
echo ""

NEED_INSTALL=()

if check_command python3; then
    PY_VER=$(python3 --version 2>&1 | awk '{print $2}')
    print_info "Python $PY_VER"
else
    NEED_INSTALL+=("python3")
    print_err "Python 3 not found"
fi

if check_command node; then
    NODE_VER=$(node -v)
    print_info "Node.js $NODE_VER"
else
    NEED_INSTALL+=("nodejs")
    print_err "Node.js not found"
fi

if ! check_command yarn; then
    print_warn "yarn not found. Installing..."
    npm install -g yarn 2>/dev/null && print_ok "yarn installed" || {
        print_err "Could not install yarn. Run: npm install -g yarn"
        exit 1
    }
fi

if ! check_command mongod && ! check_command mongosh; then
    if systemctl is-active --quiet mongod 2>/dev/null; then
        print_ok "MongoDB service running"
    else
        print_warn "MongoDB not detected. Make sure it's running and accessible."
    fi
fi

if [ ${#NEED_INSTALL[@]} -gt 0 ]; then
    echo ""
    print_err "Missing: ${NEED_INSTALL[*]}"
    echo ""
    echo -e "  Install them first:"
    echo -e "    ${DIM}Ubuntu/Debian: sudo apt install python3 python3-pip python3-venv nodejs npm${NC}"
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
echo -e "  ${DIM}Enter your domain for nginx + SSL setup.${NC}"
echo -e "  ${DIM}Leave empty to run on localhost only.${NC}"
echo ""

read -p "  Your domain (e.g., dnslab.biz) or press Enter to skip: " DOMAIN

USE_SSL=false
BACKEND_PORT=8001

if [ -n "$DOMAIN" ]; then
    read -p "  Email for SSL certificate (Let's Encrypt): " SSL_EMAIL
    while [ -z "$SSL_EMAIL" ]; do
        print_err "Email is required for Let's Encrypt"
        read -p "  Email: " SSL_EMAIL
    done

    USE_SSL=true
    PUBLIC_URL="https://${DOMAIN}"

    # Install nginx if needed
    if ! command -v nginx &> /dev/null; then
        print_warn "Installing nginx..."
        if command -v apt &> /dev/null; then
            sudo apt update -qq && sudo apt install -y -qq nginx
        elif command -v yum &> /dev/null; then
            sudo yum install -y -q epel-release && sudo yum install -y -q nginx
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y -q nginx
        else
            print_err "Cannot auto-install nginx. Install it manually."
            exit 1
        fi
        print_ok "nginx installed"
    fi

    # Install certbot if needed
    if ! command -v certbot &> /dev/null; then
        print_warn "Installing certbot..."
        if command -v apt &> /dev/null; then
            sudo apt install -y -qq certbot python3-certbot-nginx
        elif command -v yum &> /dev/null; then
            sudo yum install -y -q certbot python3-certbot-nginx
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y -q certbot python3-certbot-nginx
        fi
        print_ok "certbot installed"
    fi
else
    PUBLIC_URL="http://localhost:${BACKEND_PORT}"
    print_info "No domain. Running on localhost."
fi

# ---- Step 3: Cloudflare Configuration ----
print_step "3/9 - Cloudflare Configuration"

echo ""
echo -e "  ${BOLD}Get your API Token & Zone ID from: ${NC}https://dash.cloudflare.com"
echo ""

read -p "  Cloudflare API Token: " CF_TOKEN
while [ -z "$CF_TOKEN" ]; do
    print_err "Required"
    read -p "  Cloudflare API Token: " CF_TOKEN
done

read -p "  Cloudflare Zone ID: " CF_ZONE_ID
while [ -z "$CF_ZONE_ID" ]; do
    print_err "Required"
    read -p "  Cloudflare Zone ID: " CF_ZONE_ID
done

# ---- Step 4: Database Configuration ----
print_step "4/9 - Database Configuration"

echo ""
read -p "  MongoDB URL [mongodb://localhost:27017]: " MONGO_URL
MONGO_URL=${MONGO_URL:-mongodb://localhost:27017}

read -p "  Database name [ddns_land]: " DB_NAME
DB_NAME=${DB_NAME:-ddns_land}

print_ok "Database: ${DB_NAME}"

# ---- Step 5: Admin Account ----
print_step "5/9 - Admin Account"

echo ""
echo -e "  ${DIM}Only @gmail.com addresses are allowed.${NC}"
echo ""

read -p "  Admin Email: " ADMIN_EMAIL
while [[ ! "$ADMIN_EMAIL" == *@gmail.com ]]; do
    print_err "Must be @gmail.com"
    read -p "  Admin Email: " ADMIN_EMAIL
done

read -sp "  Admin Password (min 6 chars): " ADMIN_PASSWORD
echo ""
while [ ${#ADMIN_PASSWORD} -lt 6 ]; do
    print_err "Min 6 characters"
    read -sp "  Admin Password: " ADMIN_PASSWORD
    echo ""
done

# Generate JWT secret
JWT_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null || head -c 32 /dev/urandom | xxd -p)

# ---- Step 6: Install Dependencies ----
print_step "6/9 - Installing Dependencies"

echo ""
echo -e "  ${BOLD}Backend...${NC}"

cd "$PROJECT_DIR"

# Create Python venv if not exists
if [ ! -d "backend/venv" ]; then
    python3 -m venv backend/venv
    print_ok "Python venv created"
fi

# Activate and install
source backend/venv/bin/activate
pip install --upgrade pip -q 2>&1 | tail -1
pip install -r backend/requirements.txt -q 2>&1 | tail -1
print_ok "Backend packages installed"

echo ""
echo -e "  ${BOLD}Frontend...${NC}"
cd "$PROJECT_DIR/frontend"
yarn install --silent 2>/dev/null || yarn install
print_ok "Frontend packages installed"
cd "$PROJECT_DIR"

# ---- Step 7: Configure Environment ----
print_step "7/9 - Configuring Environment"

# Backend .env
cat > "$PROJECT_DIR/backend/.env" << ENVEOF
MONGO_URL=${MONGO_URL}
DB_NAME=${DB_NAME}
CORS_ORIGINS=*
CLOUDFLARE_API_TOKEN=${CF_TOKEN}
CLOUDFLARE_ZONE_ID=${CF_ZONE_ID}
JWT_SECRET=${JWT_SECRET}
ADMIN_EMAIL=${ADMIN_EMAIL}
ENVEOF
print_ok "backend/.env"

# Frontend .env
cat > "$PROJECT_DIR/frontend/.env" << ENVEOF
REACT_APP_BACKEND_URL=${PUBLIC_URL}
ENVEOF
print_ok "frontend/.env"

# Build frontend
echo ""
echo -e "  ${BOLD}Building frontend...${NC}"
cd "$PROJECT_DIR/frontend"
yarn build 2>&1 | tail -3
print_ok "Frontend build complete"
cd "$PROJECT_DIR"

# ---- Step 8: Setup Services ----
print_step "8/9 - Setting up Services"

# Get the full path to uvicorn in venv
UVICORN_PATH="$PROJECT_DIR/backend/venv/bin/uvicorn"
PYTHON_PATH="$PROJECT_DIR/backend/venv/bin/python"

# Verify uvicorn exists
if [ ! -f "$UVICORN_PATH" ]; then
    print_warn "uvicorn not found at $UVICORN_PATH, trying pip install..."
    source "$PROJECT_DIR/backend/venv/bin/activate"
    pip install uvicorn -q
fi

# Stop existing service if running
sudo systemctl stop ddns-backend 2>/dev/null || true

# Create systemd service
echo ""
echo -e "  ${BOLD}Creating backend service...${NC}"

sudo tee /etc/systemd/system/ddns-backend.service > /dev/null << SVCEOF
[Unit]
Description=DNSLAB.BIZ Backend API
After=network.target mongod.service

[Service]
Type=simple
User=$(whoami)
Group=$(id -gn)
WorkingDirectory=${PROJECT_DIR}/backend
Environment="PATH=${PROJECT_DIR}/backend/venv/bin:/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=${PROJECT_DIR}/backend/.env
ExecStart=${PYTHON_PATH} -m uvicorn server:app --host 127.0.0.1 --port ${BACKEND_PORT}
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

sudo systemctl daemon-reload
sudo systemctl enable ddns-backend --quiet 2>/dev/null
sudo systemctl restart ddns-backend

# Wait and check if backend started
echo -e "  ${DIM}Waiting for backend to start...${NC}"
sleep 4

RETRIES=0
BACKEND_OK=false
while [ $RETRIES -lt 5 ]; do
    if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${BACKEND_PORT}/api/health" 2>/dev/null | grep -q "200"; then
        BACKEND_OK=true
        break
    fi
    RETRIES=$((RETRIES + 1))
    sleep 2
done

if [ "$BACKEND_OK" = true ]; then
    print_ok "Backend running on port ${BACKEND_PORT}"
else
    print_err "Backend may not have started properly."
    echo ""
    echo -e "  ${YELLOW}Checking logs:${NC}"
    sudo journalctl -u ddns-backend -n 15 --no-pager 2>/dev/null || true
    echo ""
    print_warn "Try: sudo journalctl -u ddns-backend -f"
    echo ""
    read -p "  Continue with nginx/SSL setup anyway? (y/N): " CONT_ANYWAY
    if [[ ! "$CONT_ANYWAY" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "  ${BOLD}Fix the backend and re-run:${NC}"
        echo -e "    ${DIM}sudo journalctl -u ddns-backend -n 30${NC}"
        echo -e "    ${DIM}sudo systemctl restart ddns-backend${NC}"
        exit 1
    fi
fi

# Setup nginx if domain is configured
if [ "$USE_SSL" = true ]; then
    echo ""
    echo -e "  ${BOLD}Configuring nginx...${NC}"

    # Create nginx config
    sudo tee /etc/nginx/sites-available/dnslab-biz > /dev/null << NGXEOF
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

    # Ensure sites-enabled directory exists
    sudo mkdir -p /etc/nginx/sites-enabled

    # Enable site
    sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null
    sudo ln -sf /etc/nginx/sites-available/dnslab-biz /etc/nginx/sites-enabled/

    # Test and restart nginx
    if sudo nginx -t 2>/dev/null; then
        sudo systemctl restart nginx
        print_ok "nginx configured for ${DOMAIN}"
    else
        print_err "nginx config error:"
        sudo nginx -t
    fi

    # Get SSL certificate
    echo ""
    echo -e "  ${BOLD}Obtaining SSL certificate...${NC}"

    sudo certbot --nginx -d "${DOMAIN}" --email "${SSL_EMAIL}" --agree-tos --non-interactive --redirect 2>&1 | while IFS= read -r line; do
        echo -e "  ${DIM}${line}${NC}"
    done

    if sudo certbot certificates 2>/dev/null | grep -q "${DOMAIN}"; then
        print_ok "SSL certificate active for ${DOMAIN}"
    else
        print_warn "SSL may need manual setup: sudo certbot --nginx -d ${DOMAIN}"
    fi

    # Auto-renewal cron
    if ! crontab -l 2>/dev/null | grep -q certbot; then
        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
        print_ok "SSL auto-renewal cron added"
    fi
fi

# ---- Step 9: Setup Admin Account ----
print_step "9/9 - Creating Admin Account"

API_BASE="http://127.0.0.1:${BACKEND_PORT}/api"

# Wait for backend to be ready
echo ""
echo -e "  ${DIM}Waiting for API...${NC}"
sleep 2

# Check backend health first
HEALTH=$(curl -s "${API_BASE}/health" 2>/dev/null)
if echo "$HEALTH" | grep -q "healthy"; then
    print_ok "Backend API is healthy"
else
    print_warn "Backend API not responding. Admin setup skipped."
    print_info "After fixing backend, register manually and call:"
    print_info "  curl -X POST ${API_BASE}/admin/setup"
    echo ""
    # Skip to final output
    ADMIN_SETUP_SKIPPED=true
fi

if [ "${ADMIN_SETUP_SKIPPED}" != "true" ]; then
    # Register admin
    REG_RESP=$(curl -s -w "\n%{http_code}" -X POST "${API_BASE}/auth/register" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}" 2>/dev/null)

    REG_HTTP=$(echo "$REG_RESP" | tail -1)
    REG_BODY=$(echo "$REG_RESP" | head -n -1)

    if [ "$REG_HTTP" = "200" ]; then
        print_ok "Admin user registered: ${ADMIN_EMAIL}"
    elif echo "$REG_BODY" | grep -q "already registered"; then
        print_warn "Admin user already exists"
    else
        print_warn "Registration issue (HTTP $REG_HTTP). Will try admin setup anyway."
    fi

    # Promote to admin
    SETUP_RESP=$(curl -s "${API_BASE}/admin/setup" -X POST 2>/dev/null)
    if echo "$SETUP_RESP" | grep -q "now admin"; then
        print_ok "Admin role activated for ${ADMIN_EMAIL}"
    elif echo "$SETUP_RESP" | grep -q "Not found"; then
        print_warn "User not found. Register first at the website, then run:"
        print_info "  curl -X POST ${API_BASE}/admin/setup"
    else
        print_warn "Admin setup: $SETUP_RESP"
    fi
fi

# ---- Done! ----
echo ""
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════╗"
echo "  ║                                                       ║"
echo "  ║     DNSLAB.BIZ Installation Complete!                  ║"
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
    echo -e "  ${BOLD}Admin Panel:${NC}    ${GREEN}http://localhost:3000/admin${NC}"
fi

echo ""
echo -e "  ${BOLD}Admin Email:${NC}    ${ADMIN_EMAIL}"
echo ""
echo -e "  ${BOLD}Commands:${NC}"
echo -e "    sudo systemctl status ddns-backend     ${DIM}# Status${NC}"
echo -e "    sudo systemctl restart ddns-backend     ${DIM}# Restart${NC}"
echo -e "    sudo journalctl -u ddns-backend -f      ${DIM}# Logs${NC}"

if [ "$USE_SSL" = true ]; then
    echo -e "    sudo systemctl restart nginx            ${DIM}# Restart nginx${NC}"
    echo -e "    sudo certbot renew --dry-run            ${DIM}# Test SSL${NC}"
fi

echo ""
echo -e "  ${MAGENTA}Support: ${BOLD}https://t.me/DZ_CT${NC}"
echo ""
