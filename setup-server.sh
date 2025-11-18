#!/bin/bash

# ========================================
# 🚀 Telegram Bots Platform Setup Script
# Debian 12 Server Initialization with config.env support
# ========================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Файл конфигурации не найден: $CONFIG_FILE"
    echo "🧙 Запустите сначала: ./config-wizard.sh"
    exit 1
fi

# Source configuration
source "$CONFIG_FILE"

# Validate configuration
if ! validate_config 2>/dev/null; then
    echo "❌ Ошибка валидации конфигурации!"
    exit 1
fi

# Colors and Emojis
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  ${NC}$1"
}

log_success() {
    echo -e "${GREEN}✅ ${NC}$1"
}

log_warning() {
    echo -e "${YELLOW}⚠️  ${NC}$1"
}

log_error() {
    echo -e "${RED}❌ ${NC}$1"
}

log_step() {
    echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🔹 $1${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Spinner animation
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Show loaded configuration
show_config_summary() {
    log_step "Загруженная конфигурация"
    
    echo -e "${CYAN}SSH:${NC}"
    echo -e "  Порт: ${GREEN}$SSH_PORT${NC}"
    echo -e "  Password Auth: ${GREEN}$SSH_PASSWORD_AUTH${NC}"
    
    echo -e "\n${CYAN}PostgreSQL:${NC}"
    echo -e "  Max Connections: ${GREEN}$POSTGRES_MAX_CONNECTIONS${NC}"
    echo -e "  Shared Buffers: ${GREEN}$POSTGRES_SHARED_BUFFERS${NC}"
    
    echo -e "\n${CYAN}Nginx:${NC}"
    echo -e "  Max Body Size: ${GREEN}$NGINX_CLIENT_MAX_BODY_SIZE${NC}"
    echo -e "  API Rate Limit: ${GREEN}$NGINX_RATE_LIMIT_API${NC}"
    
    echo -e "\n${CYAN}Мониторинг:${NC}"
    echo -e "  Enabled: ${GREEN}$MONITORING_ENABLED${NC}"
    [ "$MONITORING_ENABLED" = "true" ] && echo -e "  Grafana Port: ${GREEN}$GRAFANA_PORT${NC}"
    
    echo -e "\n${CYAN}Fail2Ban:${NC}"
    echo -e "  Enabled: ${GREEN}$FAIL2BAN_ENABLED${NC}"
    [ "$FAIL2BAN_ENABLED" = "true" ] && echo -e "  SSH Max Retry: ${GREEN}$FAIL2BAN_SSH_MAXRETRY${NC}"
    
    echo ""
    read -p "$(echo -e ${YELLOW}Продолжить установку с этими настройками? [y/N]: ${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Установка отменена"
        exit 0
    fi
}

# Banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   ████████╗███████╗██╗     ███████╗ ██████╗ ██████╗      ║
║   ╚══██╔══╝██╔════╝██║     ██╔════╝██╔════╝ ██╔══██╗     ║
║      ██║   █████╗  ██║     █████╗  ██║  ███╗██████╔╝     ║
║      ██║   ██╔══╝  ██║     ██╔══╝  ██║   ██║██╔══██╗     ║
║      ██║   ███████╗███████╗███████╗╚██████╔╝██║  ██║     ║
║      ╚═╝   ╚══════╝╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝     ║
║                                                           ║
║        🤖 Telegram Bots Platform Setup v1.0 🤖           ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
    log_info "Используется конфигурация: $CONFIG_FILE"
    echo ""
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Backup current SSH config
backup_ssh_config() {
    log_step "Backup SSH Configuration"
    
    if [ -f /etc/ssh/sshd_config ]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
        log_success "SSH config backed up"
    fi
}

# Get current user info
get_current_user() {
    if [ -n "${SUDO_USER:-}" ]; then
        echo "$SUDO_USER"
    else
        echo "$USER"
    fi
}

# Install prerequisites
install_prerequisites() {
    log_step "Installing Prerequisites"
    
    export DEBIAN_FRONTEND=noninteractive
    
    log_info "Updating package lists..."
    apt-get update -qq 2>&1 &
    spinner $!
    
    log_info "Installing essential packages..."
    apt-get install -y -qq \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        git \
        wget \
        htop \
        vim \
        ufw \
        fail2ban \
        unattended-upgrades \
        openssl \
        certbot \
        python3-certbot-nginx \
        jq \
        2>&1 &
    spinner $!
    
    log_success "Prerequisites installed"
}

# Setup secure SSH
setup_ssh_security() {
    log_step "Configuring Secure SSH"
    
    local ADMIN_USER=$(get_current_user)
    local SSH_PORT=${SSH_PORT:-22}
    local NEW_SSH_PORT=$SSH_PORT
    
    log_info "Current SSH user: $ADMIN_USER"
    
    # Create SSH directory if not exists
    if [ ! -d "/home/$ADMIN_USER/.ssh" ]; then
        mkdir -p "/home/$ADMIN_USER/.ssh"
        chown "$ADMIN_USER:$ADMIN_USER" "/home/$ADMIN_USER/.ssh"
        chmod 700 "/home/$ADMIN_USER/.ssh"
    fi
    
    # Generate SSH key if not exists
    if [ ! -f "/home/$ADMIN_USER/.ssh/id_rsa" ]; then
        log_info "Generating SSH key pair..."
        sudo -u "$ADMIN_USER" ssh-keygen -t rsa -b 4096 -f "/home/$ADMIN_USER/.ssh/id_rsa" -N "" -C "$ADMIN_USER@telegram-bots-platform"
        log_success "SSH key generated"
        
        # Show public key
        echo -e "\n${YELLOW}📋 Save this public key for future access:${NC}"
        cat "/home/$ADMIN_USER/.ssh/id_rsa.pub"
        echo ""
    fi
    
    # Setup authorized_keys
    if [ ! -f "/home/$ADMIN_USER/.ssh/authorized_keys" ]; then
        cp "/home/$ADMIN_USER/.ssh/id_rsa.pub" "/home/$ADMIN_USER/.ssh/authorized_keys"
        chmod 600 "/home/$ADMIN_USER/.ssh/authorized_keys"
        chown "$ADMIN_USER:$ADMIN_USER" "/home/$ADMIN_USER/.ssh/authorized_keys"
    fi
    
    # Configure SSH daemon
    log_info "Configuring SSH daemon..."
    
    cat > /etc/ssh/sshd_config << EOF
# Telegram Bots Platform SSH Configuration
# Generated on $(date)

# Port and Protocol
Port $NEW_SSH_PORT
Protocol 2

# Authentication
PermitRootLogin $SSH_PERMIT_ROOT_LOGIN
PubkeyAuthentication yes
PasswordAuthentication $SSH_PASSWORD_AUTH
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Security
MaxAuthTries $SSH_MAX_AUTH_TRIES
MaxSessions 10
ClientAliveInterval $SSH_CLIENT_ALIVE_INTERVAL
ClientAliveCountMax $SSH_CLIENT_ALIVE_COUNT_MAX

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Subsystems
Subsystem sftp /usr/lib/openssh/sftp-server

# Banner
Banner /etc/ssh/banner

# Performance
UseDNS no
EOF
    
    # Create SSH banner
    cat > /etc/ssh/banner << 'EOF'
╔═══════════════════════════════════════════════╗
║    🤖 Telegram Bots Platform Server 🤖      ║
║                                               ║
║    ⚠️  AUTHORIZED ACCESS ONLY ⚠️             ║
║                                               ║
║    All connections are monitored and logged  ║
╚═══════════════════════════════════════════════╝
EOF
    
    log_warning "SSH will be configured on port $NEW_SSH_PORT"
    log_warning "Make sure to update firewall rules before disconnecting!"
    
    # Ask for confirmation before applying
    read -p "$(echo -e ${YELLOW}Apply SSH configuration now? [y/N]: ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Validate SSH config
        if sshd -t -f /etc/ssh/sshd_config; then
            log_success "SSH configuration is valid"
            log_info "SSH will be restarted after firewall configuration"
        else
            log_error "SSH configuration is invalid!"
            log_warning "Restoring backup..."
            cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config 2>/dev/null || true
            exit 1
        fi
    fi
}

# Setup firewall
setup_firewall() {
    log_step "Configuring Firewall (UFW)"
    
    local NEW_SSH_PORT=$SSH_PORT
    
    if [ "$UFW_ENABLED" = "true" ]; then
        log_info "Resetting firewall rules..."
        ufw --force reset > /dev/null 2>&1
        
        log_info "Setting default policies..."
        ufw default deny incoming
        ufw default allow outgoing
        
        log_info "Allowing essential services..."
        # SSH
        ufw allow $NEW_SSH_PORT/tcp comment 'SSH'
        
        # HTTP/HTTPS
        ufw allow 80/tcp comment 'HTTP'
        ufw allow 443/tcp comment 'HTTPS'
        
        # PostgreSQL (only from localhost)
        ufw allow from 127.0.0.1 to any port 5432 comment 'PostgreSQL Local'
        
        # Grafana (with optional IP restriction)
        if [ -n "$UFW_GRAFANA_ALLOWED_IPS" ]; then
            ufw allow from "$UFW_GRAFANA_ALLOWED_IPS" to any port $GRAFANA_PORT comment 'Grafana'
        else
            ufw allow $GRAFANA_PORT/tcp comment 'Grafana'
        fi
        
        # Additional ports
        for port in $UFW_ADDITIONAL_PORTS; do
            ufw allow $port/tcp comment "Additional port"
        done
        
        log_info "Enabling firewall..."
        ufw --force enable
        
        log_success "Firewall configured and enabled"
        ufw status numbered
    else
        log_info "UFW firewall is disabled in config, skipping configuration"
    fi
}

# Setup Fail2Ban
setup_fail2ban() {
    if [ "$FAIL2BAN_ENABLED" = "true" ]; then
        log_step "Configuring Fail2Ban"
        
        local NEW_SSH_PORT=$SSH_PORT
        
        # Create jail.local
        cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = $FAIL2BAN_BANTIME
findtime = $FAIL2BAN_FINDTIME
maxretry = $FAIL2BAN_MAXRETRY
destemail = ${FAIL2BAN_DESTEMAIL:-root@localhost}
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = $NEW_SSH_PORT
logpath = /var/log/auth.log
maxretry = $FAIL2BAN_SSH_MAXRETRY
bantime = $FAIL2BAN_SSH_BANTIME

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-noscript]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log

[nginx-badbots]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-noproxy]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
EOF
        
        systemctl restart fail2ban
        systemctl enable fail2ban
        
        log_success "Fail2Ban configured and started"
    else
        log_info "Fail2Ban is disabled in config, skipping configuration"
    fi
}

