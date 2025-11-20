#!/bin/bash

# ========================================
# 🔐 Platform Credentials & Connection Info
# Shows all credentials and connection details
# ========================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# Paths
PLATFORM_DIR="/opt/telegram-bots-platform"
BOTS_DIR="$PLATFORM_DIR/bots"
MONITORING_DIR="/opt/monitoring"
CREDS_FILE="/root/.platform/postgres_credentials"
NGINX_DIR="/etc/nginx"
LETSENCRYPT_DIR="/etc/letsencrypt"

# Logging
log_info() { echo -e "${BLUE}ℹ️  ${NC}$1"; }
log_success() { echo -e "${GREEN}✅ ${NC}$1"; }
log_warning() { echo -e "${YELLOW}⚠️  ${NC}$1"; }
log_error() { echo -e "${RED}❌ ${NC}$1"; }

# Banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   🔐 ПЛАТФОРМА: УЧЕТНЫЕ ДАННЫЕ И ПОДКЛЮЧЕНИЯ 🔐              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

# Print section header
print_section() {
    local title=$1
    echo -e "\n${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC} ${WHITE}${title}${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

# Print key-value pair
print_kv() {
    local key=$1
    local value=$2
    local color=${3:-$GREEN}
    printf "  ${YELLOW}%-25s${NC} ${color}%s${NC}\n" "$key:" "$value"
}

# Print copyable command
print_cmd() {
    local label=$1
    local cmd=$2
    echo -e "  ${GRAY}# $label${NC}"
    echo -e "  ${GREEN}$cmd${NC}\n"
}

# Mask sensitive data
mask_secret() {
    local secret=$1
    local visible=${2:-4}
    if [ ${#secret} -gt $((visible * 2)) ]; then
        echo "${secret:0:$visible}...${secret: -$visible}"
    else
        echo "****"
    fi
}

# Show PostgreSQL credentials
show_postgres() {
    print_section "📊 PostgreSQL Database"

    if [ -f "$CREDS_FILE" ]; then
        source "$CREDS_FILE"

        print_kv "Host" "localhost (внутри сервера)"
        print_kv "Port" "${POSTGRES_PORT:-5432}"
        print_kv "Main Admin User" "${POSTGRES_ADMIN_USER:-postgres}"
        print_kv "Admin Password" "$(mask_secret ${POSTGRES_ADMIN_PASSWORD:-})" "$YELLOW"

        echo -e "\n  ${CYAN}📝 Подключение через psql:${NC}"
        print_cmd "Войти как администратор" "sudo -u postgres psql"
        print_cmd "Список всех БД" "sudo -u postgres psql -l"
        print_cmd "Подключиться к БД" "sudo -u postgres psql -d DATABASE_NAME"

        print_kv "Credentials File" "$CREDS_FILE" "$GRAY"
    else
        log_warning "Файл с учетными данными PostgreSQL не найден: $CREDS_FILE"
    fi
}

# Show bot databases
show_bot_databases() {
    print_section "🤖 Базы Данных Ботов"

    if [ ! -d "$BOTS_DIR" ] || [ -z "$(ls -A $BOTS_DIR 2>/dev/null)" ]; then
        log_warning "Боты не найдены"
        return
    fi

    local found_bots=false
    for bot_dir in "$BOTS_DIR"/*; do
        if [ -d "$bot_dir" ] && [ -f "$bot_dir/.env" ]; then
            found_bots=true
            local bot_name=$(basename "$bot_dir")

            echo -e "  ${CYAN}┌─ ${WHITE}$bot_name${NC}"

            # Read .env file
            local db_name=$(grep "^POSTGRES_DB=" "$bot_dir/.env" 2>/dev/null | cut -d'=' -f2)
            local db_user=$(grep "^POSTGRES_USER=" "$bot_dir/.env" 2>/dev/null | cut -d'=' -f2)
            local db_pass=$(grep "^POSTGRES_PASSWORD=" "$bot_dir/.env" 2>/dev/null | cut -d'=' -f2)
            local db_url=$(grep "^DATABASE_URL=" "$bot_dir/.env" 2>/dev/null | cut -d'=' -f2)

            [ -n "$db_name" ] && echo -e "  ${CYAN}│${NC}   Database: ${GREEN}$db_name${NC}"
            [ -n "$db_user" ] && echo -e "  ${CYAN}│${NC}   User: ${GREEN}$db_user${NC}"
            [ -n "$db_pass" ] && echo -e "  ${CYAN}│${NC}   Password: ${YELLOW}$(mask_secret "$db_pass")${NC}"
            [ -n "$db_url" ] && echo -e "  ${CYAN}│${NC}   URL: ${GRAY}$db_url${NC}"

            # Connection command
            if [ -n "$db_name" ]; then
                echo -e "  ${CYAN}│${NC}   ${GRAY}# Подключение:${NC}"
                echo -e "  ${CYAN}│${NC}   ${GREEN}sudo -u postgres psql -d $db_name${NC}"
            fi

            # .env file path
            echo -e "  ${CYAN}│${NC}   ${GRAY}Config: $bot_dir/.env${NC}"
            echo -e "  ${CYAN}└─${NC}\n"
        fi
    done

    if [ "$found_bots" = false ]; then
        log_warning "Базы данных ботов не найдены"
    fi
}

# Show Grafana
show_grafana() {
    print_section "📈 Grafana Monitoring"

    local grafana_dir="$MONITORING_DIR"
    local grafana_env="$grafana_dir/.env"

    if [ -f "$grafana_env" ]; then
        local grafana_user=$(grep "^GF_SECURITY_ADMIN_USER=" "$grafana_env" 2>/dev/null | cut -d'=' -f2)
        local grafana_pass=$(grep "^GF_SECURITY_ADMIN_PASSWORD=" "$grafana_env" 2>/dev/null | cut -d'=' -f2)
        local grafana_port=$(grep "^GRAFANA_PORT=" "$grafana_env" 2>/dev/null | cut -d'=' -f2)
        grafana_port=${grafana_port:-3000}

        # Get server IP
        local server_ip=$(hostname -I | awk '{print $1}')

        print_kv "URL (Local)" "http://localhost:$grafana_port"
        print_kv "URL (External)" "http://$server_ip:$grafana_port"
        print_kv "Username" "${grafana_user:-admin}"
        print_kv "Password" "$(mask_secret ${grafana_pass:-admin})" "$YELLOW"

        echo -e "\n  ${CYAN}📝 Доступ:${NC}"
        echo -e "  ${GREEN}Откройте браузер: http://$server_ip:$grafana_port${NC}"
        echo -e "  ${GRAY}Логин: ${grafana_user:-admin}${NC}"
        echo -e "  ${GRAY}Пароль: [см. выше]${NC}\n"

        print_kv "Config File" "$grafana_env" "$GRAY"
        print_kv "Data Dir" "$grafana_dir/grafana_data" "$GRAY"
    else
        log_warning "Grafana не установлена или файл конфигурации не найден"
        echo -e "  ${GRAY}Установите мониторинг: ./scripts/monitoring.sh${NC}\n"
    fi
}

# Show Prometheus
show_prometheus() {
    print_section "🔥 Prometheus Monitoring"

    local prometheus_config="$MONITORING_DIR/prometheus/prometheus.yml"
    local prometheus_port=9090

    if [ -f "$prometheus_config" ]; then
        local server_ip=$(hostname -I | awk '{print $1}')

        print_kv "URL (Local)" "http://localhost:$prometheus_port"
        print_kv "URL (External)" "http://$server_ip:$prometheus_port"
        print_kv "Config File" "$prometheus_config" "$GRAY"
        print_kv "Data Dir" "$MONITORING_DIR/prometheus_data" "$GRAY"

        echo -e "\n  ${CYAN}📝 Targets:${NC}"
        if command -v yq &> /dev/null; then
            yq eval '.scrape_configs[].job_name' "$prometheus_config" 2>/dev/null | while read job; do
                echo -e "  ${GREEN}• $job${NC}"
            done
        else
            grep "job_name:" "$prometheus_config" | sed "s/.*job_name: *'\(.*\)'.*/  ${GREEN}• \1${NC}/"
        fi
        echo ""
    else
        log_warning "Prometheus не установлен"
    fi
}

# Show Redis
show_redis() {
    print_section "🔴 Redis Cache"

    if docker ps --format '{{.Names}}' | grep -q redis; then
        local server_ip=$(hostname -I | awk '{print $1}')

        print_kv "Host (Docker)" "redis"
        print_kv "Host (Local)" "localhost"
        print_kv "Port" "6379"
        print_kv "URL Format" "redis://redis:6379/0"

        echo -e "\n  ${CYAN}📝 Подключение:${NC}"
        print_cmd "Redis CLI" "docker exec -it redis redis-cli"
        print_cmd "Мониторинг" "docker exec -it redis redis-cli MONITOR"
        print_cmd "Информация" "docker exec -it redis redis-cli INFO"
    else
        log_warning "Redis контейнер не запущен"
    fi
}

# Show Nginx
show_nginx() {
    print_section "🌐 Nginx Web Server"

    print_kv "Config Dir" "$NGINX_DIR" "$GRAY"
    print_kv "Sites Available" "$NGINX_DIR/sites-available" "$GRAY"
    print_kv "Sites Enabled" "$NGINX_DIR/sites-enabled" "$GRAY"
    print_kv "Logs" "/var/log/nginx/" "$GRAY"

    echo -e "\n  ${CYAN}📝 Конфигурации ботов:${NC}"
    if [ -d "$NGINX_DIR/sites-available" ]; then
        for conf in "$NGINX_DIR/sites-available"/*.conf; do
            if [ -f "$conf" ]; then
                local conf_name=$(basename "$conf" .conf)
                local domain=$(grep "server_name" "$conf" | head -1 | awk '{print $2}' | tr -d ';')
                if [ -L "$NGINX_DIR/sites-enabled/$conf_name.conf" ]; then
                    echo -e "  ${GREEN}✓${NC} $conf_name ${GRAY}→ $domain${NC}"
                else
                    echo -e "  ${RED}✗${NC} $conf_name ${GRAY}(disabled)${NC}"
                fi
            fi
        done
    fi

    echo -e "\n  ${CYAN}📝 Команды:${NC}"
    print_cmd "Проверка конфигурации" "sudo nginx -t"
    print_cmd "Перезагрузка" "sudo nginx -s reload"
    print_cmd "Статус" "sudo systemctl status nginx"
}

# Show SSL Certificates
show_ssl() {
    print_section "🔒 SSL Certificates (Let's Encrypt)"

    if [ -d "$LETSENCRYPT_DIR/live" ]; then
        print_kv "Certificates Dir" "$LETSENCRYPT_DIR/live" "$GRAY"

        echo -e "\n  ${CYAN}📝 Установленные сертификаты:${NC}"
        for cert_dir in "$LETSENCRYPT_DIR/live"/*; do
            if [ -d "$cert_dir" ] && [ -f "$cert_dir/cert.pem" ]; then
                local domain=$(basename "$cert_dir")
                local expiry=$(openssl x509 -enddate -noout -in "$cert_dir/cert.pem" 2>/dev/null | cut -d'=' -f2)
                echo -e "  ${GREEN}✓${NC} $domain"
                [ -n "$expiry" ] && echo -e "    ${GRAY}Expires: $expiry${NC}"
            fi
        done

        echo -e "\n  ${CYAN}📝 Команды:${NC}"
        print_cmd "Обновить все сертификаты" "sudo certbot renew"
        print_cmd "Список сертификатов" "sudo certbot certificates"
    else
        log_warning "SSL сертификаты не найдены"
    fi
}

# Show Docker
show_docker() {
    print_section "🐳 Docker"

    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        print_kv "Version" "$docker_version"

        echo -e "\n  ${CYAN}📝 Запущенные контейнеры:${NC}"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tail -n +2 | while read line; do
            echo -e "  ${GREEN}•${NC} $line"
        done

        echo -e "\n  ${CYAN}📝 Networks:${NC}"
        docker network ls --format "table {{.Name}}\t{{.Driver}}" | tail -n +2 | while read line; do
            echo -e "  ${GREEN}•${NC} $line"
        done

        echo -e "\n  ${CYAN}📝 Команды:${NC}"
        print_cmd "Все контейнеры" "docker ps -a"
        print_cmd "Логи контейнера" "docker logs -f CONTAINER_NAME"
        print_cmd "Статистика" "docker stats"
    else
        log_error "Docker не установлен"
    fi
}

# Show Bot Tokens
show_bot_tokens() {
    print_section "🔑 Bot Tokens & Keys"

    if [ ! -d "$BOTS_DIR" ] || [ -z "$(ls -A $BOTS_DIR 2>/dev/null)" ]; then
        log_warning "Боты не найдены"
        return
    fi

    for bot_dir in "$BOTS_DIR"/*; do
        if [ -d "$bot_dir" ] && [ -f "$bot_dir/.env" ]; then
            local bot_name=$(basename "$bot_dir")

            echo -e "  ${CYAN}┌─ ${WHITE}$bot_name${NC}"

            local bot_token=$(grep "^BOT_TOKEN=" "$bot_dir/.env" 2>/dev/null | cut -d'=' -f2)
            local secret_key=$(grep "^SECRET_KEY=" "$bot_dir/.env" 2>/dev/null | cut -d'=' -f2)
            local domain=$(grep "^BOT_DOMAIN\|^DOMAIN=" "$bot_dir/.env" 2>/dev/null | cut -d'=' -f2 | head -1)

            [ -n "$bot_token" ] && echo -e "  ${CYAN}│${NC}   Bot Token: ${YELLOW}$(mask_secret "$bot_token" 6)${NC}"
            [ -n "$secret_key" ] && echo -e "  ${CYAN}│${NC}   Secret Key: ${YELLOW}$(mask_secret "$secret_key")${NC}"
            [ -n "$domain" ] && echo -e "  ${CYAN}│${NC}   Domain: ${GREEN}$domain${NC}"

            echo -e "  ${CYAN}│${NC}   ${GRAY}.env: $bot_dir/.env${NC}"
            echo -e "  ${CYAN}└─${NC}\n"
        fi
    done
}

# Show system info
show_system_info() {
    print_section "💻 System Information"

    local server_ip=$(hostname -I | awk '{print $1}')
    local hostname=$(hostname)
    local os_info=$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
    local uptime=$(uptime -p)

    print_kv "Hostname" "$hostname"
    print_kv "IP Address" "$server_ip"
    print_kv "OS" "$os_info"
    print_kv "Uptime" "$uptime"

    echo -e "\n  ${CYAN}📝 Директории:${NC}"
    print_kv "Platform" "$PLATFORM_DIR" "$GRAY"
    print_kv "Bots" "$BOTS_DIR" "$GRAY"
    print_kv "Monitoring" "$MONITORING_DIR" "$GRAY"
    print_kv "Backups" "$PLATFORM_DIR/backups" "$GRAY"
}

# Export to file
export_credentials() {
    local export_file="/tmp/platform_credentials_$(date +%Y%m%d_%H%M%S).txt"

    log_info "Экспорт учетных данных в файл..."

    {
        echo "================================"
        echo "PLATFORM CREDENTIALS EXPORT"
        echo "Generated: $(date)"
        echo "================================"
        echo ""

        # PostgreSQL
        if [ -f "$CREDS_FILE" ]; then
            source "$CREDS_FILE"
            echo "PostgreSQL Admin:"
            echo "  User: ${POSTGRES_ADMIN_USER:-postgres}"
            echo "  Password: ${POSTGRES_ADMIN_PASSWORD:-}"
            echo ""
        fi

        # Grafana
        local grafana_env="$MONITORING_DIR/.env"
        if [ -f "$grafana_env" ]; then
            source "$grafana_env"
            echo "Grafana:"
            echo "  URL: http://$(hostname -I | awk '{print $1}'):${GRAFANA_PORT:-3000}"
            echo "  User: ${GF_SECURITY_ADMIN_USER:-admin}"
            echo "  Password: ${GF_SECURITY_ADMIN_PASSWORD:-admin}"
            echo ""
        fi

        # Bots
        echo "Bots:"
        for bot_dir in "$BOTS_DIR"/*; do
            if [ -d "$bot_dir" ] && [ -f "$bot_dir/.env" ]; then
                local bot_name=$(basename "$bot_dir")
                echo ""
                echo "  $bot_name:"
                grep "^BOT_TOKEN\|^POSTGRES_\|^DATABASE_URL\|^DOMAIN" "$bot_dir/.env" | sed 's/^/    /'
            fi
        done

    } > "$export_file"

    chmod 600 "$export_file"
    log_success "Экспортировано в: $export_file"
    echo -e "  ${YELLOW}⚠️  Файл содержит конфиденциальную информацию!${NC}"
    echo -e "  ${GRAY}Удалите после использования: rm $export_file${NC}\n"
}

# Main menu
show_menu() {
    echo -e "${CYAN}Выберите раздел:${NC}\n"
    echo "  1) PostgreSQL Database"
    echo "  2) Bot Databases"
    echo "  3) Grafana Monitoring"
    echo "  4) Prometheus"
    echo "  5) Redis Cache"
    echo "  6) Nginx Web Server"
    echo "  7) SSL Certificates"
    echo "  8) Docker"
    echo "  9) Bot Tokens & Keys"
    echo "  10) System Information"
    echo "  11) Показать все"
    echo "  12) Экспорт в файл"
    echo "  0) Выход"
    echo ""
    read -p "$(echo -e ${YELLOW}Ваш выбор: ${NC})" choice

    case $choice in
        1) show_postgres ;;
        2) show_bot_databases ;;
        3) show_grafana ;;
        4) show_prometheus ;;
        5) show_redis ;;
        6) show_nginx ;;
        7) show_ssl ;;
        8) show_docker ;;
        9) show_bot_tokens ;;
        10) show_system_info ;;
        11)
            show_system_info
            show_postgres
            show_bot_databases
            show_bot_tokens
            show_grafana
            show_prometheus
            show_redis
            show_nginx
            show_ssl
            show_docker
            ;;
        12) export_credentials ;;
        0) log_info "Выход"; exit 0 ;;
        *) log_error "Неверный выбор" ;;
    esac

    echo ""
    read -p "Нажмите Enter для продолжения..."
}

# Main
main() {
    # Check if root
    if [[ $EUID -ne 0 ]]; then
        log_error "Скрипт должен запускаться от root"
        echo -e "  ${GRAY}Используйте: sudo $0${NC}\n"
        exit 1
    fi

    # Check if argument provided
    if [ $# -gt 0 ]; then
        case $1 in
            postgres) show_postgres ;;
            bots) show_bot_databases ;;
            grafana) show_grafana ;;
            prometheus) show_prometheus ;;
            redis) show_redis ;;
            nginx) show_nginx ;;
            ssl) show_ssl ;;
            docker) show_docker ;;
            tokens) show_bot_tokens ;;
            system) show_system_info ;;
            all)
                show_banner
                show_system_info
                show_postgres
                show_bot_databases
                show_bot_tokens
                show_grafana
                show_prometheus
                show_redis
                show_nginx
                show_ssl
                show_docker
                ;;
            export) export_credentials ;;
            *)
                echo "Usage: $0 {postgres|bots|grafana|prometheus|redis|nginx|ssl|docker|tokens|system|all|export}"
                exit 1
                ;;
        esac
    else
        # Interactive mode
        while true; do
            show_banner
            show_menu
        done
    fi
}

main "$@"
