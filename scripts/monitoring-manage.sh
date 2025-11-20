#!/bin/bash

# ========================================
# 📊 Скрипт Управления Системой Мониторинга
# Управление Grafana, Prometheus, Loki
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
MONITORING_DIR="/opt/telegram-bots-platform/monitoring-stack"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Проверка запуска от root
if [ "$EUID" -ne 0 ]; then
    log_error "Этот скрипт должен запускаться от root"
    exit 1
fi

show_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                    ║${NC}"
    echo -e "${CYAN}║      📊  Управление Системой Мониторинга  📊      ║${NC}"
    echo -e "${CYAN}║                                                    ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    echo -e "${BLUE}Выберите действие:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} 🚀 Развернуть систему мониторинга"
    echo -e "  ${GREEN}2)${NC} ▶️  Запустить мониторинг"
    echo -e "  ${GREEN}3)${NC} ⏸️  Остановить мониторинг"
    echo -e "  ${GREEN}4)${NC} 🔄 Перезапустить мониторинг"
    echo -e "  ${GREEN}5)${NC} 📊 Показать статус"
    echo -e "  ${GREEN}6)${NC} 🔍 Сканировать и добавить всех ботов"
    echo -e "  ${GREEN}7)${NC} 📋 Показать логи"
    echo -e "  ${GREEN}8)${NC} 🔐 Показать учетные данные"
    echo -e "  ${GREEN}9)${NC} 🗑️  Удалить систему мониторинга"
    echo -e "  ${RED}0)${NC} 🚪 Выход"
    echo ""
}

deploy_monitoring() {
    log_step "📦 Развертывание системы мониторинга..."

    # Проверка, установлена ли уже система
    if [ -d "$MONITORING_DIR" ]; then
        log_warning "Система мониторинга уже существует по адресу $MONITORING_DIR"
        read -p "Хотите переустановить? Данные будут сохранены. (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    # Поиск источника файлов мониторинга (пробуем разные локации)
    REPO_MONITORING=""

    # Пробуем относительно директории скрипта (разработка)
    if [ -d "$SCRIPT_DIR/../monitoring-stack" ]; then
        REPO_MONITORING="$(cd "$SCRIPT_DIR/../monitoring-stack" && pwd)"
    # Пробуем обычные локации репозитория
    elif [ -d "/home/user/telegram-bots-platform/monitoring-stack" ]; then
        REPO_MONITORING="/home/user/telegram-bots-platform/monitoring-stack"
    elif [ -d "/opt/telegram-bots-platform/monitoring-stack" ]; then
        REPO_MONITORING="/opt/telegram-bots-platform/monitoring-stack"
    elif [ -d "$(pwd)/monitoring-stack" ]; then
        REPO_MONITORING="$(pwd)/monitoring-stack"
    fi

    if [ -z "$REPO_MONITORING" ] || [ ! -d "$REPO_MONITORING" ]; then
        log_error "Источник системы мониторинга не найден!"
        log_error "Искали в следующих локациях:"
        log_error "  - $SCRIPT_DIR/../monitoring-stack"
        log_error "  - /home/user/telegram-bots-platform/monitoring-stack"
        log_error "  - /opt/telegram-bots-platform/monitoring-stack"
        log_error "  - $(pwd)/monitoring-stack"
        log_info "Запустите скрипт из директории репозитория или убедитесь, что файлы присутствуют"
        return 1
    fi

    log_info "Найден стек мониторинга: $REPO_MONITORING"

    # Создание целевой директории
    mkdir -p "$(dirname "$MONITORING_DIR")"

    # Копирование стека мониторинга
    log_info "Копирование файлов системы мониторинга..."
    cp -r "$REPO_MONITORING" "$MONITORING_DIR"

    # Загрузка или создание учетных данных PostgreSQL
    if [ -f "/root/.platform/postgres_credentials" ]; then
        source /root/.platform/postgres_credentials
    else
        log_error "Учетные данные PostgreSQL не найдены!"
        log_info "Пожалуйста, сначала запустите setup-server.sh"
        return 1
    fi

    # Генерация пароля Grafana, если не существует
    if [ -f "/root/.platform/monitoring_credentials" ]; then
        source /root/.platform/monitoring_credentials
    else
        GRAFANA_PASSWORD=$(openssl rand -base64 16)
        mkdir -p /root/.platform
        echo "GRAFANA_PASSWORD=$GRAFANA_PASSWORD" > /root/.platform/monitoring_credentials
        chmod 600 /root/.platform/monitoring_credentials
    fi

    # Создание .env файла для docker-compose
    cat > "$MONITORING_DIR/.env" << EOF
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
GRAFANA_PASSWORD=${GRAFANA_PASSWORD}
EOF

    # Настройка статус-страницы Nginx для мониторинга
    if [ ! -f "/etc/nginx/conf.d/status.conf" ]; then
        log_info "Настройка статус-страницы Nginx..."
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

    # Запуск стека мониторинга
    log_info "Запуск сервисов мониторинга..."
    cd "$MONITORING_DIR"
    docker compose up -d

    # Ожидание готовности сервисов
    log_info "Ожидание запуска сервисов..."
    sleep 10

    # Запуск сканера ботов
    log_step "🔍 Сканирование существующих ботов..."
    bash "$SCRIPT_DIR/scan-and-monitor-bots.sh" || true

    log_success "\n✅ Система мониторинга успешно развернута!"
    show_credentials
}

start_monitoring() {
    log_step "▶️  Запуск системы мониторинга..."

    if [ ! -d "$MONITORING_DIR" ]; then
        log_error "Система мониторинга не развернута. Сначала разверните её."
        return 1
    fi

    cd "$MONITORING_DIR"
    docker compose start

    log_success "Система мониторинга запущена"
    show_status
}

