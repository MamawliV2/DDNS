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
NC='\033[0m' # No Color
BOLD='\033[1m'

# Banner
echo -e "${BLUE}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║                                          ║"
echo "  ║         DDNS.LAND Installer               ║"
echo "  ║    Free Dynamic DNS Service              ║"
echo "  ║                                          ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ---- Helper functions ----
print_step() {
    echo -e "\n${CYAN}[$(date '+%H:%M:%S')]${NC} ${BOLD}$1${NC}"
}

print_success() {
    echo -e "${GREEN}  ✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}  ! $1${NC}"
}

print_error() {
    echo -e "${RED}  ✗ $1${NC}"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        print_success "$1 found: $(command -v $1)"
        return 0
    else
        print_error "$1 not found"
        return 1
    fi
}

# ---- Step 1: Check Prerequisites ----
print_step "Step 1/8: Checking prerequisites..."

MISSING=()

if ! check_command python3; then
    MISSING+=("python3")
fi

if ! check_command node; then
    MISSING+=("nodejs")
else
    NODE_VER=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VER" -lt 16 ]; then
        print_warning "Node.js version $NODE_VER is below recommended (16+)"
    fi
fi

if ! check_command yarn; then
    print_warning "yarn not found. Installing globally..."
    npm install -g yarn 2>/dev/null || {
        print_error "Failed to install yarn. Please install it manually: npm install -g yarn"
        exit 1
    }
    print_success "yarn installed"
fi

if ! check_command mongod && ! check_command mongosh; then
    print_warning "MongoDB not detected locally. Make sure MongoDB is running and accessible."
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    print_error "Missing required tools: ${MISSING[*]}"
    echo -e "\nPlease install them and re-run this script."
    echo "  - Python 3: https://www.python.org/downloads/"
    echo "  - Node.js:  https://nodejs.org/"
    echo "  - MongoDB:  https://www.mongodb.com/docs/manual/installation/"
    exit 1
fi

# ---- Step 2: Collect Configuration ----
print_step "Step 2/8: Configuration..."

echo ""
echo -e "${BOLD}Cloudflare Configuration${NC}"
echo -e "  (Get your API Token & Zone ID from https://dash.cloudflare.com)"
echo ""

read -p "  Cloudflare API Token: " CF_TOKEN
while [ -z "$CF_TOKEN" ]; do
    print_error "API Token cannot be empty"
    read -p "  Cloudflare API Token: " CF_TOKEN
done

read -p "  Cloudflare Zone ID: " CF_ZONE_ID
while [ -z "$CF_ZONE_ID" ]; do
    print_error "Zone ID cannot be empty"
    read -p "  Cloudflare Zone ID: " CF_ZONE_ID
done

