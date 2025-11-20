#!/bin/bash

# ========================================
# Telegram Bots Platform Manager
# Единая точка входа для управления платформой
# ========================================

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Логирование
log_info() { echo -e "${BLUE}[i]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# Красивый баннер
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
    ╔══════════════════════════════════════════════════════════╗
    ║                                                          ║
    ║       ПЛАТФОРМА TELEGRAM БОТОВ - Панель Управления      ║
    ║                                                          ║
    ║          Unified Management Console v2.0                 ║
    ║                                                          ║
    ╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

# Главное меню
show_main_menu() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${BOLD}${WHITE}ГЛАВНОЕ МЕНЮ${NC}                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "  ${YELLOW}▸ УСТАНОВКА И НАСТРОЙКА${NC}"
    echo -e "    ${WHITE}1${NC})  Полная установка сервера"
    echo -e "    ${WHITE}2${NC})  Установка отдельных компонентов"
    echo -e "    ${WHITE}3${NC})  Настройка статической сети Docker"
    echo ""

    echo -e "  ${GREEN}▸ УПРАВЛЕНИЕ БОТАМИ${NC}"
    echo -e "    ${WHITE}4${NC})  Добавить нового бота"
    echo -e "    ${WHITE}5${NC})  Управление ботами"
    echo -e "    ${WHITE}6${NC})  Удалить бота"
    echo ""

    echo -e "  ${BLUE}▸ СИСТЕМА${NC}"
    echo -e "    ${WHITE}7${NC})  Показать все учетные данные"
    echo -e "    ${WHITE}8${NC})  Исправить права доступа"
    echo -e "    ${WHITE}9${NC})  Статус системы"
    echo ""

    echo -e "  ${MAGENTA}▸ ДОПОЛНИТЕЛЬНО${NC}"
    echo -e "    ${WHITE}10${NC}) Удалить компонент"
    echo -e "    ${WHITE}11${NC}) Перезапустить все сервисы"
    echo ""

    echo -e "  ${RED}0${NC})  Выход"
    echo ""
    echo -e "${GRAY}──────────────────────────────────────────────────────────${NC}"
    read -p "$(echo -e "  ${BOLD}${WHITE}Ваш выбор${NC} [${CYAN}0-11${NC}]: ")" choice

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
        0)
            echo ""
            log_info "Выход из системы управления..."
            echo ""
            exit 0
            ;;
        *)
            log_error "Неверный выбор. Пожалуйста, введите число от 0 до 11"
            sleep 2
            ;;
    esac

    echo ""
    echo -e "${GRAY}Нажмите ${WHITE}Enter${GRAY} для продолжения...${NC}"
    read
}

# Полная установка сервера
full_server_setup() {
    echo ""
    log_info "Запуск полной установки сервера..."
    echo ""

    if [ -f "$SCRIPT_DIR/setup-server.sh" ]; then
        "$SCRIPT_DIR/setup-server.sh"
    else
        log_error "Файл setup-server.sh не найден"
    fi
}

# Меню установки компонентов
component_setup() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${BOLD}${WHITE}УСТАНОВКА КОМПОНЕНТОВ${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "  ${WHITE}1${NC})  PostgreSQL - База данных"
    echo -e "  ${WHITE}2${NC})  Docker - Контейнеризация"
    echo -e "  ${WHITE}3${NC})  Nginx - Веб-сервер"
    echo -e "  ${WHITE}4${NC})  Статическая сеть Docker (172.25.0.1)"
    echo -e "  ${WHITE}5${NC})  Мониторинг (Prometheus + Grafana)"
    echo -e "  ${WHITE}6${NC})  SSL сертификаты (Let's Encrypt)"
    echo ""
    echo -e "  ${RED}0${NC})  Назад в главное меню"
    echo ""
    echo -e "${GRAY}──────────────────────────────────────────────────────────${NC}"
    read -p "$(echo -e "  ${BOLD}${WHITE}Выберите компонент${NC} [${CYAN}0-6${NC}]: ")" comp

    case $comp in
        1) setup_postgresql ;;
        2) setup_docker ;;
        3) setup_nginx ;;
        4) setup_static_network ;;
        5) setup_monitoring ;;
        6) setup_ssl ;;
        0) return ;;
        *)
            log_error "Неверный выбор"
            sleep 2
            component_setup
            ;;
    esac
}

