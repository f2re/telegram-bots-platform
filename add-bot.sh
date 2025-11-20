#!/bin/bash

# ========================================
# 🤖 Add New Bot Script v2.0
# С автоопределением структуры репозитория
# ========================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="/opt/telegram-bots-platform"
BOTS_DIR="$PLATFORM_DIR/bots"
CONFIG_FILE="$SCRIPT_DIR/config.env"

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  ${NC}$1"; }
log_success() { echo -e "${GREEN}✅ ${NC}$1"; }
log_warning() { echo -e "${YELLOW}⚠️  ${NC}$1"; }
log_error() { echo -e "${RED}❌ ${NC}$1"; }
log_step() {
    echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🔹 $1${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║         🤖 ADD NEW TELEGRAM BOT v2.0 🤖              ║
║                                                       ║
║         С автоопределением структуры                 ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

# Load PostgreSQL credentials
load_pg_credentials() {
    if [ -f "/root/.platform/postgres_credentials" ]; then
        source /root/.platform/postgres_credentials
    else
        log_error "PostgreSQL credentials not found!"
        exit 1
    fi
}

# Detect bot structure
detect_bot_structure() {
    local bot_dir=$1
    local structure="unknown"

    log_info "Определение структуры проекта..."

    # Check for multi-service structure (backend/frontend)
    if [ -d "$bot_dir/backend" ] && [ -f "$bot_dir/backend/Dockerfile" ]; then
        structure="multi-service"
        log_success "Обнаружена multi-service структура (backend + frontend)"

        # Check if frontend exists
        if [ -d "$bot_dir/frontend" ] && [ -f "$bot_dir/frontend/Dockerfile" ]; then
            HAS_FRONTEND=true
        else
            HAS_FRONTEND=false
        fi

    # Check for simple structure
    elif [ -f "$bot_dir/Dockerfile" ]; then
        structure="mono-service"
        log_success "Обнаружена mono-service структура"
        HAS_FRONTEND=false

    # Check for packages structure (monorepo)
    elif [ -d "$bot_dir/packages" ]; then
        structure="monorepo"
        log_success "Обнаружена monorepo структура"

        # Find Dockerfiles in packages
        if [ -d "$bot_dir/packages/backend" ] && [ -f "$bot_dir/packages/backend/Dockerfile" ]; then
            HAS_FRONTEND=$([ -d "$bot_dir/packages/frontend" ] && echo "true" || echo "false")
        fi
    else
        log_error "Не удалось определить структуру проекта"
        log_warning "Убедитесь что есть Dockerfile в корне или в backend/"
        return 1
    fi

    echo "$structure"
}

# Detect runtime/language
detect_runtime() {
    local bot_dir=$1
    local base_dir=$2

    if [ -f "$base_dir/requirements.txt" ]; then
        echo "python"
    elif [ -f "$base_dir/package.json" ]; then
        echo "nodejs"
    elif [ -f "$base_dir/go.mod" ]; then
        echo "golang"
    else
        echo "unknown"
    fi
}

# Find .env.example and create template
prepare_env_template() {
    local bot_dir=$1
    local structure=$2

    # Log to stderr so it doesn't go to .env file
    log_info "Подготовка шаблона .env..." >&2

    local env_example=""

    # Search for .env.example
    if [ "$structure" = "multi-service" ]; then
        if [ -f "$bot_dir/.env.example" ]; then
            env_example="$bot_dir/.env.example"
        elif [ -f "$bot_dir/backend/.env.example" ]; then
            env_example="$bot_dir/backend/.env.example"
        fi
    else
        if [ -f "$bot_dir/.env.example" ]; then
            env_example="$bot_dir/.env.example"
        fi
    fi

    if [ -n "$env_example" ]; then
        log_success "Найден .env.example: $env_example" >&2
        cat "$env_example"
    else
        log_warning ".env.example не найден, используется базовый шаблон" >&2
        cat << EOF
# Telegram Bot Token
BOT_TOKEN=

# Database
DATABASE_URL=
POSTGRES_HOST=
POSTGRES_PORT=5432
POSTGRES_DB=
POSTGRES_USER=
POSTGRES_PASSWORD=

# Application
PORT=8000
ENVIRONMENT=production
LOG_LEVEL=INFO
EOF
    fi
}

# Update .env with database credentials
update_env_file() {
    local env_file=$1
    local db_name=$2
    local db_user=$3
    local db_password=$4
    local bot_token=$5
    local backend_port=$6
    local domain=$7

    log_info "Обновление .env файла..."

    # Read existing .env or create new
    local temp_env="/tmp/bot_env_$$"

    if [ -f "$env_file" ]; then
        cp "$env_file" "$temp_env"
    else
        touch "$temp_env"
    fi

    # Update or add variables
    update_or_add_var() {
        local var_name=$1
        local var_value=$2

        if grep -q "^${var_name}=" "$temp_env"; then
            sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" "$temp_env"
        else
            echo "${var_name}=${var_value}" >> "$temp_env"
        fi
    }

    # Database credentials
    update_or_add_var "DATABASE_URL" "postgresql://${db_user}:${db_password}@host.docker.internal:5432/${db_name}"
    update_or_add_var "POSTGRES_HOST" "host.docker.internal"
    update_or_add_var "POSTGRES_PORT" "5432"
    update_or_add_var "POSTGRES_DB" "$db_name"
    update_or_add_var "POSTGRES_USER" "$db_user"
    update_or_add_var "POSTGRES_PASSWORD" "$db_password"

    # Bot token
    update_or_add_var "BOT_TOKEN" "$bot_token"
    update_or_add_var "TELEGRAM_BOT_TOKEN" "$bot_token"

    # Application settings
    update_or_add_var "PORT" "$backend_port"
    update_or_add_var "BACKEND_PORT" "$backend_port"
    update_or_add_var "ENVIRONMENT" "production"
    update_or_add_var "BOT_NAME" "$BOT_NAME"

    # Domain
    if [ -n "$domain" ]; then
        update_or_add_var "DOMAIN" "https://$domain"
        update_or_add_var "WEBHOOK_URL" "https://$domain/webhook"
    fi

    # Security
    local secret_key=$(openssl rand -hex 32)
    update_or_add_var "SECRET_KEY" "$secret_key"

    # Redis (shared)
    local redis_db=$(shuf -i 1-15 -n 1)
    update_or_add_var "REDIS_URL" "redis://redis:6379/$redis_db"

    # Move temp to actual file
    mv "$temp_env" "$env_file"
    chmod 600 "$env_file"

    log_success ".env файл обновлен"
}

# Generate docker-compose.yml based on structure
generate_docker_compose_auto() {
    local bot_dir=$1
    local structure=$2
    local has_frontend=$3

    log_info "Генерация docker-compose.yml..."

    local compose_file="$bot_dir/docker-compose.yml"

    cat > "$compose_file" << 'EOF_COMPOSE_HEADER'
version: '3.8'

services:
EOF_COMPOSE_HEADER

    # Backend service
    cat >> "$compose_file" << EOF
  bot:
    build:
      context: $([ "$structure" = "multi-service" ] && echo "./backend" || echo ".")
    container_name: \${BOT_NAME}_bot
    restart: unless-stopped
    env_file:
      - .env
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - ./logs:/app/logs
      - ./data:/app/data
    ports:
      - "\${BACKEND_PORT}:\${BACKEND_PORT}"
    networks:
      - \${BOT_NAME}_network
      - shared_network
    logging:
      driver: "json-file"
      options:
        max-size: "\${DOCKER_LOG_MAX_SIZE:-10m}"
        max-file: "\${DOCKER_LOG_MAX_FILE:-3}"
        labels: "bot=\${BOT_NAME}"
EOF

    # Frontend service (if exists)
    if [ "$has_frontend" = "true" ]; then
        cat >> "$compose_file" << EOF

  frontend:
    build:
      context: $([ "$structure" = "multi-service" ] && echo "./frontend" || echo "./packages/frontend")
      args:
        - VITE_API_URL=https://\${BOT_DOMAIN}
        - REACT_APP_API_URL=https://\${BOT_DOMAIN}
        - NEXT_PUBLIC_API_URL=https://\${BOT_DOMAIN}
    container_name: \${BOT_NAME}_frontend
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "\${FRONTEND_PORT}:80"
    networks:
      - \${BOT_NAME}_network
    depends_on:
      - bot
    logging:
      driver: "json-file"
      options:
        max-size: "\${DOCKER_LOG_MAX_SIZE:-10m}"
        max-file: "\${DOCKER_LOG_MAX_FILE:-3}"
        labels: "bot=\${BOT_NAME},service=frontend"
EOF
    fi

    # Networks
    cat >> "$compose_file" << EOF

networks:
  \${BOT_NAME}_network:
    driver: bridge
  shared_network:
    external: true
    name: \${DOCKER_NETWORK_NAME:-bots_shared_network}
EOF

    log_success "docker-compose.yml создан"
}

# Main prompt function
prompt_bot_info() {
    log_step "Информация о боте"

    # Bot name
    while true; do
        read -p "$(echo -e ${CYAN}Название бота [alphanumeric, lowercase]: ${NC})" BOT_NAME
        if [[ "$BOT_NAME" =~ ^[a-z0-9_-]+$ ]]; then
            break
        else
            log_error "Некорректное название. Используйте только lowercase, цифры, дефисы и подчеркивания."
        fi
    done

    # Check if bot exists
    if [ -d "$BOTS_DIR/$BOT_NAME" ]; then
        log_error "Бот '$BOT_NAME' уже существует!"
        exit 1
    fi

    # Bot token
    read -p "$(echo -e ${CYAN}Telegram Bot Token: ${NC})" BOT_TOKEN

    # Domain
    read -p "$(echo -e ${CYAN}Доменное имя [example: bot.mydomain.com]: ${NC})" BOT_DOMAIN

    # GitHub repository
    read -p "$(echo -e ${CYAN}GitHub repository URL: ${NC})" GIT_REPO

    # Backend port
    read -p "$(echo -e ${CYAN}Backend порт [default: auto]: ${NC})" BACKEND_PORT
    if [ -z "$BACKEND_PORT" ]; then
        BACKEND_PORT=$(shuf -i 3000-9000 -n 1)
    fi

    # Confirmation
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}Подтверждение конфигурации:${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "  Название: ${GREEN}$BOT_NAME${NC}"
    echo -e "  Домен: ${GREEN}$BOT_DOMAIN${NC}"
    echo -e "  Backend Port: ${GREEN}$BACKEND_PORT${NC}"
    echo -e "  Repository: ${GREEN}$GIT_REPO${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"

    read -p "$(echo -e ${YELLOW}Продолжить? [y/N]: ${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Отменено пользователем"
        exit 0
    fi
}

# Create database
create_database() {
    log_step "Создание PostgreSQL базы данных"

    DB_NAME="${BOT_NAME//-/_}_db"
    DB_USER="${BOT_NAME//-/_}_user"
    DB_PASSWORD=$(openssl rand -base64 32)

    log_info "Создание базы данных: $DB_NAME"

    sudo -u postgres psql << EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\c $DB_NAME
GRANT ALL ON SCHEMA public TO $DB_USER;
EOF

    log_success "База данных создана: $DB_NAME"
}

# Clone and setup repository
clone_and_setup_repo() {
    log_step "Клонирование и настройка репозитория"

    local BOT_DIR="$BOTS_DIR/$BOT_NAME"

    # Create bot directory
    mkdir -p "$BOT_DIR"/{logs,data}

    # Clone repository
    log_info "Клонирование $GIT_REPO..."
    git clone "$GIT_REPO" "$BOT_DIR/app" || {
        log_error "Не удалось клонировать репозиторий"
        rm -rf "$BOT_DIR"
        exit 1
    }

    cd "$BOT_DIR/app"

    # Detect structure
    STRUCTURE=$(detect_bot_structure "$BOT_DIR/app")

    if [ "$STRUCTURE" = "unknown" ]; then
        log_error "Не удалось определить структуру проекта"
        exit 1
    fi

    # Determine if has frontend
    HAS_FRONTEND=${HAS_FRONTEND:-false}

    if [ "$HAS_FRONTEND" = "true" ]; then
        read -p "$(echo -e ${CYAN}Frontend порт [default: auto]: ${NC})" FRONTEND_PORT
        if [ -z "$FRONTEND_PORT" ]; then
            FRONTEND_PORT=$(shuf -i 3000-9000 -n 1)
        fi
    fi

    log_success "Репозиторий клонирован"
}

# Setup environment
setup_environment() {
    log_step "Настройка окружения"

    local BOT_DIR="$BOTS_DIR/$BOT_NAME"
    local ENV_FILE="$BOT_DIR/.env"

    # Prepare .env template
    prepare_env_template "$BOT_DIR/app" "$STRUCTURE" > "$ENV_FILE"

    # Update with credentials
    update_env_file "$ENV_FILE" "$DB_NAME" "$DB_USER" "$DB_PASSWORD" "$BOT_TOKEN" "$BACKEND_PORT" "$BOT_DOMAIN"

    # Generate docker-compose
    generate_docker_compose_auto "$BOT_DIR" "$STRUCTURE" "$HAS_FRONTEND"

    log_success "Окружение настроено"
}

# Configure Nginx
configure_nginx() {
    log_step "Настройка Nginx"

    local NGINX_CONF="/etc/nginx/sites-available/${BOT_NAME}.conf"

    # Create Nginx configuration
    cat > "$NGINX_CONF" << EOF
# $BOT_NAME - Generated on $(date)

upstream ${BOT_NAME}_backend {
    server 127.0.0.1:${BACKEND_PORT};
}

EOF

    # Add frontend upstream if needed
    if [ -n "${FRONTEND_PORT:-}" ]; then
        cat >> "$NGINX_CONF" << EOF
upstream ${BOT_NAME}_frontend {
    server 127.0.0.1:${FRONTEND_PORT};
}

EOF
    fi

    # HTTP server (redirect to HTTPS)
    cat >> "$NGINX_CONF" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $BOT_DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $BOT_DOMAIN;

    # SSL will be configured by certbot
    ssl_certificate /etc/letsencrypt/live/$BOT_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$BOT_DOMAIN/privkey.pem;

    include /etc/nginx/snippets/ssl-params.conf;

    # Security headers
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/${BOT_NAME}_access.log;
    error_log /var/log/nginx/${BOT_NAME}_error.log;

    # Rate limiting
    limit_req zone=api burst=20 nodelay;

EOF

    if [ -n "${FRONTEND_PORT:-}" ]; then
        cat >> "$NGINX_CONF" << EOF
    # Frontend
    location / {
        proxy_pass http://${BOT_NAME}_frontend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Backend API
    location /api {
        proxy_pass http://${BOT_NAME}_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
EOF
    else
        cat >> "$NGINX_CONF" << EOF
    # Backend only
    location / {
        proxy_pass http://${BOT_NAME}_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
EOF
    fi

    cat >> "$NGINX_CONF" << EOF
}
EOF

    # Enable site
    ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/${BOT_NAME}.conf"

    # Test Nginx configuration
    nginx -t || {
        log_error "Nginx configuration test failed!"
        rm -f "/etc/nginx/sites-enabled/${BOT_NAME}.conf"
        exit 1
    }

    log_success "Nginx настроен"
}

# Obtain SSL certificate
obtain_ssl_certificate() {
    log_step "Получение SSL сертификата"

    log_info "Requesting certificate for $BOT_DOMAIN..."

    # Reload Nginx to serve ACME challenge
    systemctl reload nginx

    # Obtain certificate
    certbot certonly \
        --nginx \
        --non-interactive \
        --agree-tos \
        --email "admin@$BOT_DOMAIN" \
        --domains "$BOT_DOMAIN" \
        || {
            log_warning "Failed to obtain SSL certificate. Using self-signed certificate."

            # Create self-signed certificate
            mkdir -p "/etc/letsencrypt/live/$BOT_DOMAIN"
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout "/etc/letsencrypt/live/$BOT_DOMAIN/privkey.pem" \
                -out "/etc/letsencrypt/live/$BOT_DOMAIN/fullchain.pem" \
                -subj "/CN=$BOT_DOMAIN"
        }

    # Reload Nginx with SSL
    systemctl reload nginx

    log_success "SSL настроен"
}

# Start bot
start_bot() {
    log_step "Запуск бота"

    local BOT_DIR="$BOTS_DIR/$BOT_NAME"

    cd "$BOT_DIR"

    # Create shared network if not exists
    docker network create ${DOCKER_NETWORK_NAME:-bots_shared_network} 2>/dev/null || true

    # Build and start
    log_info "Сборка Docker образов..."
    docker compose build

    log_info "Запуск контейнеров..."
    docker compose up -d

    log_success "Бот запущен"
}

# Save bot info
save_bot_info() {
    local BOT_DIR="$BOTS_DIR/$BOT_NAME"

    cat > "$BOT_DIR/bot_info.json" << EOF
{
    "name": "$BOT_NAME",
    "domain": "$BOT_DOMAIN",
    "structure": "$STRUCTURE",
    "backend_port": $BACKEND_PORT,
    $([ "$HAS_FRONTEND" = "true" ] && echo "\"frontend_port\": $FRONTEND_PORT,")
    "database": "$DB_NAME",
    "repository": "$GIT_REPO",
    "created_at": "$(date -Iseconds)"
}
EOF
}

# Show completion
show_completion() {
    echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}║         🎉 БОТ УСПЕШНО ДОБАВЛЕН! 🎉                      ║${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${CYAN}📝 Информация о боте:${NC}\n"
    echo -e "  ${YELLOW}➤${NC} Название: ${GREEN}$BOT_NAME${NC}"
    echo -e "  ${YELLOW}➤${NC} Структура: ${GREEN}$STRUCTURE${NC}"
    echo -e "  ${YELLOW}➤${NC} Домен: ${GREEN}https://$BOT_DOMAIN${NC}"
    echo -e "  ${YELLOW}➤${NC} Backend: ${GREEN}$BACKEND_PORT${NC}"
    [ "$HAS_FRONTEND" = "true" ] && echo -e "  ${YELLOW}➤${NC} Frontend: ${GREEN}$FRONTEND_PORT${NC}"
    echo -e "  ${YELLOW}➤${NC} База данных: ${GREEN}$DB_NAME${NC}"
    echo -e "  ${YELLOW}➤${NC} Директория: ${GREEN}$BOTS_DIR/$BOT_NAME${NC}\n"

    echo -e "${CYAN}🔧 Полезные команды:${NC}\n"
    echo -e "  Логи:          ${GREEN}docker logs -f ${BOT_NAME}_bot${NC}"
    echo -e "  Перезапуск:    ${GREEN}cd $BOTS_DIR/$BOT_NAME && docker compose restart${NC}"
    echo -e "  Остановка:     ${GREEN}cd $BOTS_DIR/$BOT_NAME && docker compose stop${NC}"
    echo -e "  Обновление:    ${GREEN}cd $BOTS_DIR/$BOT_NAME/app && git pull && cd .. && docker compose up --build -d${NC}\n"
}

# Main
main() {
    show_banner

    if [[ $EUID -ne 0 ]]; then
        log_error "Скрипт должен запускаться от root"
        exit 1
    fi

    load_pg_credentials
    prompt_bot_info
    create_database
    clone_and_setup_repo
    setup_environment
    configure_nginx
    obtain_ssl_certificate
    start_bot
    save_bot_info
    show_completion
}

main "$@"