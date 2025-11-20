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

# Поиск директории с ботами
BOTS_DIR=""

# Пробуем разные локации
if [ -d "/opt/telegram-bots-platform/bots" ]; then
    BOTS_DIR="/opt/telegram-bots-platform/bots"
elif [ -d "$HOME/telegram-bots/bots" ]; then
    BOTS_DIR="$HOME/telegram-bots/bots"
elif [ -d "$HOME/bots" ]; then
    BOTS_DIR="$HOME/bots"
elif [ -d "/var/www/bots" ]; then
    BOTS_DIR="/var/www/bots"
fi

# Если не нашли автоматически, спросим у пользователя
if [ -z "$BOTS_DIR" ] || [ ! -d "$BOTS_DIR" ]; then
    log_warning "Не удалось автоматически найти директорию с ботами"
    echo ""
    log_info "Пробовали следующие локации:"
    echo "  - /opt/telegram-bots-platform/bots"
    echo "  - $HOME/telegram-bots/bots"
    echo "  - $HOME/bots"
    echo "  - /var/www/bots"
    echo ""

    read -p "Введите полный путь к директории с ботами: " BOTS_DIR

    if [ -z "$BOTS_DIR" ] || [ ! -d "$BOTS_DIR" ]; then
        log_error "Директория не найдена: $BOTS_DIR"
        exit 1
    fi
fi

