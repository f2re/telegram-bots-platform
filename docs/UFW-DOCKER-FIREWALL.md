# UFW and Docker Network Configuration

## Overview

This platform uses a **static Docker network** (`bots_shared_network`) with a fixed subnet `172.25.0.0/16` and gateway `172.25.0.1`. PostgreSQL listens on this gateway IP, allowing all bot containers to access the database through a consistent, predictable address.

**Critical**: UFW (Uncomplicated Firewall) must be configured to allow traffic from the Docker subnet, otherwise containers cannot communicate with PostgreSQL or each other.

## Network Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Host System                          │
│                                                         │
│  PostgreSQL: 172.25.0.1:5432 ────────┐                │
│                                       │                │
│  ┌────────────────────────────────────┼──────────────┐ │
│  │  Docker Network: bots_shared_network               │ │
│  │  Subnet: 172.25.0.0/16             │               │ │
│  │  Gateway: 172.25.0.1 ◄─────────────┘               │ │
│  │                                                     │ │
│  │  ┌──────────────┐  ┌──────────────┐               │ │
│  │  │   Bot 1      │  │   Bot 2      │               │ │
│  │  │ 172.25.0.x   │  │ 172.25.0.y   │               │ │
│  │  └──────────────┘  └──────────────┘               │ │
│  │                                                     │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                         │
│  UFW Firewall: MUST ALLOW 172.25.0.0/16                │
└─────────────────────────────────────────────────────────┘
```

## Required UFW Rules

### 1. Allow Docker Subnet to PostgreSQL
```bash
sudo ufw allow from 172.25.0.0/16 to any port 5432 comment 'PostgreSQL Docker'
```

This rule allows any container in the Docker network to connect to PostgreSQL on port 5432.

### 2. Allow Docker Subnet Traffic
```bash
sudo ufw allow from 172.25.0.0/16 comment 'Docker bots_shared_network'
```

This rule allows all traffic originating from the Docker subnet, enabling:
- Container-to-host communication
- Container-to-container communication through host
- Access to other host services if needed

## Automatic Configuration

All setup scripts now automatically configure UFW rules:

### During Server Setup
```bash
./setup-server.sh
```
The `setup_firewall()` function adds Docker subnet rules.

### During Network Setup
```bash
./setup-static-network.sh
```
Automatically adds UFW rules after creating the network.

### During PostgreSQL Setup
```bash
./platform.sh
# Select option: Install PostgreSQL
```
Adds UFW rules when configuring PostgreSQL for Docker network.

## Manual Configuration

If you need to manually fix UFW rules:

### Quick Fix Script
```bash
sudo ./scripts/fix-ufw-docker.sh
```

This script:
1. Checks UFW status
2. Verifies existing rules
3. Adds missing rules for Docker subnet
4. Reloads UFW
5. Shows final configuration

### Manual Steps

1. **Check current UFW status:**
   ```bash
   sudo ufw status numbered
   ```

2. **Add PostgreSQL rule:**
   ```bash
   sudo ufw allow from 172.25.0.0/16 to any port 5432 comment 'PostgreSQL Docker'
   ```

3. **Add Docker subnet rule:**
   ```bash
   sudo ufw allow from 172.25.0.0/16 comment 'Docker bots_shared_network'
   ```

4. **Reload UFW:**
   ```bash
   sudo ufw reload
   ```

5. **Verify rules:**
   ```bash
   sudo ufw status verbose | grep 172.25
   ```

## Verification

### Check UFW Rules
```bash
sudo ufw status numbered | grep 172.25
```

Expected output:
```
[ X] 5432                   ALLOW IN    172.25.0.0/16             # PostgreSQL Docker
[ Y] Anywhere               ALLOW IN    172.25.0.0/16             # Docker bots_shared_network
```

### Test Database Connectivity from Container

1. **Start a test container:**
   ```bash
   docker run --rm --network bots_shared_network -it postgres:15 psql -h 172.25.0.1 -U postgres
   ```

2. **Expected result:** Successfully connects to PostgreSQL

### Check Container Network
```bash
# Verify network exists
docker network ls | grep bots_shared_network

