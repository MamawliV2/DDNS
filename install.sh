#!/bin/bash

# ============================================================
#  DNSLAB.BIZ - Automated Installation Script
#  Free Dynamic DNS Service powered by Cloudflare
#  https://github.com/MamawliV2/DDNS
# ============================================================

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
echo "  ____  _   _ ____  _       _    ____      ____ ___ _____"
echo " |  _ \| \ | / ___|| |     / \  | __ )    | __ )_ _|__  /"
echo " | | | |  \| \___ \| |    / _ \ |  _ \    |  _ \| |  / / "
echo " | |_| | |\  |___) | |___/ ___ \| |_) |   | |_) | | / /_ "
echo " |____/|_| \_|____/|_____/_/   \_\____/ () |____/___/____|"
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
        return 0
    else
        return 1
    fi
}

fail_exit() {
    print_err "$1"
    echo -e "\n  ${RED}Installation aborted.${NC}\n"
    exit 1
}

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Prevent interactive prompts during package installation
export DEBIAN_FRONTEND=noninteractive

# ---- Check root/sudo ----
if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo &> /dev/null; then
        fail_exit "This script requires root privileges. Run with: sudo bash install.sh"
    fi
    SUDO="sudo"
else
    SUDO=""
fi

# ---- Detect OS ----
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
    OS_CODENAME=$VERSION_CODENAME
else
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    OS_VERSION=""
    OS_CODENAME=""
fi
print_info "Detected OS: $OS $OS_VERSION ($OS_CODENAME)"

# ---- Supported OS check ----
case "$OS" in
    ubuntu|debian|centos|rhel|rocky|almalinux|fedora)
        print_ok "Supported OS: $OS"
        ;;
    *)
        print_warn "OS '$OS' is not officially supported. The script will try to continue."
        print_info "Supported: Ubuntu, Debian, CentOS, RHEL, Rocky, AlmaLinux, Fedora"
        read -p "  Continue anyway? (y/N): " CONT
        [[ ! "$CONT" =~ ^[Yy]$ ]] && exit 0
        ;;
esac

# ---- Helper: package installer ----
pkg_install() {
    case "$OS" in
        ubuntu|debian)
            $SUDO apt-get install -y -qq "$@" > /dev/null 2>&1
            ;;
        centos|rhel|rocky|almalinux)
            $SUDO yum install -y -q "$@" > /dev/null 2>&1
            ;;
        fedora)
            $SUDO dnf install -y -q "$@" > /dev/null 2>&1
            ;;
    esac
}

pkg_update() {
    case "$OS" in
        ubuntu|debian)
            $SUDO apt-get update -qq > /dev/null 2>&1
            ;;
        centos|rhel|rocky|almalinux)
            $SUDO yum makecache -q > /dev/null 2>&1
            ;;
        fedora)
            $SUDO dnf makecache -q > /dev/null 2>&1
            ;;
    esac
}

# ============================================================
#  STEP 1: Install ALL prerequisites automatically
# ============================================================
print_step "1/9 - Installing prerequisites"

echo ""
echo -e "  ${BOLD}Phase 1: Basic system tools${NC}"
echo ""

# Update package lists first
print_info "Updating package lists..."
pkg_update
print_ok "Package lists updated"

# Install essential tools that the rest of the script depends on
BASIC_TOOLS_DEB="curl wget git ca-certificates gnupg lsb-release software-properties-common build-essential"
BASIC_TOOLS_RPM="curl wget git ca-certificates gnupg2"

case "$OS" in
    ubuntu|debian)
        print_info "Installing basic tools..."
        $SUDO apt-get install -y -qq $BASIC_TOOLS_DEB > /dev/null 2>&1
        ;;
    centos|rhel|rocky|almalinux)
        print_info "Installing basic tools..."
        $SUDO yum install -y -q $BASIC_TOOLS_RPM > /dev/null 2>&1
        $SUDO yum groupinstall -y -q "Development Tools" > /dev/null 2>&1 || true
        ;;
    fedora)
        print_info "Installing basic tools..."
        $SUDO dnf install -y -q $BASIC_TOOLS_RPM > /dev/null 2>&1
        $SUDO dnf groupinstall -y -q "Development Tools" > /dev/null 2>&1 || true
        ;;
