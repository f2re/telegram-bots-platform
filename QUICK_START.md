# 🚀 Quick Start - Bot Management

## 🔐 View All Credentials

**Quick access to all passwords, URLs, and connection info:**

```bash
sudo ./show-credentials.sh
```

This shows:
- PostgreSQL admin & bot database credentials
- Grafana dashboard (URL + login)
- Prometheus monitoring URLs
- Redis connection details
- Nginx configs & SSL certificates
- Docker containers status
- Bot tokens (masked for security)
- All config file paths

**Command line usage:**
```bash
sudo ./show-credentials.sh all        # Show everything
sudo ./show-credentials.sh postgres   # Just PostgreSQL
sudo ./show-credentials.sh grafana    # Just Grafana
sudo ./show-credentials.sh export     # Export to file
```

Also available from:
- Bot management menu (option 10)
- Platform orchestrator (option 7)

---

## Managing Your Bots

### Easy Way (Recommended)
```bash
cd ~/telegram-bots-platform
./bot-ctl
```
This will automatically use sudo and show you the management menu.

### Interactive Management
```bash
sudo ./bot-manage.sh
```

You'll see a menu like this:
```
╔═══════════════════════════════════════════════════════╗
║         🤖 УПРАВЛЕНИЕ TELEGRAM БОТАМИ 🤖             ║
╚═══════════════════════════════════════════════════════╝

  1) Список всех ботов
  2) Информация о боте
  3) Запустить бота
  4) Остановить бота
  5) Перезапустить бота
  6) Показать логи
  7) Обновить бота (git pull + rebuild)
  8) Пересобрать бота
  9) Создать резервную копию
  0) Выход

Ваш выбор: 3
```

When you select an option that requires a bot, you'll see:
```
Запустить бота:

  1) ● bg-remove-bot
  2) ● another-bot
  0) Отмена

Ваш выбор [0-2]: 1
```

● Green = Running
● Red = Stopped

### Command Line Usage
```bash
# List all bots
sudo ./bot-manage.sh list

# Start a specific bot
sudo ./bot-manage.sh start bg-remove-bot

# Stop a bot
sudo ./bot-manage.sh stop bg-remove-bot

# Restart a bot
sudo ./bot-manage.sh restart bg-remove-bot

# View logs
sudo ./bot-manage.sh logs bg-remove-bot

# Show bot info
sudo ./bot-manage.sh info bg-remove-bot
```

## Adding a New Bot
```bash
sudo ./add-bot.sh
```

Follow the prompts:
1. Enter bot name (lowercase, alphanumeric)
2. Enter Telegram bot token
3. Enter domain name
4. Enter GitHub repository URL
5. Confirm and wait for setup

## Removing a Bot
```bash
sudo ./remove-bot.sh
```

You'll see a numbered list of bots to remove. Select the number and confirm.

## Platform Orchestrator
```bash
./platform-orchestrator.sh
```

One-stop shop for all platform management:
- Server setup
- Add bot
- Manage bots
- Fix permissions
- Setup monitoring
- Restart platform

## Troubleshooting

### Permission Denied
Make sure you're using `sudo`:
```bash
sudo ./bot-manage.sh
```

Or use the wrapper:
```bash
./bot-ctl
```

### Bot Not Found
Check if bot exists:
```bash
ls -la /opt/telegram-bots-platform/bots/
```

### Docker Issues
Check Docker status:
```bash
sudo systemctl status docker
```

Restart Docker:
```bash
sudo systemctl restart docker
```

### Logs Not Showing
Make sure the bot is running:
```bash
cd /opt/telegram-bots-platform/bots/YOUR_BOT_NAME
sudo docker compose ps
```

View logs directly:
```bash
cd /opt/telegram-bots-platform/bots/YOUR_BOT_NAME
sudo docker compose logs -f
```

## File Locations

- **Bots Directory**: `/opt/telegram-bots-platform/bots/`
- **Bot Configuration**: `/opt/telegram-bots-platform/bots/BOT_NAME/.env`
- **Nginx Config**: `/etc/nginx/sites-available/BOT_NAME.conf`
- **SSL Certificates**: `/etc/letsencrypt/live/DOMAIN/`
- **Backups**: `/opt/telegram-bots-platform/backups/`

## Common Operations

### Check Bot Status
```bash
cd /opt/telegram-bots-platform/bots/YOUR_BOT_NAME
sudo docker compose ps
```

### Restart Bot Manually
```bash
cd /opt/telegram-bots-platform/bots/YOUR_BOT_NAME
sudo docker compose restart
```

### Update Bot Code
```bash
cd /opt/telegram-bots-platform/bots/YOUR_BOT_NAME/app
git pull
cd ..
sudo docker compose up --build -d
```

### Check Database Connection
```bash
sudo -u postgres psql -l
```

## Need Help?

1. Check logs: `sudo ./bot-manage.sh logs <bot-name>`
2. Check bot info: `sudo ./bot-manage.sh info <bot-name>`
3. Verify permissions: `sudo ./scripts/fix-permissions.sh`
4. Read full docs: `cat README_RU.md`