# Установка PostgreSQL
setup_postgresql() {
    echo ""
    log_info "Установка PostgreSQL с настройкой статической сети..."
    echo ""

    # Установка PostgreSQL
    apt-get update -qq
    apt-get install -y postgresql postgresql-contrib

    # Настройка для статической сети
    PG_VERSION=$(sudo -u postgres psql --version | grep -oP '\d+' | head -1)
    PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

    # Резервное копирование
    mkdir -p /root/.platform/backups
    cp "$PG_CONF" "/root/.platform/backups/postgresql.conf.$(date +%Y%m%d_%H%M%S)"
    cp "$PG_HBA" "/root/.platform/backups/pg_hba.conf.$(date +%Y%m%d_%H%M%S)"

    # Настройка listen_addresses
    sed -i "s/^listen_addresses/#listen_addresses/" "$PG_CONF"
    echo "listen_addresses = 'localhost,172.25.0.1'" >> "$PG_CONF"

    # Настройка pg_hba.conf
    if ! grep -q "172.25.0.0/16" "$PG_HBA"; then
        echo "host    all    all    172.25.0.0/16    scram-sha-256" >> "$PG_HBA"
    fi

    # Перезапуск PostgreSQL
    systemctl restart postgresql
    systemctl enable postgresql

    log_success "PostgreSQL настроен для статической сети (172.25.0.1)"
}

# Установка Docker
setup_docker() {
    echo ""
    log_info "Установка Docker..."
    echo ""

    # Установка Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh

    # Запуск и автозагрузка
    systemctl start docker
    systemctl enable docker

    log_success "Docker установлен и запущен"
}

# Установка Nginx
setup_nginx() {
    echo ""
    log_info "Установка Nginx..."
    echo ""

    apt-get update -qq
    apt-get install -y nginx certbot python3-certbot-nginx

    # Создание параметров SSL
    cat > /etc/nginx/snippets/ssl-params.conf << 'EOF'
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
ssl_session_timeout 10m;
ssl_session_cache shared:SSL:10m;
EOF

    systemctl start nginx
    systemctl enable nginx

    log_success "Nginx установлен и настроен"
}

# Настройка статической сети
setup_static_network() {
    if [ -f "$SCRIPT_DIR/setup-static-network.sh" ]; then
        "$SCRIPT_DIR/setup-static-network.sh"
    else
        log_error "Файл setup-static-network.sh не найден"
    fi
}

# Установка мониторинга
setup_monitoring() {
    echo ""
    log_info "Установка стека мониторинга..."
    echo ""

    if [ -f "$SCRIPT_DIR/scripts/monitoring.sh" ]; then
        "$SCRIPT_DIR/scripts/monitoring.sh"
    else
        log_warning "Скрипт мониторинга не найден"
    fi
}

# Настройка SSL
setup_ssl() {
    echo ""
    log_info "Настройка SSL - используйте при создании бота"
    log_info "SSL сертификаты автоматически получаются при добавлении бота"
    echo ""
}

# Настройка сети
network_setup() {
    if [ -f "$SCRIPT_DIR/setup-static-network.sh" ]; then
        "$SCRIPT_DIR/setup-static-network.sh"
    else
        log_error "Файл setup-static-network.sh не найден"
    fi
}

# Добавить бота
add_bot() {
    if [ -f "$SCRIPT_DIR/add-bot.sh" ]; then
        "$SCRIPT_DIR/add-bot.sh"
    else
        log_error "Файл add-bot.sh не найден"
    fi
}

# Управление ботами
manage_bots() {
    if [ -f "$SCRIPT_DIR/bot-manage.sh" ]; then
        "$SCRIPT_DIR/bot-manage.sh"
    else
        log_error "Файл bot-manage.sh не найден"
    fi
}

# Удалить бота
remove_bot() {
    if [ -f "$SCRIPT_DIR/remove-bot.sh" ]; then
        "$SCRIPT_DIR/remove-bot.sh"
    else
        log_error "Файл remove-bot.sh не найден"
    fi
}

# Показать учетные данные
show_credentials() {
    if [ -f "$SCRIPT_DIR/show-credentials.sh" ]; then
        "$SCRIPT_DIR/show-credentials.sh"
    else
        log_error "Файл show-credentials.sh не найден"
    fi
}

# Исправить права доступа
fix_permissions() {
    if [ -f "$SCRIPT_DIR/scripts/fix-permissions.sh" ]; then
        bash "$SCRIPT_DIR/scripts/fix-permissions.sh"
    else
        log_warning "Файл fix-permissions.sh не найден"
    fi
}