# Install Docker
install_docker() {
    log_step "Installing Docker"
    
    if command -v docker &> /dev/null; then
        log_warning "Docker is already installed"
        docker --version
        return 0
    fi
    
    log_info "Adding Docker GPG key..."
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    log_info "Adding Docker repository..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    log_info "Installing Docker Engine..."
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>&1 &
    spinner $!
    
    # Add user to docker group
    local ADMIN_USER=$(get_current_user)
    usermod -aG docker "$ADMIN_USER"
    
    # Enable Docker service
    systemctl enable docker
    systemctl start docker
    
    log_success "Docker installed: $(docker --version)"
}

# Install PostgreSQL
install_postgresql() {
    log_step "Installing PostgreSQL"
    
    log_info "Installing PostgreSQL $POSTGRES_VERSION..."
    apt-get install -y -qq postgresql postgresql-contrib postgresql-$POSTGRES_VERSION 2>&1 &
    spinner $!
    
    # Configure PostgreSQL
    log_info "Configuring PostgreSQL..."
    
    # Set password for postgres user
    local PG_PASSWORD=$POSTGRES_PASSWORD
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$PG_PASSWORD';" > /dev/null
    
    # Save credentials
    mkdir -p /root/.platform
    cat > /root/.platform/postgres_credentials << EOF
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$PG_PASSWORD
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
EOF
    chmod 600 /root/.platform/postgres_credentials
    
    # Configure pg_hba.conf for local connections
    cat >> /etc/postgresql/$POSTGRES_VERSION/main/pg_hba.conf << 'EOF'

# Telegram Bots Platform Configuration
local   all             all                                     scram-sha-256
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
host    all             all             172.16.0.0/12           scram-sha-256
EOF
    
    # Configure postgresql.conf with values from config
    cat >> /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf << EOF

# Telegram Bots Platform Configuration
listen_addresses = '$POSTGRES_LISTEN_ADDRESSES'
max_connections = $POSTGRES_MAX_CONNECTIONS
shared_buffers = $POSTGRES_SHARED_BUFFERS
effective_cache_size = $POSTGRES_EFFECTIVE_CACHE_SIZE
maintenance_work_mem = $POSTGRES_MAINTENANCE_WORK_MEM
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = $POSTGRES_WORK_MEM
min_wal_size = $POSTGRES_MIN_WAL_SIZE
max_wal_size = $POSTGRES_MAX_WAL_SIZE
EOF
    
    systemctl restart postgresql
    systemctl enable postgresql
    
    log_success "PostgreSQL installed and configured"
    
    echo -e "\n${YELLOW}📋 PostgreSQL credentials saved to: /root/.platform/postgres_credentials${NC}\n"
}

