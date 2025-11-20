#!/bin/bash

# ========================================
# 🔧 Configure PostgreSQL for Static Network
# Configures PostgreSQL to listen on static gateway IP
# ========================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  ${NC}$1"; }
log_success() { echo -e "${GREEN}✅ ${NC}$1"; }
log_warning() { echo -e "${YELLOW}⚠️  ${NC}$1"; }
log_error() { echo -e "${RED}❌ ${NC}$1"; }

# Network configuration
GATEWAY="172.25.0.1"
SUBNET="172.25.0.0/16"

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║     🔧 POSTGRESQL NETWORK CONFIGURATION 🔧           ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Check if root
if [[ $EUID -ne 0 ]]; then
    log_error "Скрипт должен запускаться от root"
    echo -e "  ${GRAY}Используйте: sudo $0${NC}\n"
    exit 1
fi

# Detect PostgreSQL version
PG_VERSION=$(sudo -u postgres psql --version | grep -oP '\d+' | head -1)
PG_CONF_DIR="/etc/postgresql/$PG_VERSION/main"
PG_CONF="$PG_CONF_DIR/postgresql.conf"
PG_HBA="$PG_CONF_DIR/pg_hba.conf"

log_info "Обнаружена PostgreSQL версия: $PG_VERSION"
log_info "Конфигурация: $PG_CONF"
echo ""

# Check if files exist
if [ ! -f "$PG_CONF" ]; then
    log_error "postgresql.conf не найден: $PG_CONF"
    exit 1
fi

if [ ! -f "$PG_HBA" ]; then
    log_error "pg_hba.conf не найден: $PG_HBA"
    exit 1
fi

# Backup existing configs
BACKUP_DIR="/root/.platform/postgres_backups"
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
log_info "Создание резервных копий..."
cp "$PG_CONF" "$BACKUP_DIR/postgresql.conf.$TIMESTAMP"
cp "$PG_HBA" "$BACKUP_DIR/pg_hba.conf.$TIMESTAMP"
log_success "Резервные копии созданы в: $BACKUP_DIR"
echo ""

# Configure postgresql.conf
log_info "Настройка listen_addresses в postgresql.conf..."

# Check if already configured
if grep -q "^listen_addresses.*$GATEWAY" "$PG_CONF"; then
    log_success "listen_addresses уже настроен"
else
    # Comment out existing listen_addresses
    sed -i "s/^listen_addresses/#listen_addresses/" "$PG_CONF"

    # Add new configuration
    cat >> "$PG_CONF" << EOF

# Telegram Bots Platform - Static Network Configuration
# Added by configure-postgres-network.sh on $(date)
listen_addresses = 'localhost,$GATEWAY'
EOF

    log_success "listen_addresses настроен: 'localhost,$GATEWAY'"
fi

echo ""

# Configure pg_hba.conf
log_info "Настройка pg_hba.conf для сети $SUBNET..."

# Check if already configured
if grep -q "$SUBNET" "$PG_HBA"; then
    log_success "pg_hba.conf уже настроен для сети $SUBNET"
else
    # Add configuration before the last line
    cat >> "$PG_HBA" << EOF

# Telegram Bots Platform - Static Network Access
# Added by configure-postgres-network.sh on $(date)
# Allow connections from Docker containers on static network
host    all    all    $SUBNET    scram-sha-256
EOF

    log_success "pg_hba.conf настроен для сети $SUBNET"
fi

echo ""

# Restart PostgreSQL
log_info "Перезапуск PostgreSQL..."
if systemctl restart postgresql; then
    log_success "PostgreSQL перезапущен"
else
    log_error "Не удалось перезапустить PostgreSQL"
    exit 1
fi

# Test connection
echo ""
log_info "Проверка подключения..."
sleep 2

if sudo -u postgres psql -c "SELECT 1" > /dev/null 2>&1; then
    log_success "PostgreSQL работает корректно"
else
    log_error "Не удалось подключиться к PostgreSQL"
    exit 1
fi

echo ""
log_success "Конфигурация PostgreSQL завершена!"
echo ""

# Show configuration summary
echo -e "${CYAN}📋 Конфигурация:${NC}"
echo -e "  ${YELLOW}Gateway IP:${NC} $GATEWAY"
echo -e "  ${YELLOW}Subnet:${NC} $SUBNET"
echo -e "  ${YELLOW}Listen Addresses:${NC} localhost, $GATEWAY"
echo -e "  ${YELLOW}Access:${NC} Разрешено для $SUBNET"
echo ""

echo -e "${CYAN}📝 Следующие шаги:${NC}"
echo ""
echo -e "1. ${YELLOW}Обновить .env файлы всех ботов:${NC}"
echo -e "   ${GRAY}DATABASE_URL=postgresql://user:password@$GATEWAY:5432/dbname${NC}"
echo ""
echo -e "2. ${YELLOW}Или запустить автообновление:${NC}"
echo -e "   ${GRAY}sudo ./update-bot-database-urls.sh${NC}"
echo ""
echo -e "3. ${YELLOW}Перезапустить всех ботов:${NC}"
echo -e "   ${GRAY}cd /opt/telegram-bots-platform/bots && for bot in */; do cd \$bot && docker compose restart; cd ..; done${NC}"
echo ""

log_info "Резервные копии сохранены в: $BACKUP_DIR"
