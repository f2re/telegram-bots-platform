#!/bin/bash

# ========================================
# 🧙 Configuration Wizard
# Интерактивная настройка конфигурации
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

CONFIG_FILE="$(dirname "$0")/config.env"
CONFIG_BACKUP="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║         🧙 CONFIGURATION WIZARD 🧙                       ║
║                                                           ║
║         Интерактивная настройка платформы                ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

log_info() { echo -e "${BLUE}ℹ️  ${NC}$1"; }
log_success() { echo -e "${GREEN}✅ ${NC}$1"; }
log_warning() { echo -e "${YELLOW}⚠️  ${NC}$1"; }
log_error() { echo -e "${RED}❌ ${NC}$1"; }

# Backup current config
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$CONFIG_BACKUP"
    log_info "Создана резервная копия: $CONFIG_BACKUP"
fi

# Prompt with default value
prompt_with_default() {
    local prompt=$1
    local default=$2
    local var_name=$3
    local value
    
    read -p "$(echo -e ${CYAN}${prompt} ${GREEN}[${default}]${CYAN}: ${NC})" value
    value=${value:-$default}
    
    eval "$var_name='$value'"
}

# Yes/No prompt
prompt_yes_no() {
    local prompt=$1
    local default=$2
    local var_name=$3
    local value
    
    while true; do
        read -p "$(echo -e ${CYAN}${prompt} ${GREEN}[${default}]${CYAN}: ${NC})" yn
        yn=${yn:-$default}
        case $yn in
            [Yy]* ) eval "$var_name='true'"; break;;
            [Nn]* ) eval "$var_name='false'"; break;;
            * ) echo "Пожалуйста, ответьте y или n.";;
        esac
    done
}

echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}📧 Основные настройки${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}\n"

prompt_with_default "Email администратора" "admin@example.com" ADMIN_EMAIL
prompt_with_default "Временная зона сервера" "Europe/Moscow" SERVER_TIMEZONE

echo -e "\n${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}🔐 SSH настройки${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}\n"

prompt_with_default "SSH порт" "2222" SSH_PORT
prompt_yes_no "Отключить вход по паролю (рекомендуется)" "y" SSH_PASSWORD_AUTH_DISABLED

if [ "$SSH_PASSWORD_AUTH_DISABLED" = "true" ]; then
    SSH_PASSWORD_AUTH="no"
else
    SSH_PASSWORD_AUTH="yes"
fi

echo -e "\n${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}🗄️  PostgreSQL настройки${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}\n"

log_info "Пароль PostgreSQL будет сгенерирован автоматически"
prompt_with_default "Максимум подключений" "200" POSTGRES_MAX_CONNECTIONS
prompt_with_default "Shared buffers (25% RAM)" "256MB" POSTGRES_SHARED_BUFFERS
prompt_with_default "Effective cache size (50-75% RAM)" "1GB" POSTGRES_EFFECTIVE_CACHE_SIZE

echo -e "\n${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}🌐 Nginx настройки${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}\n"

prompt_with_default "Максимальный размер загружаемого файла" "100M" NGINX_CLIENT_MAX_BODY_SIZE
prompt_with_default "Rate limit для API (запросов/сек)" "30r/s" NGINX_RATE_LIMIT_API

echo -e "\n${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}📊 Мониторинг${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}\n"

prompt_yes_no "Установить систему мониторинга (Grafana + Prometheus)" "y" MONITORING_ENABLED
if [ "$MONITORING_ENABLED" = "true" ]; then
    prompt_with_default "Grafana порт" "3000" GRAFANA_PORT
    log_info "Пароль Grafana будет сгенерирован автоматически"
fi

echo -e "\n${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}🛡️  Fail2Ban${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}\n"

prompt_yes_no "Включить Fail2Ban защиту" "y" FAIL2BAN_ENABLED
if [ "$FAIL2BAN_ENABLED" = "true" ]; then
    prompt_with_default "Время бана (секунды)" "3600" FAIL2BAN_BANTIME
    prompt_with_default "Максимум попыток для SSH" "3" FAIL2BAN_SSH_MAXRETRY
fi

echo -e "\n${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}🎨 Oh-My-Zsh${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}\n"