echo ""
echo -e "${BOLD}MongoDB Configuration${NC}"
read -p "  MongoDB URL [mongodb://localhost:27017]: " MONGO_URL
MONGO_URL=${MONGO_URL:-mongodb://localhost:27017}

read -p "  Database Name [ddns_land]: " DB_NAME
DB_NAME=${DB_NAME:-ddns_land}

echo ""
echo -e "${BOLD}Admin Account${NC}"
echo -e "  (Note: Only @gmail.com addresses are allowed)"

read -p "  Admin Email: " ADMIN_EMAIL
while [[ ! "$ADMIN_EMAIL" == *@gmail.com ]]; do
    print_error "Admin email must be a @gmail.com address"
    read -p "  Admin Email: " ADMIN_EMAIL
done

read -sp "  Admin Password (min 6 chars): " ADMIN_PASSWORD
echo ""
while [ ${#ADMIN_PASSWORD} -lt 6 ]; do
    print_error "Password must be at least 6 characters"
    read -sp "  Admin Password: " ADMIN_PASSWORD
    echo ""
done

echo ""
echo -e "${BOLD}Server Configuration${NC}"
read -p "  Backend Port [8001]: " BACKEND_PORT
BACKEND_PORT=${BACKEND_PORT:-8001}

read -p "  Frontend Port [3000]: " FRONTEND_PORT
FRONTEND_PORT=${FRONTEND_PORT:-3000}

read -p "  Public URL (e.g., https://ddns.land or http://localhost:8001) [http://localhost:${BACKEND_PORT}]: " PUBLIC_URL
PUBLIC_URL=${PUBLIC_URL:-http://localhost:${BACKEND_PORT}}

# Generate random JWT secret
JWT_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")

# ---- Step 3: Setup Backend ----
print_step "Step 3/8: Setting up backend..."

cd "$(dirname "$0")"
PROJECT_DIR=$(pwd)

# Create Python virtual environment
if [ ! -d "backend/venv" ]; then
    python3 -m venv backend/venv
    print_success "Virtual environment created"
fi

source backend/venv/bin/activate

pip install -r backend/requirements.txt -q
print_success "Backend dependencies installed"

# Create backend .env
cat > backend/.env << EOF
MONGO_URL=${MONGO_URL}
DB_NAME=${DB_NAME}
CORS_ORIGINS=*
CLOUDFLARE_API_TOKEN=${CF_TOKEN}
CLOUDFLARE_ZONE_ID=${CF_ZONE_ID}
JWT_SECRET=${JWT_SECRET}
ADMIN_EMAIL=${ADMIN_EMAIL}
EOF
print_success "Backend .env configured"

# ---- Step 4: Setup Frontend ----
print_step "Step 4/8: Setting up frontend..."

cd frontend
yarn install --silent 2>/dev/null
print_success "Frontend dependencies installed"

# Create frontend .env
cat > .env << EOF
REACT_APP_BACKEND_URL=${PUBLIC_URL}
EOF
print_success "Frontend .env configured"

cd "$PROJECT_DIR"

# ---- Step 5: Build Frontend ----
print_step "Step 5/8: Building frontend for production..."

cd frontend
yarn build --silent 2>/dev/null || yarn build
print_success "Frontend built successfully"
cd "$PROJECT_DIR"

# ---- Step 6: Start Backend ----
print_step "Step 6/8: Starting backend server..."

source backend/venv/bin/activate

# Kill any existing process on backend port
lsof -ti:${BACKEND_PORT} | xargs kill -9 2>/dev/null || true

nohup uvicorn server:app --host 0.0.0.0 --port ${BACKEND_PORT} --app-dir backend > /tmp/ddns-backend.log 2>&1 &
BACKEND_PID=$!

sleep 3

# Check if backend started
if kill -0 $BACKEND_PID 2>/dev/null; then
    print_success "Backend started (PID: $BACKEND_PID)"
else
    print_error "Backend failed to start. Check /tmp/ddns-backend.log"
    cat /tmp/ddns-backend.log
    exit 1
fi

# ---- Step 7: Setup Admin Account ----
print_step "Step 7/8: Setting up admin account..."

API_BASE="http://localhost:${BACKEND_PORT}/api"

# Register admin user
REGISTER_RESPONSE=$(curl -s -X POST "${API_BASE}/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}" 2>/dev/null)

if echo "$REGISTER_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('token',''))" 2>/dev/null | grep -q "."; then
    print_success "Admin user registered: ${ADMIN_EMAIL}"
else
    DETAIL=$(echo "$REGISTER_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('detail',''))" 2>/dev/null)
    if [ "$DETAIL" = "Email already registered" ]; then
        print_warning "Admin user already exists"
    else
        print_warning "Registration response: $DETAIL"
    fi
fi

# Promote to admin
SETUP_RESPONSE=$(curl -s -X POST "${API_BASE}/admin/setup" 2>/dev/null)
SETUP_MSG=$(echo "$SETUP_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message',''))" 2>/dev/null)
print_success "$SETUP_MSG"

# ---- Step 8: Summary ----
print_step "Step 8/8: Installation Complete!"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                  ║${NC}"
echo -e "${GREEN}║  ${BOLD}DDNS.LAND installed successfully!${NC}${GREEN}              ║${NC}"
echo -e "${GREEN}║                                                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Backend API:${NC}     http://localhost:${BACKEND_PORT}"
echo -e "  ${BOLD}Frontend:${NC}        cd frontend && yarn start"
echo -e "  ${BOLD}Frontend Build:${NC}  frontend/build/ (serve with nginx/caddy)"
echo ""
echo -e "  ${BOLD}Admin Panel:${NC}     ${PUBLIC_URL}/admin"
echo -e "  ${BOLD}Admin Email:${NC}     ${ADMIN_EMAIL}"
echo ""
echo -e "  ${BOLD}Backend PID:${NC}     ${BACKEND_PID}"
echo -e "  ${BOLD}Backend Logs:${NC}    /tmp/ddns-backend.log"
echo ""
echo -e "${YELLOW}  Notes:${NC}"
echo -e "  - To run frontend dev server: cd frontend && yarn start"
echo -e "  - To serve production build: use nginx/caddy with frontend/build/"
echo -e "  - To stop backend: kill ${BACKEND_PID}"
echo -e "  - Logs: tail -f /tmp/ddns-backend.log"
echo ""
echo -e "${CYAN}  For premium plans: https://t.me/DZ_CT${NC}"
echo ""