log_step "🔧 Генерация bot_info.json для существующих ботов..."
log_info "Директория ботов: $BOTS_DIR"
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
    if grep -q "backend:" "$DOCKER_COMPOSE_FILE" 2>/dev/null; then
        STRUCTURE="multi-service"
        # Извлечение backend порта
        BACKEND_PORT=$(grep -A 20 "backend:" "$DOCKER_COMPOSE_FILE" | grep -oP 'published:\s*\K\d+' | head -1 2>/dev/null || echo "")
        # Если не нашли через published, пробуем старый формат
        if [ -z "$BACKEND_PORT" ]; then
            BACKEND_PORT=$(grep -A 20 "backend:" "$DOCKER_COMPOSE_FILE" | grep -oP '"\d+:\d+"' | grep -oP '^\K\d+' | head -1 2>/dev/null || echo "")
        fi
        # Извлечение frontend порта если есть
        if grep -q "frontend:" "$DOCKER_COMPOSE_FILE" 2>/dev/null; then
            FRONTEND_PORT=$(grep -A 20 "frontend:" "$DOCKER_COMPOSE_FILE" | grep -oP 'published:\s*\K\d+' | head -1 2>/dev/null || echo "")
            if [ -z "$FRONTEND_PORT" ]; then
                FRONTEND_PORT=$(grep -A 20 "frontend:" "$DOCKER_COMPOSE_FILE" | grep -oP '"\d+:\d+"' | grep -oP '^\K\d+' | sed -n '2p' 2>/dev/null || echo "")
            fi
        fi
    else
        STRUCTURE="mono-service"
        # Извлечение порта для моносервиса
        BACKEND_PORT=$(grep -oP 'published:\s*\K\d+' "$DOCKER_COMPOSE_FILE" | head -1 2>/dev/null || echo "")
        if [ -z "$BACKEND_PORT" ]; then
            BACKEND_PORT=$(grep -oP '"\d+:\d+"' "$DOCKER_COMPOSE_FILE" | grep -oP '^\K\d+' | head -1 2>/dev/null || echo "")
        fi
    fi

    # Извлечение DB_NAME из .env если есть
    if [ -f "$ENV_FILE" ]; then
        DB_FROM_ENV=$(grep -oP '^DB_NAME=\K.*' "$ENV_FILE" 2>/dev/null || echo "")
        [ -n "$DB_FROM_ENV" ] && DB_NAME="$DB_FROM_ENV"

        DB_FROM_ENV=$(grep -oP '^POSTGRES_DB=\K.*' "$ENV_FILE" 2>/dev/null || echo "")
        [ -n "$DB_FROM_ENV" ] && DB_NAME="$DB_FROM_ENV"

        DB_FROM_ENV=$(grep -oP '^DATABASE_NAME=\K.*' "$ENV_FILE" 2>/dev/null || echo "")
        [ -n "$DB_FROM_ENV" ] && DB_NAME="$DB_FROM_ENV"
    fi

    # Попытка найти домен из nginx конфига
    NGINX_CONF="/etc/nginx/sites-enabled/${BOT_NAME}"
    if [ -f "$NGINX_CONF" ]; then
        DOMAIN=$(grep -oP 'server_name\s+\K[^\s;]+' "$NGINX_CONF" | head -1 2>/dev/null || echo "")
    fi

    # Определение SSL метода
    SSL_METHOD="none"
    if [ -n "$DOMAIN" ]; then
        if [[ "$DOMAIN" == *.duckdns.org ]]; then
            SSL_METHOD="duckdns"
        elif [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
            SSL_METHOD="letsencrypt"
        fi
    fi

    # Создание bot_info.json с правильным синтаксисом
    {
        echo "{"
        echo "    \"name\": \"$BOT_NAME\","
        echo "    \"domain\": \"${DOMAIN:-unknown}\","
        echo "    \"ssl_method\": \"$SSL_METHOD\","
        echo "    \"structure\": \"$STRUCTURE\","

        # backend_port
        if [ -n "$BACKEND_PORT" ]; then
            echo "    \"backend_port\": $BACKEND_PORT,"
        else
            echo "    \"backend_port\": 0,"
        fi

        # frontend_port (только если есть)
        if [ -n "$FRONTEND_PORT" ]; then
            echo "    \"frontend_port\": $FRONTEND_PORT,"
        fi

        # database
        echo "    \"database\": {"
        echo "        \"name\": \"$DB_NAME\","
        echo "        \"user\": \"${BOT_NAME}_user\","
        echo "        \"host\": \"172.25.0.1\","
        echo "        \"port\": 5432"
        echo "    },"

        echo "    \"repository\": \"unknown\","
        echo "    \"created_at\": \"$(date -Iseconds)\","
        echo "    \"generated\": true,"
        echo "    \"generated_at\": \"$(date -Iseconds)\""
        echo "}"
    } > "$BOT_INFO_FILE"

    # Проверка что файл создан успешно
    if [ -f "$BOT_INFO_FILE" ] && jq empty "$BOT_INFO_FILE" 2>/dev/null; then
        GENERATED_COUNT=$((GENERATED_COUNT + 1))
        log_success "  ✅ Создан bot_info.json"
        log_info "     Порт Backend: ${BACKEND_PORT:-Н/Д}"
        log_info "     База данных: $DB_NAME"
        log_info "     Домен: ${DOMAIN:-Н/Д}"
        log_info "     Структура: $STRUCTURE"
    elif [ -f "$BOT_INFO_FILE" ]; then
        log_warning "  ⚠️  Файл создан, но JSON может быть некорректным"
        log_info "     Проверьте файл: $BOT_INFO_FILE"
        GENERATED_COUNT=$((GENERATED_COUNT + 1))
    else
        log_error "  ❌ Не удалось создать файл"
    fi

    echo ""
done

echo ""
log_step "📊 Сводка"
if [ $GENERATED_COUNT -gt 0 ]; then
    log_success "Сгенерировано файлов: $GENERATED_COUNT"
    echo ""
    log_info "Теперь запустите сканер ботов для добавления в мониторинг:"
    echo -e "${CYAN}  sudo bash scripts/scan-and-monitor-bots.sh${NC}"
    echo ""
    log_info "Или через меню мониторинга (пункт 6)"
else
    log_warning "Не было создано ни одного bot_info.json"
    log_info "Возможные причины:"
    echo "  - Все боты уже имеют bot_info.json"
    echo "  - В директории нет директорий с ботами"
    echo "  - У ботов нет docker-compose.yml"
fi

echo ""
log_success "🎉 Готово!"
