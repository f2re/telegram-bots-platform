#!/bin/bash

# ========================================
# 🔒 Enhanced SSL Setup Script
# Улучшенная настройка SSL с проверками
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

if [ $# -lt 2 ]; then
    echo "Usage: $0 <domain> <email>"
    exit 1
fi

DOMAIN=$1
EMAIL=$2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info "Настройка SSL для домена: $DOMAIN"

# Step 1: Verify DNS
log_info "Шаг 1: Проверка DNS записей..."
if ! bash "$SCRIPT_DIR/verify-dns.sh" "$DOMAIN"; then
    DNS_CHECK_RESULT=$?
    if [ $DNS_CHECK_RESULT -eq 2 ]; then
        log_warning "DNS не настроен, создаем self-signed сертификат"
        CREATE_SELF_SIGNED=true
    else
        log_error "DNS проверка не прошла"
        exit 1
    fi
else
    CREATE_SELF_SIGNED=false
fi

# Step 2: Ensure Nginx is configured
log_info "Шаг 2: Проверка конфигурации Nginx..."
if ! nginx -t >/dev/null 2>&1; then
    log_error "Конфигурация Nginx содержит ошибки"
    nginx -t
    exit 1
fi

# Step 3: Reload Nginx to serve ACME challenge
log_info "Шаг 3: Перезагрузка Nginx..."
systemctl reload nginx

if [ "$CREATE_SELF_SIGNED" = "true" ]; then
    # Create self-signed certificate
    log_warning "Создание self-signed SSL сертификата..."
    
    mkdir -p "/etc/letsencrypt/live/$DOMAIN"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "/etc/letsencrypt/live/$DOMAIN/privkey.pem" \
        -out "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" \
        -subj "/CN=$DOMAIN/O=Telegram Bots Platform/C=RU" \
        2>/dev/null
    
    log_success "Self-signed сертификат создан"
    log_warning "⚠️  Браузеры будут показывать предупреждение безопасности"
    log_warning "⚠️  Настройте DNS и запустите: certbot renew --force-renewal"
    
    exit 0
fi

# Step 4: Request Let's Encrypt certificate
log_info "Шаг 4: Запрос Let's Encrypt сертификата..."

MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if certbot certonly \
        --nginx \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        --domains "$DOMAIN" \
        --preferred-challenges http \
        --http-01-port 80; then
        
        log_success "✓ SSL сертификат успешно получен!"
        
        # Setup auto-renewal
        log_info "Настройка автоматического обновления..."
        
        # Create renewal hook
        cat > "/etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh" << 'HOOK_EOF'
#!/bin/bash
systemctl reload nginx
HOOK_EOF
        chmod +x "/etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh"
        
        # Test renewal
        log_info "Тестирование процесса обновления..."
        if certbot renew --dry-run; then
            log_success "✓ Автоматическое обновление настроено"
        else
            log_warning "Тест обновления не прошел, но сертификат установлен"
        fi
        
        # Reload Nginx with SSL
        systemctl reload nginx
        
        log_success "\n🎉 SSL успешно настроен для $DOMAIN!\n"
        
        echo -e "${CYAN}📋 Информация о сертификате:${NC}"
        certbot certificates -d "$DOMAIN"
        
        echo -e "\n${GREEN}✓ Сертификат будет автоматически обновляться${NC}"
        echo -e "${GREEN}✓ Домен доступен по HTTPS: https://$DOMAIN${NC}"
        
        exit 0
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            log_warning "Попытка $RETRY_COUNT из $MAX_RETRIES не удалась"
            log_info "Повторная попытка через 10 секунд..."
            sleep 10
        fi
    fi
done

# All retries failed
log_error "Не удалось получить SSL сертификат после $MAX_RETRIES попыток"
log_warning "Создаем self-signed сертификат как fallback..."

mkdir -p "/etc/letsencrypt/live/$DOMAIN"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "/etc/letsencrypt/live/$DOMAIN/privkey.pem" \
    -out "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" \
    -subj "/CN=$DOMAIN/O=Telegram Bots Platform/C=RU" \
    2>/dev/null

log_success "Self-signed сертификат создан как fallback"
systemctl reload nginx

echo -e "\n${YELLOW}⚠️  Возможные причины ошибки:${NC}"
echo "  1. DNS записи еще не распространились (подождите 30 минут)"
echo "  2. Порт 80 недоступен из интернета (проверьте firewall)"
echo "  3. Домен уже имеет сертификат (проверьте: certbot certificates)"
echo "  4. Достигнут лимит Let's Encrypt (5 сертификатов в неделю на домен)"
echo ""
echo -e "${CYAN}Для повторной попытки:${NC}"
echo "  bash $SCRIPT_DIR/setup-ssl.sh $DOMAIN $EMAIL"

exit 1
