# 🤖 Telegram Bots Platform

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Debian%2012-blue)](https://www.debian.org/)
[![Docker](https://img.shields.io/badge/Docker-Supported-blue)](https://www.docker.com/)

Полнофункциональная платформа для развертывания и управления множественными Telegram-ботами на выделенном сервере Debian 12.

## 🌟 Возможности

- ✅ Автоматическая настройка безопасного SSH
- ✅ Firewall (UFW) и Fail2Ban
- ✅ PostgreSQL с изолированными БД для каждого бота
- ✅ Nginx с автоматическим SSL (Let's Encrypt)
- ✅ Docker для изоляции приложений
- ✅ Grafana + Prometheus для мониторинга
- ✅ Oh-My-Zsh с плагинами
- ✅ Красивые скрипты с цветным выводом

## 📋 Требования

- Debian 12 (чистая установка)
- Минимум 2GB RAM
- 20GB свободного места на диске
- Root доступ
- Домены с настроенными A-записями

## 🚀 Быстрый старт

### 1. Скачать платформу

```bash
cd /opt
git clone <repository-url> telegram-bots-platform
cd telegram-bots-platform
chmod +x *.sh scripts/*.sh
```

### 2. Первичная настройка сервера

```bash
sudo ./setup-server.sh
```

Этот скрипт:
- Установит все необходимые пакеты
- Настроит безопасный SSH
- Установит и настроит firewall
- Установит PostgreSQL, Docker, Nginx
- Развернет систему мониторинга
- Установит Oh-My-Zsh

⚠️ **ВАЖНО**: Сохраните SSH ключ после установки!

### 3. Добавить первого бота

```bash
sudo ./add-bot.sh
```

Скрипт запросит:
- Название бота
- Telegram Bot Token
- Домен
- Тип бота (простой/с веб-интерфейсом/Node.js)
- Порты (или автоматически)
- GitHub репозиторий (опционально)

### 4. Проверить статус

```bash
./monitor-status.sh
```

## 📁 Структура проекта

```
/opt/telegram-bots-platform/
├── setup-server.sh              # Первичная настройка
├── add-bot.sh                   # Добавление бота
├── remove-bot.sh                # Удаление бота
├── monitor-status.sh            # Статус системы
├── scripts/
│   ├── utils.sh
│   ├── database.sh
│   └── monitoring.sh
├── configs/
│   ├── nginx/
│   ├── grafana/
│   └── postgres/
└── bots/
    └── [bot-name]/
        ├── docker-compose.yml
        ├── .env
        ├── app/
        └── logs/
```

## 🛠️ Управление ботами

### Добавить бота

```bash
bot-add
```

### Удалить бота

```bash
bot-remove [bot-name]
```

### Просмотр логов

```bash
docker logs -f [bot-name]_bot
```

### Перезапуск бота

```bash
cd /opt/telegram-bots-platform/bots/[bot-name]
docker compose restart
```

## 📊 Мониторинг

### Grafana

URL: `http://YOUR_SERVER_IP:3000`
- Логин: `admin`
- Пароль: в `/root/.platform/monitoring_credentials`

### Prometheus

URL: `http://YOUR_SERVER_IP:9090`

## 🔒 Безопасность

### SSH

- Порт: `2222` (настраиваемый)
- Авторизация только по ключу
- Root вход отключен
- Fail2Ban активен

### Firewall (UFW)

Открытые порты:
- 2222 (SSH)
- 80 (HTTP)
- 443 (HTTPS)
- 3000 (Grafana)

### SSL Сертификаты

Автоматическое получение от Let's Encrypt для каждого бота.

## 🗄️ База данных

### Подключение к PostgreSQL

```bash
sudo -u postgres psql
```

### Список баз данных

```bash
\l
```

### Подключиться к базе бота

```bash
\c [bot-name]_db
```

## 🔧 Расширенные настройки

### Изменение конфигурации Nginx

```bash
sudo nano /etc/nginx/sites-available/[bot-name].conf
sudo nginx -t
sudo systemctl reload nginx
```

### Изменение переменных окружения бота

```bash
sudo nano /opt/telegram-bots-platform/bots/[bot-name]/.env
cd /opt/telegram-bots-platform/bots/[bot-name]
docker compose restart
```

## 📝 Алиасы Zsh

После установки доступны:

- `bots` - перейти в каталог ботов
- `bot-add` - добавить бота
- `bot-remove` - удалить бота
- `bot-status` - статус всех ботов
- `dps` - список контейнеров
- `dlog` - логи контейнера
- `pgcli` - PostgreSQL CLI

## 🆘 Решение проблем

### Бот не запускается

```bash
cd /opt/telegram-bots-platform/bots/[bot-name]
docker compose logs
```

### Проблемы с SSL

```bash
sudo certbot certificates
sudo certbot renew --dry-run
```

### Проверка портов

```bash
sudo netstat -tulpn | grep LISTEN
```

## 📚 Документация репозиториев

- [Digital-Time-Capsule](https://github.com/f2re/Digital-Time-Capsule)
- [Raffle-Web3-Bot](https://github.com/f2re/raffle-web3-bot)
- [BG-Remove-Bot](https://github.com/f2re/bg-remove-bot)
- [Match3-MiniApp](https://github.com/f2re/match3-miniapp)

## 🤝 Contributing

1. Fork this repository
2. Create a branch for your feature (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 Лицензия

MIT License - см. файл `LICENSE` для подробностей.

## 📞 Поддержка

Для вопросов и предложений создайте Issue в репозитории.

---
Сделано с ❤️ для автоматизации управления Telegram-ботами