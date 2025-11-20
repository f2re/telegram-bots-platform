#!/bin/bash

# ========================================
# Telegram Bots Platform Manager
# Unified entry point for all platform operations
# ========================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Aligned banner (no emoji spacing issues)
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║      TELEGRAM BOTS PLATFORM - Management Console          ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

# Main menu
show_main_menu() {
    echo -e "${CYAN}═══ Main Menu ═══${NC}\n"
    echo "  ${YELLOW}SETUP & CONFIGURATION${NC}"
    echo "  1) Initial Server Setup (Full)"
    echo "  2) Component Setup (Select Components)"
    echo "  3) Network Setup (Static Docker Network)"
    echo ""
    echo "  ${YELLOW}BOT MANAGEMENT${NC}"
    echo "  4) Add New Bot"
    echo "  5) Manage Bots"
    echo "  6) Remove Bot"
    echo ""
    echo "  ${YELLOW}SYSTEM MANAGEMENT${NC}"
    echo "  7) Show All Credentials"
    echo "  8) Fix Permissions"
    echo "  9) View System Status"
    echo ""
    echo "  ${YELLOW}ADVANCED${NC}"
    echo "  10) Remove Component"
    echo "  11) Restart All Services"
    echo ""
    echo "  0) Exit"
    echo ""
    read -p "$(echo -e ${WHITE}Your choice: ${NC})" choice

    case $choice in
        1) full_server_setup ;;
        2) component_setup ;;
        3) network_setup ;;
        4) add_bot ;;
        5) manage_bots ;;
        6) remove_bot ;;
        7) show_credentials ;;
        8) fix_permissions ;;
        9) system_status ;;
        10) remove_component_menu ;;
        11) restart_all ;;
        0) exit 0 ;;
        *) log_error "Invalid choice" ;;
    esac

    echo ""
    read -p "Press Enter to continue..."
}

# Full server setup
full_server_setup() {
    log_info "Starting full server setup..."
    if [ -f "$SCRIPT_DIR/setup-server.sh" ]; then
        "$SCRIPT_DIR/setup-server.sh"
    else
        log_error "setup-server.sh not found"
    fi
}

# Component setup menu
component_setup() {
    echo -e "\n${CYAN}═══ Component Setup ═══${NC}\n"
    echo "  1) PostgreSQL Database"
    echo "  2) Docker"
    echo "  3) Nginx Web Server"
    echo "  4) Static Docker Network"
    echo "  5) Monitoring (Prometheus + Grafana)"
    echo "  6) SSL Certificates"
    echo "  0) Back"
    echo ""
    read -p "$(echo -e ${WHITE}Select component: ${NC})" comp

    case $comp in
        1) setup_postgresql ;;
        2) setup_docker ;;
        3) setup_nginx ;;
        4) setup_static_network ;;
        5) setup_monitoring ;;
        6) setup_ssl ;;
        0) return ;;
        *) log_error "Invalid choice" ;;
    esac
}

# PostgreSQL setup with static network
setup_postgresql() {
    log_info "Setting up PostgreSQL with static network configuration..."

    # Install PostgreSQL
    apt-get update
    apt-get install -y postgresql postgresql-contrib

    # Configure for static network
    PG_VERSION=$(sudo -u postgres psql --version | grep -oP '\d+' | head -1)
    PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

    # Backup
    mkdir -p /root/.platform/backups
    cp "$PG_CONF" "/root/.platform/backups/postgresql.conf.$(date +%Y%m%d_%H%M%S)"
    cp "$PG_HBA" "/root/.platform/backups/pg_hba.conf.$(date +%Y%m%d_%H%M%S)"

    # Configure listen_addresses
    sed -i "s/^listen_addresses/#listen_addresses/" "$PG_CONF"
    echo "listen_addresses = 'localhost,172.25.0.1'" >> "$PG_CONF"

    # Configure pg_hba.conf
    if ! grep -q "172.25.0.0/16" "$PG_HBA"; then
        echo "host    all    all    172.25.0.0/16    scram-sha-256" >> "$PG_HBA"
    fi

    # Restart PostgreSQL
    systemctl restart postgresql
    systemctl enable postgresql

    log_success "PostgreSQL configured for static network (172.25.0.1)"
}