prompt_yes_no "Установить Oh-My-Zsh" "y" INSTALL_OH_MY_ZSH
if [ "$INSTALL_OH_MY_ZSH" = "true" ]; then
    prompt_with_default "Тема Zsh" "agnoster" ZSH_THEME
fi

echo -e "\n${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}📦 Резервное копирование${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}\n"

prompt_yes_no "Включить автоматические бэкапы" "y" AUTO_BACKUP_ENABLED
if [ "$AUTO_BACKUP_ENABLED" = "true" ]; then
    prompt_with_default "Срок хранения бэкапов (дни)" "30" BACKUP_RETENTION_DAYS
fi

echo -e "\n${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}🤖 Боты - настройки по умолчанию${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}\n"

prompt_yes_no "Автоматическое получение SSL сертификатов" "y" BOT_AUTO_SSL
prompt_with_default "Лимит памяти для бота (по умолчанию)" "512m" BOT_DEFAULT_MEMORY_LIMIT
prompt_with_default "Лимит CPU для бота (по умолчанию)" "1.0" BOT_DEFAULT_CPU_LIMIT

# Generate configuration file
log_info "Генерация конфигурационного файла..."

cat > "$CONFIG_FILE" << EOF
#!/bin/bash
# ========================================
# 🔧 Telegram Bots Platform Configuration
# Создан: $(date)
# ========================================

# Сервер и сеть
SERVER_TIMEZONE="$SERVER_TIMEZONE"
SERVER_LOCALE="ru_RU.UTF-8"
SERVER_IP=""
ADMIN_EMAIL="$ADMIN_EMAIL"

# SSH конфигурация
SSH_PORT=$SSH_PORT
SSH_PERMIT_ROOT_LOGIN="no"
SSH_PASSWORD_AUTH="$SSH_PASSWORD_AUTH"
SSH_MAX_AUTH_TRIES=3
SSH_CLIENT_ALIVE_INTERVAL=300
SSH_CLIENT_ALIVE_COUNT_MAX=2

# Firewall
UFW_ENABLED=true
UFW_ADDITIONAL_PORTS=""
UFW_GRAFANA_ALLOWED_IPS=""

# PostgreSQL
POSTGRES_VERSION=15
POSTGRES_PASSWORD=""
POSTGRES_MAX_CONNECTIONS=$POSTGRES_MAX_CONNECTIONS
POSTGRES_SHARED_BUFFERS="$POSTGRES_SHARED_BUFFERS"
POSTGRES_EFFECTIVE_CACHE_SIZE="$POSTGRES_EFFECTIVE_CACHE_SIZE"
POSTGRES_MAINTENANCE_WORK_MEM="64MB"
POSTGRES_WORK_MEM="1310kB"
POSTGRES_MIN_WAL_SIZE="1GB"
POSTGRES_MAX_WAL_SIZE="4GB"
POSTGRES_LISTEN_ADDRESSES="localhost,172.17.0.1"

# Docker
DOCKER_COMPOSE_VERSION="latest"
DOCKER_LOG_DRIVER="json-file"
DOCKER_LOG_MAX_SIZE="10m"
DOCKER_LOG_MAX_FILE="3"
DOCKER_NETWORK_NAME="bots_shared_network"
DOCKER_NETWORK_SUBNET="172.20.0.0/16"

# Nginx
NGINX_WORKER_PROCESSES="auto"
NGINX_WORKER_CONNECTIONS=2048
NGINX_CLIENT_MAX_BODY_SIZE="$NGINX_CLIENT_MAX_BODY_SIZE"
NGINX_KEEPALIVE_TIMEOUT=65
NGINX_GZIP_COMP_LEVEL=6
NGINX_RATE_LIMIT_GENERAL="10r/s"
NGINX_RATE_LIMIT_API="$NGINX_RATE_LIMIT_API"
NGINX_SSL_PROTOCOLS="TLSv1.2 TLSv1.3"
NGINX_SSL_CIPHERS="ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"

# Мониторинг
MONITORING_ENABLED=$MONITORING_ENABLED
GRAFANA_PORT=${GRAFANA_PORT:-3000}
GRAFANA_ADMIN_PASSWORD=""
GRAFANA_ALLOW_SIGN_UP=false
PROMETHEUS_PORT=9090
PROMETHEUS_RETENTION_TIME="30d"
NODE_EXPORTER_PORT=9100
POSTGRES_EXPORTER_PORT=9187
NGINX_EXPORTER_PORT=9113
CADVISOR_PORT=8080