esac

for tool in curl wget git; do
    if check_command "$tool"; then
        print_ok "$tool"
    else
        print_warn "$tool not found after install attempt"
    fi
done

# ---- Python 3 ----
echo ""
echo -e "  ${BOLD}Phase 2: Python 3${NC}"
echo ""

if check_command python3; then
    PYTHON_VER=$(python3 --version 2>&1 | awk '{print $2}')
    print_ok "Python $PYTHON_VER"
else
    print_warn "Python 3 not found. Installing..."
    case "$OS" in
        ubuntu|debian)
            $SUDO apt-get install -y -qq python3 python3-pip python3-venv python3-dev > /dev/null 2>&1
            # Also install version-specific venv package
            PY_VER_INIT=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
            if [ -n "$PY_VER_INIT" ]; then
                $SUDO apt-get install -y -qq "python${PY_VER_INIT}-venv" > /dev/null 2>&1
            fi
            ;;
        centos|rhel|rocky|almalinux)
            $SUDO yum install -y -q python3 python3-pip python3-devel > /dev/null 2>&1
            ;;
        fedora)
            $SUDO dnf install -y -q python3 python3-pip python3-devel > /dev/null 2>&1
            ;;
    esac
    if check_command python3; then
        print_ok "Python $(python3 --version 2>&1 | awk '{print $2}') installed"
    else
        fail_exit "Python 3 installation failed. Install manually: https://www.python.org/downloads/"
    fi
fi

# Ensure pip3
if ! python3 -m pip --version > /dev/null 2>&1; then
    print_warn "pip not found. Installing..."
    case "$OS" in
        ubuntu|debian)
            $SUDO apt-get install -y -qq python3-pip > /dev/null 2>&1
            ;;
        *)
            curl -sS https://bootstrap.pypa.io/get-pip.py | python3 > /dev/null 2>&1 || true
            ;;
    esac
    if python3 -m pip --version > /dev/null 2>&1; then
        print_ok "pip installed"
    else
        print_warn "pip may not be available. Will try to continue."
    fi
else
    print_ok "pip $(python3 -m pip --version 2>&1 | awk '{print $2}')"
fi

# Ensure python3-venv + ensurepip (test by actually creating a temp venv)
PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
VENV_TEST_DIR=$(mktemp -d)
VENV_OK=false

if python3 -m venv "$VENV_TEST_DIR/test_venv" > /dev/null 2>&1; then
    VENV_OK=true
fi
rm -rf "$VENV_TEST_DIR"

if [ "$VENV_OK" = false ]; then
    print_warn "python3-venv/ensurepip not working. Installing for Python ${PY_VER}..."
    case "$OS" in
        ubuntu|debian)
            $SUDO apt-get install -y -qq "python${PY_VER}-venv" python3-venv > /dev/null 2>&1
            # If still missing, try installing ensurepip directly
            if ! python3 -c "import ensurepip" > /dev/null 2>&1; then
                $SUDO apt-get install -y -qq "python${PY_VER}-full" > /dev/null 2>&1 || true
            fi
            ;;
        centos|rhel|rocky|almalinux)
            $SUDO yum install -y -q python3-libs > /dev/null 2>&1 || true
            ;;
        fedora)
            $SUDO dnf install -y -q python3-libs > /dev/null 2>&1 || true
            ;;
    esac

    # Verify again
    VENV_TEST_DIR2=$(mktemp -d)
    if python3 -m venv "$VENV_TEST_DIR2/test_venv" > /dev/null 2>&1; then
        print_ok "python3-venv installed and working"
    else
        print_warn "python3-venv still not working. Will try --without-pip fallback in Step 6."
    fi
    rm -rf "$VENV_TEST_DIR2"
else
    print_ok "python3-venv (Python ${PY_VER})"
fi

# ---- Node.js 20.x ----
echo ""
echo -e "  ${BOLD}Phase 3: Node.js${NC}"
echo ""