# Docker setup
setup_docker() {
    log_info "Installing Docker..."

    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    log_success "Docker installed and started"
}

# Nginx setup
setup_nginx() {
    log_info "Installing Nginx..."

    apt-get update
    apt-get install -y nginx certbot python3-certbot-nginx

    # Create SSL params
    cat > /etc/nginx/snippets/ssl-params.conf << 'EOF'
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
ssl_session_timeout 10m;
ssl_session_cache shared:SSL:10m;
EOF

    systemctl start nginx
    systemctl enable nginx

    log_success "Nginx installed and configured"
}

# Static network setup
setup_static_network() {
    if [ -f "$SCRIPT_DIR/setup-static-network.sh" ]; then
        "$SCRIPT_DIR/setup-static-network.sh"
    else
        log_error "setup-static-network.sh not found"
    fi
}

# Monitoring setup
setup_monitoring() {
    log_info "Setting up monitoring stack..."

    if [ -f "$SCRIPT_DIR/scripts/monitoring.sh" ]; then
        "$SCRIPT_DIR/scripts/monitoring.sh"
    else
        log_warning "Monitoring script not found"
    fi
}

# SSL setup
setup_ssl() {
    log_info "SSL setup - use during bot creation"
    log_info "SSL certificates are automatically obtained when adding a bot"
}

# Network setup
network_setup() {
    if [ -f "$SCRIPT_DIR/setup-static-network.sh" ]; then
        "$SCRIPT_DIR/setup-static-network.sh"
    else
        log_error "setup-static-network.sh not found"
    fi
}

# Add bot
add_bot() {
    if [ -f "$SCRIPT_DIR/add-bot.sh" ]; then
        "$SCRIPT_DIR/add-bot.sh"
    else
        log_error "add-bot.sh not found"
    fi
}

# Manage bots
manage_bots() {
    if [ -f "$SCRIPT_DIR/bot-manage.sh" ]; then
        "$SCRIPT_DIR/bot-manage.sh"
    else
        log_error "bot-manage.sh not found"
    fi
}

# Remove bot
remove_bot() {
    if [ -f "$SCRIPT_DIR/remove-bot.sh" ]; then
        "$SCRIPT_DIR/remove-bot.sh"
    else
        log_error "remove-bot.sh not found"
    fi
}

# Show credentials
show_credentials() {
    if [ -f "$SCRIPT_DIR/show-credentials.sh" ]; then
        "$SCRIPT_DIR/show-credentials.sh"
    else
        log_error "show-credentials.sh not found"
    fi
}

# Fix permissions
fix_permissions() {
    if [ -f "$SCRIPT_DIR/scripts/fix-permissions.sh" ]; then
        bash "$SCRIPT_DIR/scripts/fix-permissions.sh"
    else
        log_warning "fix-permissions.sh not found"
    fi
}

