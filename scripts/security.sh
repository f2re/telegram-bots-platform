#!/bin/bash

# Security functions

# Update firewall rules
update_firewall_rules() {
    local new_ssh_port=${1:-2222}
    
    # Reset firewall
    ufw --force reset > /dev/null 2>&1
    
    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow essential services
    ufw allow $new_ssh_port/tcp comment 'SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    ufw allow from 127.0.0.1 to any port 5432 comment 'PostgreSQL Local'
    ufw allow 3000/tcp comment 'Grafana'
    
    # Enable firewall
    ufw --force enable
}

# Configure fail2ban
configure_fail2ban() {
    local ssh_port=${1:-2222}
    
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = root@localhost
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = $ssh_port
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-noscript]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log

[nginx-badbots]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-noproxy]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
EOF
    
    systemctl restart fail2ban
    systemctl enable fail2ban
}

# Generate SSL certificate
generate_ssl_cert() {
    local domain=$1
    
    # Reload Nginx to serve ACME challenge
    systemctl reload nginx
    
    # Obtain certificate
    certbot certonly \
        --nginx \
        --non-interactive \
        --agree-tos \
        --email "admin@$domain" \
        --domains "$domain" \
        || {
            # Create self-signed certificate as fallback
            mkdir -p "/etc/letsencrypt/live/$domain"
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout "/etc/letsencrypt/live/$domain/privkey.pem" \
                -out "/etc/letsencrypt/live/$domain/fullchain.pem" \
                -subj "/CN=$domain"
        }
    
    # Reload Nginx with SSL
    systemctl reload nginx
}

# Check security status
check_security_status() {
    local ssh_port=$(grep -E "^Port " /etc/ssh/sshd_config | awk '{print $2}')
    local firewall_enabled=$(ufw status | grep -i "active" | wc -l)
    local fail2ban_running=$(systemctl is-active --quiet fail2ban && echo "active" || echo "inactive")
    
    echo "SSH Port: ${ssh_port:-22}"
    echo "Firewall: $(if [ $firewall_enabled -gt 0 ]; then echo "Enabled"; else echo "Disabled"; fi)"
    echo "Fail2Ban: $fail2ban_running"
}