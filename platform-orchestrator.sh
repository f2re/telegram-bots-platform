#!/bin/bash

# ========================================
# 🌐 Telegram Bots Platform Orchestration Script
# Главный менеджер для установки, управления и мониторинга
# ========================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️ ${NC}$1"; }
log_success() { echo -e "${GREEN}✅ ${NC}$1"; }
log_warning() { echo -e "${YELLOW}⚠️ ${NC}$1"; }
log_error() { echo -e "${RED}❌ ${NC}$1"; }

BOTS_DIR="/opt/telegram-bots-platform/bots"

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
        echo -e "  ${YELLOW}$i)${NC} $bot" >&2
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

show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔═════════════════════════════════════════════════════════════════╗
║                                                               ║
║   🌐 TELEGRAM BOTS PLATFORM ОРКЕСТРАТОР                        ║
║                                                               ║
╚═════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

show_menu() {
    echo -e "${CYAN}Выберите действие:${NC}\n"
    echo "  1) Установить и сконфигурировать сервер (setup-server.sh)"
    echo "  2) Добавить нового бота (add-bot.sh)"
    echo "  3) Управление ботами (bot-manage.sh)"
    echo "  4) Исправить права доступа (fix-permissions.sh)"
    echo "  5) Включить мониторинг (setup-grafana-bot.sh)"
    echo "  6) Перезапустить платформу"
    echo "  7) 🔐 Показать учетные данные"
    echo "  8) Диагностика/помощь"
    echo "  0) Выход"
    echo ""
    read -p "$(echo -e ${YELLOW}Ваш выбор: ${NC})" choice
    case $choice in
        1)
            log_info "Запуск установки сервера..."
            sudo ./setup-server.sh
            ;;
        2)
            log_info "Запуск мастера добавления бота..."
            sudo ./add-bot.sh
            ;;
        3)
            log_info "Запуск управления ботами..."
            sudo ./bot-manage.sh
            ;;
        4)
            log_info "Исправление прав доступа..."
            sudo bash ./scripts/fix-permissions.sh
            ;;
        5)
            log_info "Настройка мониторинга бота..."
            bot_name=$(select_bot "Выберите бота для мониторинга")
            if [ $? -eq 0 ]; then
                db_name="${bot_name//-/_}_db"
                sudo bash ./scripts/setup-grafana-bot.sh "$bot_name" "$db_name"
            else
                log_warning "Отменено"
            fi
            ;;
        6)
            log_info "Перезапуск всех контейнеров платформы..."
            docker compose -f /opt/monitoring/docker-compose.yml restart
            for bot in /opt/telegram-bots-platform/bots/*; do
                cd "$bot"
                docker compose restart
            done
            log_success "Все сервисы перезапущены"
            ;;
        7)
            log_info "Показ учетных данных..."
            sudo ./show-credentials.sh
            ;;
        8)
            show_help
            ;;
        0)
            log_info "Выход из оркестратора"
            exit 0
            ;;
        *)
            log_error "Неверный выбор"
            ;;
    esac
    echo ""
    read -p "Нажмите Enter для продолжения..."
}

show_help() {
    echo -e "${CYAN}Справка по платформе:${NC}"
    echo "  - Все скрипты из корня: ./setup-server.sh, ./add-bot.sh, ./bot-manage.sh"
    echo "  - Для управления ботами лучше использовать ./bot-manage.sh"
    echo "  - Для мониторинга Grafana используйте ./scripts/setup-grafana-bot.sh <bot> <db>"
    echo "  - Для исправления прав ./scripts/fix-permissions.sh"
    echo "  - Логи: docker logs -f <container> или через bot-manage.sh"
    echo "  - Документация: смотрите README_RU.md"
    echo "  - Если скрипт предлагает действие — просто введите нужный пункт меню или команду"
}

main() {
    show_banner
    while true; do
        show_menu
    done
}

main "$@"
