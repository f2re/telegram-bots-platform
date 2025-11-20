#!/bin/bash

# ========================================
# 📊 Monitoring Stack Management Script
# Manage Grafana, Prometheus, Loki monitoring
# ========================================

set -euo pipefail

# Colors
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

# Configuration
MONITORING_DIR="/opt/telegram-bots-platform/monitoring-stack"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

show_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                    ║${NC}"
    echo -e "${CYAN}║      📊  Monitoring Stack Management  📊          ║${NC}"
    echo -e "${CYAN}║                                                    ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    echo -e "${BLUE}Choose an option:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} 🚀 Deploy Monitoring Stack"
    echo -e "  ${GREEN}2)${NC} ▶️  Start Monitoring"
    echo -e "  ${GREEN}3)${NC} ⏸️  Stop Monitoring"
    echo -e "  ${GREEN}4)${NC} 🔄 Restart Monitoring"
    echo -e "  ${GREEN}5)${NC} 📊 Show Status"
    echo -e "  ${GREEN}6)${NC} 🔍 Scan & Monitor All Bots"
    echo -e "  ${GREEN}7)${NC} 📋 Show Logs"
    echo -e "  ${GREEN}8)${NC} 🔐 Show Credentials"
    echo -e "  ${GREEN}9)${NC} 🗑️  Remove Monitoring Stack"
    echo -e "  ${RED}0)${NC} 🚪 Exit"
    echo ""
}

deploy_monitoring() {
    log_step "📦 Deploying monitoring stack..."

    # Check if already deployed
    if [ -d "$MONITORING_DIR" ]; then
        log_warning "Monitoring stack already exists at $MONITORING_DIR"
        read -p "Do you want to redeploy? This will preserve your data. (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    # Copy monitoring stack from repository
    REPO_MONITORING="/home/user/telegram-bots-platform/monitoring-stack"

    if [ ! -d "$REPO_MONITORING" ]; then
        log_error "Monitoring stack source not found at $REPO_MONITORING"
        log_error "Please ensure the repository is up to date"
        return 1
    fi

    # Create target directory
    mkdir -p "$(dirname "$MONITORING_DIR")"

    # Copy monitoring stack
    log_info "Copying monitoring stack files..."
    cp -r "$REPO_MONITORING" "$MONITORING_DIR"

    # Load or create PostgreSQL credentials
    if [ -f "/root/.platform/postgres_credentials" ]; then
        source /root/.platform/postgres_credentials
    else
        log_error "PostgreSQL credentials not found!"
        log_info "Please run setup-server.sh first"
        return 1
    fi

    # Generate Grafana password if not exists
    if [ -f "/root/.platform/monitoring_credentials" ]; then
        source /root/.platform/monitoring_credentials
    else
        GRAFANA_PASSWORD=$(openssl rand -base64 16)
        mkdir -p /root/.platform
        echo "GRAFANA_PASSWORD=$GRAFANA_PASSWORD" > /root/.platform/monitoring_credentials
        chmod 600 /root/.platform/monitoring_credentials
    fi

    # Create .env file for docker-compose
    cat > "$MONITORING_DIR/.env" << EOF
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
GRAFANA_PASSWORD=${GRAFANA_PASSWORD}
EOF

    # Configure Nginx status endpoint for monitoring
    if [ ! -f "/etc/nginx/conf.d/status.conf" ]; then
        log_info "Configuring Nginx status endpoint..."
        cat > /etc/nginx/conf.d/status.conf << 'EOF'
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
        nginx -s reload 2>/dev/null || systemctl reload nginx
    fi

    # Start monitoring stack
    log_info "Starting monitoring stack..."
    cd "$MONITORING_DIR"
    docker compose up -d

    # Wait for services to be ready
    log_info "Waiting for services to start..."
    sleep 10

    # Run bot scanner
    log_step "🔍 Scanning for existing bots..."
    bash "$SCRIPT_DIR/scan-and-monitor-bots.sh" || true

    log_success "\n✅ Monitoring stack deployed successfully!"
    show_credentials
}

start_monitoring() {
    log_step "▶️  Starting monitoring stack..."

    if [ ! -d "$MONITORING_DIR" ]; then
        log_error "Monitoring stack not deployed. Please deploy first."
        return 1
    fi

    cd "$MONITORING_DIR"
    docker compose start

    log_success "Monitoring stack started"
    show_status
}

stop_monitoring() {
    log_step "⏸️  Stopping monitoring stack..."

    if [ ! -d "$MONITORING_DIR" ]; then
        log_error "Monitoring stack not deployed"
        return 1
    fi

    cd "$MONITORING_DIR"
    docker compose stop

    log_success "Monitoring stack stopped"
}

restart_monitoring() {
    log_step "🔄 Restarting monitoring stack..."

    if [ ! -d "$MONITORING_DIR" ]; then
        log_error "Monitoring stack not deployed"
        return 1
    fi

    cd "$MONITORING_DIR"
    docker compose restart

    log_success "Monitoring stack restarted"
    show_status
}

