#!/bin/bash

# ========================================
# Fix UFW Rules for Docker Network
# Ensures Docker subnet can access PostgreSQL
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

# Docker network configuration
DOCKER_SUBNET="172.25.0.0/16"
DOCKER_GATEWAY="172.25.0.1"

echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║          Fix UFW Rules for Docker Network                 ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    echo -e "  ${YELLOW}Use: sudo $0${NC}\n"
    exit 1
fi

# Check if UFW is installed
if ! command -v ufw &> /dev/null; then
    log_error "UFW is not installed"
    exit 1
fi

# Check UFW status
log_info "Checking UFW status..."
UFW_STATUS=$(ufw status | head -1)
echo "  $UFW_STATUS"

if ! echo "$UFW_STATUS" | grep -q "Status: active"; then
    log_warning "UFW is not active"
    read -p "$(echo -e ${YELLOW}Do you want to enable UFW? [y/N]: ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Enabling UFW..."
        ufw --force enable
        log_success "UFW enabled"
    else
        log_warning "UFW not enabled, rules will be added but not active"
    fi
fi

echo ""
log_info "Checking existing UFW rules for Docker subnet..."

# Check if rules already exist
DOCKER_RULE_EXISTS=false
POSTGRES_RULE_EXISTS=false

if ufw status numbered | grep -q "172.25.0.0/16"; then
    log_info "Found existing rules for Docker subnet:"
    ufw status numbered | grep "172.25.0.0/16"
    echo ""

    if ufw status numbered | grep "172.25.0.0/16" | grep -q "5432"; then
        POSTGRES_RULE_EXISTS=true
        log_success "PostgreSQL rule exists"
    fi

    if ufw status numbered | grep "172.25.0.0/16" | grep -q "ALLOW.*172.25.0.0/16"; then
        DOCKER_RULE_EXISTS=true
        log_success "Docker subnet rule exists"
    fi
else
    log_warning "No rules found for Docker subnet"
fi

echo ""
log_info "Adding/updating UFW rules..."

# Add rule for PostgreSQL access from Docker subnet
if [ "$POSTGRES_RULE_EXISTS" = false ]; then
    log_info "Adding PostgreSQL rule (172.25.0.0/16 -> port 5432)..."
    ufw allow from 172.25.0.0/16 to any port 5432 comment 'PostgreSQL Docker'
    log_success "PostgreSQL rule added"
else
    log_info "PostgreSQL rule already exists, skipping"
fi

# Add rule for Docker subnet (allow all traffic from containers)
if [ "$DOCKER_RULE_EXISTS" = false ]; then
    log_info "Adding Docker subnet rule (172.25.0.0/16 -> any)..."
    ufw allow from 172.25.0.0/16 comment 'Docker bots_shared_network'
    log_success "Docker subnet rule added"
else
    log_info "Docker subnet rule already exists, skipping"
fi

# Reload UFW
log_info "Reloading UFW..."
ufw reload

echo ""
log_success "UFW configuration complete!"
echo ""

# Show final UFW status
log_info "Current UFW rules for Docker:"
echo ""
ufw status numbered | grep -E "(172.25.0.0/16|5432)" || echo "  No Docker-related rules found"

echo ""
log_info "Full UFW status:"
ufw status verbose

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Docker containers can now access PostgreSQL at 172.25.0.1:5432${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
