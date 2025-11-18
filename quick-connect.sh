#!/bin/bash

# ========================================
# 🔑 Quick SSH Key Setup
# Автоматическое получение ключа с сервера
# ========================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════╗
║                                               ║
║     🔑 SSH Key Setup для                     ║
║     Telegram Bots Platform                   ║
║                                               ║
╚═══════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Запрос данных
read -p "$(echo -e ${CYAN}IP адрес сервера: ${NC})" SERVER_IP
read -p "$(echo -e ${CYAN}SSH порт [default: 2222]: ${NC})" SERVER_PORT
SERVER_PORT=${SERVER_PORT:-2222}
read -p "$(echo -e ${CYAN}Имя пользователя: ${NC})" SERVER_USER

LOCAL_KEY_PATH="$HOME/.ssh/telegram_bots_${SERVER_IP//./_}_key"

echo -e "\n${YELLOW}Выберите метод:${NC}"
echo "  1) У меня есть пароль (первое подключение)"
echo "  2) У меня есть доступ через веб-консоль хостинга"
echo "  3) У меня уже есть приватный ключ"
read -p "$(echo -e ${CYAN}Выбор [1-3]: ${NC})" METHOD

case $METHOD in
    1)
        echo -e "\n${CYAN}📥 Получение ключа с сервера через SCP...${NC}"
        
        # Попытка скопировать ключ
        if scp -P $SERVER_PORT "$SERVER_USER@$SERVER_IP:/home/$SERVER_USER/.ssh/id_rsa" "$LOCAL_KEY_PATH" 2>/dev/null; then
            echo -e "${GREEN}✅ Ключ скопирован${NC}"
        else
            # Альтернативный метод
            echo -e "${YELLOW}⚠️  Прямое копирование не удалось${NC}"
            echo -e "${CYAN}Подключаюсь для получения ключа...${NC}"
            
            ssh -p $SERVER_PORT "$SERVER_USER@$SERVER_IP" "cat ~/.ssh/id_rsa" > "$LOCAL_KEY_PATH"
            
            if [ -s "$LOCAL_KEY_PATH" ]; then
                echo -e "${GREEN}✅ Ключ получен${NC}"
            else
                echo -e "${RED}❌ Не удалось получить ключ${NC}"
                exit 1
            fi
        fi
        ;;
        
    2)
        echo -e "\n${CYAN}📝 Инструкции для веб-консоли:${NC}\n"
        echo "1. Откройте веб-консоль в панели вашего хостинга"
        echo "2. Выполните команду: cat ~/.ssh/id_rsa"
        echo "3. Скопируйте весь вывод (включая -----BEGIN и -----END)"
        echo ""
        read -p "Нажмите Enter когда будете готовы вставить ключ..."
        
        echo -e "\n${CYAN}Вставьте приватный ключ (завершите вставку строкой END_KEY):${NC}"
        
        # Создать временный файл
        > "$LOCAL_KEY_PATH"
        
        while IFS= read -r line; do
            [[ "$line" == "END_KEY" ]] && break
            echo "$line" >> "$LOCAL_KEY_PATH"
        done
        
        if [ -s "$LOCAL_KEY_PATH" ]; then
            echo -e "${GREEN}✅ Ключ сохранен${NC}"
        else
            echo -e "${RED}❌ Ключ не был вставлен${NC}"
            exit 1
        fi
        ;;
        
    3)
        echo -e "\n${CYAN}📁 Укажите путь к приватному ключу:${NC}"
        read -p "Путь: " EXISTING_KEY_PATH
        
        # Расширить тильду
        EXISTING_KEY_PATH="${EXISTING_KEY_PATH/#\~/$HOME}"
        
        if [ -f "$EXISTING_KEY_PATH" ]; then
            cp "$EXISTING_KEY_PATH" "$LOCAL_KEY_PATH"
            echo -e "${GREEN}✅ Ключ скопирован${NC}"
        else
            echo -e "${RED}❌ Файл не найден: $EXISTING_KEY_PATH${NC}"
            exit 1
        fi
        ;;
        
    *)
        echo -e "${RED}❌ Неверный выбор${NC}"
        exit 1
        ;;
esac

# Установить права
chmod 600 "$LOCAL_KEY_PATH"
echo -e "${GREEN}✅ Права доступа установлены (600)${NC}"