show_status() {
    log_step "📊 Monitoring Stack Status"
    echo ""

    if [ ! -d "$MONITORING_DIR" ]; then
        log_warning "Monitoring stack not deployed"
        return 0
    fi

    cd "$MONITORING_DIR"

    # Show docker compose status
    echo -e "${CYAN}═══ Services Status ═══${NC}"
    docker compose ps
    echo ""

    # Show URLs
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")

    echo -e "${CYAN}═══ Access URLs ═══${NC}"
    echo -e "${GREEN}Grafana:${NC}    http://$SERVER_IP:3000"
    echo -e "${GREEN}Prometheus:${NC} http://$SERVER_IP:9090"
    echo -e "${GREEN}Loki:${NC}       http://$SERVER_IP:3100"
    echo ""

    # Show resource usage
    echo -e "${CYAN}═══ Resource Usage ═══${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
        $(docker compose ps -q 2>/dev/null) 2>/dev/null || log_warning "No containers running"
    echo ""
}

scan_bots() {
    log_step "🔍 Scanning for bots to monitor..."

    if [ ! -f "$SCRIPT_DIR/scan-and-monitor-bots.sh" ]; then
        log_error "Bot scanner script not found"
        return 1
    fi

    bash "$SCRIPT_DIR/scan-and-monitor-bots.sh"
}

show_logs() {
    log_step "📋 Monitoring Logs"
    echo ""

    if [ ! -d "$MONITORING_DIR" ]; then
        log_error "Monitoring stack not deployed"
        return 1
    fi

    echo -e "${BLUE}Select service:${NC}"
    echo "  1) Prometheus"
    echo "  2) Grafana"
    echo "  3) Loki"
    echo "  4) Promtail"
    echo "  5) cAdvisor"
    echo "  6) All services"
    echo ""
    read -p "Choice [1-6]: " choice

    cd "$MONITORING_DIR"

    case $choice in
        1) docker compose logs -f prometheus ;;
        2) docker compose logs -f grafana ;;
        3) docker compose logs -f loki ;;
        4) docker compose logs -f promtail ;;
        5) docker compose logs -f cadvisor ;;
        6) docker compose logs -f ;;
        *) log_error "Invalid choice" ;;
    esac
}

show_credentials() {
    log_step "🔐 Monitoring Credentials"
    echo ""

    if [ -f "/root/.platform/monitoring_credentials" ]; then
        source /root/.platform/monitoring_credentials

        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")

        echo -e "${CYAN}═══ Grafana Login ═══${NC}"
        echo -e "${GREEN}URL:${NC}      http://$SERVER_IP:3000"
        echo -e "${GREEN}Username:${NC} admin"
        echo -e "${GREEN}Password:${NC} $GRAFANA_PASSWORD"
        echo ""
        echo -e "${YELLOW}💡 Credentials are stored in: /root/.platform/monitoring_credentials${NC}"
    else
        log_warning "Credentials file not found. Monitoring may not be deployed."
    fi
}

remove_monitoring() {
    log_warning "⚠️  This will remove the monitoring stack"
    log_warning "Data volumes will be preserved unless you manually remove them"
    echo ""
    read -p "Are you sure? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Cancelled"
        return
    fi

    if [ -d "$MONITORING_DIR" ]; then
        log_step "Stopping and removing containers..."
        cd "$MONITORING_DIR"
        docker compose down

        log_step "Removing monitoring directory..."
        rm -rf "$MONITORING_DIR"

        log_success "Monitoring stack removed"
        log_info "To remove data volumes, run: docker volume prune"
    else
        log_warning "Monitoring stack not found"
    fi
}

# Main menu loop
main() {
    while true; do
        show_header
        show_menu

        read -p "Enter choice [0-9]: " choice
        echo ""

        case $choice in
            1) deploy_monitoring ;;
            2) start_monitoring ;;
            3) stop_monitoring ;;
            4) restart_monitoring ;;
            5) show_status ;;
            6) scan_bots ;;
            7) show_logs ;;
            8) show_credentials ;;
            9) remove_monitoring ;;
            0)
                log_info "Goodbye!"
                exit 0
                ;;
            *)
                log_error "Invalid choice. Please try again."
                ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main menu if no arguments provided
if [ $# -eq 0 ]; then
    main
else
    # Allow running specific commands directly
    case "$1" in
        deploy) deploy_monitoring ;;
        start) start_monitoring ;;
        stop) stop_monitoring ;;
        restart) restart_monitoring ;;
        status) show_status ;;
        scan) scan_bots ;;
        logs) show_logs ;;
        credentials) show_credentials ;;
        remove) remove_monitoring ;;
        *)
            echo "Usage: $0 {deploy|start|stop|restart|status|scan|logs|credentials|remove}"
            exit 1
            ;;
    esac
fi
