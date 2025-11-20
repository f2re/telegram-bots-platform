#!/bin/bash

# ========================================
# 🌐 Setup Permanent Static Docker Network
# Creates a static bridge network with fixed gateway
# ========================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  ${NC}$1"; }
log_success() { echo -e "${GREEN}✅ ${NC}$1"; }
log_warning() { echo -e "${YELLOW}⚠️  ${NC}$1"; }
log_error() { echo -e "${RED}❌ ${NC}$1"; }

# Network configuration
NETWORK_NAME="bots_shared_network"
SUBNET="172.25.0.0/16"
GATEWAY="172.25.0.1"

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║     🌐 STATIC DOCKER NETWORK SETUP 🌐                ║
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

log_info "Настройка постоянной статической сети Docker..."
echo ""

# Check if network already exists
if docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
    log_warning "Сеть $NETWORK_NAME уже существует"

    # Check if it has correct settings
    CURRENT_SUBNET=$(docker network inspect "$NETWORK_NAME" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || echo "")
    CURRENT_GATEWAY=$(docker network inspect "$NETWORK_NAME" --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || echo "")

    if [ "$CURRENT_SUBNET" = "$SUBNET" ] && [ "$CURRENT_GATEWAY" = "$GATEWAY" ]; then
        log_success "Сеть уже настроена правильно"
        echo -e "  ${GREEN}Subnet: $CURRENT_SUBNET${NC}"
        echo -e "  ${GREEN}Gateway: $CURRENT_GATEWAY${NC}"
    else
        log_warning "Сеть существует, но с другими настройками:"
        echo -e "  ${YELLOW}Current Subnet: $CURRENT_SUBNET${NC}"
        echo -e "  ${YELLOW}Current Gateway: $CURRENT_GATEWAY${NC}"
        echo -e "  ${YELLOW}Expected Subnet: $SUBNET${NC}"
        echo -e "  ${YELLOW}Expected Gateway: $GATEWAY${NC}"
        echo ""

        read -p "$(echo -e ${YELLOW}Пересоздать сеть с правильными настройками? [y/N]: ${NC})" -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Проверка использования сети..."

            # Check if any containers are using this network
            CONTAINERS=$(docker network inspect "$NETWORK_NAME" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo "")

            if [ -n "$CONTAINERS" ]; then
                log_warning "Следующие контейнеры используют эту сеть:"
                echo -e "  ${YELLOW}$CONTAINERS${NC}"
                log_info "Остановка контейнеров..."

                for container in $CONTAINERS; do
                    docker stop "$container" 2>/dev/null || true
                done
            fi

            log_info "Удаление старой сети..."
            docker network rm "$NETWORK_NAME" || log_error "Не удалось удалить сеть"
        else
            log_info "Использование существующей сети"
            exit 0
        fi
    fi
else
    log_info "Создание новой статической сети..."
fi

# Create network if it doesn't exist
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
    log_info "Создание сети: $NETWORK_NAME"
    log_info "  Subnet: $SUBNET"
    log_info "  Gateway: $GATEWAY"

    if docker network create \
        --driver bridge \
        --subnet="$SUBNET" \
        --gateway="$GATEWAY" \
        "$NETWORK_NAME"; then

        log_success "Сеть создана успешно!"
    else
        log_error "Не удалось создать сеть"
        exit 1
    fi
fi

echo ""
log_success "Статическая сеть настроена"
echo ""

# Show network details
log_info "Детали сети:"
docker network inspect "$NETWORK_NAME" --format \
'  Name:     {{.Name}}
  Driver:   {{.Driver}}
  Subnet:   {{range .IPAM.Config}}{{.Subnet}}{{end}}
  Gateway:  {{range .IPAM.Config}}{{.Gateway}}{{end}}
  Scope:    {{.Scope}}'

echo ""
echo -e "${CYAN}📋 Следующие шаги:${NC}"
echo ""
echo -e "1. ${YELLOW}Настроить PostgreSQL:${NC}"
echo -e "   ${GRAY}sudo ./configure-postgres-network.sh${NC}"
echo ""
echo -e "2. ${YELLOW}Обновить .env файлы ботов:${NC}"
echo -e "   ${GRAY}Заменить DATABASE_URL на: postgresql://user:pass@$GATEWAY:5432/dbname${NC}"
echo ""
echo -e "3. ${YELLOW}Перезапустить ботов:${NC}"
echo -e "   ${GRAY}sudo ./bot-manage.sh${NC}"
echo ""

log_success "Готово! Gateway IP: $GATEWAY (никогда не изменится)"