# Проверить ключ
if ssh-keygen -l -f "$LOCAL_KEY_PATH" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Ключ валидный${NC}"
    FINGERPRINT=$(ssh-keygen -l -f "$LOCAL_KEY_PATH" | awk '{print $2}')
    echo -e "   Fingerprint: ${YELLOW}$FINGERPRINT${NC}"
else
    echo -e "${RED}❌ Ключ невалидный или поврежден${NC}"
    exit 1
fi

# Создать SSH конфиг
SSH_CONFIG="$HOME/.ssh/config"
ALIAS="telegram-bots-$(echo $SERVER_IP | tr '.' '-')"

echo -e "\n${CYAN}📝 Создание SSH конфига...${NC}"

# Создать .ssh если не существует
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Добавить в конфиг если еще нет
if ! grep -q "Host $ALIAS" "$SSH_CONFIG" 2>/dev/null; then
    cat >> "$SSH_CONFIG" << EOF

# Telegram Bots Platform - $SERVER_IP
Host $ALIAS
    HostName $SERVER_IP
    User $SERVER_USER
    Port $SERVER_PORT
    IdentityFile $LOCAL_KEY_PATH
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
    chmod 600 "$SSH_CONFIG"
    echo -e "${GREEN}✅ SSH конфиг обновлен${NC}"
else
    echo -e "${YELLOW}⚠️  Запись уже существует в SSH конфиге${NC}"
fi

# Добавить в ssh-agent
echo -e "\n${CYAN}🔑 Добавление ключа в ssh-agent...${NC}"
eval "$(ssh-agent -s)" >/dev/null 2>&1
if ssh-add "$LOCAL_KEY_PATH" 2>/dev/null; then
    echo -e "${GREEN}✅ Ключ добавлен в ssh-agent${NC}"
else
    echo -e "${YELLOW}⚠️  Не удалось добавить в ssh-agent (возможно требуется passphrase)${NC}"
fi

# Тест подключения
echo -e "\n${CYAN}🧪 Тестирование подключения...${NC}"
if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "$ALIAS" "echo 'success'" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Подключение успешно!${NC}"
else
    echo -e "${YELLOW}⚠️  Автоматическое тестирование не прошло, но это нормально${NC}"
    echo -e "${YELLOW}   (может потребоваться подтверждение fingerprint)${NC}"
fi

# Итоговая информация
echo -e "\n${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                               ║${NC}"
echo -e "${GREEN}║         ✅ НАСТРОЙКА ЗАВЕРШЕНА! ✅            ║${NC}"
echo -e "${GREEN}║                                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}📝 Информация о подключении:${NC}\n"
echo -e "  Сервер:      ${GREEN}$SERVER_IP:$SERVER_PORT${NC}"
echo -e "  Пользователь: ${GREEN}$SERVER_USER${NC}"
echo -e "  Ключ:        ${GREEN}$LOCAL_KEY_PATH${NC}"
echo -e "  Алиас:       ${GREEN}$ALIAS${NC}\n"

echo -e "${CYAN}🔧 Команды для подключения:${NC}\n"
echo -e "  Простое:     ${GREEN}ssh $ALIAS${NC}"
echo -e "  Полное:      ${GREEN}ssh -i $LOCAL_KEY_PATH -p $SERVER_PORT $SERVER_USER@$SERVER_IP${NC}"
echo -e "  SCP:         ${GREEN}scp file.txt $ALIAS:/path/to/destination/${NC}"
echo -e "  Мониторинг:  ${GREEN}ssh $ALIAS 'bot-status'${NC}\n"

echo -e "${YELLOW}⚠️  ВАЖНО: Сохраните резервную копию ключа!${NC}"
echo -e "   Ключ находится: ${CYAN}$LOCAL_KEY_PATH${NC}\n"

# Предложение создать резервную копию
read -p "$(echo -e ${CYAN}Создать резервную копию ключа? [y/N]: ${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    BACKUP_PATH="$HOME/telegram_bots_platform_key_backup_$(date +%Y%m%d).txt"
    cp "$LOCAL_KEY_PATH" "$BACKUP_PATH"
    echo -e "${GREEN}✅ Резервная копия создана: $BACKUP_PATH${NC}"
    echo -e "${RED}⚠️  Храните её в безопасном месте!${NC}"
fi

echo -e "\n${GREEN}🚀 Теперь можете подключаться: ssh $ALIAS${NC}\n"