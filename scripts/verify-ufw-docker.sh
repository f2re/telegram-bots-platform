#!/bin/bash

# ========================================
# Verify UFW + Docker Configuration
# Tests that UFW rules are properly configured
# ========================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[i]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

ERRORS=0
WARNINGS=0

echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║       Verify UFW + Docker Configuration                   ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Test 1: Check if UFW is installed
echo -e "${CYAN}━━━ Test 1: UFW Installation ━━━${NC}"
if command -v ufw &> /dev/null; then
    log_success "UFW is installed"
else
    log_error "UFW is NOT installed"
    ((ERRORS++))
fi
echo ""

# Test 2: Check UFW status
echo -e "${CYAN}━━━ Test 2: UFW Status ━━━${NC}"
if ufw status | grep -q "Status: active"; then
    log_success "UFW is active"
else
    log_warning "UFW is NOT active"
    ((WARNINGS++))
fi
echo ""

# Test 3: Check Docker network exists
echo -e "${CYAN}━━━ Test 3: Docker Network ━━━${NC}"
if docker network ls --format '{{.Name}}' | grep -q "^bots_shared_network$"; then
    log_success "bots_shared_network exists"

    # Verify subnet and gateway
    SUBNET=$(docker network inspect bots_shared_network --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null)
    GATEWAY=$(docker network inspect bots_shared_network --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null)

    if [ "$SUBNET" = "172.25.0.0/16" ]; then
        log_success "Correct subnet: $SUBNET"
    else
        log_error "Wrong subnet: $SUBNET (expected 172.25.0.0/16)"
        ((ERRORS++))
    fi

    if [ "$GATEWAY" = "172.25.0.1" ]; then
        log_success "Correct gateway: $GATEWAY"
    else
        log_error "Wrong gateway: $GATEWAY (expected 172.25.0.1)"
        ((ERRORS++))
    fi
else
    log_error "bots_shared_network does NOT exist"
    log_info "Run: sudo ./setup-static-network.sh"
    ((ERRORS++))
fi
echo ""

# Test 4: Check UFW rules for Docker subnet
echo -e "${CYAN}━━━ Test 4: UFW Rules for Docker Subnet ━━━${NC}"

# Check PostgreSQL rule
if ufw status | grep -q "172.25.0.0/16.*5432"; then
    log_success "PostgreSQL rule exists (172.25.0.0/16 -> 5432)"
else
    log_error "PostgreSQL rule MISSING (172.25.0.0/16 -> 5432)"
    log_info "Add with: sudo ufw allow from 172.25.0.0/16 to any port 5432"
    ((ERRORS++))
fi

# Check Docker subnet rule
if ufw status | grep "172.25.0.0/16" | grep -v "5432" | grep -q "ALLOW"; then
    log_success "Docker subnet rule exists (172.25.0.0/16 -> any)"
else
    log_error "Docker subnet rule MISSING (172.25.0.0/16 -> any)"
    log_info "Add with: sudo ufw allow from 172.25.0.0/16"
    ((ERRORS++))
fi
echo ""

# Test 5: Check PostgreSQL configuration
echo -e "${CYAN}━━━ Test 5: PostgreSQL Configuration ━━━${NC}"

if systemctl is-active --quiet postgresql; then
    log_success "PostgreSQL is running"

    # Find PostgreSQL version
    if command -v psql &> /dev/null; then
        PG_VERSION=$(psql --version | grep -oP '\d+' | head -1)

        # Check if listening on Docker gateway
        if [ -f "/etc/postgresql/$PG_VERSION/main/postgresql.conf" ]; then
            if grep -q "listen_addresses.*172.25.0.1" "/etc/postgresql/$PG_VERSION/main/postgresql.conf"; then
                log_success "PostgreSQL listening on 172.25.0.1"
            else
                log_warning "PostgreSQL may not be listening on 172.25.0.1"
                log_info "Check: /etc/postgresql/$PG_VERSION/main/postgresql.conf"
                ((WARNINGS++))
            fi

            # Check pg_hba.conf
            if grep -q "172.25.0.0/16" "/etc/postgresql/$PG_VERSION/main/pg_hba.conf"; then
                log_success "pg_hba.conf allows Docker subnet"
            else
                log_warning "pg_hba.conf may not allow Docker subnet"
                log_info "Check: /etc/postgresql/$PG_VERSION/main/pg_hba.conf"
                ((WARNINGS++))
            fi
        fi
    fi
else
    log_warning "PostgreSQL is NOT running"
    ((WARNINGS++))
fi
echo ""

# Test 6: Show current UFW rules
echo -e "${CYAN}━━━ Test 6: Current UFW Rules for Docker ━━━${NC}"
echo "Rules containing 172.25:"
ufw status numbered | grep "172.25" || echo "  No rules found for Docker subnet"
echo ""

# Summary
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                      SUMMARY                               ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! Configuration is correct.${NC}"
    echo ""
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Tests passed with $WARNINGS warning(s)${NC}"
    echo ""
    echo "Configuration is mostly correct but may need attention."
    echo ""
    exit 0
else
    echo -e "${RED}✗ Found $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo -e "${YELLOW}To fix UFW rules, run:${NC}"
    echo -e "  ${GREEN}sudo ./scripts/fix-ufw-docker.sh${NC}"
    echo ""
    echo -e "${YELLOW}For more information, see:${NC}"
    echo -e "  ${GREEN}docs/UFW-DOCKER-FIREWALL.md${NC}"
    echo ""
    exit 1
fi