NEED_NODE=false
if check_command node; then
    NODE_VER=$(node -v 2>&1)
    NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_MAJOR" -ge 18 ] 2>/dev/null; then
        print_ok "Node.js $NODE_VER"
    else
        print_warn "Node.js $NODE_VER is too old (need 18+). Will upgrade..."
        NEED_NODE=true
    fi
else
    print_warn "Node.js not found."
    NEED_NODE=true
fi

if [ "$NEED_NODE" = true ]; then
    print_info "Installing Node.js 20.x..."
    case "$OS" in
        ubuntu|debian)
            # Remove old nodejs if present
            $SUDO apt-get remove -y -qq nodejs > /dev/null 2>&1 || true

            # Setup NodeSource repository
            $SUDO mkdir -p /etc/apt/keyrings
            curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | $SUDO gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg --yes 2>/dev/null
            echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | $SUDO tee /etc/apt/sources.list.d/nodesource.list > /dev/null
            $SUDO apt-get update -qq > /dev/null 2>&1
            $SUDO apt-get install -y -qq nodejs > /dev/null 2>&1

            # If NodeSource fails, try alternative: install via nvm-like approach
            if ! check_command node; then
                print_warn "NodeSource failed. Trying alternative install..."
                curl -fsSL https://deb.nodesource.com/setup_20.x | $SUDO -E bash - > /dev/null 2>&1
                $SUDO apt-get install -y -qq nodejs > /dev/null 2>&1
            fi
            ;;
        centos|rhel|rocky|almalinux)
            curl -fsSL https://rpm.nodesource.com/setup_20.x | $SUDO bash - > /dev/null 2>&1
            $SUDO yum install -y -q nodejs > /dev/null 2>&1
            ;;
        fedora)
            curl -fsSL https://rpm.nodesource.com/setup_20.x | $SUDO bash - > /dev/null 2>&1
            $SUDO dnf install -y -q nodejs > /dev/null 2>&1
            ;;
        *)
            fail_exit "Cannot auto-install Node.js on $OS. Install from https://nodejs.org/ and re-run."
            ;;
    esac

    if check_command node; then
        print_ok "Node.js $(node -v) installed"
    else
        fail_exit "Node.js installation failed. Install manually from https://nodejs.org/ and re-run."
    fi
fi

# Ensure npm is available
if ! check_command npm; then
    print_warn "npm not found. Installing..."
    case "$OS" in
        ubuntu|debian)
            $SUDO apt-get install -y -qq npm > /dev/null 2>&1
            ;;
    esac
    if check_command npm; then
        print_ok "npm $(npm -v)"
    else
        print_warn "npm not found. Will try corepack for yarn."
    fi
else
    print_ok "npm $(npm -v)"
fi

# ---- Yarn ----
echo ""
echo -e "  ${BOLD}Phase 4: Yarn${NC}"
echo ""

if check_command yarn; then
    print_ok "yarn $(yarn -v)"
else
    print_info "Installing yarn..."
    YARN_INSTALLED=false

    # Method 1: via npm
    if check_command npm; then
        $SUDO npm install -g yarn > /dev/null 2>&1 && YARN_INSTALLED=true
    fi

    # Method 2: via corepack (comes with Node.js 16+)
    if [ "$YARN_INSTALLED" = false ] && check_command corepack; then
        $SUDO corepack enable > /dev/null 2>&1
        corepack prepare yarn@stable --activate > /dev/null 2>&1 && YARN_INSTALLED=true
    fi

    # Method 3: via official apt repo
    if [ "$YARN_INSTALLED" = false ]; then
        case "$OS" in
            ubuntu|debian)
                curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | $SUDO gpg --dearmor -o /usr/share/keyrings/yarnkey.gpg --yes 2>/dev/null
                echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" | $SUDO tee /etc/apt/sources.list.d/yarn.list > /dev/null
                $SUDO apt-get update -qq > /dev/null 2>&1
                $SUDO apt-get install -y -qq yarn > /dev/null 2>&1 && YARN_INSTALLED=true
                ;;
        esac
    fi

    if check_command yarn; then
        print_ok "yarn $(yarn -v) installed"
    else
        fail_exit "Could not install yarn. Install manually: https://yarnpkg.com/getting-started/install"
    fi
