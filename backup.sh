#!/bin/bash

# ============================================================
#  DNSLAB.BIZ - Backup & Restore Script
#  Backs up MongoDB database and sends to Telegram
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Telegram config
BOT_TOKEN="8430261121:AAGWHza5uWFk94fq36DwFcAN-xQrfybswKQ"
CHAT_ID="865122337"

# Database config (same as backend/.env)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/backend/.env" ]; then
    MONGO_URL=$(grep '^MONGO_URL' "$SCRIPT_DIR/backend/.env" | cut -d'=' -f2- | tr -d '"')
    DB_NAME=$(grep '^DB_NAME' "$SCRIPT_DIR/backend/.env" | cut -d'=' -f2- | tr -d '"')
fi
MONGO_URL=${MONGO_URL:-mongodb://localhost:27017}
DB_NAME=${DB_NAME:-ddns_land}

# Backup directory
BACKUP_DIR="$SCRIPT_DIR/backups"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${DATE}"

print_ok() { echo -e "  ${GREEN}[OK]${NC} $1"; }
print_err() { echo -e "  ${RED}[ERROR]${NC} $1"; }
print_info() { echo -e "  ${DIM}$1${NC}"; }

send_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$message" \
        -d parse_mode="HTML" > /dev/null 2>&1
}

send_telegram_file() {
    local file="$1"
    local caption="$2"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
        -F chat_id="$CHAT_ID" \
        -F document=@"$file" \
        -F caption="$caption" \
        -F parse_mode="HTML" > /dev/null 2>&1
}

# ---- BACKUP ----
do_backup() {
    echo ""
    echo -e "${CYAN}${BOLD}  DNSLAB.BIZ - Database Backup${NC}"
    echo ""

    mkdir -p "$BACKUP_DIR"

    # Check mongodump
    if ! command -v mongodump &> /dev/null; then
        print_err "mongodump not found. Installing mongodb-database-tools..."
        sudo apt-get install -y -qq mongodb-database-tools > /dev/null 2>&1 || \
        sudo yum install -y -q mongodb-database-tools > /dev/null 2>&1
        if ! command -v mongodump &> /dev/null; then
            print_err "Install mongodb-database-tools manually: https://www.mongodb.com/try/download/database-tools"
            exit 1
        fi
    fi

    print_info "Backing up database: $DB_NAME"

    mongodump --uri="$MONGO_URL" --db="$DB_NAME" --out="$BACKUP_FILE" --quiet 2>/dev/null
    if [ $? -ne 0 ]; then
        print_err "mongodump failed"
        send_telegram "❌ <b>DNSLAB Backup Failed</b>%0A$(date '+%Y-%m-%d %H:%M')"
        exit 1
    fi

    # Compress
    ARCHIVE="${BACKUP_FILE}.tar.gz"
    tar -czf "$ARCHIVE" -C "$BACKUP_DIR" "${DB_NAME}_${DATE}" 2>/dev/null
    rm -rf "$BACKUP_FILE"

    SIZE=$(du -h "$ARCHIVE" | cut -f1)
    print_ok "Backup created: $ARCHIVE ($SIZE)"

    # Count records
    USERS=$(mongosh "$MONGO_URL/$DB_NAME" --quiet --eval "db.users.countDocuments()" 2>/dev/null || echo "?")
    RECORDS=$(mongosh "$MONGO_URL/$DB_NAME" --quiet --eval "db.dns_records.countDocuments()" 2>/dev/null || echo "?")
    DOMAINS=$(mongosh "$MONGO_URL/$DB_NAME" --quiet --eval "db.domains.countDocuments()" 2>/dev/null || echo "?")

    # Send to Telegram
    print_info "Sending to Telegram..."
    send_telegram_file "$ARCHIVE" "✅ DNSLAB Backup
📅 $(date '+%Y-%m-%d %H:%M')
📦 Size: $SIZE
👥 Users: $USERS
📋 Records: $RECORDS
🌐 Domains: $DOMAINS"

    if [ $? -eq 0 ]; then
        print_ok "Sent to Telegram"
    else
        print_err "Failed to send to Telegram"
    fi

    # Keep only last 7 local backups
    ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f 2>/dev/null
    print_ok "Cleanup: keeping last 7 backups"

    echo ""
    print_ok "Backup complete!"
    echo ""
}