# Inspect network configuration
docker network inspect bots_shared_network

# Expected gateway: 172.25.0.1
```

## Troubleshooting

### Problem: Containers can't connect to PostgreSQL

**Symptoms:**
- Connection timeout
- "Connection refused" errors
- Database connection errors in bot logs

**Solution:**
1. Check UFW rules:
   ```bash
   sudo ufw status | grep 172.25
   ```

2. If rules are missing, run:
   ```bash
   sudo ./scripts/fix-ufw-docker.sh
   ```

3. Restart affected containers:
   ```bash
   cd /opt/telegram-bots-platform/bots/YOUR_BOT
   docker compose restart
   ```

### Problem: UFW is blocking Docker traffic

**Check firewall logs:**
```bash
sudo grep UFW /var/log/syslog | grep 172.25
```

If you see BLOCK entries for 172.25.x.x addresses:
```bash
sudo ./scripts/fix-ufw-docker.sh
```

### Problem: Need to reset UFW rules

**Complete reset and reconfiguration:**
```bash
# WARNING: This removes ALL UFW rules!
sudo ufw --force reset

# Reconfigure
sudo ./setup-server.sh  # Run full setup
# OR
sudo ./scripts/fix-ufw-docker.sh  # Just fix Docker rules
```

## Security Considerations

### Why Allow Entire Docker Subnet?

The rule `ufw allow from 172.25.0.0/16` might seem broad, but it's safe because:

1. **Isolated network**: Only trusted bot containers use this network
2. **Internal communication**: Traffic stays within the host
3. **No external exposure**: External traffic still requires explicit rules (port 80, 443, etc.)

### Alternative: Port-Specific Rules

If you prefer more restrictive rules, you can allow only specific ports:

```bash
# Remove broad rule
sudo ufw delete allow from 172.25.0.0/16

# Add specific rules
sudo ufw allow from 172.25.0.0/16 to any port 5432 comment 'PostgreSQL'
sudo ufw allow from 172.25.0.0/16 to any port 80 comment 'HTTP'
sudo ufw allow from 172.25.0.0/16 to any port 443 comment 'HTTPS'
# Add more as needed
```

## Integration with Other Scripts

### Scripts that Configure UFW for Docker

All these scripts now include UFW configuration:

1. **setup-server.sh** - Initial server setup
2. **scripts/security.sh** - Security configuration
3. **setup-static-network.sh** - Network creation
4. **platform.sh** - Component installation
5. **scripts/fix-ufw-docker.sh** - Dedicated fix script

### Scripts that Use Docker Network

These scripts ensure the network exists before starting containers:

1. **add-bot.sh** - Creates static network if missing
2. **bot-manage.sh** - Verifies network before start/restart
3. **platform.sh** - Uses network for services

## Best Practices

1. **Always run fix-ufw-docker.sh after:**
   - Creating new Docker networks
   - Resetting UFW
   - Installing new firewall software
   - Changing network configuration

2. **Before troubleshooting connectivity:**
   - Check UFW rules first
   - Verify Docker network exists
   - Confirm PostgreSQL is listening on 172.25.0.1

3. **When adding new services:**
   - Add explicit UFW rules if they need host access
   - Use the static network for PostgreSQL connectivity
   - Document required ports

## Quick Reference

```bash
# Check UFW status
sudo ufw status numbered

# Fix Docker UFW rules
sudo ./scripts/fix-ufw-docker.sh

# Verify network exists
docker network inspect bots_shared_network

# Test PostgreSQL from container
docker run --rm --network bots_shared_network postgres:15 \
  psql -h 172.25.0.1 -U postgres -c "SELECT version();"

# View firewall logs
sudo tail -f /var/log/syslog | grep UFW

# Restart all bots
cd /opt/telegram-bots-platform/bots
for bot in */; do
  cd "$bot" && docker compose restart && cd ..
done
```

## Related Documentation

- [Static Network Setup](./STATIC-NETWORK-SETUP.md)
- [PostgreSQL Configuration](./POSTGRES-CONFIG.md)
- [Security Best Practices](./SECURITY.md)
- [Troubleshooting Guide](./TROUBLESHOOTING.md)
