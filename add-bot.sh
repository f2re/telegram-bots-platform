#!/bin/bash

# ========================================
# 🤖 Add New Bot Script
# Telegram Bots Platform
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
PLATFORM_DIR="/opt/telegram-bots-platform"
BOTS_DIR="$PLATFORM_DIR/bots"
SCRIPTS_DIR="$PLATFORM_DIR/scripts"

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
║         🤖 ADD NEW TELEGRAM BOT 🤖                   ║
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

# Prompt for bot information
prompt_bot_info() {
    log_step "Bot Information"
    
    # Bot name
    while true; do
        read -p "$(echo -e ${CYAN}Enter bot name [alphanumeric, lowercase]: ${NC})" BOT_NAME
        if [[ "$BOT_NAME" =~ ^[a-z0-9_-]+$ ]]; then
            break
        else
            log_error "Invalid bot name. Use only lowercase letters, numbers, hyphens, and underscores."
        fi
    done
    
    # Check if bot already exists
    if [ -d "$BOTS_DIR/$BOT_NAME" ]; then
        log_error "Bot '$BOT_NAME' already exists!"
        exit 1
    fi
    
    # Bot token
    read -p "$(echo -e ${CYAN}Enter Telegram bot token: ${NC})" BOT_TOKEN
    
    # Domain
    read -p "$(echo -e ${CYAN}Enter domain name [e.g., bot.example.com]: ${NC})" BOT_DOMAIN
    
    # Bot type
    echo -e "\n${CYAN}Select bot type:${NC}"
    echo "  1) Simple bot (Python, no web interface)"
    echo "  2) Web app bot (Python backend + frontend)"
    echo "  3) Node.js bot"
    read -p "$(echo -e ${CYAN}Choice [1-3]: ${NC})" BOT_TYPE
    
    # Ports
    read -p "$(echo -e ${CYAN}Backend port [default: auto]: ${NC})" BACKEND_PORT
    if [ -z "$BACKEND_PORT" ]; then
        BACKEND_PORT=$(shuf -i 3000-9000 -n 1)
    fi
    
    if [ "$BOT_TYPE" == "2" ]; then
        read -p "$(echo -e ${CYAN}Frontend port [default: auto]: ${NC})" FRONTEND_PORT
        if [ -z "$FRONTEND_PORT" ]; then
            FRONTEND_PORT=$(shuf -i 3000-9000 -n 1)
        fi
    fi
    
    # GitHub repository (optional)
    read -p "$(echo -e ${CYAN}GitHub repository URL [optional]: ${NC})" GIT_REPO
    
    # Confirm
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}Confirm Bot Configuration:${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "  Name: ${GREEN}$BOT_NAME${NC}"
    echo -e "  Domain: ${GREEN}$BOT_DOMAIN${NC}"
    echo -e "  Backend Port: ${GREEN}$BACKEND_PORT${NC}"
    [ -n "${FRONTEND_PORT:-}" ] && echo -e "  Frontend Port: ${GREEN}$FRONTEND_PORT${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"
    
    read -p "$(echo -e ${YELLOW}Proceed? [y/N]: ${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Cancelled by user"
        exit 0
    fi
}

# Create database and user
create_database() {
    log_step "Creating PostgreSQL Database"
    
    local DB_NAME="${BOT_NAME//-/_}_db"
    local DB_USER="${BOT_NAME//-/_}_user"
    local DB_PASSWORD=$(openssl rand -base64 32)
    
    log_info "Creating database: $DB_NAME"
    
    sudo -u postgres psql << EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\c $DB_NAME
GRANT ALL ON SCHEMA public TO $DB_USER;
EOF
    
    log_success "Database created: $DB_NAME"
    
    # Save credentials
    export DB_NAME DB_USER DB_PASSWORD
}

# Create bot directory structure
create_bot_structure() {
    log_step "Creating Bot Directory Structure"
    
    local BOT_DIR="$BOTS_DIR/$BOT_NAME"
    
    mkdir -p "$BOT_DIR"/{app,config,logs,data}
    
    # Clone repository if provided
    if [ -n "${GIT_REPO:-}" ]; then
        log_info "Cloning repository..."
        git clone "$GIT_REPO" "$BOT_DIR/app" || {
            log_error "Failed to clone repository"
            exit 1
        }
    fi
    
    log_success "Directory structure created"
}

# Generate .env file
generate_env_file() {
    log_step "Generating Environment Configuration"
    
    local BOT_DIR="$BOTS_DIR/$BOT_NAME"
    local DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@host.docker.internal:5432/${DB_NAME}"
    
    cat > "$BOT_DIR/.env" << EOF
# Generated on $(date)
# Bot: $BOT_NAME

# Telegram Bot
BOT_TOKEN=$BOT_TOKEN
BOT_NAME=$BOT_NAME

# Database
DATABASE_URL=$DATABASE_URL
POSTGRES_HOST=host.docker.internal
POSTGRES_PORT=5432
POSTGRES_DB=$DB_NAME
POSTGRES_USER=$DB_USER
POSTGRES_PASSWORD=$DB_PASSWORD

# Application
BACKEND_PORT=$BACKEND_PORT
${FRONTEND_PORT:+FRONTEND_PORT=$FRONTEND_PORT}
DOMAIN=$BOT_DOMAIN
ENVIRONMENT=production

# Security
SECRET_KEY=$(openssl rand -hex 32)

# Redis (shared)
REDIS_URL=redis://redis:6379/$(shuf -i 1-15 -n 1)
EOF
    
    chmod 600 "$BOT_DIR/.env"
    log_success ".env file created"
}

