# DuckDNS SSL Certificate Setup Guide

This guide explains how to configure SSL certificates for DuckDNS domains on the Telegram Bots Platform.

## Overview

The platform now supports automatic SSL certificate generation for both standard domains and DuckDNS domains. DuckDNS domains require a different approach (DNS-01 challenge) compared to standard domains (HTTP-01 challenge).

## What's New in v2.1

- ✅ Automatic detection of DuckDNS domains
- ✅ DNS-01 challenge support via `certbot-dns-duckdns` plugin
- ✅ Secure DuckDNS token storage
- ✅ Improved SSL configuration in Nginx
- ✅ Enhanced error handling and logging
- ✅ Self-signed certificate fallback

## SSL Challenge Methods

### HTTP-01 Challenge (Standard Domains)

**Used for:** Regular domains (e.g., bot.example.com)

**How it works:**
- Certbot places a verification file on your web server
- Let's Encrypt accesses it via HTTP (port 80)
- Requires port 80 to be publicly accessible

**Pros:**
- No additional setup required
- Works out of the box

**Cons:**
- Requires port 80 open
- Needs web server running

### DNS-01 Challenge (DuckDNS Domains)

**Used for:** DuckDNS domains (e.g., yourbot.duckdns.org)

**How it works:**
- Certbot creates a DNS TXT record
- Let's Encrypt verifies via DNS query
- No need for port 80 to be accessible

**Pros:**
- Works behind firewalls/NAT
- More flexible
- Can obtain wildcard certificates

**Cons:**
- Requires DuckDNS API token
- DNS propagation delay (120 seconds)

## Quick Start

### 1. Get Your DuckDNS Token

