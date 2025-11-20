#!/bin/bash

# ========================================
# 🤖 Bot Management Script
# Скрипт управления ботами на русском
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOTS_DIR="/opt/telegram-bots-platform/bots"

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  ${NC}$1"; }
log_success() { echo -e "${GREEN}✅ ${NC}$1"; }
log_warning() { echo -e "${YELLOW}⚠️  ${NC}$1"; }
log_error() { echo -e "${RED}❌ ${NC}$1"; }

# Banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║           TELEGRAM BOTS - Management Console              ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

# Get list of bots
get_bots_list() {
    local bots=()
    if [ -d "$BOTS_DIR" ]; then
        for bot_dir in "$BOTS_DIR"/*; do
            if [ -d "$bot_dir" ]; then
                bots+=("$(basename "$bot_dir")")
            fi
        done
    fi
    echo "${bots[@]}"
}

# Select bot from menu
select_bot() {
    local prompt_msg=${1:-"Выберите бота"}

    # Get available bots
    local bots=($(get_bots_list))

    if [ ${#bots[@]} -eq 0 ]; then
        log_error "Боты не найдены в $BOTS_DIR" >&2
        return 1
    fi

    # Output menu to stderr so it doesn't get captured
    echo -e "${CYAN}$prompt_msg:${NC}\n" >&2

    # Show numbered list
    local i=1
    for bot in "${bots[@]}"; do
        # Get status
        if [ -d "$BOTS_DIR/$bot" ]; then
            cd "$BOTS_DIR/$bot" 2>/dev/null
            if docker compose ps --format json 2>/dev/null | grep -q "running"; then
                status="${GREEN}●${NC}"
            else
                status="${RED}●${NC}"
            fi
            echo -e "  ${YELLOW}$i)${NC} $status $bot" >&2
        fi
        ((i++))
    done

    echo -e "  ${YELLOW}0)${NC} Отмена" >&2
    echo "" >&2

    # Get user choice
    local choice
    while true; do
        read -p "$(echo -e ${YELLOW}Ваш выбор [0-$((${#bots[@]}))]: ${NC})" choice </dev/tty

        if [[ "$choice" == "0" ]]; then
            return 1
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#bots[@]} ]; then
            # Only the selected bot name goes to stdout
            echo "${bots[$((choice-1))]}"
            return 0
        else
            log_error "Неверный выбор. Введите число от 0 до ${#bots[@]}" >&2
        fi
    done
}

# List all bots
list_bots() {
    echo -e "${CYAN}📋 Список всех ботов:${NC}\n"

    if [ ! -d "$BOTS_DIR" ] || [ -z "$(ls -A $BOTS_DIR 2>/dev/null)" ]; then
        log_warning "Боты не найдены"
        return
    fi

    printf "${YELLOW}%-20s %-15s %-20s %-30s${NC}\n" "ИМЯ БОТА" "СТАТУС" "КОНТЕЙНЕРЫ" "ДОМЕН"
    echo "────────────────────────────────────────────────────────────────────────────────────"

    for bot_dir in "$BOTS_DIR"/*; do
        if [ -d "$bot_dir" ]; then
            bot_name=$(basename "$bot_dir")

            # Get status
            cd "$bot_dir"
            if docker compose ps --format json 2>/dev/null | grep -q "running"; then
                status="${GREEN}●${NC} Запущен"
            else
                status="${RED}●${NC} Остановлен"
            fi

            # Count containers
            container_count=$(docker compose ps -q 2>/dev/null | wc -l)

            # Get domain
            domain=$(grep "BOT_DOMAIN" .env 2>/dev/null | cut -d'=' -f2 || echo "N/A")

            printf "%-20s %-25s %-20s %-30s\n" "$bot_name" "$status" "$container_count контейнер(ов)" "$domain"
        fi
    done
    echo ""
}

# Show bot details
show_bot_info() {
    local bot_name=$1
    local bot_dir="$BOTS_DIR/$bot_name"
    
    if [ ! -d "$bot_dir" ]; then
        log_error "Бот '$bot_name' не найден"
        return 1
    fi
    
    echo -e "${CYAN}📊 Информация о боте: $bot_name${NC}\n"
    
    cd "$bot_dir"
    
    # Basic info
    echo -e "${YELLOW}Основная информация:${NC}"
    [ -f "bot_info.json" ] && cat bot_info.json | jq '.' 2>/dev/null || echo "  Информация недоступна"
    
    echo -e "\n${YELLOW}Контейнеры:${NC}"
    docker compose ps
    
    echo -e "\n${YELLOW}Использование ресурсов:${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" $(docker compose ps -q)
    
    echo -e "\n${YELLOW}Переменные окружения:${NC}"
    echo "  BOT_TOKEN: $(grep BOT_TOKEN .env | cut -d'=' -f2 | sed 's/^\(....\).*\(....\)$/\1****\2/')"
    echo "  DATABASE: $(grep POSTGRES_DB .env | cut -d'=' -f2)"
    echo "  DOMAIN: $(grep BOT_DOMAIN .env | cut -d'=' -f2)"
    echo ""
}

# Start bot
start_bot() {
    local bot_name=$1
    local bot_dir="$BOTS_DIR/$bot_name"

    if [ ! -d "$bot_dir" ]; then
        log_error "Бот '$bot_name' не найден"
        return 1
    fi

    log_info "Запуск бота: $bot_name"
    cd "$bot_dir"

    # Ensure .env file exists
    if [ ! -f ".env" ]; then
        log_error ".env файл не найден в $bot_dir"
        return 1
    fi

    # Load .env
    set -a
    source .env
    set +a

    # Ensure BOT_NAME is set in .env
    if [ -z "$BOT_NAME" ]; then
        echo "BOT_NAME=$bot_name" >> .env
        export BOT_NAME="$bot_name"
        log_info "Добавлено BOT_NAME=$bot_name в .env"
    fi

    # Ensure static network exists with correct configuration
    local shared_network="bots_shared_network"
    local subnet="172.25.0.0/16"
    local gateway="172.25.0.1"

    if ! docker network ls --format '{{.Name}}' | grep -q "^${shared_network}$"; then
        log_info "Создание статической сети: $shared_network (gateway: $gateway)"
        docker network create \
            --driver bridge \
            --subnet="$subnet" \
            --gateway="$gateway" \
            "$shared_network" 2>/dev/null || log_warning "Сеть уже существует"
    fi

    # Start bot
    log_info "Запуск контейнеров..."
    docker compose up -d

    if [ $? -eq 0 ]; then
        log_success "Бот $bot_name запущен"
    else
        log_error "Ошибка при запуске бота"
        return 1
    fi
}

# Stop bot
stop_bot() {
    local bot_name=$1
    local bot_dir="$BOTS_DIR/$bot_name"
    
    if [ ! -d "$bot_dir" ]; then
        log_error "Бот '$bot_name' не найден"
        return 1
    fi
    
    log_info "Остановка бота: $bot_name"
    cd "$bot_dir"
    docker compose stop
    log_success "Бот $bot_name остановлен"
}

# Restart bot
restart_bot() {
    local bot_name=$1
    local bot_dir="$BOTS_DIR/$bot_name"

    if [ ! -d "$bot_dir" ]; then
        log_error "Бот '$bot_name' не найден"
        return 1
    fi

    log_info "Перезапуск бота: $bot_name"
    cd "$bot_dir"

    # Ensure networks exist before restart
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a

        if [ -z "$BOT_NAME" ]; then
            echo "BOT_NAME=$bot_name" >> .env
            export BOT_NAME="$bot_name"
        fi

        # Ensure static network exists
        local shared_network="bots_shared_network"
        local subnet="172.25.0.0/16"
        local gateway="172.25.0.1"

        docker network create \
            --driver bridge \
            --subnet="$subnet" \
            --gateway="$gateway" \
            "$shared_network" 2>/dev/null || true
    fi

    docker compose restart
    log_success "Бот $bot_name перезапущен"
}

# Show logs
show_logs() {
    local bot_name=$1
    local bot_dir="$BOTS_DIR/$bot_name"
    local lines=${2:-100}
    
    if [ ! -d "$bot_dir" ]; then
        log_error "Бот '$bot_name' не найден"
        return 1
    fi
    
    log_info "Логи бота: $bot_name (последние $lines строк)"
    echo ""
    cd "$bot_dir"
    docker compose logs --tail=$lines -f
}

# Update bot
update_bot() {
    local bot_name=$1
    local bot_dir="$BOTS_DIR/$bot_name"
    
    if [ ! -d "$bot_dir" ]; then
        log_error "Бот '$bot_name' не найден"
        return 1
    fi
    
    log_info "Обновление бота: $bot_name"
    cd "$bot_dir/app"
    
    # Pull latest code
    log_info "Получение последних изменений из Git..."
    git pull
    
    # Rebuild and restart
    cd "$bot_dir"
    log_info "Пересборка контейнеров..."
    docker compose build --no-cache
    
    log_info "Перезапуск с новой версией..."
    docker compose up -d
    
    log_success "Бот $bot_name обновлен"
}

# Rebuild bot
rebuild_bot() {
    local bot_name=$1
    local bot_dir="$BOTS_DIR/$bot_name"

    if [ ! -d "$bot_dir" ]; then
        log_error "Бот '$bot_name' не найден"
        return 1
    fi

    log_info "Пересборка бота: $bot_name"
    cd "$bot_dir"

    # Load .env and ensure networks exist
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a

        if [ -z "$BOT_NAME" ]; then
            echo "BOT_NAME=$bot_name" >> .env
            export BOT_NAME="$bot_name"
        fi

        # Ensure static network exists
        local shared_network="bots_shared_network"
        local subnet="172.25.0.0/16"
        local gateway="172.25.0.1"

        docker network create \
            --driver bridge \
            --subnet="$subnet" \
            --gateway="$gateway" \
            "$shared_network" 2>/dev/null || true
    fi

    docker compose down
    docker compose build --no-cache
    docker compose up -d

    log_success "Бот $bot_name пересобран"
}

# Backup bot
backup_bot() {
    local bot_name=$1
    local bot_dir="$BOTS_DIR/$bot_name"
    local backup_dir="/opt/telegram-bots-platform/backups"
    
    if [ ! -d "$bot_dir" ]; then
        log_error "Бот '$bot_name' не найден"
        return 1
    fi
    
    mkdir -p "$backup_dir"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/${bot_name}_${timestamp}.tar.gz"
    
    log_info "Создание резервной копии: $bot_name"
    
    # Backup database
    local db_name=$(grep POSTGRES_DB "$bot_dir/.env" | cut -d'=' -f2)
    log_info "Резервное копирование базы данных: $db_name"
    sudo -u postgres pg_dump "$db_name" > "$backup_dir/${bot_name}_${timestamp}.sql"
    
    # Backup files
    log_info "Архивирование файлов..."
    tar -czf "$backup_file" -C "$BOTS_DIR" "$bot_name"
    
    log_success "Резервная копия создана: $backup_file"
    log_success "База данных: $backup_dir/${bot_name}_${timestamp}.sql"
}

# Show menu
show_menu() {
    echo -e "${CYAN}Выберите действие:${NC}\n"
    echo "  1) Список всех ботов"
    echo "  2) Информация о боте"
    echo "  3) Запустить бота"
    echo "  4) Остановить бота"
    echo "  5) Перезапустить бота"
    echo "  6) Показать логи"
    echo "  7) Обновить бота (git pull + rebuild)"
    echo "  8) Пересобрать бота"
    echo "  9) Создать резервную копию"
    echo "  10) 🔐 Показать учетные данные"
    echo "  0) Выход"
    echo ""
    read -p "$(echo -e ${YELLOW}Ваш выбор: ${NC})" choice

    case $choice in
        1)
            list_bots
            ;;
        2)
            bot_name=$(select_bot "Информация о боте")
            if [ $? -eq 0 ]; then
                show_bot_info "$bot_name"
            fi
            ;;
        3)
            bot_name=$(select_bot "Запустить бота")
            if [ $? -eq 0 ]; then
                start_bot "$bot_name"
            fi
            ;;
        4)
            bot_name=$(select_bot "Остановить бота")
            if [ $? -eq 0 ]; then
                stop_bot "$bot_name"
            fi
            ;;
        5)
            bot_name=$(select_bot "Перезапустить бота")
            if [ $? -eq 0 ]; then
                restart_bot "$bot_name"
            fi
            ;;
        6)
            bot_name=$(select_bot "Показать логи")
            if [ $? -eq 0 ]; then
                read -p "Количество строк [100]: " lines
                lines=${lines:-100}
                show_logs "$bot_name" "$lines"
            fi
            ;;
        7)
            bot_name=$(select_bot "Обновить бота")
            if [ $? -eq 0 ]; then
                update_bot "$bot_name"
            fi
            ;;
        8)
            bot_name=$(select_bot "Пересобрать бота")
            if [ $? -eq 0 ]; then
                rebuild_bot "$bot_name"
            fi
            ;;
        9)
            bot_name=$(select_bot "Создать резервную копию")
            if [ $? -eq 0 ]; then
                backup_bot "$bot_name"
            fi
            ;;
        10)
            "$SCRIPT_DIR/show-credentials.sh" all
            ;;
        0)
            log_info "Выход"
            exit 0
            ;;
        *)
            log_error "Неверный выбор"
            ;;
    esac

    echo ""
    read -p "Нажмите Enter для продолжения..."
}

# Main
main() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Скрипт должен запускаться от root"
        exit 1
    fi
    
    # Check if command line argument provided
    if [ $# -gt 0 ]; then
        command=$1
        shift
        
        case $command in
            list|ls)
                list_bots
                ;;
            info)
                show_bot_info "$@"
                ;;
            start)
                start_bot "$@"
                ;;
            stop)
                stop_bot "$@"
                ;;
            restart)
                restart_bot "$@"
                ;;
            logs)
                show_logs "$@"
                ;;
            update)
                update_bot "$@"
                ;;
            rebuild)
                rebuild_bot "$@"
                ;;
            backup)
                backup_bot "$@"
                ;;
            *)
                echo "Usage: $0 {list|info|start|stop|restart|logs|update|rebuild|backup} [bot_name] [options]"
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
