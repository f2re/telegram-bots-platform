#!/bin/bash

# ========================================
# 📊 Grafana Bot Integration Script
# Автоматическая настройка мониторинга для бота
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

if [ $# -lt 2 ]; then
    echo "Usage: $0 <bot_name> <db_name>"
    exit 1
fi

BOT_NAME=$1
DB_NAME=$2
GRAFANA_DIR="/opt/monitoring/grafana/provisioning/dashboards"

# Load PostgreSQL credentials
if [ -f "/root/.platform/postgres_credentials" ]; then
    source /root/.platform/postgres_credentials
else
    log_error "PostgreSQL credentials not found!"
    exit 1
fi

log_info "Настройка Grafana мониторинга для бота: $BOT_NAME"

# Create bot-specific dashboard JSON
cat > "$GRAFANA_DIR/${BOT_NAME}_dashboard.json" << 'EOF'
{
  "dashboard": {
    "id": null,
    "uid": "BOT_UID",
    "title": "BOT_TITLE Monitoring",
    "tags": ["telegram-bot", "BOT_NAME"],
    "timezone": "browser",
    "schemaVersion": 16,
    "version": 0,
    "refresh": "30s",
    "panels": [
      {
        "id": 1,
        "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8},
        "type": "graph",
        "title": "Database Connections",
        "targets": [
          {
            "expr": "pg_stat_database_numbackends{datname=\"DB_NAME\"}",
            "legendFormat": "Active Connections",
            "refId": "A"
          }
        ],
        "yaxes": [
          {"format": "short", "label": "Connections"},
          {"format": "short"}
        ]
      },
      {
        "id": 2,
        "gridPos": {"x": 12, "y": 0, "w": 12, "h": 8},
        "type": "graph",
        "title": "Database Size",
        "targets": [
          {
            "expr": "pg_database_size_bytes{datname=\"DB_NAME\"}",
            "legendFormat": "Size (bytes)",
            "refId": "A"
          }
        ],
        "yaxes": [
          {"format": "bytes", "label": "Size"},
          {"format": "short"}
        ]
      },
      {
        "id": 3,
        "gridPos": {"x": 0, "y": 8, "w": 12, "h": 8},
        "type": "graph",
        "title": "Transactions Per Second",
        "targets": [
          {
            "expr": "rate(pg_stat_database_xact_commit{datname=\"DB_NAME\"}[5m])",
            "legendFormat": "Commits/s",
            "refId": "A"
          },
          {
            "expr": "rate(pg_stat_database_xact_rollback{datname=\"DB_NAME\"}[5m])",
            "legendFormat": "Rollbacks/s",
            "refId": "B"
          }
        ],
        "yaxes": [
          {"format": "ops", "label": "TPS"},
          {"format": "short"}
        ]
      },
      {
        "id": 4,
        "gridPos": {"x": 12, "y": 8, "w": 12, "h": 8},
        "type": "graph",
        "title": "Docker Container CPU",
        "targets": [
          {
            "expr": "rate(container_cpu_usage_seconds_total{name=~\".*BOT_NAME.*\"}[5m]) * 100",
            "legendFormat": "{{name}}",
            "refId": "A"
          }
        ],
        "yaxes": [
          {"format": "percent", "label": "CPU %"},
          {"format": "short"}
        ]
      },
      {
        "id": 5,
        "gridPos": {"x": 0, "y": 16, "w": 12, "h": 8},
        "type": "graph",
        "title": "Docker Container Memory",
        "targets": [
          {
            "expr": "container_memory_usage_bytes{name=~\".*BOT_NAME.*\"}",
            "legendFormat": "{{name}}",
            "refId": "A"
          }
        ],
        "yaxes": [
          {"format": "bytes", "label": "Memory"},
          {"format": "short"}
        ]
      },
      {
        "id": 6,
        "gridPos": {"x": 12, "y": 16, "w": 12, "h": 8},
        "type": "graph",
        "title": "Docker Container Network I/O",
        "targets": [
          {
            "expr": "rate(container_network_receive_bytes_total{name=~\".*BOT_NAME.*\"}[5m])",
            "legendFormat": "{{name}} RX",
            "refId": "A"
          },
          {
            "expr": "rate(container_network_transmit_bytes_total{name=~\".*BOT_NAME.*\"}[5m])",
            "legendFormat": "{{name}} TX",
            "refId": "B"
          }
        ],
        "yaxes": [
          {"format": "Bps", "label": "Bandwidth"},
          {"format": "short"}
        ]
      }
    ]
  },
  "overwrite": true
}
EOF

# Replace placeholders
BOT_UID="${BOT_NAME//-/_}_$(date +%s)"
sed -i "s/BOT_UID/$BOT_UID/g" "$GRAFANA_DIR/${BOT_NAME}_dashboard.json"
sed -i "s/BOT_TITLE/$BOT_NAME/g" "$GRAFANA_DIR/${BOT_NAME}_dashboard.json"
sed -i "s/BOT_NAME/$BOT_NAME/g" "$GRAFANA_DIR/${BOT_NAME}_dashboard.json"
sed -i "s/DB_NAME/$DB_NAME/g" "$GRAFANA_DIR/${BOT_NAME}_dashboard.json"

log_success "Dashboard создан: $GRAFANA_DIR/${BOT_NAME}_dashboard.json"

# Update Prometheus to include bot-specific metrics
PROMETHEUS_CONFIG="/opt/monitoring/prometheus/prometheus.yml"

if ! grep -q "job_name: '$BOT_NAME'" "$PROMETHEUS_CONFIG"; then
    cat >> "$PROMETHEUS_CONFIG" << EOF

  - job_name: '$BOT_NAME'
    static_configs:
      - targets: ['host.docker.internal:${BACKEND_PORT:-8000}']
        labels:
          bot: '$BOT_NAME'
EOF
    
    log_success "Prometheus конфигурация обновлена для $BOT_NAME"
    
    # Reload Prometheus
    docker exec prometheus kill -HUP 1 2>/dev/null || log_warning "Не удалось перезагрузить Prometheus"
fi

# Create PostgreSQL exporter for specific bot database
MONITORING_COMPOSE="/opt/monitoring/docker-compose.yml"

if [ -f "$MONITORING_COMPOSE" ]; then
    # Check if exporter already exists
    if ! grep -q "${BOT_NAME}-postgres-exporter" "$MONITORING_COMPOSE"; then
        # Add bot-specific postgres exporter
        cat >> "$MONITORING_COMPOSE" << EOF

  ${BOT_NAME}-postgres-exporter:
    image: prometheuscommunity/postgres-exporter:latest
    container_name: ${BOT_NAME}_postgres_exporter
    restart: unless-stopped
    environment:
      DATA_SOURCE_NAME: "postgresql://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@host.docker.internal:5432/${DB_NAME}?sslmode=disable"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - monitoring
EOF
        
        log_success "PostgreSQL exporter добавлен для $BOT_NAME"
    fi
fi

# Restart Grafana to load new dashboard
log_info "Перезапуск Grafana..."
docker restart grafana 2>/dev/null || log_warning "Grafana не запущен"

log_success "\n✅ Grafana настроен для бота $BOT_NAME!\n"

echo -e "${CYAN}📊 Информация:${NC}"
echo "  Dashboard: ${BOT_NAME} Monitoring"
echo "  UID: $BOT_UID"
echo "  Database: $DB_NAME"
echo "\nОткройте Grafana и найдите dashboard: $BOT_NAME"
