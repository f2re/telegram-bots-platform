#!/bin/bash

# ========================================
# 🔍 Сканер Ботов и Интеграция с Мониторингом
# Автоматическое обнаружение и мониторинг всех ботов
# ========================================

set -euo pipefail

# Цвета
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

# Конфигурация
BOTS_DIR="/opt/telegram-bots-platform/bots"
MONITORING_DIR="/opt/telegram-bots-platform/monitoring-stack"
PROMETHEUS_CONFIG="$MONITORING_DIR/prometheus/prometheus.yml"
DOCKER_COMPOSE="$MONITORING_DIR/docker-compose.yml"
GRAFANA_DASHBOARDS="$MONITORING_DIR/grafana/dashboards"

# Проверка развернута ли система мониторинга
if [ ! -d "$MONITORING_DIR" ]; then
    log_error "Система мониторинга не найдена по адресу $MONITORING_DIR"
    log_info "Пожалуйста, сначала разверните систему мониторинга"
    exit 1
fi

# Проверка существует ли директория ботов
if [ ! -d "$BOTS_DIR" ]; then
    log_warning "Директория ботов не найдена по адресу $BOTS_DIR"
    log_info "Нет ботов для сканирования. Это нормально для новой установки."
    exit 0
fi

# Загрузка учетных данных PostgreSQL
if [ -f "/root/.platform/postgres_credentials" ]; then
    source /root/.platform/postgres_credentials
else
    log_error "Учетные данные PostgreSQL не найдены!"
    exit 1
fi

log_step "🔍 Сканирование ботов в $BOTS_DIR..."

# Счетчики ботов
BOT_COUNT=0
MONITORED_COUNT=0

# Удаление старых конфигураций ботов из Prometheus
if [ -f "$PROMETHEUS_CONFIG" ]; then
    # Создание резервной копии
    cp "$PROMETHEUS_CONFIG" "$PROMETHEUS_CONFIG.bak"

    # Удаление всех конфигураций ботов (все после комментария "# Bot-specific")
    sed -i '/# Bot-specific scrape configs/q' "$PROMETHEUS_CONFIG"
fi