# Install Nginx
install_nginx() {
    log_step "Installing Nginx"
    
    log_info "Installing Nginx..."
    apt-get install -y -qq nginx 2>&1 &
    spinner $!
    
    # Create directory structure
    mkdir -p /etc/nginx/sites-enabled
    mkdir -p /etc/nginx/sites-available
    mkdir -p /etc/nginx/snippets
    mkdir -p /var/www/html/.well-known/acme-challenge
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Create SSL parameters snippet
    cat > /etc/nginx/snippets/ssl-params.conf << 'EOF'
# SSL Configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_stapling on;
ssl_stapling_verify on;

# Security Headers
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
EOF
    
    # Create base configuration
    cat > /etc/nginx/nginx.conf << EOF
user www-data;
worker_processes $NGINX_WORKER_PROCESSES;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections $NGINX_WORKER_CONNECTIONS;
    use epoll;
    multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout $NGINX_KEEPALIVE_TIMEOUT;
    types_hash_max_size 2048;
    server_tokens off;
    client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;

    # MIME
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level $NGINX_GZIP_COMP_LEVEL;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;

    # Rate Limiting
    limit_req_zone \$binary_remote_addr zone=general:10m rate=$NGINX_RATE_LIMIT_GENERAL;
    limit_req_zone \$binary_remote_addr zone=api:10m rate=$NGINX_RATE_LIMIT_API;

    # Virtual Host Configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF
    
    # Test and reload Nginx
    nginx -t
    systemctl restart nginx
    systemctl enable nginx
    
    log_success "Nginx installed and configured"
}

