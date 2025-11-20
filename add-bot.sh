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

    # Database credentials - using static gateway IP
    local pg_host="172.25.0.1"  # Static gateway from bots_shared_network
    update_or_add_var "DATABASE_URL" "postgresql://${db_user}:${db_password}@${pg_host}:5432/${db_name}"
    update_or_add_var "POSTGRES_HOST" "$pg_host"
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

    # Determine build context based on structure
    local build_context
    if [ "$structure" = "multi-service" ]; then
        build_context="./app/backend"
    else
        build_context="./app"
    fi

    cat > "$compose_file" << EOF
services:
  bot:
    build:
      context: $build_context
    container_name: \${BOT_NAME}_bot
    restart: unless-stopped
    env_file:
      - .env
    volumes:
      - ./logs:/app/logs
      - ./data:/app/data
    ports:
      - "\${BACKEND_PORT}:\${BACKEND_PORT}"
    networks:
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
        local frontend_context
        if [ "$structure" = "multi-service" ]; then
            frontend_context="./app/frontend"
        else
            frontend_context="./app/packages/frontend"
        fi

        cat >> "$compose_file" << EOF

  frontend:
    build:
      context: $frontend_context
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
      - shared_network
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

    # Networks - using only static shared network
    cat >> "$compose_file" << 'EOF'

networks:
  shared_network:
    external: true
    name: bots_shared_network
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

    # Check if database already exists
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        log_warning "База данных $DB_NAME уже существует"

        # Get existing password if possible, otherwise use new one
        if [ -f "/root/.platform/${BOT_NAME}_db_credentials" ]; then
            source "/root/.platform/${BOT_NAME}_db_credentials"
            log_info "Используются существующие учетные данные"
        else
            log_warning "Учетные данные не найдены, используется новый пароль"
        fi
    else
        # Create database and user
        sudo -u postgres psql 2>&1 << EOF | grep -v "already exists" || true
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\c $DB_NAME
GRANT ALL ON SCHEMA public TO $DB_USER;
EOF

        # Save credentials
        mkdir -p "/root/.platform"
        cat > "/root/.platform/${BOT_NAME}_db_credentials" << EOF
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
EOF
        chmod 600 "/root/.platform/${BOT_NAME}_db_credentials"

        log_success "База данных создана: $DB_NAME"
    fi
}

# Clone and setup repository
clone_and_setup_repo() {
    log_step "Клонирование и настройка репозитория"

    local BOT_DIR="$BOTS_DIR/$BOT_NAME"

    # Create bot directory
    mkdir -p "$BOT_DIR"/{logs,data}

    # Check if app directory already exists
    if [ -d "$BOT_DIR/app" ]; then
        log_warning "Директория $BOT_DIR/app уже существует"
        read -p "$(echo -e ${YELLOW}Удалить и клонировать заново? [y/N]: ${NC})" -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Удаление существующей директории..."
            rm -rf "$BOT_DIR/app"
        else
            log_info "Используем существующую директорию"
            cd "$BOT_DIR/app"
            git pull || log_warning "Не удалось обновить репозиторий"
        fi
    fi

    # Clone repository if doesn't exist
    if [ ! -d "$BOT_DIR/app" ]; then
        log_info "Клонирование $GIT_REPO..."
        git clone "$GIT_REPO" "$BOT_DIR/app" || {
            log_error "Не удалось клонировать репозиторий"
            rm -rf "$BOT_DIR"
            exit 1
        }
    fi

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

    log_success "Репозиторий настроен"
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

    # Create Nginx configuration - HTTP only initially
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

    # HTTP server - allow ACME challenge and serve content
    cat >> "$NGINX_CONF" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $BOT_DOMAIN;

    # ACME challenge for Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

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
    if nginx -t 2>&1; then
        log_success "Nginx configuration valid"
        # Reload Nginx
        systemctl reload nginx || log_warning "Could not reload Nginx"
    else
        log_error "Nginx configuration test failed!"
        log_warning "Removing invalid configuration..."
        rm -f "/etc/nginx/sites-enabled/${BOT_NAME}.conf"
        return 1
    fi

    log_success "Nginx настроен (HTTP only, SSL will be added next)"
}

# Obtain SSL certificate
obtain_ssl_certificate() {
    log_step "Получение SSL сертификата"

    log_info "Requesting certificate for $BOT_DOMAIN..."

    # Obtain certificate
    certbot certonly \
        --webroot \
        --webroot-path=/var/www/html \
        --non-interactive \
        --agree-tos \
        --email "admin@$BOT_DOMAIN" \
        --domains "$BOT_DOMAIN" \
        || {
            log_warning "Failed to obtain SSL certificate. Creating self-signed certificate..."

            # Create self-signed certificate
            mkdir -p "/etc/letsencrypt/live/$BOT_DOMAIN"
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout "/etc/letsencrypt/live/$BOT_DOMAIN/privkey.pem" \
                -out "/etc/letsencrypt/live/$BOT_DOMAIN/fullchain.pem" \
                -subj "/CN=$BOT_DOMAIN" 2>/dev/null
        }

    # Now update Nginx configuration to add HTTPS
    local NGINX_CONF="/etc/nginx/sites-available/${BOT_NAME}.conf"

    log_info "Adding HTTPS configuration to Nginx..."

    # Update HTTP server to redirect to HTTPS
    sed -i '/server_name '"$BOT_DOMAIN"';/a\
\
    # Redirect all HTTP to HTTPS except ACME challenge\
    location / {\
        return 301 https://$server_name$request_uri;\
    }' "$NGINX_CONF"

    # Remove old proxy_pass locations from HTTP server (they'll be in HTTPS)
    sed -i '/# Frontend/,/^    }/d; /# Backend only/,/^    }/d; /# Backend API/,/^    }/d' "$NGINX_CONF"

    # Add HTTPS server block
    cat >> "$NGINX_CONF" << EOF

# HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $BOT_DOMAIN;

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/$BOT_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$BOT_DOMAIN/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;

    # Security headers
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000" always;

    # Logging
    access_log /var/log/nginx/${BOT_NAME}_access.log;
    error_log /var/log/nginx/${BOT_NAME}_error.log;

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

    # Test and reload Nginx
    if nginx -t 2>&1; then
        systemctl reload nginx
        log_success "SSL настроен и Nginx перезагружен"
    else
        log_error "Nginx configuration test failed after adding SSL!"
        return 1
    fi
}

# Start bot
start_bot() {
    log_step "Запуск бота"

    local BOT_DIR="$BOTS_DIR/$BOT_NAME"

    cd "$BOT_DIR"

    # Load .env to ensure we have all variables
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a
    fi

    # Ensure static network exists with correct configuration
    local shared_network="bots_shared_network"
    local subnet="172.25.0.0/16"
    local gateway="172.25.0.1"

    log_info "Проверка статической сети: $shared_network"

    if ! docker network ls --format '{{.Name}}' | grep -q "^${shared_network}$"; then
        log_info "Создание статической сети с фиксированным gateway..."
        docker network create \
            --driver bridge \
            --subnet="$subnet" \
            --gateway="$gateway" \
            "$shared_network" || log_warning "Не удалось создать сеть (возможно уже существует)"
    else
        log_success "Статическая сеть существует"
    fi

    # Build and start
    log_info "Сборка Docker образов..."
    docker compose build

    log_info "Запуск контейнеров..."
    docker compose up -d

    log_success "Бот запущен"
    log_info "Gateway IP для PostgreSQL: $gateway"
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