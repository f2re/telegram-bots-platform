#!/bin/bash

# ========================================
# 🔧 Генератор bot_info.json для Существующих Ботов
# Создает bot_info.json для ботов без этого файла
# ========================================

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  ${NC}$1"; }
log_success() { echo -e "${GREEN}✅ ${NC}$1"; }
log_warning() { echo -e "${YELLOW}⚠️  ${NC}$1"; }
log_error() { echo -e "${RED}❌ ${NC}$1"; }
log_step() { echo -e "${MAGENTA}▶️  ${NC}$1"; }

BOTS_DIR="/opt/telegram-bots-platform/bots"

if [ ! -d "$BOTS_DIR" ]; then
    log_error "Директория ботов не найдена: $BOTS_DIR"
    exit 1
fi

log_step "🔧 Генерация bot_info.json для существующих ботов..."
echo ""

GENERATED_COUNT=0

for bot_dir in "$BOTS_DIR"/*; do
    if [ ! -d "$bot_dir" ]; then
        continue
    fi

    BOT_NAME=$(basename "$bot_dir")
    BOT_INFO_FILE="$bot_dir/bot_info.json"
    DOCKER_COMPOSE_FILE="$bot_dir/docker-compose.yml"
    ENV_FILE="$bot_dir/.env"

    log_info "Проверка бота: $BOT_NAME"

    # Если bot_info.json уже существует, пропускаем
    if [ -f "$BOT_INFO_FILE" ]; then
        log_success "  bot_info.json уже существует"
        continue
    fi

    # Проверка наличия docker-compose.yml
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        log_warning "  docker-compose.yml не найден, пропуск"
        continue
    fi

    log_info "  Создание bot_info.json..."

    # Извлечение информации из docker-compose.yml и .env
    BACKEND_PORT=""
    FRONTEND_PORT=""
    DB_NAME="${BOT_NAME}_db"
    DOMAIN=""
    STRUCTURE="unknown"

    # Попытка извлечь порты из docker-compose.yml
    if grep -q "backend:" "$DOCKER_COMPOSE_FILE"; then
        STRUCTURE="multi-service"
        # Извлечение backend порта
        BACKEND_PORT=$(grep -A 20 "backend:" "$DOCKER_COMPOSE_FILE" | grep -oP 'published:\s*\K\d+' | head -1)
        # Извлечение frontend порта если есть
        if grep -q "frontend:" "$DOCKER_COMPOSE_FILE"; then
            FRONTEND_PORT=$(grep -A 20 "frontend:" "$DOCKER_COMPOSE_FILE" | grep -oP 'published:\s*\K\d+' | head -1)
        fi
    else
        STRUCTURE="mono-service"
        # Извлечение порта для моносервиса
        BACKEND_PORT=$(grep -oP 'published:\s*\K\d+' "$DOCKER_COMPOSE_FILE" | head -1)
    fi

    # Извлечение DB_NAME из .env если есть
    if [ -f "$ENV_FILE" ]; then
        DB_FROM_ENV=$(grep -oP '^DB_NAME=\K.*' "$ENV_FILE" 2>/dev/null || echo "")
        [ -n "$DB_FROM_ENV" ] && DB_NAME="$DB_FROM_ENV"

        DB_FROM_ENV=$(grep -oP '^POSTGRES_DB=\K.*' "$ENV_FILE" 2>/dev/null || echo "")
        [ -n "$DB_FROM_ENV" ] && DB_NAME="$DB_FROM_ENV"
    fi

    # Попытка найти домен из nginx конфига
    NGINX_CONF="/etc/nginx/sites-enabled/${BOT_NAME}"
    if [ -f "$NGINX_CONF" ]; then
        DOMAIN=$(grep -oP 'server_name\s+\K[^\s;]+' "$NGINX_CONF" | head -1)
    fi

    # Определение SSL метода
    SSL_METHOD="none"
    if [ -n "$DOMAIN" ]; then
        if [[ "$DOMAIN" == *.duckdns.org ]]; then
            SSL_METHOD="duckdns"
        else
            SSL_METHOD="letsencrypt"
        fi
    fi

    # Создание bot_info.json
    cat > "$BOT_INFO_FILE" << EOF
{
    "name": "$BOT_NAME",
    "domain": "${DOMAIN:-unknown}",
    "ssl_method": "$SSL_METHOD",
    "structure": "$STRUCTURE",
    "backend_port": ${BACKEND_PORT:-0},
EOF

    # Добавление frontend_port если есть
    if [ -n "$FRONTEND_PORT" ]; then
        cat >> "$BOT_INFO_FILE" << EOF
    "frontend_port": ${FRONTEND_PORT},
EOF
    fi

    # Завершение JSON
    cat >> "$BOT_INFO_FILE" << EOF
    "database": {
        "name": "$DB_NAME",
        "user": "${BOT_NAME}_user",
        "host": "172.25.0.1",
        "port": 5432
    },
    "repository": "unknown",
    "created_at": "$(date -Iseconds)",
    "generated": true,
    "generated_at": "$(date -Iseconds)"
}
EOF

    GENERATED_COUNT=$((GENERATED_COUNT + 1))
    log_success "  ✅ Создан bot_info.json"
    log_info "     Порт Backend: ${BACKEND_PORT:-Н/Д}"
    log_info "     База данных: $DB_NAME"
    log_info "     Домен: ${DOMAIN:-Н/Д}"
    echo ""
done

echo ""
log_step "📊 Сводка"
log_success "Сгенерировано файлов: $GENERATED_COUNT"

if [ $GENERATED_COUNT -gt 0 ]; then
    echo ""
    log_info "Теперь запустите сканер ботов для добавления в мониторинг:"
    echo -e "${CYAN}  sudo bash /opt/telegram-bots-platform/scripts/scan-and-monitor-bots.sh${NC}"
fi

echo ""
log_success "🎉 Готово!"