# ---- RESTORE ----
do_restore() {
    echo ""
    echo -e "${CYAN}${BOLD}  DNSLAB.BIZ - Database Restore${NC}"
    echo ""

    # Check mongorestore
    if ! command -v mongorestore &> /dev/null; then
        print_err "mongorestore not found. Installing mongodb-database-tools..."
        sudo apt-get install -y -qq mongodb-database-tools > /dev/null 2>&1 || \
        sudo yum install -y -q mongodb-database-tools > /dev/null 2>&1
        if ! command -v mongorestore &> /dev/null; then
            print_err "Install mongodb-database-tools manually"
            exit 1
        fi
    fi

    RESTORE_FILE="$1"

    # If no file specified, show available backups
    if [ -z "$RESTORE_FILE" ]; then
        echo -e "  ${BOLD}Available backups:${NC}"
        echo ""
        BACKUPS=($(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null))
        if [ ${#BACKUPS[@]} -eq 0 ]; then
            print_err "No backups found in $BACKUP_DIR"
            echo -e "  ${DIM}Place a backup .tar.gz file in $BACKUP_DIR or specify path:${NC}"
            echo -e "  ${DIM}  bash backup.sh restore /path/to/backup.tar.gz${NC}"
            exit 1
        fi
        for i in "${!BACKUPS[@]}"; do
            SIZE=$(du -h "${BACKUPS[$i]}" | cut -f1)
            NAME=$(basename "${BACKUPS[$i]}")
            echo -e "    ${GREEN}$((i+1)))${NC} $NAME ($SIZE)"
        done
        echo ""
        read -p "  Select backup number: " CHOICE
        if [ -z "$CHOICE" ] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt ${#BACKUPS[@]} ] 2>/dev/null; then
            print_err "Invalid choice"
            exit 1
        fi
        RESTORE_FILE="${BACKUPS[$((CHOICE-1))]}"
    fi

    if [ ! -f "$RESTORE_FILE" ]; then
        print_err "File not found: $RESTORE_FILE"
        exit 1
    fi

    echo ""
    echo -e "  ${YELLOW}${BOLD}WARNING: This will REPLACE all current data!${NC}"
    echo -e "  ${DIM}File: $(basename "$RESTORE_FILE")${NC}"
    echo ""
    read -p "  Are you sure? (y/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "  Cancelled."
        exit 0
    fi

    # Extract
    TEMP_DIR=$(mktemp -d)
    tar -xzf "$RESTORE_FILE" -C "$TEMP_DIR" 2>/dev/null
    if [ $? -ne 0 ]; then
        print_err "Failed to extract backup"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Find the database directory
    DB_DIR=$(find "$TEMP_DIR" -name "$DB_NAME" -type d | head -1)
    if [ -z "$DB_DIR" ]; then
        # Try finding any directory with bson files
        DB_DIR=$(find "$TEMP_DIR" -name "*.bson" -exec dirname {} \; | head -1)
    fi

    if [ -z "$DB_DIR" ]; then
        print_err "Could not find database files in backup"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    print_info "Restoring from: $(basename "$RESTORE_FILE")"

    mongorestore --uri="$MONGO_URL" --db="$DB_NAME" --drop "$DB_DIR" --quiet 2>/dev/null
    if [ $? -eq 0 ]; then
        print_ok "Database restored successfully!"
        echo ""
        echo -e "  ${DIM}Restart backend: sudo systemctl restart ddns-backend${NC}"
    else
        print_err "Restore failed"
    fi

    rm -rf "$TEMP_DIR"
    echo ""
}

# ---- AUTO BACKUP (for cron) ----
do_auto() {
    mkdir -p "$BACKUP_DIR"

    if ! command -v mongodump &> /dev/null; then
        exit 1
    fi

    mongodump --uri="$MONGO_URL" --db="$DB_NAME" --out="$BACKUP_FILE" --quiet 2>/dev/null
    if [ $? -ne 0 ]; then
        send_telegram "❌ <b>DNSLAB Auto-Backup Failed</b>%0A$(date '+%Y-%m-%d %H:%M')"
        exit 1
    fi

    ARCHIVE="${BACKUP_FILE}.tar.gz"
    tar -czf "$ARCHIVE" -C "$BACKUP_DIR" "${DB_NAME}_${DATE}" 2>/dev/null
    rm -rf "$BACKUP_FILE"

    SIZE=$(du -h "$ARCHIVE" | cut -f1)

    send_telegram_file "$ARCHIVE" "✅ DNSLAB Auto-Backup
📅 $(date '+%Y-%m-%d %H:%M')
📦 $SIZE"

    # Keep only last 7
    ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f 2>/dev/null
}

# ---- SETUP CRON ----
do_cron() {
    echo ""
    echo -e "${CYAN}${BOLD}  Setup Daily Auto-Backup${NC}"
    echo ""

    CRON_CMD="0 3 * * * cd $SCRIPT_DIR && bash backup.sh auto"

    if crontab -l 2>/dev/null | grep -q "backup.sh auto"; then
        print_info "Auto-backup cron already exists"
        crontab -l 2>/dev/null | grep "backup.sh"
    else
        (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
        print_ok "Daily backup scheduled at 3:00 AM"
    fi
    echo ""
}

# ---- HELP ----
show_help() {
    echo ""
    echo -e "${CYAN}${BOLD}  DNSLAB.BIZ - Backup & Restore${NC}"
    echo ""
    echo -e "  ${BOLD}Usage:${NC}"
    echo -e "    bash backup.sh backup          ${DIM}# Backup now + send to Telegram${NC}"
    echo -e "    bash backup.sh restore          ${DIM}# Restore from a backup${NC}"
    echo -e "    bash backup.sh restore file.gz  ${DIM}# Restore specific file${NC}"
    echo -e "    bash backup.sh cron             ${DIM}# Setup daily auto-backup (3 AM)${NC}"
    echo -e "    bash backup.sh auto             ${DIM}# Silent backup (for cron)${NC}"
    echo ""
}

# ---- MAIN ----
case "${1:-}" in
    backup)  do_backup ;;
    restore) do_restore "$2" ;;
    auto)    do_auto ;;
    cron)    do_cron ;;
    *)       show_help ;;
esac