fi

# ---- MongoDB ----
echo ""
echo -e "  ${BOLD}Phase 5: MongoDB${NC}"
echo ""

MONGO_RUNNING=false
if command -v mongod > /dev/null 2>&1 || command -v mongosh > /dev/null 2>&1; then
    MONGO_RUNNING=true
fi
if systemctl is-active --quiet mongod 2>/dev/null; then
    MONGO_RUNNING=true
fi
# Also check if mongo is reachable on default port
if curl -s --connect-timeout 2 http://127.0.0.1:27017 > /dev/null 2>&1; then
    MONGO_RUNNING=true
fi

if [ "$MONGO_RUNNING" = true ]; then
    print_ok "MongoDB detected"
else
    print_warn "MongoDB not found. Installing MongoDB 7.0..."
    case "$OS" in
        ubuntu|debian)
            # Install gnupg if needed
            $SUDO apt-get install -y -qq gnupg > /dev/null 2>&1

            # Import MongoDB public GPG key
            curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | $SUDO gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg --yes 2>/dev/null

            # Determine the correct codename
            if [ -n "$OS_CODENAME" ]; then
                CODENAME="$OS_CODENAME"
            else
                CODENAME=$(lsb_release -cs 2>/dev/null || echo "jammy")
            fi

            # For newer Ubuntu versions that MongoDB may not support yet, fall back
            case "$CODENAME" in
                jammy|focal|bionic) ;; # supported
                noble|mantic|lunar|kinetic) CODENAME="jammy" ;; # use jammy as fallback
                bookworm|bullseye|buster) ;; # debian supported
                *) CODENAME="jammy" ;; # default fallback
            esac

            if [ "$OS" = "debian" ]; then
                echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/debian ${CODENAME}/mongodb-org/7.0 main" | $SUDO tee /etc/apt/sources.list.d/mongodb-org-7.0.list > /dev/null
            else
                echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu ${CODENAME}/mongodb-org/7.0 multiverse" | $SUDO tee /etc/apt/sources.list.d/mongodb-org-7.0.list > /dev/null
            fi

            $SUDO apt-get update -qq > /dev/null 2>&1
            $SUDO apt-get install -y -qq mongodb-org > /dev/null 2>&1

            # Fallback: try community package if mongodb-org fails
            if ! check_command mongod; then
                $SUDO apt-get install -y -qq mongodb > /dev/null 2>&1
            fi
            ;;
        centos|rhel|rocky|almalinux|fedora)
            cat << 'REPOEOF' | $SUDO tee /etc/yum.repos.d/mongodb-org-7.0.repo > /dev/null
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-7.0.asc
REPOEOF
            $SUDO yum install -y -q mongodb-org > /dev/null 2>&1 || $SUDO dnf install -y -q mongodb-org > /dev/null 2>&1
            ;;
        *)
            print_warn "Cannot auto-install MongoDB on $OS."
            print_info "Install from: https://www.mongodb.com/docs/manual/installation/"
            ;;
    esac

    # Enable and start MongoDB
    $SUDO systemctl daemon-reload > /dev/null 2>&1 || true
    $SUDO systemctl enable mongod > /dev/null 2>&1 || true
    $SUDO systemctl start mongod > /dev/null 2>&1 || true

    # Wait and verify
    sleep 3
    if systemctl is-active --quiet mongod 2>/dev/null; then
        print_ok "MongoDB installed and running"
    else
        # Try starting with different service name
        $SUDO systemctl start mongodb > /dev/null 2>&1 || true
        if systemctl is-active --quiet mongodb 2>/dev/null; then
            print_ok "MongoDB installed and running (mongodb service)"
        else
            print_warn "MongoDB installed but may need manual start:"
            print_info "  sudo systemctl start mongod"
            print_info "  sudo journalctl -u mongod -n 20"
            read -p "  Continue anyway? (y/N): " CONT_MONGO
            [[ ! "$CONT_MONGO" =~ ^[Yy]$ ]] && exit 1
        fi
    fi