# Generate Docker Compose file
generate_docker_compose() {
    log_step "Generating Docker Compose Configuration"
    
    local BOT_DIR="$BOTS_DIR/$BOT_NAME"
    
    cat > "$BOT_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  bot:
    build: ./app
    container_name: ${BOT_NAME}_bot
    restart: unless-stopped
    env_file:
      - .env
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - ./app:/app
      - ./logs:/app/logs
      - ./data:/app/data
    ports:
      - "${BACKEND_PORT}:${BACKEND_PORT}"
    networks:
      - ${BOT_NAME}_network
      - shared_network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "bot=${BOT_NAME}"

EOF
    
    # Add frontend if needed
    if [ -n "${FRONTEND_PORT:-}" ]; then
        cat >> "$BOT_DIR/docker-compose.yml" << EOF
  frontend:
    build: ./app/frontend
    container_name: ${BOT_NAME}_frontend
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "${FRONTEND_PORT}:80"
    networks:
      - ${BOT_NAME}_network
    depends_on:
      - bot
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "bot=${BOT_NAME},service=frontend"

EOF
    fi
    
    cat >> "$BOT_DIR/docker-compose.yml" << EOF
networks:
  ${BOT_NAME}_network:
    driver: bridge
  shared_network:
    external: true
    name: bots_shared_network
EOF
    
    log_success "Docker Compose file created"
}

# Configure Nginx
configure_nginx() {
    log_step "Configuring Nginx"
    
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
    
    log_success "Nginx configured"
}

# Obtain SSL certificate
obtain_ssl_certificate() {
    log_step "Obtaining SSL Certificate"
    
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
    
    log_success "SSL certificate configured"
}

# Start bot
start_bot() {
    log_step "Starting Bot"
    
    local BOT_DIR="$BOTS_DIR/$BOT_NAME"
    
    cd "$BOT_DIR"
    
    # Create shared network if not exists
    docker network create bots_shared_network 2>/dev/null || true
    
    # Build and start containers
    log_info "Building Docker images..."
    docker compose build
    
    log_info "Starting containers..."
    docker compose up -d
    
    log_success "Bot started"
}

# Add to monitoring
add_to_monitoring() {
    log_step "Adding to Monitoring"
    
    local BOT_DIR="$BOTS_DIR/$BOT_NAME"
    
    # Add Prometheus job
    if [ -f "/opt/monitoring/prometheus/prometheus.yml" ]; then
        cat >> "/opt/monitoring/prometheus/prometheus.yml" << EOF

  - job_name: '${BOT_NAME}'
    static_configs:
      - targets: ['host.docker.internal:${BACKEND_PORT}']
        labels:
          bot: '${BOT_NAME}'
EOF
        
        # Reload Prometheus
        docker exec prometheus kill -HUP 1 2>/dev/null || true
        
        log_success "Added to monitoring"
    fi
}

# Save bot info
save_bot_info() {
    log_step "Saving Bot Information"
    
    local BOT_DIR="$BOTS_DIR/$BOT_NAME"
    
    cat > "$BOT_DIR/bot_info.json" << EOF
{
    "name": "$BOT_NAME",
    "domain": "$BOT_DOMAIN",
    "backend_port": $BACKEND_PORT,
    ${FRONTEND_PORT:+"frontend_port": $FRONTEND_PORT,}
    "database": "$DB_NAME",
    "created_at": "$(date -Iseconds)",
    "type": "$BOT_TYPE"
}
EOF
    
    log_success "Bot information saved"
}

# Show completion message
show_completion() {
    echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}║              🎉 BOT ADDED SUCCESSFULLY! 🎉               ║${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}📝 Bot Information:${NC}\n"
    echo -e "  ${YELLOW}➤${NC} Name: ${GREEN}$BOT_NAME${NC}"
    echo -e "  ${YELLOW}➤${NC} Domain: ${GREEN}https://$BOT_DOMAIN${NC}"
    echo -e "  ${YELLOW}➤${NC} Backend Port: ${GREEN}$BACKEND_PORT${NC}"
    [ -n "${FRONTEND_PORT:-}" ] && echo -e "  ${YELLOW}➤${NC} Frontend Port: ${GREEN}$FRONTEND_PORT${NC}"
    echo -e "  ${YELLOW}➤${NC} Database: ${GREEN}$DB_NAME${NC}"
    echo -e "  ${YELLOW}➤${NC} Directory: ${GREEN}$BOTS_DIR/$BOT_NAME${NC}\n"
    
    echo -e "${CYAN}🔧 Useful Commands:${NC}\n"
    echo -e "  View logs:     ${GREEN}docker logs -f ${BOT_NAME}_bot${NC}"
    echo -e "  Restart:       ${GREEN}cd $BOTS_DIR/$BOT_NAME && docker compose restart${NC}"
    echo -e "  Stop:          ${GREEN}cd $BOTS_DIR/$BOT_NAME && docker compose stop${NC}"
    echo -e "  Remove:        ${GREEN}bot-remove $BOT_NAME${NC}\n"
}

# Main execution
main() {
    show_banner
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    load_pg_credentials
    prompt_bot_info
    create_database
    create_bot_structure
    generate_env_file
    generate_docker_compose
    configure_nginx
    obtain_ssl_certificate
    start_bot
    add_to_monitoring
    save_bot_info
    show_completion
}

# Run
main "$@"