1. Visit [https://www.duckdns.org](https://www.duckdns.org)
2. Login with your account
3. Copy your token from the top of the page

### 2. Run the Bot Setup

```bash
cd /opt/telegram-bots-platform
sudo ./add-bot.sh
```

### 3. Enter Bot Details

When prompted for the domain, use your DuckDNS domain:

```
Доменное имя: yourbot.duckdns.org
```

The script will automatically:
- Detect it's a DuckDNS domain
- Ask for your DuckDNS token (if not already configured)
- Install the necessary plugin
- Obtain the SSL certificate via DNS-01 challenge

## Manual Setup

If you want to set up DuckDNS SSL manually or for an existing bot:

### Step 1: Create DuckDNS Token File

```bash
mkdir -p /root/.secrets
echo "dns_duckdns_token=YOUR_DUCKDNS_TOKEN" > /root/.secrets/duckdns.ini
chmod 600 /root/.secrets/duckdns.ini
```

### Step 2: Install certbot-dns-duckdns Plugin

```bash
pip3 install certbot-dns-duckdns
```

### Step 3: Obtain Certificate

```bash
certbot certonly \
    --dns-duckdns \
    --dns-duckdns-credentials /root/.secrets/duckdns.ini \
    --dns-duckdns-propagation-seconds 120 \
    --non-interactive \
    --agree-tos \
    --email admin@yourbot.duckdns.org \
    --domains yourbot.duckdns.org \
    --preferred-challenges dns
```

### Step 4: Update Nginx Configuration

The certificate will be stored at:
- Certificate: `/etc/letsencrypt/live/yourbot.duckdns.org/fullchain.pem`
- Private Key: `/etc/letsencrypt/live/yourbot.duckdns.org/privkey.pem`

Your Nginx configuration should already reference these paths if created by `add-bot.sh`.

### Step 5: Reload Nginx

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Certificate Renewal

### Automatic Renewal

Certbot automatically sets up a renewal cron job. For DuckDNS domains, ensure the renewal configuration includes the DNS plugin:

```bash
# Test renewal
sudo certbot renew --dry-run --dns-duckdns --dns-duckdns-credentials /root/.secrets/duckdns.ini
```

### Manual Renewal

```bash
sudo certbot renew --dns-duckdns --dns-duckdns-credentials /root/.secrets/duckdns.ini
sudo systemctl reload nginx
```

### Check Certificate Status

```bash
sudo certbot certificates
```

Output example:
```
Certificate Name: yourbot.duckdns.org
  Domains: yourbot.duckdns.org
  Expiry Date: 2026-02-18 09:37:33+00:00 (VALID: 89 days)
  Certificate Path: /etc/letsencrypt/live/yourbot.duckdns.org/fullchain.pem
  Private Key Path: /etc/letsencrypt/live/yourbot.duckdns.org/privkey.pem
```

## Troubleshooting

### Issue: "Failed to obtain SSL certificate"

**Possible causes:**

1. **Invalid DuckDNS Token**
   ```bash
   # Verify token
   cat /root/.secrets/duckdns.ini
   
   # Test token
   curl "https://www.duckdns.org/update?domains=yourbot&token=YOUR_TOKEN&ip="
   # Should return: OK
   ```

2. **DNS Propagation Timeout**
   - Increase propagation time:
   ```bash
   --dns-duckdns-propagation-seconds 180
   ```

3. **Plugin Not Installed**
   ```bash
   pip3 list | grep certbot-dns-duckdns
   # If not found:
   pip3 install certbot-dns-duckdns
   ```

### Issue: "SERVFAIL errors"

This usually indicates DNS issues:

```bash
# Check if domain resolves
dig yourbot.duckdns.org

# Check DuckDNS status
curl "https://www.duckdns.org/update?domains=yourbot&token=YOUR_TOKEN"
```

### Issue: "Self-signed certificate warning in browser"

If the script falls back to a self-signed certificate:

1. Check certbot logs:
   ```bash
   tail -n 50 /var/log/letsencrypt/letsencrypt.log
   ```

2. Manually obtain certificate:
   ```bash
   sudo certbot certonly --dns-duckdns \
     --dns-duckdns-credentials /root/.secrets/duckdns.ini \
     --dns-duckdns-propagation-seconds 180 \
     -d yourbot.duckdns.org
   ```

3. Reload Nginx:
   ```bash
   sudo systemctl reload nginx
   ```

### Issue: "Token authentication failed"

1. Regenerate token at [duckdns.org](https://www.duckdns.org)
2. Update token file:
   ```bash
   echo "dns_duckdns_token=NEW_TOKEN" > /root/.secrets/duckdns.ini
   chmod 600 /root/.secrets/duckdns.ini
   ```
3. Retry certificate generation

### Issue: "Rate limit exceeded"

Let's Encrypt has rate limits:
- 5 failed attempts per hour
- 50 certificates per domain per week

**Solution:** Wait 1 hour and try again, or use staging environment for testing:

```bash
certbot certonly --dns-duckdns \
  --dns-duckdns-credentials /root/.secrets/duckdns.ini \
  --staging \
  -d yourbot.duckdns.org
```

## Advanced Configuration

### Multiple DuckDNS Domains

The token is stored once and reused for all DuckDNS domains:

```bash
# First bot - token will be requested
sudo ./add-bot.sh
# Domain: bot1.duckdns.org

# Second bot - token already configured
sudo ./add-bot.sh
# Domain: bot2.duckdns.org
```

### Custom Propagation Time

For slower DNS propagation, edit the script or use manual method with increased time:

```bash
certbot certonly --dns-duckdns \
  --dns-duckdns-credentials /root/.secrets/duckdns.ini \
  --dns-duckdns-propagation-seconds 240 \
  -d yourbot.duckdns.org
```

### Wildcard Certificates

DNS-01 challenge supports wildcard certificates:

```bash
certbot certonly --dns-duckdns \
  --dns-duckdns-credentials /root/.secrets/duckdns.ini \
  --dns-duckdns-propagation-seconds 120 \
  -d "*.yourbot.duckdns.org" \
  -d "yourbot.duckdns.org"
```

### Renewal Hooks

Automatic Nginx reload on renewal:

```bash
# Create renewal hook
cat > /etc/letsencrypt/renewal-hooks/post/reload-nginx.sh << 'EOF'
#!/bin/bash
systemctl reload nginx
EOF

chmod +x /etc/letsencrypt/renewal-hooks/post/reload-nginx.sh
```

## Security Best Practices

### 1. Protect Token File

```bash
# Correct permissions
chmod 600 /root/.secrets/duckdns.ini
chown root:root /root/.secrets/duckdns.ini
```

### 2. Regular Security Updates

```bash
apt update
apt upgrade certbot python3-certbot-nginx
pip3 install --upgrade certbot-dns-duckdns
```

### 3. Monitor Certificate Expiry

Add to monitoring script:

```bash
# Check all certificates
certbot certificates | grep -A 2 "Expiry Date"
```

### 4. Strong SSL Configuration

The platform uses secure SSL settings by default:
- TLS 1.2 and 1.3 only
- Strong cipher suites
- HSTS enabled
- Security headers

## Nginx SSL Configuration

The generated Nginx configuration includes:

```nginx
# SSL configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers HIGH:!aNULL:!MD5;
ssl_prefer_server_ciphers on;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;

# Security headers
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

## Comparison: Standard vs DuckDNS

| Feature | Standard Domain | DuckDNS Domain |
|---------|----------------|----------------|
| SSL Method | HTTP-01 | DNS-01 |
| Port 80 Required | Yes | No |
| Setup Complexity | Low | Medium |
| Additional Requirements | None | DuckDNS Token |
| Propagation Time | Instant | 120 seconds |
| Wildcard Support | No | Yes |
| Behind NAT/Firewall | No | Yes |

## Migration Guide

### From Standard to DuckDNS

If you want to migrate an existing bot from a standard domain to DuckDNS:

1. **Setup DuckDNS domain** and point it to your server

2. **Update bot domain:**
   ```bash
   cd /opt/telegram-bots-platform/bots/YOUR_BOT
   nano .env
   # Update DOMAIN and WEBHOOK_URL
   ```

3. **Obtain new certificate:**
   ```bash
   certbot certonly --dns-duckdns \
     --dns-duckdns-credentials /root/.secrets/duckdns.ini \
     -d yourbot.duckdns.org
   ```

4. **Update Nginx configuration:**
   ```bash
   nano /etc/nginx/sites-available/YOUR_BOT.conf
   # Update server_name
   # Update ssl_certificate paths if needed
   ```

5. **Test and reload:**
   ```bash
   nginx -t
   systemctl reload nginx
   docker compose restart
   ```

## Resources

- [DuckDNS Official Site](https://www.duckdns.org)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot DNS Plugins](https://eff-certbot.readthedocs.io/en/stable/using.html#dns-plugins)
- [certbot-dns-duckdns on PyPI](https://pypi.org/project/certbot-dns-duckdns/)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review certbot logs: `/var/log/letsencrypt/letsencrypt.log`
3. Check Nginx logs: `/var/log/nginx/error.log`
4. Create an issue on GitHub repository

---

**Updated:** November 20, 2025  
**Version:** 2.1  
**Platform:** Telegram Bots Platform with DuckDNS SSL Support