fi

echo ""
print_ok "All prerequisites installed successfully"

# ============================================================
#  STEP 2: Domain & SSL Configuration
# ============================================================
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

    # Install nginx if not present
    if ! check_command nginx; then
        print_info "Installing nginx..."
        case "$OS" in
            ubuntu|debian) $SUDO apt-get install -y -qq nginx > /dev/null 2>&1 ;;
            centos|rhel|rocky|almalinux) $SUDO yum install -y -q epel-release > /dev/null 2>&1 && $SUDO yum install -y -q nginx > /dev/null 2>&1 ;;
            fedora) $SUDO dnf install -y -q nginx > /dev/null 2>&1 ;;
            *) fail_exit "Cannot auto-install nginx on $OS." ;;
        esac
        if check_command nginx; then
            print_ok "nginx installed"
        else
            fail_exit "nginx installation failed."
        fi
    else
        print_ok "nginx"
    fi

    # Install certbot if not present
    if ! check_command certbot; then
        print_info "Installing certbot..."
        case "$OS" in
            ubuntu|debian) $SUDO apt-get install -y -qq certbot python3-certbot-nginx > /dev/null 2>&1 ;;
            centos|rhel|rocky|almalinux) $SUDO yum install -y -q certbot python3-certbot-nginx > /dev/null 2>&1 ;;
            fedora) $SUDO dnf install -y -q certbot python3-certbot-nginx > /dev/null 2>&1 ;;
        esac
        if check_command certbot; then
            print_ok "certbot installed"
        else
            print_warn "certbot installation failed. SSL setup may need manual steps."
        fi
    else
        print_ok "certbot"
    fi
else
    PUBLIC_URL="http://localhost:${BACKEND_PORT}"
    print_info "No domain entered. Running on localhost."
fi

# ============================================================
#  STEP 3: Cloudflare Configuration
# ============================================================
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

# ============================================================
#  STEP 4: Database Configuration
# ============================================================
print_step "4/9 - Database Configuration"

echo ""
read -p "  MongoDB URL [mongodb://localhost:27017]: " MONGO_URL
MONGO_URL=${MONGO_URL:-mongodb://localhost:27017}

read -p "  Database name [ddns_land]: " DB_NAME
DB_NAME=${DB_NAME:-ddns_land}

print_ok "Database: ${DB_NAME} at ${MONGO_URL}"

# ============================================================
#  STEP 5: Admin Account
# ============================================================
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

JWT_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null || head -c 32 /dev/urandom | xxd -p | tr -d '\n')

# ============================================================
#  STEP 6: Install Application Dependencies
# ============================================================
print_step "6/9 - Installing Application Dependencies"

echo ""
echo -e "  ${BOLD}Backend setup...${NC}"

cd "$PROJECT_DIR"

# Create Python virtual environment
if [ ! -d "backend/venv" ]; then
    print_info "Creating Python virtual environment..."
    if ! python3 -m venv backend/venv > /dev/null 2>&1; then
        print_warn "venv creation failed. Auto-fixing..."

        # Detect Python version and install the correct venv package
        PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        print_info "Detected Python ${PY_VER}, installing python${PY_VER}-venv..."

        case "$OS" in
            ubuntu|debian)
                $SUDO apt-get update -qq > /dev/null 2>&1
                $SUDO apt-get install -y -qq "python${PY_VER}-venv" python3-venv > /dev/null 2>&1
                ;;
            centos|rhel|rocky|almalinux)
                $SUDO yum install -y -q python3-libs > /dev/null 2>&1
                ;;
            fedora)
                $SUDO dnf install -y -q python3-libs > /dev/null 2>&1
                ;;
        esac

        # Retry venv creation
        rm -rf backend/venv 2>/dev/null
        if python3 -m venv backend/venv > /dev/null 2>&1; then
            print_ok "Python venv created (after auto-fix)"
        else
            # Last resort: create venv without pip, then install pip manually
            print_warn "Trying --without-pip fallback..."
            rm -rf backend/venv 2>/dev/null
            python3 -m venv --without-pip backend/venv > /dev/null 2>&1
            if [ -d "backend/venv" ]; then
                source backend/venv/bin/activate
                curl -sS https://bootstrap.pypa.io/get-pip.py | python3 > /dev/null 2>&1
                print_ok "Python venv created (without-pip fallback)"
            else
                fail_exit "Failed to create Python virtual environment. Run manually: sudo apt install python${PY_VER}-venv"
            fi
        fi
    else
        print_ok "Python venv created"
    fi
