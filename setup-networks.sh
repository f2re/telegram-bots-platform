#!/bin/bash

# ========================================
# 🌐 Docker Network Setup Script
# Ensures all required Docker networks exist
# ========================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

BOTS_DIR="/opt/telegram-bots-platform/bots"

log_info() { echo -e "${BLUE}ℹ️  ${NC}$1"; }
log_success() { echo -e "${GREEN}✅ ${NC}$1"; }
log_warning() { echo -e "${YELLOW}⚠️  ${NC}$1"; }
log_error() { echo -e "${RED}❌ ${NC}$1"; }

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║              Docker Networks Setup for Bots               ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

log_info "Проверка и создание Docker сетей для ботов..."

# Check if root
if [[ $EUID -ne 0 ]]; then
    log_error "Скрипт должен запускаться от root"
    echo -e "  ${NC}Используйте: sudo $0${NC}\n"
    exit 1
fi

# Create shared network
SHARED_NETWORK="bots_shared_network"
log_info "Проверка общей сети: $SHARED_NETWORK"

if docker network ls --format '{{.Name}}' | grep -q "^${SHARED_NETWORK}$"; then
    log_success "Общая сеть уже существует: $SHARED_NETWORK"
else
    log_info "Создание общей сети: $SHARED_NETWORK"
    if docker network create "$SHARED_NETWORK"; then
        log_success "Общая сеть создана: $SHARED_NETWORK"
    else
        log_error "Не удалось создать общую сеть"
    fi
fi

# Process each bot
if [ ! -d "$BOTS_DIR" ] || [ -z "$(ls -A $BOTS_DIR 2>/dev/null)" ]; then
    log_warning "Боты не найдены в $BOTS_DIR"
    exit 0
fi

echo ""
log_info "Проверка сетей для ботов:\n"

for bot_dir in "$BOTS_DIR"/*; do
    if [ -d "$bot_dir" ] && [ -f "$bot_dir/.env" ]; then
        bot_name=$(basename "$bot_dir")

        # Load .env to get BOT_NAME
        cd "$bot_dir"
        set -a
        source .env 2>/dev/null || true
        set +a

        # Use BOT_NAME from .env or directory name as fallback
        local_bot_name="${BOT_NAME:-$bot_name}"

        # Ensure BOT_NAME is in .env
        if ! grep -q "^BOT_NAME=" .env; then
            echo "BOT_NAME=$bot_name" >> .env
            log_info "  [$bot_name] Добавлено BOT_NAME в .env"
        fi

        # Create bot-specific network
        local bot_network="${local_bot_name}_network"

        echo -e "  ${CYAN}• $bot_name${NC}"

        if docker network ls --format '{{.Name}}' | grep -q "^${bot_network}$"; then
            echo -e "    ${GREEN}✓${NC} Сеть существует: $bot_network"
        else
            echo -e "    ${YELLOW}↻${NC} Создание сети: $bot_network"
            if docker network create "$bot_network" 2>/dev/null; then
                echo -e "    ${GREEN}✓${NC} Сеть создана: $bot_network"
            else
                echo -e "    ${RED}✗${NC} Не удалось создать сеть: $bot_network"
            fi
        fi
    fi
done

echo ""
log_success "Проверка сетей завершена"

# Show summary
echo -e "\n${CYAN}📊 Список Docker сетей:${NC}\n"
docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | grep -E "bots_|_network|NAME"

echo ""
log_info "Все необходимые сети настроены!"