# Fail2Ban
FAIL2BAN_ENABLED=$FAIL2BAN_ENABLED
FAIL2BAN_BANTIME=${FAIL2BAN_BANTIME:-3600}
FAIL2BAN_FINDTIME=600
FAIL2BAN_MAXRETRY=5
FAIL2BAN_SSH_MAXRETRY=${FAIL2BAN_SSH_MAXRETRY:-3}
FAIL2BAN_SSH_BANTIME=7200
FAIL2BAN_DESTEMAIL=""

# Oh-My-Zsh
INSTALL_OH_MY_ZSH=$INSTALL_OH_MY_ZSH
ZSH_THEME="${ZSH_THEME:-agnoster}"
ZSH_CUSTOM_PLUGINS="zsh-autosuggestions zsh-syntax-highlighting"
SET_ZSH_AS_DEFAULT=true

# Автоматические обновления
AUTO_UPDATES_ENABLED=true
AUTO_UPDATES_EMAIL=""

# Резервное копирование
BACKUP_DIR="/opt/telegram-bots-platform/backups"
AUTO_BACKUP_ENABLED=$AUTO_BACKUP_ENABLED
BACKUP_CRON_SCHEDULE="0 3 * * *"
BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}
BACKUP_COMPRESSION=true

# Боты - настройки по умолчанию
BOT_PORT_START=3000
BOT_PORT_END=9000
BOT_AUTO_SSL=$BOT_AUTO_SSL
BOT_SSL_STAGING=false
BOT_AUTO_RESTART="unless-stopped"
BOT_DEFAULT_CPU_LIMIT="$BOT_DEFAULT_CPU_LIMIT"
BOT_DEFAULT_MEMORY_LIMIT="$BOT_DEFAULT_MEMORY_LIMIT"
BOT_HEALTH_CHECK_INTERVAL=30

# Уведомления
TELEGRAM_NOTIFICATIONS_ENABLED=false
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
SLACK_NOTIFICATIONS_ENABLED=false
SLACK_WEBHOOK_URL=""

# Дополнительные настройки
INSTALL_ADDITIONAL_TOOLS=true
ADDITIONAL_PACKAGES="ncdu tldr bat ripgrep"
COLORED_OUTPUT=true
VERBOSE_MODE=false

# Безопасность
IP_BLACKLIST_ENABLED=true
ENABLE_MANDATORY_ACCESS_CONTROL=false
DISABLE_IPV6=false

# Логирование
CENTRALIZED_LOGGING=true
LOGS_DIR="/var/log/telegram-bots-platform"
LOG_ROTATION_DAYS=14
LOG_COMPRESSION=true

# Производительность
NETWORK_OPTIMIZATION=true
SWAP_SIZE="2G"
SWAPPINESS=10
MAX_OPEN_FILES=65535

# Метаданные
CONFIG_VERSION="1.0.0"
CONFIG_CREATED="$(date -Iseconds)"

# Генерация паролей
generate_secure_password() {
    openssl rand -base64 32
}

if [ -z "\$POSTGRES_PASSWORD" ]; then
    POSTGRES_PASSWORD=\$(generate_secure_password)
fi

if [ -z "\$GRAFANA_ADMIN_PASSWORD" ]; then
    GRAFANA_ADMIN_PASSWORD=\$(generate_secure_password)
fi

if [ -z "\$SERVER_IP" ]; then
    SERVER_IP=\$(curl -s ifconfig.me || echo "127.0.0.1")
fi
EOF

chmod 600 "$CONFIG_FILE"

echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║         ✅ КОНФИГУРАЦИЯ СОЗДАНА УСПЕШНО! ✅              ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

log_success "Файл конфигурации: $CONFIG_FILE"
log_success "Резервная копия: $CONFIG_BACKUP"

echo -e "\n${CYAN}📝 Следующие шаги:${NC}\n"
echo -e "  1. Проверьте конфигурацию: ${GREEN}cat $CONFIG_FILE${NC}"
echo -e "  2. При необходимости отредактируйте: ${GREEN}nano $CONFIG_FILE${NC}"
echo -e "  3. Запустите установку: ${GREEN}sudo ./setup-server.sh${NC}\n"