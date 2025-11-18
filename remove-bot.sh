#!/bin/bash

# ========================================
# 🗑️  Remove Bot Script
# Telegram Bots Platform
# ========================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths
PLATFORM_DIR="/opt/telegram-bots-platform"
BOTS_DIR="$PLATFORM_DIR/bots"

# Logging
log_info() { echo -e "${BLUE}ℹ️  ${NC}$1"; }
log_success() { echo -e "${GREEN}✅ ${NC}$1"; }
log_warning() { echo -e "${YELLOW}⚠️  ${NC}$1"; }
log_error() { echo -e "${RED}❌ ${NC}$1"; }

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║         🗑️  REMOVE TELEGRAM BOT 🗑️                  ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Get bot name
if [ $# -eq 0 ]; then
    read -p "$(echo -e ${CYAN}Enter bot name to remove: ${NC})" BOT_NAME
else
    BOT_NAME=$1
fi

# Check if bot exists
BOT_DIR="$BOTS_DIR/$BOT_NAME"
if [ ! -d "$BOT_DIR" ]; then
    log_error "Bot '$BOT_NAME' not found!"
    exit 1
fi

# Load bot info
if [ -f "$BOT_DIR/bot_info.json" ]; then
    BOT_DOMAIN=$(jq -r '.domain' "$BOT_DIR/bot_info.json")
    DB_NAME=$(jq -r '.database' "$BOT_DIR/bot_info.json")
fi

# Confirmation
echo -e "${YELLOW}⚠️  WARNING: This will permanently remove the bot and all its data!${NC}\n"
echo -e "  Bot: ${RED}$BOT_NAME${NC}"
[ -n "${BOT_DOMAIN:-}" ] && echo -e "  Domain: ${RED}$BOT_DOMAIN${NC}"
[ -n "${DB_NAME:-}" ] && echo -e "  Database: ${RED}$DB_NAME${NC}"
echo ""

read -p "$(echo -e ${RED}Type bot name to confirm deletion: ${NC})" CONFIRM
if [ "$CONFIRM" != "$BOT_NAME" ]; then
    log_warning "Cancelled"
    exit 0
fi

# Stop and remove containers
log_info "Stopping containers..."
cd "$BOT_DIR"
docker compose down -v 2>/dev/null || true
log_success "Containers stopped"

# Remove from Nginx
log_info "Removing Nginx configuration..."
rm -f "/etc/nginx/sites-enabled/${BOT_NAME}.conf"
rm -f "/etc/nginx/sites-available/${BOT_NAME}.conf"
nginx -s reload
log_success "Nginx configuration removed"

# Remove SSL certificate
if [ -n "${BOT_DOMAIN:-}" ]; then
    log_info "Removing SSL certificate..."
    certbot delete --cert-name "$BOT_DOMAIN" --non-interactive 2>/dev/null || true
    log_success "SSL certificate removed"
fi

# Remove database
if [ -n "${DB_NAME:-}" ]; then
    log_info "Removing database..."
    sudo -u postgres psql << EOF 2>/dev/null || true
DROP DATABASE IF EXISTS $DB_NAME;
DROP USER IF EXISTS ${DB_NAME%_db}_user;
EOF
    log_success "Database removed"
fi

# Backup before deletion
BACKUP_DIR="$PLATFORM_DIR/backups/${BOT_NAME}_$(date +%Y%m%d_%H%M%S)"
log_info "Creating backup..."
mkdir -p "$BACKUP_DIR"
tar -czf "$BACKUP_DIR/${BOT_NAME}_backup.tar.gz" -C "$BOTS_DIR" "$BOT_NAME" 2>/dev/null || true
log_success "Backup created: $BACKUP_DIR"

# Remove bot directory
log_info "Removing bot directory..."
rm -rf "$BOT_DIR"
log_success "Bot directory removed"

# Remove from monitoring
if [ -f "/opt/monitoring/prometheus/prometheus.yml" ]; then
    log_info "Removing from monitoring..."
    sed -i "/job_name: '${BOT_NAME}'/,+4d" "/opt/monitoring/prometheus/prometheus.yml"
    docker exec prometheus kill -HUP 1 2>/dev/null || true
fi

echo -e "\n${GREEN}✅ Bot '$BOT_NAME' removed successfully!${NC}\n"
echo -e "${CYAN}Backup available at: ${YELLOW}$BACKUP_DIR${NC}\n"