#!/bin/bash

# Monitoring utilities

# Check if monitoring stack is running
is_monitoring_running() {
    if docker ps --filter "name=prometheus" --filter "status=running" -q | grep -q . && 
       docker ps --filter "name=grafana" --filter "status=running" -q | grep -q .; then
        return 0
    else
        return 1
    fi
}

# Get monitoring status
get_monitoring_status() {
    local prometheus_running="● Stopped"
    local grafana_running="● Stopped"
    local prometheus_color="\\033[0;31m"  # RED
    local grafana_color="\\033[0;31m"     # RED
    
    if docker ps --filter "name=prometheus" --filter "status=running" -q | grep -q .; then
        prometheus_running="● Running"
        prometheus_color="\\033[0;32m"    # GREEN
    fi
    
    if docker ps --filter "name=grafana" --filter "status=running" -q | grep -q .; then
        grafana_running="● Running"
        grafana_color="\\033[0;32m"       # GREEN
    fi
    
    echo -e "${prometheus_color}${prometheus_running}\\033[0m"
    echo -e "${grafana_color}${grafana_running}\\033[0m"
}

# Restart monitoring stack
restart_monitoring() {
    cd /opt/monitoring
    docker compose down
    docker compose up -d
}

# Add bot to monitoring
add_bot_to_monitoring() {
    local bot_name=$1
    local bot_port=$2
    
    if [ -f "/opt/monitoring/prometheus/prometheus.yml" ]; then
        cat >> "/opt/monitoring/prometheus/prometheus.yml" << EOF

  - job_name: '${bot_name}'
    static_configs:
      - targets: ['host.docker.internal:${bot_port}']
        labels:
          bot: '${bot_name}'
EOF
        
        # Reload Prometheus
        docker exec prometheus kill -HUP 1 2>/dev/null || true
    fi
}

# Remove bot from monitoring
remove_bot_from_monitoring() {
    local bot_name=$1
    
    if [ -f "/opt/monitoring/prometheus/prometheus.yml" ]; then
        sed -i "/job_name: '${bot_name}'/,+4d" "/opt/monitoring/prometheus/prometheus.yml"
        docker exec prometheus kill -HUP 1 2>/dev/null || true
    fi
}