else
    print_ok "Python venv exists"
fi

# Activate venv and install packages
source backend/venv/bin/activate
print_info "Upgrading pip..."
pip install --upgrade pip > /dev/null 2>&1
print_info "Installing backend dependencies..."
pip install -r backend/requirements.txt > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_ok "Backend packages installed"
else
    print_warn "Some backend packages may have failed. Retrying..."
    pip install -r backend/requirements.txt 2>&1 | tail -5
fi

# Ensure uvicorn is installed
if [ ! -f "$PROJECT_DIR/backend/venv/bin/uvicorn" ]; then
    print_info "Installing uvicorn..."
    pip install uvicorn > /dev/null 2>&1
fi

echo ""
echo -e "  ${BOLD}Frontend setup...${NC}"
cd "$PROJECT_DIR/frontend"
print_info "Installing frontend packages (this may take a few minutes)..."
yarn install --network-timeout 120000 2>&1 | tail -3
if [ $? -eq 0 ]; then
    print_ok "Frontend packages installed"
else
    print_warn "Retrying frontend install..."
    yarn install 2>&1 | tail -5
fi
cd "$PROJECT_DIR"

# ============================================================
#  STEP 7: Configure Environment
# ============================================================
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
print_ok "backend/.env configured"

# Frontend .env
cat > "$PROJECT_DIR/frontend/.env" << ENVEOF
REACT_APP_BACKEND_URL=${PUBLIC_URL}
ENVEOF
print_ok "frontend/.env configured"

# Build frontend
echo ""
echo -e "  ${BOLD}Building frontend for production...${NC}"
cd "$PROJECT_DIR/frontend"
yarn build 2>&1 | tail -5
if [ -d "build" ] && [ -f "build/index.html" ]; then
    print_ok "Frontend build complete"
else
    print_warn "Frontend build may have issues. Check manually: cd frontend && yarn build"
fi
cd "$PROJECT_DIR"

# ============================================================
#  STEP 8: Setup Services
# ============================================================
print_step "8/9 - Setting up Services"

PYTHON_PATH="$PROJECT_DIR/backend/venv/bin/python"

# Stop existing service if running
$SUDO systemctl stop ddns-backend > /dev/null 2>&1 || true

echo ""
echo -e "  ${BOLD}Creating backend systemd service...${NC}"

$SUDO tee /etc/systemd/system/ddns-backend.service > /dev/null << SVCEOF
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

$SUDO systemctl daemon-reload
$SUDO systemctl enable ddns-backend --quiet > /dev/null 2>&1
$SUDO systemctl restart ddns-backend

echo -e "  ${DIM}Waiting for backend to start...${NC}"
sleep 5