stop_monitoring() {
    log_step "⏸️  Остановка системы мониторинга..."

    if [ ! -d "$MONITORING_DIR" ]; then
        log_error "Система мониторинга не развернута"
        return 1
    fi

    cd "$MONITORING_DIR"
    docker compose stop

    log_success "Система мониторинга остановлена"
}

restart_monitoring() {
    log_step "🔄 Перезапуск системы мониторинга..."

    if [ ! -d "$MONITORING_DIR" ]; then
        log_error "Система мониторинга не развернута"
        return 1
    fi

    cd "$MONITORING_DIR"
    docker compose restart

    log_success "Система мониторинга перезапущена"
    show_status
}

show_status() {
    log_step "📊 Статус Системы Мониторинга"
    echo ""

    if [ ! -d "$MONITORING_DIR" ]; then
        log_warning "Система мониторинга не развернута"
        return 0
    fi

    cd "$MONITORING_DIR"

    # Показать статус docker compose
    echo -e "${CYAN}═══ Статус Сервисов ═══${NC}"
    docker compose ps
    echo ""

    # Показать URL-адреса
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")

    echo -e "${CYAN}═══ URL-адреса для доступа ═══${NC}"
    echo -e "${GREEN}Grafana:${NC}    http://$SERVER_IP:3000"
    echo -e "${GREEN}Prometheus:${NC} http://$SERVER_IP:9090"
    echo -e "${GREEN}Loki:${NC}       http://$SERVER_IP:3100"
    echo ""

    # Показать использование ресурсов
    echo -e "${CYAN}═══ Использование Ресурсов ═══${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
        $(docker compose ps -q 2>/dev/null) 2>/dev/null || log_warning "Контейнеры не запущены"
    echo ""
}

scan_bots() {
    log_step "🔍 Сканирование ботов для мониторинга..."

    if [ ! -f "$SCRIPT_DIR/scan-and-monitor-bots.sh" ]; then
        log_error "Скрипт сканирования ботов не найден"
        return 1
    fi

    bash "$SCRIPT_DIR/scan-and-monitor-bots.sh"
}

show_logs() {
    log_step "📋 Логи Мониторинга"
    echo ""

    if [ ! -d "$MONITORING_DIR" ]; then
        log_error "Система мониторинга не развернута"
        return 1
    fi

    echo -e "${BLUE}Выберите сервис:${NC}"
    echo "  1) Prometheus"
    echo "  2) Grafana"
    echo "  3) Loki"
    echo "  4) Promtail"
    echo "  5) cAdvisor"
    echo "  6) Все сервисы"
    echo ""
    read -p "Выбор [1-6]: " choice

    cd "$MONITORING_DIR"

    case $choice in
        1) docker compose logs -f prometheus ;;
        2) docker compose logs -f grafana ;;
        3) docker compose logs -f loki ;;
        4) docker compose logs -f promtail ;;
        5) docker compose logs -f cadvisor ;;
        6) docker compose logs -f ;;
        *) log_error "Неверный выбор" ;;
    esac
}

show_credentials() {
    log_step "🔐 Учетные Данные Мониторинга"
    echo ""

    if [ -f "/root/.platform/monitoring_credentials" ]; then
        source /root/.platform/monitoring_credentials

        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")

        echo -e "${CYAN}═══ Вход в Grafana ═══${NC}"
        echo -e "${GREEN}URL:${NC}      http://$SERVER_IP:3000"
        echo -e "${GREEN}Логин:${NC}    admin"
        echo -e "${GREEN}Пароль:${NC}   $GRAFANA_PASSWORD"
        echo ""
        echo -e "${YELLOW}💡 Учетные данные хранятся в: /root/.platform/monitoring_credentials${NC}"
        echo ""
        echo -e "${CYAN}═══ Доступные Дашборды ═══${NC}"
        echo -e "  • Обзор Системы - Мониторинг сервера (CPU, Память, Диск, Сеть)"
        echo -e "  • Обзор PostgreSQL - Производительность БД"
        echo -e "  • Обзор Ботов - Все боты одним взглядом"
        echo -e "  • Дашборд Логов - Централизованный просмотр логов"
        echo -e "  • Индивидуальные дашборды для каждого бота"
        echo ""
    else
        log_warning "Файл с учетными данными не найден. Возможно, мониторинг не развернут."
    fi
}

remove_monitoring() {
    log_warning "⚠️  Это удалит систему мониторинга"
    log_warning "Тома данных будут сохранены, если вы не удалите их вручную"
    echo ""
    read -p "Вы уверены? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Отменено"
        return
    fi

    if [ -d "$MONITORING_DIR" ]; then
        log_step "Остановка и удаление контейнеров..."
        cd "$MONITORING_DIR"
        docker compose down

        log_step "Удаление директории мониторинга..."
        rm -rf "$MONITORING_DIR"

        log_success "Система мониторинга удалена"
        log_info "Для удаления томов данных выполните: docker volume prune"
    else
        log_warning "Система мониторинга не найдена"
    fi
}

# Главный цикл меню
main() {
    while true; do
        show_header
        show_menu

        read -p "Введите выбор [0-9]: " choice
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
                log_info "До свидания!"
                exit 0
                ;;
            *)
                log_error "Неверный выбор. Пожалуйста, попробуйте снова."
                ;;
        esac

        echo ""
        read -p "Нажмите Enter для продолжения..."
    done
}

# Запуск главного меню если нет аргументов
if [ $# -eq 0 ]; then
    main
else
    # Разрешить запуск конкретных команд напрямую
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
            echo "Использование: $0 {deploy|start|stop|restart|status|scan|logs|credentials|remove}"
            exit 1
            ;;
    esac
fi
