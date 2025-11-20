# 📊 Telegram Bots Platform - Monitoring Stack

Comprehensive monitoring solution with **Grafana**, **Prometheus**, **Loki**, and **cAdvisor** for complete observability of your Telegram bots platform.

## 🎯 Features

### Metrics Collection
- **System Metrics**: CPU, Memory, Disk, Network (via Node Exporter)
- **PostgreSQL Metrics**: Connections, transactions, cache hit ratio, locks (via PostgreSQL Exporter)
- **Docker Metrics**: Container CPU, memory, network I/O (via cAdvisor)
- **Nginx Metrics**: Request rates, response times (via Nginx Exporter)
- **Application Metrics**: Custom metrics from your bots (if exposed)

### Log Aggregation
- **Loki**: Centralized log storage and querying
- **Promtail**: Automatic log collection from:
  - System logs (`/var/log/*.log`)
  - Nginx access and error logs
  - Docker container logs
  - Bot-specific logs
  - PostgreSQL logs

### Visualization
- **4 Pre-built Dashboards**:
  1. **System Overview**: Server health, CPU, memory, disk, network
  2. **PostgreSQL Overview**: Database performance, connections, queries
  3. **Bots Overview**: All bots monitoring at a glance
  4. **Logs Dashboard**: Real-time log viewing and searching

### Automation
- **Automatic Bot Discovery**: Scans and registers all bots automatically
- **Auto-Dashboard Creation**: Creates custom dashboard for each bot
- **Auto-Integration**: New bots are automatically monitored when added

## 🚀 Quick Start

### Initial Deployment

The monitoring stack is automatically deployed during server setup if `MONITORING_ENABLED=true` in your `config.env`.

To deploy manually:

```bash
sudo bash /opt/telegram-bots-platform/scripts/monitoring-manage.sh deploy
```

### Access Dashboards

After deployment, access your monitoring at:

- **Grafana**: `http://your-server-ip:3000`
- **Prometheus**: `http://your-server-ip:9090`

**Default Credentials:**
- Username: `admin`
- Password: Stored in `/root/.platform/monitoring_credentials`

## 🔧 Management

### Management Script

Use the monitoring management script for all operations:

```bash
sudo bash /opt/telegram-bots-platform/scripts/monitoring-manage.sh
```

**Available Commands:**

| Command | Description |
|---------|-------------|
| `deploy` | Deploy the monitoring stack |
| `start` | Start all monitoring services |
| `stop` | Stop all monitoring services |
| `restart` | Restart all monitoring services |
| `status` | Show status of all services |
| `scan` | Scan and register all bots |
| `logs` | View logs from monitoring services |
| `credentials` | Display Grafana credentials |
| `remove` | Remove monitoring stack |

### Command Line Usage

```bash
# Deploy monitoring
sudo bash scripts/monitoring-manage.sh deploy

# Check status
sudo bash scripts/monitoring-manage.sh status

# Restart services
sudo bash scripts/monitoring-manage.sh restart

# Scan for new bots
sudo bash scripts/monitoring-manage.sh scan
```

## 📊 Dashboards

### 1. System Overview
Monitor your server's health:
- CPU usage per core
- Memory usage (used, cached, buffers)
- Disk usage and I/O
- Network traffic
- Running containers count

### 2. PostgreSQL Overview
Database performance monitoring:
- Active connections per database
- Transactions per second (commits/rollbacks)
- Cache hit ratio
- Database sizes
- Tuple operations (inserts, updates, deletes)
- Deadlocks and conflicts

### 3. Bots Overview
All bots at a glance:
- Running bots count
- CPU usage per bot
- Memory usage per bot
- Network I/O per bot
- Database connections per bot
- Database sizes per bot

### 4. Logs Dashboard
Centralized log viewing:
- Real-time bot logs
- Nginx error logs
- Docker container logs
- System logs
- Log volume by source
- Searchable and filterable

### 5. Individual Bot Dashboards
Each bot gets its own dashboard with:
- Bot status (UP/DOWN)
- Container metrics (CPU, Memory, Network)
- Database metrics (connections, transactions, size)
- Recent logs

## 🔍 Bot Scanner

The bot scanner automatically discovers and monitors all bots:

```bash
sudo bash /opt/telegram-bots-platform/scripts/scan-and-monitor-bots.sh
```

**What it does:**
1. Scans `/opt/telegram-bots-platform/bots/` for all bots
2. Reads bot metadata from `bot_info.json`
3. Adds Prometheus scrape configs for each bot
4. Creates Grafana dashboard for each bot
5. Adds PostgreSQL exporter for each bot's database
6. Restarts services to apply changes

