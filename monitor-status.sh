#!/bin/bash

# ========================================
# 📊 Monitor Status Script
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

# Clear screen
clear

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║         📊 TELEGRAM BOTS PLATFORM STATUS 📊             ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# System resources
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🖥️  System Resources${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# CPU
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
echo -e "  CPU Usage:    ${GREEN}${CPU_USAGE}%${NC}"

# Memory
MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.1f", $3/$2 * 100}')
echo -e "  Memory:       ${GREEN}${MEM_USED}${NC} / ${MEM_TOTAL} (${MEM_PERCENT}%)"

# Disk
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
echo -e "  Disk Usage:   ${GREEN}${DISK_USED}${NC} / ${DISK_TOTAL} (${DISK_USAGE}%)"

# Uptime
UPTIME=$(uptime -p | sed 's/up //')
echo -e "  Uptime:       ${GREEN}${UPTIME}${NC}\n"

# PostgreSQL
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🗄️  PostgreSQL Status${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if systemctl is-active --quiet postgresql; then
    echo -e "  Status:       ${GREEN}● Running${NC}"
    
    DB_COUNT=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_database WHERE datistemplate = false;" | xargs)
    echo -e "  Databases:    ${GREEN}${DB_COUNT}${NC}"
    
    CONN_COUNT=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_activity;" | xargs)
    echo -e "  Connections:  ${GREEN}${CONN_COUNT}${NC}"
else
    echo -e "  Status:       ${RED}● Stopped${NC}"
fi
echo ""

# Docker
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🐳 Docker Status${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if systemctl is-active --quiet docker; then
    echo -e "  Status:       ${GREEN}● Running${NC}"
    
    CONTAINER_COUNT=$(docker ps -q | wc -l)
    echo -e "  Containers:   ${GREEN}${CONTAINER_COUNT} running${NC}"
    
    IMAGE_COUNT=$(docker images -q | wc -l)
    echo -e "  Images:       ${GREEN}${IMAGE_COUNT}${NC}"
else
    echo -e "  Status:       ${RED}● Stopped${NC}"
fi
echo ""

# Nginx
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🌐 Nginx Status${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if systemctl is-active --quiet nginx; then
    echo -e "  Status:       ${GREEN}● Running${NC}"
    
    SITE_COUNT=$(ls -1 /etc/nginx/sites-enabled/ | wc -l)
    echo -e "  Active Sites: ${GREEN}${SITE_COUNT}${NC}"
else
    echo -e "  Status:       ${RED}● Stopped${NC}"
fi
echo ""

# Bots
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🤖 Telegram Bots${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if [ -d "$BOTS_DIR" ] && [ "$(ls -A $BOTS_DIR 2>/dev/null)" ]; then
    printf "  %-20s %-25s %-15s %s\n" "NAME" "DOMAIN" "STATUS" "CONTAINERS"
    echo -e "  ${MAGENTA}$(printf '%.0s─' {1..75})${NC}"
    
    for bot_dir in "$BOTS_DIR"/*; do
        if [ -d "$bot_dir" ]; then
            BOT_NAME=$(basename "$bot_dir")
            
            # Load bot info
            if [ -f "$bot_dir/bot_info.json" ]; then
                BOT_DOMAIN=$(jq -r '.domain' "$bot_dir/bot_info.json" 2>/dev/null || echo "N/A")
            else
                BOT_DOMAIN="N/A"
            fi
            
            # Check container status
            cd "$bot_dir"
            CONTAINER_STATUS=$(docker compose ps -q 2>/dev/null | wc -l)
            RUNNING_CONTAINERS=$(docker compose ps --filter "status=running" -q 2>/dev/null | wc -l)
            
            if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
                STATUS="${GREEN}● Running${NC}"
            else
                STATUS="${RED}● Stopped${NC}"
            fi
            
            printf "  %-20s %-25s %-24s %s/%s\n" \
                "$BOT_NAME" \
                "$BOT_DOMAIN" \
                "$(echo -e $STATUS)" \
                "$RUNNING_CONTAINERS" \
                "$CONTAINER_STATUS"
        fi
    done
else
    echo -e "  ${YELLOW}No bots configured${NC}"
fi
echo ""

# Monitoring
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📊 Monitoring Services${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Grafana
if docker ps --filter "name=grafana" --filter "status=running" -q | grep -q .; then
    GRAFANA_PORT=$(docker port grafana 3000 2>/dev/null | cut -d':' -f2)
    echo -e "  Grafana:      ${GREEN}● Running${NC} - http://$(curl -s ifconfig.me):${GRAFANA_PORT}"
else
    echo -e "  Grafana:      ${RED}● Stopped${NC}"
fi

# Prometheus
if docker ps --filter "name=prometheus" --filter "status=running" -q | grep -q .; then
    echo -e "  Prometheus:   ${GREEN}● Running${NC}"
else
    echo -e "  Prometheus:   ${RED}● Stopped${NC}"
fi

echo ""

# Quick actions
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}⚡ Quick Actions${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
echo -e "  ${GREEN}bot-add${NC}         - Add new bot"
echo -e "  ${GREEN}bot-remove${NC}      - Remove bot"
echo -e "  ${GREEN}bot-status${NC}      - This status page"
echo -e "  ${GREEN}dps${NC}             - List all containers"
echo ""