# System status
system_status() {
    echo -e "\n${CYAN}═══ System Status ═══${NC}\n"

    # PostgreSQL
    echo -e "${YELLOW}PostgreSQL:${NC}"
    if systemctl is-active --quiet postgresql; then
        echo -e "  ${GREEN}●${NC} Running"
    else
        echo -e "  ${RED}●${NC} Stopped"
    fi

    # Docker
    echo -e "\n${YELLOW}Docker:${NC}"
    if systemctl is-active --quiet docker; then
        echo -e "  ${GREEN}●${NC} Running"
        docker ps --format "table {{.Names}}\t{{.Status}}" | head -5
    else
        echo -e "  ${RED}●${NC} Stopped"
    fi

    # Nginx
    echo -e "\n${YELLOW}Nginx:${NC}"
    if systemctl is-active --quiet nginx; then
        echo -e "  ${GREEN}●${NC} Running"
    else
        echo -e "  ${RED}●${NC} Stopped"
    fi

    # Networks
    echo -e "\n${YELLOW}Docker Networks:${NC}"
    docker network ls --format "table {{.Name}}\t{{.Driver}}" | grep -E "bots_|NAME"

    # Bots
    echo -e "\n${YELLOW}Bots:${NC}"
    if [ -d "/opt/telegram-bots-platform/bots" ]; then
        for bot in /opt/telegram-bots-platform/bots/*; do
            if [ -d "$bot" ]; then
                bot_name=$(basename "$bot")
                cd "$bot"
                if docker compose ps --format json 2>/dev/null | grep -q "running"; then
                    echo -e "  ${GREEN}●${NC} $bot_name"
                else
                    echo -e "  ${RED}●${NC} $bot_name"
                fi
            fi
        done
    fi
}

# Remove component menu
remove_component_menu() {
    echo -e "\n${RED}═══ Remove Component ═══${NC}\n"
    echo -e "${YELLOW}WARNING: This will remove components from the system!${NC}\n"
    echo "  1) Remove PostgreSQL"
    echo "  2) Remove Docker"
    echo "  3) Remove Nginx"
    echo "  4) Remove Monitoring"
    echo "  0) Back"
    echo ""
    read -p "$(echo -e ${WHITE}Select component to remove: ${NC})" comp

    case $comp in
        1) remove_postgresql ;;
        2) remove_docker ;;
        3) remove_nginx ;;
        4) remove_monitoring ;;
        0) return ;;
        *) log_error "Invalid choice" ;;
    esac
}

# Remove PostgreSQL
remove_postgresql() {
    echo -e "\n${RED}WARNING: This will remove PostgreSQL and ALL databases!${NC}"
    read -p "Type 'DELETE' to confirm: " confirm

    if [ "$confirm" = "DELETE" ]; then
        log_info "Stopping PostgreSQL..."
        systemctl stop postgresql

        log_info "Removing PostgreSQL..."
        apt-get remove --purge -y postgresql postgresql-*
        rm -rf /var/lib/postgresql
        rm -rf /etc/postgresql

        log_success "PostgreSQL removed"
    else
        log_warning "Cancelled"
    fi
}

# Remove Docker
remove_docker() {
    echo -e "\n${RED}WARNING: This will remove Docker and ALL containers!${NC}"
    read -p "Type 'DELETE' to confirm: " confirm

    if [ "$confirm" = "DELETE" ]; then
        log_info "Stopping all containers..."
        docker stop $(docker ps -aq) 2>/dev/null || true

        log_info "Removing Docker..."
        apt-get remove --purge -y docker-ce docker-ce-cli containerd.io
        rm -rf /var/lib/docker

        log_success "Docker removed"
    else
        log_warning "Cancelled"
    fi
}

# Remove Nginx
remove_nginx() {
    echo -e "\n${RED}WARNING: This will remove Nginx and all configurations!${NC}"
    read -p "Type 'DELETE' to confirm: " confirm

    if [ "$confirm" = "DELETE" ]; then
        log_info "Stopping Nginx..."
        systemctl stop nginx

        log_info "Removing Nginx..."
        apt-get remove --purge -y nginx nginx-common
        rm -rf /etc/nginx

        log_success "Nginx removed"
    else
        log_warning "Cancelled"
    fi
}

# Remove monitoring
remove_monitoring() {
    echo -e "\n${RED}WARNING: This will remove monitoring stack!${NC}"
    read -p "Type 'DELETE' to confirm: " confirm

    if [ "$confirm" = "DELETE" ]; then
        log_info "Removing monitoring..."

        if [ -d "/opt/monitoring" ]; then
            cd /opt/monitoring
            docker compose down -v 2>/dev/null || true
            cd /
            rm -rf /opt/monitoring
        fi

        log_success "Monitoring removed"
    else
        log_warning "Cancelled"
    fi
}

# Restart all services
restart_all() {
    log_info "Restarting all services..."

    systemctl restart postgresql 2>/dev/null || true
    systemctl restart docker 2>/dev/null || true
    systemctl restart nginx 2>/dev/null || true

    if [ -d "/opt/telegram-bots-platform/bots" ]; then
        for bot in /opt/telegram-bots-platform/bots/*; do
            if [ -d "$bot" ]; then
                cd "$bot"
                docker compose restart 2>/dev/null || true
            fi
        done
    fi

    log_success "All services restarted"
}

# Main
main() {
    # Check if root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        echo "Use: sudo $0"
        exit 1
    fi

    # Interactive mode
    while true; do
        show_banner
        show_main_menu
    done
}

main "$@"