# Install Oh My Zsh
install_oh_my_zsh() {
    if [ "$INSTALL_OH_MY_ZSH" = "true" ]; then
        log_step "Installing Oh My Zsh"
        
        local ADMIN_USER=$(get_current_user)
        
        # Install Zsh
        apt-get install -y -qq zsh 2>&1 &
        spinner $!
        
        # Install Oh My Zsh
        if [ ! -d "/home/$ADMIN_USER/.oh-my-zsh" ]; then
            log_info "Installing Oh My Zsh for $ADMIN_USER..."
            sudo -u "$ADMIN_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
            
            # Install plugins
            log_info "Installing Zsh plugins..."
            
            # zsh-autosuggestions
            sudo -u "$ADMIN_USER" git clone https://github.com/zsh-users/zsh-autosuggestions "/home/$ADMIN_USER/.oh-my-zsh/custom/plugins/zsh-autosuggestions" 2>/dev/null || true
            
            # zsh-syntax-highlighting
            sudo -u "$ADMIN_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "/home/$ADMIN_USER/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" 2>/dev/null || true
            
            # Configure .zshrc
            cat > "/home/$ADMIN_USER/.zshrc" << 'EOF'
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="agnoster"

plugins=(
    git
    docker
    docker-compose
    postgres
    npm
    node
    python
    pip
    sudo
    systemd
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Platform Aliases
alias bots='cd /opt/telegram-bots-platform/bots'
alias bot-add='sudo /opt/telegram-bots-platform/add-bot.sh'
alias bot-remove='sudo /opt/telegram-bots-platform/remove-bot.sh'
alias bot-status='sudo /opt/telegram-bots-platform/monitor-status.sh'
alias bot-logs='docker logs -f'
alias pgcli='sudo -u postgres psql'

# Docker Aliases
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dlog='docker logs -f --tail 100'
alias dstop='docker stop'
alias dstart='docker start'
alias drestart='docker restart'

echo "🤖 Telegram Bots Platform"
echo "Run 'bot-status' to see all bots"
EOF
            
            chown "$ADMIN_USER:$ADMIN_USER" "/home/$ADMIN_USER/.zshrc"
            
            # Set Zsh as default shell
            chsh -s $(which zsh) "$ADMIN_USER"
            
            log_success "Oh My Zsh installed for $ADMIN_USER"
        else
            log_warning "Oh My Zsh already installed"
        fi
    else
        log_info "Oh-My-Zsh installation is disabled in config"
    fi
}

# Install Monitoring Stack
install_monitoring() {
    if [ "$MONITORING_ENABLED" = "true" ]; then
        log_step "Installing Monitoring Stack (Prometheus + Grafana)"
        
        mkdir -p /opt/monitoring/{prometheus,grafana}
        
        # Create Prometheus configuration
        cat > /opt/monitoring/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'postgres_exporter'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'nginx_exporter'
    static_configs:
      - targets: ['nginx-exporter:9113']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
EOF
        
        # Create Grafana provisioning
        mkdir -p /opt/monitoring/grafana/provisioning/{datasources,dashboards}
        
        cat > /opt/monitoring/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF
        
        cat > /opt/monitoring/grafana/provisioning/dashboards/default.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF
        
        # Create Docker Compose for monitoring
        cat > /opt/monitoring/docker-compose.yml << EOF
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=$PROMETHEUS_RETENTION_TIME'
      - '--web.enable-lifecycle'
    ports:
      - "$PROMETHEUS_PORT:9090"
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - monitoring

  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:latest
    container_name: postgres-exporter
    restart: unless-stopped
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:${POSTGRES_PASSWORD}@host.docker.internal:5432/postgres?sslmode=disable"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    privileged: true
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
      - /dev/disk:/dev/disk:ro
    devices:
      - /dev/kmsg
    networks:
      - monitoring

  nginx-exporter:
    image: nginx/nginx-prometheus-exporter:latest
    container_name: nginx-exporter
    restart: unless-stopped
    command:
      - '-nginx.scrape-uri=http://host.docker.internal:8080/stub_status'
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin}
      - GF_USERS_ALLOW_SIGN_UP=$GRAFANA_ALLOW_SIGN_UP
      - GF_SERVER_ROOT_URL=http://localhost:$GRAFANA_PORT
      - GF_INSTALL_PLUGINS=
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    ports:
      - "$GRAFANA_PORT:3000"
    networks:
      - monitoring
    depends_on:
      - prometheus

volumes:
  prometheus_data:
  grafana_data:

networks:
  monitoring:
    driver: bridge
EOF
        
        # Set environment variable for Postgres password
        source /root/.platform/postgres_credentials
        export POSTGRES_PASSWORD
        export GRAFANA_PASSWORD=$GRAFANA_ADMIN_PASSWORD
        
        # Save Grafana password
        echo "GRAFANA_PASSWORD=$GRAFANA_PASSWORD" >> /root/.platform/monitoring_credentials
        chmod 600 /root/.platform/monitoring_credentials
        
        # Add Nginx status endpoint
        cat > /etc/nginx/conf.d/status.conf << EOF
server {
    listen 8080;
    server_name localhost;
    
    location /stub_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        allow 172.16.0.0/12;
        deny all;
    }
}
EOF
        
        nginx -s reload
        
        # Start monitoring stack
        cd /opt/monitoring
        docker compose up -d
        
        log_success "Monitoring stack installed"
        echo -e "\n${YELLOW}📊 Grafana credentials saved to: /root/.platform/monitoring_credentials${NC}"
        echo -e "${YELLOW}📊 Access Grafana at: http://$(curl -s ifconfig.me):$GRAFANA_PORT${NC}"
        echo -e "${YELLOW}📊 Default username: admin${NC}\n"
    else
        log_info "Monitoring installation is disabled in config"
    fi
}

