#!/bin/bash

# ========================================
# 🔍 DNS Verification Script
# Проверка DNS записей перед запросом SSL
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
log_warning() { echo -e "${YELLOW}⚠️  ${NC}$1"; }
log_error() { echo -e "${RED}❌ ${NC}$1"; }

if [ $# -lt 1 ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

DOMAIN=$1
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "")

log_info "Проверка DNS для домена: $DOMAIN"
log_info "IP сервера: $SERVER_IP"

# Function to resolve domain
resolve_domain() {
    local domain=$1
    local resolved_ip=""
    
    # Try multiple methods
    if command -v dig >/dev/null 2>&1; then
        resolved_ip=$(dig +short "$domain" A | head -n1)
    elif command -v host >/dev/null 2>&1; then
        resolved_ip=$(host "$domain" | grep "has address" | head -n1 | awk '{print $4}')
    elif command -v nslookup >/dev/null 2>&1; then
        resolved_ip=$(nslookup "$domain" | grep -A1 "Name:" | tail -n1 | awk '{print $2}')
    fi
    
    echo "$resolved_ip"
}

# Resolve domain
RESOLVED_IP=$(resolve_domain "$DOMAIN")

if [ -z "$RESOLVED_IP" ]; then
    log_error "Не удалось получить IP для домена $DOMAIN"
    log_warning "Убедитесь что:"
    echo "  1. DNS запись A создана для $DOMAIN"
    echo "  2. DNS изменения распространились (может занять до 48 часов)"
    echo "  3. Доменное имя указано правильно"
    exit 1
fi

log_info "Домен $DOMAIN указывает на: $RESOLVED_IP"

# Check if resolved IP matches server IP
if [ "$RESOLVED_IP" = "$SERVER_IP" ]; then
    log_success "✓ DNS настроен правильно!"
    log_success "✓ $DOMAIN → $SERVER_IP"
    exit 0
else
    log_error "DNS запись не указывает на этот сервер!"
    echo ""
    echo -e "${YELLOW}Текущая ситуация:${NC}"
    echo "  Домен: $DOMAIN"
    echo "  Указывает на: $RESOLVED_IP"
    echo "  Должен указывать на: $SERVER_IP"
    echo ""
    echo -e "${YELLOW}Что нужно сделать:${NC}"
    echo "  1. Зайдите в панель управления DNS вашего регистратора"
    echo "  2. Создайте или измените A запись:"
    echo "     Тип: A"
    echo "     Имя: $DOMAIN (или @ для корневого домена)"
    echo "     Значение: $SERVER_IP"
    echo "     TTL: 300 (или минимальное)"
    echo "  3. Подождите 5-30 минут для распространения"
    echo "  4. Запустите этот скрипт снова для проверки"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Продолжить без правильного DNS? Будет создан self-signed сертификат [y/N]: ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Продолжаем с self-signed сертификатом"
        exit 2
    else
        exit 1
    fi
fi