# Перебор всех директорий ботов
for bot_dir in "$BOTS_DIR"/*; do
    if [ ! -d "$bot_dir" ]; then
        continue
    fi

    BOT_NAME=$(basename "$bot_dir")
    BOT_INFO_FILE="$bot_dir/bot_info.json"

    if [ ! -f "$BOT_INFO_FILE" ]; then
        log_warning "Пропуск $BOT_NAME: bot_info.json не найден"
        continue
    fi

    BOT_COUNT=$((BOT_COUNT + 1))
    log_info "Найден бот: $BOT_NAME"

    # Извлечение информации о боте из bot_info.json
    if command -v jq &> /dev/null; then
        DB_NAME=$(jq -r '.database.name // empty' "$BOT_INFO_FILE" 2>/dev/null || echo "${BOT_NAME}_db")
        BACKEND_PORT=$(jq -r '.backend_port // empty' "$BOT_INFO_FILE" 2>/dev/null || echo "")
        DOMAIN=$(jq -r '.domain // empty' "$BOT_INFO_FILE" 2>/dev/null || echo "")
    else
        # Запасной вариант если jq недоступен
        DB_NAME="${BOT_NAME}_db"
        BACKEND_PORT=$(grep -oP '"backend_port":\s*\K\d+' "$BOT_INFO_FILE" 2>/dev/null || echo "")
        DOMAIN=$(grep -oP '"domain":\s*"\K[^"]+' "$BOT_INFO_FILE" 2>/dev/null || echo "")
    fi

    log_info "  База данных: $DB_NAME"
    log_info "  Порт Backend: ${BACKEND_PORT:-Н/Д}"
    log_info "  Домен: ${DOMAIN:-Н/Д}"

    # Добавление конфигурации Prometheus для этого бота (если есть endpoint метрик)
    if [ -n "$BACKEND_PORT" ]; then
        cat >> "$PROMETHEUS_CONFIG" << EOF

  - job_name: '${BOT_NAME}_backend'
    static_configs:
      - targets: ['host.docker.internal:${BACKEND_PORT}']
        labels:
          bot: '$BOT_NAME'
          service: 'backend'
    scrape_interval: 30s
    metrics_path: '/metrics'
    scrape_timeout: 10s
EOF
        log_success "  Добавлена конфигурация Prometheus"
    fi

    # Создание дашборда для бота
    create_bot_dashboard "$BOT_NAME" "$DB_NAME"

    # Добавление PostgreSQL exporter для базы данных бота
    add_postgres_exporter "$BOT_NAME" "$DB_NAME"

    MONITORED_COUNT=$((MONITORED_COUNT + 1))
    log_success "✅ Мониторинг настроен для $BOT_NAME"
    echo ""
done

log_step "📊 Сводка по Мониторингу"
log_info "Всего найдено ботов: $BOT_COUNT"
log_success "Настроено мониторинга: $MONITORED_COUNT"

# Перезапуск сервисов мониторинга для применения изменений
if [ $MONITORED_COUNT -gt 0 ]; then
    log_step "🔄 Перезапуск сервисов мониторинга..."

    cd "$MONITORING_DIR"

    # Перезагрузка конфигурации Prometheus
    if docker ps --format '{{.Names}}' | grep -q '^prometheus$'; then
        docker exec prometheus kill -HUP 1 2>/dev/null && log_success "Prometheus перезагружен" || log_warning "Не удалось перезагрузить Prometheus"
    fi

    # Перезапуск docker-compose для добавления новых экспортеров
    docker compose up -d 2>/dev/null && log_success "Стек мониторинга обновлен" || log_warning "Не удалось обновить стек мониторинга"

    log_success "\n✅ Все боты теперь мониторятся!"
    echo ""
    log_info "📊 Доступ к дашбордам:"
    log_info "   • Grafana: http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-server-ip'):3000"
    log_info "   • Prometheus: http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-server-ip'):9090"
    echo ""
    log_info "🔐 Учетные данные Grafana хранятся в: /root/.platform/monitoring_credentials"
else
    log_warning "Боты для мониторинга не найдены"
fi

# Функция создания дашборда для конкретного бота
create_bot_dashboard() {
    local BOT_NAME=$1
    local DB_NAME=$2
    local DASHBOARD_FILE="$GRAFANA_DASHBOARDS/${BOT_NAME}-dashboard.json"
    local BOT_UID="${BOT_NAME//-/_}_$(date +%s)"

    cat > "$DASHBOARD_FILE" << EOF
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "thresholds"},
          "mappings": [
            {"options": {"0": {"text": "ВЫКЛ"}}, "type": "value"},
            {"options": {"1": {"text": "ВКЛ"}}, "type": "value"}
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "red", "value": null},
              {"color": "green", "value": 1}
            ]
          },
          "unit": "short"
        }
      },
      "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
      "id": 1,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "targets": [
        {
          "expr": "count(container_last_seen{name=~\".*$BOT_NAME.*\"})",
          "refId": "A"
        }
      ],
      "title": "Статус Бота",
      "type": "gauge"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "thresholds"},
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null},
              {"color": "yellow", "value": 5},
              {"color": "red", "value": 10}
            ]
          },
          "unit": "short"
        }
      },
      "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
      "id": 2,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "targets": [
        {
          "expr": "pg_stat_database_numbackends{datname=\"$DB_NAME\"}",
          "refId": "A"
        }
      ],
      "title": "Подключения к БД",
      "type": "gauge"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "thresholds"},
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null}
            ]
          },
          "unit": "bytes"
        }
      },
      "gridPos": {"h": 4, "w": 6, "x": 12, "y": 0},
      "id": 3,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "targets": [
        {
          "expr": "pg_database_size_bytes{datname=\"$DB_NAME\"}",
          "refId": "A"
        }
      ],
      "title": "Размер БД",
      "type": "gauge"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "thresholds"},
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null}
            ]
          },
          "unit": "bytes"
        }
      },
      "gridPos": {"h": 4, "w": 6, "x": 18, "y": 0},
      "id": 4,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "targets": [
        {
          "expr": "container_memory_usage_bytes{name=~\".*$BOT_NAME.*\"}",
          "refId": "A"
        }
      ],
      "title": "Использование Памяти",
      "type": "gauge"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "palette-classic"},
          "custom": {
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 20,
            "gradientMode": "opacity",
            "hideFrom": {"tooltip": false, "viz": false, "legend": false},
            "lineInterpolation": "smooth",
            "lineWidth": 2,
            "pointSize": 5,
            "scaleDistribution": {"type": "linear"},
            "showPoints": "never",
            "spanNulls": true
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null}
            ]
          },
          "unit": "percentunit"
        }
      },
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
      "id": 5,
      "options": {
        "legend": {"calcs": ["last", "max"], "displayMode": "table", "placement": "bottom"},
        "tooltip": {"mode": "multi"}
      },
      "targets": [
        {
          "expr": "rate(container_cpu_usage_seconds_total{name=~\".*$BOT_NAME.*\"}[5m])",
          "legendFormat": "{{name}}",
          "refId": "A"
        }
      ],
      "title": "Использование CPU",
      "type": "timeseries"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "palette-classic"},
          "custom": {
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 20,
            "gradientMode": "opacity",
            "hideFrom": {"tooltip": false, "viz": false, "legend": false},
            "lineInterpolation": "smooth",
            "lineWidth": 2,
            "pointSize": 5,
            "scaleDistribution": {"type": "linear"},
            "showPoints": "never",
            "spanNulls": true
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null}
            ]
          },
          "unit": "bytes"
        }
      },
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
      "id": 6,
      "options": {
        "legend": {"calcs": ["last", "max"], "displayMode": "table", "placement": "bottom"},
        "tooltip": {"mode": "multi"}
      },
      "targets": [
        {
          "expr": "container_memory_usage_bytes{name=~\".*$BOT_NAME.*\"}",
          "legendFormat": "{{name}}",
          "refId": "A"
        }
      ],
      "title": "Использование Памяти",
      "type": "timeseries"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "palette-classic"},
          "custom": {
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 20,
            "gradientMode": "none",
            "hideFrom": {"tooltip": false, "viz": false, "legend": false},
            "lineInterpolation": "smooth",
            "lineWidth": 2,
            "pointSize": 5,
            "scaleDistribution": {"type": "linear"},
            "showPoints": "never",
            "spanNulls": true
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null}
            ]
          },
          "unit": "Bps"
        }
      },
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12},
      "id": 7,
      "options": {
        "legend": {"calcs": ["last", "max"], "displayMode": "table", "placement": "bottom"},
        "tooltip": {"mode": "multi"}
      },
      "targets": [
        {
          "expr": "rate(container_network_receive_bytes_total{name=~\".*$BOT_NAME.*\"}[5m])",
          "legendFormat": "{{name}} Прием",
          "refId": "A"
        },
        {
          "expr": "rate(container_network_transmit_bytes_total{name=~\".*$BOT_NAME.*\"}[5m])",
          "legendFormat": "{{name}} Передача",
          "refId": "B"
        }
      ],
      "title": "Сетевой I/O",
      "type": "timeseries"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "palette-classic"},
          "custom": {
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 20,
            "gradientMode": "none",
            "hideFrom": {"tooltip": false, "viz": false, "legend": false},
            "lineInterpolation": "smooth",
            "lineWidth": 2,
            "pointSize": 5,
            "scaleDistribution": {"type": "linear"},
            "showPoints": "never",
            "spanNulls": true
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null}
            ]
          },
          "unit": "ops"
        }
      },
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 12},
      "id": 8,
      "options": {
        "legend": {"calcs": ["last", "max"], "displayMode": "table", "placement": "bottom"},
        "tooltip": {"mode": "multi"}
      },
      "targets": [
        {
          "expr": "rate(pg_stat_database_xact_commit{datname=\"$DB_NAME\"}[5m])",
          "legendFormat": "Коммиты",
          "refId": "A"
        },
        {
          "expr": "rate(pg_stat_database_xact_rollback{datname=\"$DB_NAME\"}[5m])",
          "legendFormat": "Откаты",
          "refId": "B"
        }
      ],
      "title": "Транзакции БД",
      "type": "timeseries"
    },
    {
      "datasource": "Loki",
      "gridPos": {"h": 10, "w": 24, "x": 0, "y": 20},
      "id": 9,
      "options": {
        "dedupStrategy": "none",
        "enableLogDetails": true,
        "prettifyLogMessage": false,
        "showCommonLabels": false,
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": false
      },
      "targets": [
        {
          "expr": "{job=\"telegram_bots\",bot_name=\"$BOT_NAME\"}",
          "refId": "A"
        }
      ],
      "title": "Последние Логи",
      "type": "logs"
    }
  ],
  "refresh": "30s",
  "schemaVersion": 36,
  "style": "dark",
  "tags": ["bot", "$BOT_NAME"],
  "templating": {"list": []},
  "time": {"from": "now-1h", "to": "now"},
  "timepicker": {},
  "timezone": "",
  "title": "Дашборд $BOT_NAME",
  "uid": "$BOT_UID",
  "version": 0,
  "weekStart": ""
}
EOF

    log_success "  Создан дашборд: $DASHBOARD_FILE"
}

# Функция добавления PostgreSQL exporter для базы данных бота
add_postgres_exporter() {
    local BOT_NAME=$1
    local DB_NAME=$2

    # Проверка существует ли exporter в docker-compose
    if grep -q "${BOT_NAME}_postgres_exporter" "$DOCKER_COMPOSE" 2>/dev/null; then
        log_info "  PostgreSQL exporter уже существует для $BOT_NAME"
        return
    fi

    # Добавление сервиса exporter
    cat >> "$DOCKER_COMPOSE" << EOF

  ${BOT_NAME}_postgres_exporter:
    image: prometheuscommunity/postgres-exporter:latest
    container_name: ${BOT_NAME}_postgres_exporter
    restart: unless-stopped
    environment:
      DATA_SOURCE_NAME: "postgresql://\${POSTGRES_USER:-postgres}:\${POSTGRES_PASSWORD}@host.docker.internal:5432/${DB_NAME}?sslmode=disable"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - monitoring
EOF

    # Добавление в конфигурацию Prometheus
    cat >> "$PROMETHEUS_CONFIG" << EOF

  - job_name: '${BOT_NAME}_postgres'
    static_configs:
      - targets: ['${BOT_NAME}_postgres_exporter:9187']
        labels:
          bot: '$BOT_NAME'
          service: 'postgres'
EOF

    log_success "  Добавлен PostgreSQL exporter для $DB_NAME"
}

log_success "\n🎉 Сканирование и настройка мониторинга завершены!"