# Create platform directory structure
create_platform_structure() {
    log_step "Creating Platform Directory Structure"
    
    mkdir -p /opt/telegram-bots-platform/{bots,scripts,configs,logs,$(basename $BACKUP_DIR)}
    mkdir -p /opt/telegram-bots-platform/configs/{nginx,postgres,templates}
    
    log_success "Directory structure created"
}

# Finalize setup
finalize_setup() {
    log_step "Finalizing Setup"
    
    local ADMIN_USER=$(get_current_user)
    local NEW_SSH_PORT=$SSH_PORT
    
    # Restart SSH
    log_info "Restarting SSH service..."
    systemctl restart sshd
    
    # Create setup info file
    cat > /root/.platform/setup_info << EOF
# Telegram Bots Platform Setup Information
# Generated on $(date)

SERVER_IP=$(curl -s ifconfig.me)
ADMIN_USER=$ADMIN_USER
SSH_PORT=$NEW_SSH_PORT
SERVER_TIMEZONE=$SERVER_TIMEZONE
ADMIN_EMAIL=$ADMIN_EMAIL

PLATFORM_DIR=/opt/telegram-bots-platform
BOTS_DIR=/opt/telegram-bots-platform/bots
BACKUP_DIR=$BACKUP_DIR

# Services Status
DOCKER_VERSION=$(docker --version)
NGINX_VERSION=$(nginx -v 2>&1)
POSTGRESQL_VERSION=$(sudo -u postgres psql --version)
EOF
    
    chmod 600 /root/.platform/setup_info
    
    log_success "Setup completed successfully!"
    
    # Display summary
    echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}║              🎉 SETUP COMPLETED! 🎉                      ║${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}📝 Important Information:${NC}\n"
    echo -e "  ${YELLOW}➤${NC} SSH Port: ${GREEN}$NEW_SSH_PORT${NC}"
    echo -e "  ${YELLOW}➤${NC} SSH User: ${GREEN}$ADMIN_USER${NC}"
    echo -e "  ${YELLOW}➤${NC} Platform Directory: ${GREEN}/opt/telegram-bots-platform${NC}"
    [ "$MONITORING_ENABLED" = "true" ] && echo -e "  ${YELLOW}➤${NC} Grafana: ${GREEN}http://$(curl -s ifconfig.me):$GRAFANA_PORT${NC}"
    echo -e "  ${YELLOW}➤${NC} Credentials: ${GREEN}/root/.platform/${NC}\n"
    
    echo -e "${RED}⚠️  IMPORTANT SECURITY NOTES:${NC}\n"
    echo -e "  1. Save your SSH private key from: ${YELLOW}/home/$ADMIN_USER/.ssh/id_rsa${NC}"
    echo -e "  2. New SSH port: ${YELLOW}$NEW_SSH_PORT${NC}"
    echo -e "  3. Password authentication is ${RED}$(if [ "$SSH_PASSWORD_AUTH" = "no" ]; then echo "DISABLED"; else echo "ENABLED"; fi)${NC}"
    echo -e "  4. Reconnect using: ${YELLOW}ssh -p $NEW_SSH_PORT $ADMIN_USER@$(curl -s ifconfig.me)${NC}\n"
    
    echo -e "${CYAN}🤖 Next Steps:${NC}\n"
    echo -e "  1. Test SSH connection in a NEW terminal window"
    echo -e "  2. Run: ${GREEN}bot-add${NC} to add your first bot"
    echo -e "  3. Run: ${GREEN}bot-status${NC} to monitor all bots\n"
    
    read -p "Press Enter to continue..."
}

# Main execution
main() {
    show_banner
    check_root
    show_config_summary
    
    log_info "Starting server setup with configuration from $CONFIG_FILE"
    
    backup_ssh_config
    install_prerequisites
    setup_ssh_security
    setup_firewall
    
    if [ "$FAIL2BAN_ENABLED" = "true" ]; then
        setup_fail2ban
    fi
    
    install_docker
    install_postgresql
    install_nginx
    
    if [ "$INSTALL_OH_MY_ZSH" = "true" ]; then
        install_oh_my_zsh
    fi
    
    if [ "$MONITORING_ENABLED" = "true" ]; then
        install_monitoring
    fi
    
    create_platform_structure
    finalize_setup
}

# Run main function
main "$@"