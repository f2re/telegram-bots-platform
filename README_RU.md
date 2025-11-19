# 🤖 Платформа для Telegram Ботов - Полное Руководство

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Debian%2012-blue)](https://www.debian.org/)
[![Docker](https://img.shields.io/badge/Docker-Supported-blue)](https://www.docker.com/)

## 📚 Содержание

- [Введение](#введение)
- [Быстрый старт](#быстрый-старт)
- [Управление ботами](#управление-ботами)
  - [Команды Docker](#команды-docker)
  - [Просмотр логов](#просмотр-логов)
  - [Обновление ботов](#обновление-ботов)
- [Мониторинг](#мониторинг)
- [База данных PostgreSQL](#база-данных-postgresql)
- [SSL Сертификаты](#ssl-сертификаты)
- [Решение проблем](#решение-проблем)
- [Резервное копирование](#резервное-копирование)

---

## Введение

Это полнофункциональная платформа для развёртывания и управления множественными Telegram-ботами на выделенном сервере Debian 12 с поддержкой:

- ✅ Автоматической настройки безопасного SSH
- ✅ Firewall (UFW) и Fail2Ban для защиты
- ✅ PostgreSQL с изолированными БД для каждого бота
- ✅ Nginx с автоматическим SSL (Let's Encrypt)
- ✅ Docker для изоляции приложений
- ✅ Grafana + Prometheus для мониторинга
- ✅ Автоматической интеграции с системой мониторинга

---

## Быстрый старт

### 1. Клонирование репозитория

```bash
cd /opt
git clone https://github.com/f2re/telegram-bots-platform.git
cd telegram-bots-platform
chmod +x *.sh scripts/*.sh
```

### 2. Запуск мастера конфигурации

```bash
sudo ./config-wizard.sh
```

Ответьте на вопросы для создания файла `config.env` с вашими настройками.

### 3. Первичная настройка сервера

```bash
sudo ./setup-server.sh
```

**Что делает этот скрипт:**
- Устанавливает Docker, PostgreSQL, Nginx
- Настраивает SSH на безопасный порт
- Конфигурирует firewall (UFW)
- Устанавливает Fail2Ban
- Разворачивает Grafana и Prometheus
- Устанавливает Oh-My-Zsh с полезными алиасами

⚠️ **ВАЖНО:** Сохраните SSH ключ после установки! Находится в `/home/<user>/.ssh/id_rsa`

### 4. Добавление первого бота

```bash
sudo ./add-bot.sh
```

Скрипт запросит:
- Название бота (только буквы, цифры, дефисы)
- Telegram Bot Token (получить у @BotFather)
- Доменное имя (например: mybot.example.com)
- GitHub репозиторий с кодом бота
- Порты (или автоматически)

---

## Управление ботами

### Использование скрипта bot-manage.sh

Самый удобный способ управления ботами:

```bash
# Интерактивный режим
sudo ./bot-manage.sh

# Командная строка
sudo ./bot-manage.sh list                    # Список всех ботов
sudo ./bot-manage.sh info mybot              # Информация о боте
sudo ./bot-manage.sh start mybot             # Запустить бота
sudo ./bot-manage.sh stop mybot              # Остановить бота
sudo ./bot-manage.sh restart mybot           # Перезапустить бота
sudo ./bot-manage.sh logs mybot 200          # Показать 200 последних строк логов
sudo ./bot-manage.sh update mybot            # Обновить бота из Git
sudo ./bot-manage.sh rebuild mybot           # Пересобрать Docker образы
sudo ./bot-manage.sh backup mybot            # Создать резервную копию
```

### Команды Docker

Прямое управление через Docker Compose:

#### Запуск бота

```bash
cd /opt/telegram-bots-platform/bots/<bot-name>
docker compose up -d
```

#### Остановка бота

```bash
cd /opt/telegram-bots-platform/bots/<bot-name>
docker compose stop
```

#### Перезапуск бота

```bash
cd /opt/telegram-bots-platform/bots/<bot-name>
docker compose restart
```

#### Полная пересборка

```bash
cd /opt/telegram-bots-platform/bots/<bot-name>
docker compose down
docker compose build --no-cache
docker compose up -d
```

#### Проверка статуса

```bash
# Все контейнеры
docker ps

# Контейнеры конкретного бота
cd /opt/telegram-bots-platform/bots/<bot-name>
docker compose ps
```

#### Использование ресурсов

```bash
# Реальное время
docker stats

# Разовый снимок
docker stats --no-stream
```

### Просмотр логов

#### Через Docker

```bash
# Последние 100 строк с отслеживанием в реальном времени
docker logs -f --tail 100 <bot-name>_bot

# Все логи
docker logs <bot-name>_bot

# Логи с временными метками
docker logs -t <bot-name>_bot

# Логи за последний час
docker logs --since 1h <bot-name>_bot
```

#### Через Docker Compose

```bash
cd /opt/telegram-bots-platform/bots/<bot-name>

# Все сервисы
docker compose logs -f

# Конкретный сервис
docker compose logs -f bot

# Последние 50 строк
docker compose logs --tail=50
```

#### Файловые логи

```bash
# Логи бота (если настроено)
tail -f /opt/telegram-bots-platform/bots/<bot-name>/logs/bot.log

# Логи Nginx
tail -f /var/log/nginx/<bot-name>_access.log
tail -f /var/log/nginx/<bot-name>_error.log
```

### Обновление ботов

#### Автоматическое обновление

```bash
sudo ./bot-manage.sh update <bot-name>
```

Эта команда:
1. Получает последние изменения из Git
2. Пересобирает Docker образы
3. Перезапускает контейнеры

#### Ручное обновление

```bash
cd /opt/telegram-bots-platform/bots/<bot-name>/app

# Получить обновления
git pull

# Вернуться в директорию бота
cd ..

# Пересобрать и перезапустить
docker compose build --no-cache
docker compose up -d
```

#### Откат к предыдущей версии

```bash
cd /opt/telegram-bots-platform/bots/<bot-name>/app

# Посмотреть историю коммитов
git log --oneline

# Откатиться к конкретному коммиту
git reset --hard <commit-hash>

# Пересобрать
cd ..
docker compose build --no-cache
docker compose up -d
```

### Изменение переменных окружения

```bash
# Редактировать .env файл
nano /opt/telegram-bots-platform/bots/<bot-name>/.env

# Перезапустить для применения изменений
cd /opt/telegram-bots-platform/bots/<bot-name>
docker compose restart
```

**Основные переменные:**

```env
BOT_TOKEN=your_telegram_bot_token
DATABASE_URL=postgresql://user:password@host:5432/dbname
PORT=8000
ENVIRONMENT=production
LOG_LEVEL=INFO
```

---

## Мониторинг

### Grafana

**URL:** `http://YOUR_SERVER_IP:3000`

**Учётные данные:**
- Логин: `admin`
- Пароль: смотрите в `/root/.platform/monitoring_credentials`

```bash
cat /root/.platform/monitoring_credentials
```

### Доступные дашборды

После добавления бота автоматически создаётся дашборд с метриками:

- 📊 **Database Connections** - Активные подключения к БД
- 💾 **Database Size** - Размер базы данных
- ⚡ **Transactions Per Second** - TPS (commits/rollbacks)
- 🖥️ **CPU Usage** - Использование процессора контейнерами
- 💾 **Memory Usage** - Использование памяти
- 🌐 **Network I/O** - Сетевой трафик

### Prometheus

**URL:** `http://YOUR_SERVER_IP:9090`

Используйте для прямых запросов метрик:

```promql
# Использование CPU контейнером
rate(container_cpu_usage_seconds_total{name=~".*mybot.*"}[5m]) * 100

# Память контейнера
container_memory_usage_bytes{name=~".*mybot.*"}

# Подключения к PostgreSQL
pg_stat_database_numbackends{datname="mybot_db"}
```

### Ручная настройка мониторинга для бота

Если бот был добавлен до обновления платформы:

```bash
sudo bash /opt/telegram-bots-platform/scripts/setup-grafana-bot.sh <bot-name> <db-name>
```

---

## База данных PostgreSQL

### Подключение к PostgreSQL

```bash
# Подключиться как postgres
sudo -u postgres psql

# Подключиться к конкретной базе
sudo -u postgres psql -d <bot-name>_db
```

### Полезные команды

```sql
-- Список всех баз данных
\l

-- Подключиться к базе
\c mybot_db

-- Список таблиц
\dt

-- Описание таблицы
\d table_name

-- Список пользователей
\du

-- Размер базы данных
SELECT pg_size_pretty(pg_database_size('mybot_db'));

-- Активные подключения
SELECT * FROM pg_stat_activity WHERE datname = 'mybot_db';

-- Выход
\q
```

### Создание резервной копии БД

```bash
# Резервная копия одной базы
sudo -u postgres pg_dump mybot_db > mybot_backup.sql

# Резервная копия с сжатием
sudo -u postgres pg_dump mybot_db | gzip > mybot_backup.sql.gz

# Резервная копия всех баз
sudo -u postgres pg_dumpall > all_databases_backup.sql
```

### Восстановление из резервной копии

```bash
# Восстановить базу
sudo -u postgres psql mybot_db < mybot_backup.sql

# Восстановить из сжатого архива
gunzip -c mybot_backup.sql.gz | sudo -u postgres psql mybot_db
```

### Доступ к базе из бота

Боты подключаются к PostgreSQL через `host.docker.internal`:

```env
DATABASE_URL=postgresql://mybot_user:password@host.docker.internal:5432/mybot_db
```

---

## SSL Сертификаты

### Автоматическое получение

Скрипт `add-bot.sh` автоматически:
1. Проверяет DNS записи
2. Запрашивает SSL сертификат от Let's Encrypt
3. Настраивает автоматическое обновление

### Ручной запрос сертификата

```bash
sudo bash /opt/telegram-bots-platform/scripts/setup-ssl.sh mybot.example.com admin@example.com
```

### Проверка сертификатов

```bash
# Список всех сертификатов
sudo certbot certificates

# Информация о конкретном сертификате
sudo certbot certificates -d mybot.example.com
```

### Обновление сертификатов

```bash
# Тестовый прогон (dry-run)
sudo certbot renew --dry-run

# Принудительное обновление
sudo certbot renew --force-renewal

# Обновление конкретного сертификата
sudo certbot renew --cert-name mybot.example.com
```

### Проблемы с SSL

#### DNS не настроен

Если DNS записи не указывают на сервер, создаётся self-signed сертификат.

**Решение:**
1. Настройте A-запись в DNS:
   ```
   Тип: A
   Имя: mybot (или @ для корневого домена)
   Значение: <IP_СЕРВЕРА>
   TTL: 300
   ```
2. Подождите 5-30 минут
3. Проверьте:
   ```bash
   dig mybot.example.com +short
   ```
4. Запросите сертификат заново:
   ```bash
   sudo bash /opt/telegram-bots-platform/scripts/setup-ssl.sh mybot.example.com admin@example.com
   ```

#### Достигнут лимит Let's Encrypt

Let's Encrypt ограничивает до 5 сертификатов в неделю на домен.

**Решение:**
- Подождите 7 дней
- Используйте поддомены (bot1.example.com, bot2.example.com)
- Используйте wildcard сертификат (*.example.com) - требует DNS валидации

---

## Решение проблем

### Бот не запускается

#### 1. Проверьте логи

```bash
cd /opt/telegram-bots-platform/bots/<bot-name>
docker compose logs
```

#### 2. Проверьте статус контейнеров

```bash
docker compose ps
```

#### 3. Проверьте переменные окружения

```bash
cat .env
```

#### 4. Проверьте подключение к БД

```bash
# Внутри контейнера
docker compose exec bot bash
env | grep DATABASE
```

#### 5. Пересоберите контейнеры

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

### Проблемы с правами доступа

```bash
# Исправить все права
sudo bash /opt/telegram-bots-platform/scripts/fix-permissions.sh

# Для конкретного бота
sudo chown -R root:root /opt/telegram-bots-platform/bots/<bot-name>
sudo chmod 777 /opt/telegram-bots-platform/bots/<bot-name>/logs
sudo chmod 777 /opt/telegram-bots-platform/bots/<bot-name>/data
sudo chmod 600 /opt/telegram-bots-platform/bots/<bot-name>/.env
```

### Nginx ошибки

#### Проверить конфигурацию

```bash
sudo nginx -t
```

#### Перезагрузить Nginx

```bash
sudo systemctl reload nginx
```

#### Логи Nginx

```bash
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/<bot-name>_error.log
```

### PostgreSQL проблемы

#### Не удаётся подключиться

```bash
# Проверить статус
sudo systemctl status postgresql

# Перезапустить
sudo systemctl restart postgresql

# Проверить логи
sudo tail -f /var/log/postgresql/postgresql-15-main.log
```

#### Проверить подключения

```sql
-- Как postgres
SELECT * FROM pg_stat_activity;
```

### Docker проблемы

#### Очистка неиспользуемых ресурсов

```bash
# Удалить остановленные контейнеры
docker container prune

# Удалить неиспользуемые образы
docker image prune -a

# Удалить неиспользуемые volumes
docker volume prune

# Полная очистка (осторожно!)
docker system prune -a --volumes
```

#### Перезапуск Docker

```bash
sudo systemctl restart docker
```

### Проверка портов

```bash
# Все открытые порты
sudo netstat -tulpn | grep LISTEN

# Конкретный порт
sudo netstat -tulpn | grep :8000

# Через ss
sudo ss -tulpn | grep LISTEN
```

### Проверка firewall

```bash
# Статус UFW
sudo ufw status verbose

# Разрешить порт
sudo ufw allow 8000/tcp

# Перезагрузить правила
sudo ufw reload
```

---

## Резервное копирование

### Автоматическое резервное копирование

```bash
# Резервная копия бота (БД + файлы)
sudo ./bot-manage.sh backup <bot-name>
```

Результат:
- `/opt/telegram-bots-platform/backups/<bot-name>_YYYYMMDD_HHMMSS.tar.gz` - файлы
- `/opt/telegram-bots-platform/backups/<bot-name>_YYYYMMDD_HHMMSS.sql` - база данных

### Ручное резервное копирование

#### База данных

```bash
sudo -u postgres pg_dump <bot-name>_db > backup_$(date +%Y%m%d).sql
```

#### Файлы бота

```bash
tar -czf bot_backup_$(date +%Y%m%d).tar.gz /opt/telegram-bots-platform/bots/<bot-name>
```

#### Вся платформа

```bash
tar -czf platform_backup_$(date +%Y%m%d).tar.gz \
  /opt/telegram-bots-platform \
  /etc/nginx/sites-available \
  /root/.platform
```

### Восстановление

#### База данных

```bash
sudo -u postgres psql <bot-name>_db < backup.sql
```

#### Файлы

```bash
tar -xzf bot_backup.tar.gz -C /
```

### Настройка автоматического резервного копирования

Создайте cron задачу:

```bash
sudo crontab -e
```

Добавьте:

```cron
# Ежедневное резервное копирование в 2:00 AM
0 2 * * * /opt/telegram-bots-platform/bot-manage.sh backup mybot >> /var/log/backup.log 2>&1

# Еженедельное резервное копирование всех ботов в воскресенье в 3:00 AM
0 3 * * 0 for bot in /opt/telegram-bots-platform/bots/*; do /opt/telegram-bots-platform/bot-manage.sh backup $(basename $bot); done >> /var/log/backup.log 2>&1
```

---

## Краткая справка по командам

### Управление ботами

```bash
# Список ботов
sudo ./bot-manage.sh list

# Запуск/остановка/перезапуск
sudo ./bot-manage.sh start <bot-name>
sudo ./bot-manage.sh stop <bot-name>
sudo ./bot-manage.sh restart <bot-name>

# Логи
sudo ./bot-manage.sh logs <bot-name> 100

# Обновление
sudo ./bot-manage.sh update <bot-name>
```

### Docker

```bash
# Статус контейнеров
docker ps

# Логи
docker logs -f <container-name>

# Перезапуск
cd /opt/telegram-bots-platform/bots/<bot-name>
docker compose restart
```

### PostgreSQL

```bash
# Подключение
sudo -u postgres psql -d <bot-name>_db

# Резервная копия
sudo -u postgres pg_dump <bot-name>_db > backup.sql
```

### Nginx

```bash
# Тест конфигурации
sudo nginx -t

# Перезагрузка
sudo systemctl reload nginx

# Логи
sudo tail -f /var/log/nginx/<bot-name>_error.log
```

### SSL

```bash
# Список сертификатов
sudo certbot certificates

# Обновление
sudo certbot renew
```

### Мониторинг

```bash
# Grafana
http://<SERVER_IP>:3000

# Prometheus
http://<SERVER_IP>:9090
```

---

## Поддержка

Для вопросов и предложений создайте Issue в репозитории:
https://github.com/f2re/telegram-bots-platform/issues

---

**Сделано с ❤️ для автоматизации управления Telegram-ботами**