# Статус системы
system_status() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                  ${BOLD}${WHITE}СТАТУС СИСТЕМЫ${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    # PostgreSQL
    echo -e "  ${YELLOW}┌─ PostgreSQL${NC}"
    if systemctl is-active --quiet postgresql; then
        echo -e "  ${YELLOW}│${NC}  Статус: ${GREEN}● Запущен${NC}"
        local pg_version=$(sudo -u postgres psql --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
        [ -n "$pg_version" ] && echo -e "  ${YELLOW}│${NC}  Версия: ${GRAY}$pg_version${NC}"
        echo -e "  ${YELLOW}│${NC}  Gateway: ${CYAN}172.25.0.1:5432${NC}"
    else
        echo -e "  ${YELLOW}│${NC}  Статус: ${RED}● Остановлен${NC}"
    fi
    echo -e "  ${YELLOW}└─${NC}"

    # Docker
    echo ""
    echo -e "  ${YELLOW}┌─ Docker${NC}"
    if systemctl is-active --quiet docker; then
        echo -e "  ${YELLOW}│${NC}  Статус: ${GREEN}● Запущен${NC}"
        local container_count=$(docker ps -q 2>/dev/null | wc -l)
        echo -e "  ${YELLOW}│${NC}  Контейнеров: ${CYAN}$container_count${NC}"

        if [ $container_count -gt 0 ]; then
            echo -e "  ${YELLOW}│${NC}"
            docker ps --format "  ${YELLOW}│${NC}    ${GREEN}▪${NC} {{.Names}} ${GRAY}({{.Status}})${NC}" 2>/dev/null | head -5
        fi
    else
        echo -e "  ${YELLOW}│${NC}  Статус: ${RED}● Остановлен${NC}"
    fi
    echo -e "  ${YELLOW}└─${NC}"

    # Nginx
    echo ""
    echo -e "  ${YELLOW}┌─ Nginx${NC}"
    if systemctl is-active --quiet nginx; then
        echo -e "  ${YELLOW}│${NC}  Статус: ${GREEN}● Запущен${NC}"
        local nginx_version=$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+')
        [ -n "$nginx_version" ] && echo -e "  ${YELLOW}│${NC}  Версия: ${GRAY}$nginx_version${NC}"
    else
        echo -e "  ${YELLOW}│${NC}  Статус: ${RED}● Остановлен${NC}"
    fi
    echo -e "  ${YELLOW}└─${NC}"

    # Docker Networks
    echo ""
    echo -e "  ${YELLOW}┌─ Docker Networks${NC}"
    if command -v docker &> /dev/null; then
        if docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "bots_shared_network"; then
            echo -e "  ${YELLOW}│${NC}  ${GREEN}▪${NC} bots_shared_network ${CYAN}(172.25.0.0/16)${NC}"
            local gateway=$(docker network inspect bots_shared_network --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null)
            [ -n "$gateway" ] && echo -e "  ${YELLOW}│${NC}    Gateway: ${CYAN}$gateway${NC}"
        else
            echo -e "  ${YELLOW}│${NC}  ${RED}✗${NC} Статическая сеть не найдена"
        fi
    fi
    echo -e "  ${YELLOW}└─${NC}"

    # Боты
    echo ""
    echo -e "  ${YELLOW}┌─ Telegram Боты${NC}"
    if [ -d "/opt/telegram-bots-platform/bots" ]; then
        local bot_count=0
        local running_count=0

        for bot in /opt/telegram-bots-platform/bots/*; do
            if [ -d "$bot" ]; then
                bot_count=$((bot_count + 1))
                bot_name=$(basename "$bot")
                cd "$bot"
                if docker compose ps --format json 2>/dev/null | grep -q "running"; then
                    echo -e "  ${YELLOW}│${NC}  ${GREEN}● $bot_name${NC}"
                    running_count=$((running_count + 1))
                else
                    echo -e "  ${YELLOW}│${NC}  ${RED}● $bot_name${NC}"
                fi
            fi
        done

        if [ $bot_count -eq 0 ]; then
            echo -e "  ${YELLOW}│${NC}  ${GRAY}Ботов не найдено${NC}"
        else
            echo -e "  ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}│${NC}  Всего: ${CYAN}$bot_count${NC} | Запущено: ${GREEN}$running_count${NC}"
        fi
    else
        echo -e "  ${YELLOW}│${NC}  ${GRAY}Директория ботов не найдена${NC}"
    fi
    echo -e "  ${YELLOW}└─${NC}"

    echo ""
}

# Меню удаления компонентов
remove_component_menu() {
    clear
    echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}              ${BOLD}${WHITE}УДАЛЕНИЕ КОМПОНЕНТОВ${NC}                     ${RED}║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${YELLOW}  ⚠  ВНИМАНИЕ: Это удалит компоненты из системы!${NC}\n"

    echo -e "  ${WHITE}1${NC})  Удалить PostgreSQL (+ все базы данных)"
    echo -e "  ${WHITE}2${NC})  Удалить Docker (+ все контейнеры)"
    echo -e "  ${WHITE}3${NC})  Удалить Nginx (+ все конфигурации)"
    echo -e "  ${WHITE}4${NC})  Удалить мониторинг"
    echo ""
    echo -e "  ${GREEN}0${NC})  Назад в главное меню"
    echo ""
    echo -e "${GRAY}──────────────────────────────────────────────────────────${NC}"
    read -p "$(echo -e "  ${BOLD}${WHITE}Выберите компонент${NC} [${CYAN}0-4${NC}]: ")" comp

    case $comp in
        1) remove_postgresql ;;
        2) remove_docker ;;
        3) remove_nginx ;;
        4) remove_monitoring ;;
        0) return ;;
        *)
            log_error "Неверный выбор"
            sleep 2
            remove_component_menu
            ;;
    esac
}

# Удалить PostgreSQL
remove_postgresql() {
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ВНИМАНИЕ! Это удалит PostgreSQL и ВСЕ базы данных!    ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "$(echo -e "Введите ${RED}DELETE${NC} для подтверждения: ")" confirm

    if [ "$confirm" = "DELETE" ]; then
        log_info "Остановка PostgreSQL..."
        systemctl stop postgresql

        log_info "Удаление PostgreSQL..."
        apt-get remove --purge -y postgresql postgresql-* 2>/dev/null
        rm -rf /var/lib/postgresql
        rm -rf /etc/postgresql

        log_success "PostgreSQL удален"
    else
        log_warning "Отменено"
    fi
}

# Удалить Docker
remove_docker() {
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ВНИМАНИЕ! Это удалит Docker и ВСЕ контейнеры!         ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "$(echo -e "Введите ${RED}DELETE${NC} для подтверждения: ")" confirm

    if [ "$confirm" = "DELETE" ]; then
        log_info "Остановка всех контейнеров..."
        docker stop $(docker ps -aq) 2>/dev/null || true

        log_info "Удаление Docker..."
        apt-get remove --purge -y docker-ce docker-ce-cli containerd.io 2>/dev/null
        rm -rf /var/lib/docker

        log_success "Docker удален"
    else
        log_warning "Отменено"
    fi
}

# Удалить Nginx
remove_nginx() {
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ВНИМАНИЕ! Это удалит Nginx и все конфигурации!        ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "$(echo -e "Введите ${RED}DELETE${NC} для подтверждения: ")" confirm

    if [ "$confirm" = "DELETE" ]; then
        log_info "Остановка Nginx..."
        systemctl stop nginx

        log_info "Удаление Nginx..."
        apt-get remove --purge -y nginx nginx-common 2>/dev/null
        rm -rf /etc/nginx

        log_success "Nginx удален"
    else
        log_warning "Отменено"
    fi
}

# Удалить мониторинг
remove_monitoring() {
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ВНИМАНИЕ! Это удалит весь стек мониторинга!           ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "$(echo -e "Введите ${RED}DELETE${NC} для подтверждения: ")" confirm

    if [ "$confirm" = "DELETE" ]; then
        log_info "Удаление мониторинга..."

        if [ -d "/opt/monitoring" ]; then
            cd /opt/monitoring
            docker compose down -v 2>/dev/null || true
            cd /
            rm -rf /opt/monitoring
        fi

        log_success "Мониторинг удален"
    else
        log_warning "Отменено"
    fi
}

# Перезапустить все сервисы
restart_all() {
    echo ""
    log_info "Перезапуск всех сервисов..."
    echo ""

    # Системные сервисы
    echo -e "  ${BLUE}▸${NC} PostgreSQL..."
    systemctl restart postgresql 2>/dev/null && log_success "PostgreSQL перезапущен" || log_warning "PostgreSQL не найден"

    echo -e "  ${BLUE}▸${NC} Docker..."
    systemctl restart docker 2>/dev/null && log_success "Docker перезапущен" || log_warning "Docker не найден"

    echo -e "  ${BLUE}▸${NC} Nginx..."
    systemctl restart nginx 2>/dev/null && log_success "Nginx перезапущен" || log_warning "Nginx не найден"

    # Боты
    echo ""
    if [ -d "/opt/telegram-bots-platform/bots" ]; then
        log_info "Перезапуск ботов..."
        for bot in /opt/telegram-bots-platform/bots/*; do
            if [ -d "$bot" ]; then
                bot_name=$(basename "$bot")
                echo -e "  ${BLUE}▸${NC} $bot_name..."
                cd "$bot"
                docker compose restart 2>/dev/null && echo -e "    ${GREEN}✓${NC} Перезапущен" || echo -e "    ${RED}✗${NC} Ошибка"
            fi
        done
    fi

    echo ""
    log_success "Все сервисы перезапущены"
    echo ""
}

# Главная функция
main() {
    # Проверка root
    if [[ $EUID -ne 0 ]]; then
        clear
        echo ""
        log_error "Этот скрипт должен запускаться от root"
        echo ""
        echo -e "  Используйте: ${CYAN}sudo $0${NC}"
        echo ""
        exit 1
    fi

    # Интерактивный режим
    while true; do
        show_banner
        show_main_menu
    done
}

main "$@"