**When to run:**
- After deploying monitoring stack initially
- After adding/removing bots manually
- Automatically runs when you add a bot via `add-bot.sh`

## 📁 Directory Structure

```
/opt/telegram-bots-platform/monitoring-stack/
├── docker-compose.yml          # Main compose file
├── .env                        # Environment variables
├── prometheus/
│   └── prometheus.yml          # Prometheus configuration
├── loki/
│   └── loki-config.yml        # Loki configuration
├── promtail/
│   └── promtail-config.yml    # Log collection config
└── grafana/
    ├── provisioning/
    │   ├── datasources/        # Auto-configured datasources
    │   └── dashboards/         # Dashboard provider config
    └── dashboards/             # Dashboard JSON files
        ├── system-overview.json
        ├── postgresql-overview.json
        ├── bots-overview.json
        ├── logs-dashboard.json
        └── [bot-name]-dashboard.json
```

## 🔌 Integration

### Automatic Integration

When you add a bot using `add-bot.sh`, it's automatically registered with the monitoring system.

### Manual Integration

To manually register a bot:

```bash
# Run the scanner
sudo bash /opt/telegram-bots-platform/scripts/scan-and-monitor-bots.sh
```

## 📈 Custom Metrics

To expose custom metrics from your bot:

### 1. Implement /metrics Endpoint

Your bot should expose a `/metrics` endpoint in Prometheus format:

```python
# Python example with prometheus_client
from prometheus_client import Counter, Histogram, generate_latest

requests_total = Counter('bot_requests_total', 'Total requests')
request_duration = Histogram('bot_request_duration_seconds', 'Request duration')

@app.route('/metrics')
def metrics():
    return generate_latest()
```

### 2. Bot Auto-Registration

The scanner automatically adds your bot's metrics endpoint to Prometheus if:
- Your `bot_info.json` contains `backend_port`
- Your bot exposes metrics at `http://localhost:backend_port/metrics`

## 🛠️ Troubleshooting

### Services Not Starting

Check Docker logs:
```bash
cd /opt/telegram-bots-platform/monitoring-stack
docker compose logs
```

### Bot Not Appearing in Grafana

1. Check if bot is running:
   ```bash
   docker ps | grep bot-name
   ```

2. Re-scan bots:
   ```bash
   sudo bash scripts/scan-and-monitor-bots.sh
   ```

3. Restart Grafana:
   ```bash
   docker restart grafana
   ```

### No Data in Dashboards

1. Check Prometheus targets:
   - Open `http://your-server-ip:9090/targets`
   - Ensure all targets are "UP"

2. Verify exporters are running:
   ```bash
   docker ps | grep exporter
   ```

3. Check firewall rules:
   ```bash
   sudo ufw status
   ```

### Logs Not Appearing

1. Check Promtail is running:
   ```bash
   docker logs promtail
   ```

2. Verify Loki is accessible:
   ```bash
   curl http://localhost:3100/ready
   ```

3. Check log file permissions:
   ```bash
   ls -la /opt/telegram-bots-platform/bots/*/logs/
   ```

## 🔐 Security

### Credentials Storage

All monitoring credentials are stored securely in:
- `/root/.platform/monitoring_credentials`
- Permissions: `600` (read/write for root only)

### Network Security

- Grafana: Accessible on port 3000
- Prometheus: Accessible on port 9090
- Loki: Accessible on port 3100
- All ports should be firewalled and accessed via SSH tunnel or VPN

### Recommended: Nginx Reverse Proxy

Add authentication to Grafana via Nginx:

```nginx
location /grafana/ {
    proxy_pass http://localhost:3000/;
    auth_basic "Restricted";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

## 📊 Data Retention

### Prometheus
- Default: 30 days
- Configure in `docker-compose.yml`: `--storage.tsdb.retention.time=30d`

### Loki
- Default: 31 days (744 hours)
- Configure in `loki/loki-config.yml`: `retention_period: 744h`

### Disk Space

Monitor disk usage:
```bash
docker system df
```

Clean up old data:
```bash
docker system prune -a --volumes
```

## 🎓 Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [PromQL Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)

## 🤝 Support

For issues or questions:
1. Check logs: `docker compose logs`
2. Verify configuration files
3. Re-run bot scanner
4. Restart monitoring stack

## 📝 License

Part of the Telegram Bots Platform project.
