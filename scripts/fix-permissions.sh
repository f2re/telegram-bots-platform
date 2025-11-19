#!/bin/bash

# ========================================
# 🔧 Fix Permissions Script
# Исправление проблем с правами доступа
# ========================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  ${NC}$1"; }
log_success() { echo -e "${GREEN}✅ ${NC}$1"; }
log_error() { echo -e "${RED}❌ ${NC}$1"; }

BOTS_DIR="/opt/telegram-bots-platform/bots"

if [[ $EUID -ne 0 ]]; then
    log_error "Скрипт должен запускаться от root"
    exit 1
fi

log_info "Исправление прав доступа для платформы..."

# Fix platform directory permissions
chown -R root:root /opt/telegram-bots-platform
chmod 755 /opt/telegram-bots-platform
chmod 755 /opt/telegram-bots-platform/{scripts,configs,logs}

# Fix bot directories
if [ -d "$BOTS_DIR" ]; then
    for bot_dir in "$BOTS_DIR"/*; do
        if [ -d "$bot_dir" ]; then
            bot_name=$(basename "$bot_dir")
            log_info "Fixing permissions for bot: $bot_name"
            
            # Fix main directory
            chmod 755 "$bot_dir"
            
            # Fix logs directory (must be writable by Docker containers)
            if [ -d "$bot_dir/logs" ]; then
                chmod 777 "$bot_dir/logs"
                log_success "  ✓ logs directory: 777"
            fi
            
            # Fix data directory (must be writable by Docker containers)
            if [ -d "$bot_dir/data" ]; then
                chmod 777 "$bot_dir/data"
                log_success "  ✓ data directory: 777"
            fi
            
            # Fix .env file (must be readable by Docker)
            if [ -f "$bot_dir/.env" ]; then
                chmod 600 "$bot_dir/.env"
                log_success "  ✓ .env file: 600"
            fi
            
            # Fix docker-compose.yml
            if [ -f "$bot_dir/docker-compose.yml" ]; then
                chmod 644 "$bot_dir/docker-compose.yml"
                log_success "  ✓ docker-compose.yml: 644"
            fi
            
            # Fix app directory
            if [ -d "$bot_dir/app" ]; then
                chmod -R 755 "$bot_dir/app"
                log_success "  ✓ app directory: 755 (recursive)"
            fi
        fi
    done
fi

# Fix PostgreSQL data directory permissions
if [ -d "/var/lib/postgresql" ]; then
    chown -R postgres:postgres /var/lib/postgresql
    chmod 700 /var/lib/postgresql
    log_success "PostgreSQL data directory permissions fixed"
fi

# Fix Nginx configuration permissions
if [ -d "/etc/nginx" ]; then
    chown -R root:root /etc/nginx
    chmod 755 /etc/nginx
    chmod 644 /etc/nginx/nginx.conf
    if [ -d "/etc/nginx/sites-available" ]; then
        chmod 644 /etc/nginx/sites-available/*
    fi
    log_success "Nginx configuration permissions fixed"
fi

# Fix monitoring directory
if [ -d "/opt/monitoring" ]; then
    chmod 755 /opt/monitoring
    chmod -R 755 /opt/monitoring/prometheus
    chmod -R 755 /opt/monitoring/grafana
    log_success "Monitoring directory permissions fixed"
fi

# Fix script permissions in platform
chmod +x /opt/telegram-bots-platform/*.sh 2>/dev/null || true
chmod +x /opt/telegram-bots-platform/scripts/*.sh 2>/dev/null || true

log_success "\n✅ Все права доступа исправлены!\n"

echo -e "${YELLOW}📋 Рекомендации:${NC}"
echo "  1. Перезапустите Docker контейнеры: docker compose restart"
echo "  2. Проверьте логи: docker logs -f <container_name>"
echo "  3. При добавлении новых файлов в bot/data или bot/logs используйте chmod 666"