RETRIES=0
BACKEND_OK=false
while [ $RETRIES -lt 10 ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${BACKEND_PORT}/api/health" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
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
    $SUDO journalctl -u ddns-backend -n 20 --no-pager 2>/dev/null || true
    echo ""
    print_warn "Debug with: sudo journalctl -u ddns-backend -f"
    read -p "  Continue anyway? (y/N): " CONT_ANYWAY
    if [[ ! "$CONT_ANYWAY" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ---- Nginx & SSL (if domain is set) ----
if [ "$USE_SSL" = true ]; then
    echo ""
    echo -e "  ${BOLD}Configuring nginx...${NC}"

    # Create nginx config
    $SUDO tee /etc/nginx/sites-available/dnslab-biz > /dev/null << NGXEOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        root ${PROJECT_DIR}/frontend/build;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

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

    location /static/ {
        root ${PROJECT_DIR}/frontend/build;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
NGXEOF

    # Enable site
    $SUDO mkdir -p /etc/nginx/sites-enabled
    $SUDO rm -f /etc/nginx/sites-enabled/default > /dev/null 2>&1
    $SUDO ln -sf /etc/nginx/sites-available/dnslab-biz /etc/nginx/sites-enabled/

    # Test and restart nginx
    if $SUDO nginx -t > /dev/null 2>&1; then
        $SUDO systemctl restart nginx
        print_ok "nginx configured for ${DOMAIN}"
    else
        print_err "nginx config error:"
        $SUDO nginx -t
    fi

    # Obtain SSL certificate
    echo ""
    echo -e "  ${BOLD}Obtaining SSL certificate...${NC}"

    $SUDO certbot --nginx -d "${DOMAIN}" --email "${SSL_EMAIL}" --agree-tos --non-interactive --redirect 2>&1 | while IFS= read -r line; do
        echo -e "  ${DIM}${line}${NC}"
    done

    if $SUDO certbot certificates 2>/dev/null | grep -q "${DOMAIN}"; then
        print_ok "SSL certificate active for ${DOMAIN}"
    else
        print_warn "SSL may need manual setup: sudo certbot --nginx -d ${DOMAIN}"
    fi

    # Auto-renewal cron
    if ! crontab -l 2>/dev/null | grep -q certbot; then
        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
        print_ok "SSL auto-renewal cron added"
    fi

    # Fix permissions
    chmod 755 "$(dirname "$PROJECT_DIR")" > /dev/null 2>&1 || true
    chmod 755 "$PROJECT_DIR" > /dev/null 2>&1 || true
    chmod -R 755 "$PROJECT_DIR/frontend/build" > /dev/null 2>&1 || true
    print_ok "File permissions set"
fi

# ============================================================
#  STEP 9: Setup Admin Account
# ============================================================
print_step "9/9 - Creating Admin Account"

API_BASE="http://127.0.0.1:${BACKEND_PORT}/api"

echo ""
echo -e "  ${DIM}Waiting for API to be ready...${NC}"
sleep 3

HEALTH=$(curl -s "${API_BASE}/health" 2>/dev/null)
if echo "$HEALTH" | grep -q "healthy"; then
    print_ok "Backend API is healthy"

    # Register admin user
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
        print_warn "Registration response: HTTP $REG_HTTP"
    fi

    # Promote to admin
    SETUP_RESP=$(curl -s -X POST "${API_BASE}/admin/setup" 2>/dev/null)
    if echo "$SETUP_RESP" | grep -q "now admin"; then
        print_ok "Admin role activated for ${ADMIN_EMAIL}"
    else
        print_warn "Admin setup: $SETUP_RESP"
    fi
else
    print_warn "Backend not responding. After fixing, run these commands manually:"
    print_info "  curl -X POST ${API_BASE}/auth/register -H 'Content-Type: application/json' -d '{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"YOUR_PASSWORD\"}'"
    print_info "  curl -X POST ${API_BASE}/admin/setup"
fi

# ============================================================
#  DONE!
# ============================================================
echo ""
echo ""
echo -e "${GREEN}${BOLD}"
echo "  +=========================================================+"
echo "  |                                                         |"
echo "  |     DNSLAB.BIZ Installation Complete!                   |"
echo "  |                                                         |"
echo "  +=========================================================+"
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
echo -e "  ${BOLD}Useful Commands:${NC}"
echo -e "    sudo systemctl status ddns-backend     ${DIM}# Check status${NC}"
echo -e "    sudo systemctl restart ddns-backend     ${DIM}# Restart backend${NC}"
echo -e "    sudo journalctl -u ddns-backend -f      ${DIM}# View logs${NC}"

if [ "$USE_SSL" = true ]; then
    echo -e "    sudo systemctl restart nginx            ${DIM}# Restart nginx${NC}"
    echo -e "    sudo certbot renew --dry-run            ${DIM}# Test SSL renewal${NC}"
fi

echo ""
echo -e "  ${MAGENTA}Support: ${BOLD}https://t.me/DZ_CT${NC}"
echo ""
