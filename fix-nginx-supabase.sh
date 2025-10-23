#!/bin/bash

# Quick Fix Script for Nginx Default Page Issue
# This script diagnoses and fixes the common issue where Nginx shows default page instead of Supabase

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

section() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

section "Diagnosing Nginx and Supabase Issues"

# 1. Check if Supabase is installed
log "Checking Supabase installation..."
if [ -d "/srv/supabase" ]; then
    log "✓ Supabase directory exists"
else
    error "✗ Supabase directory not found. Run the installation first:"
    error "sudo ./install-supabase.sh"
    exit 1
fi

# 2. Check if Supabase services are running
log "Checking Supabase services..."
cd /srv/supabase/supabase/docker 2>/dev/null || {
    error "✗ Supabase Docker directory not found"
    exit 1
}

if docker-compose ps | grep -q "Up"; then
    log "✓ Some Supabase services are running"
    info "Running services:"
    docker-compose ps | grep "Up" | while read line; do
        info "  $line"
    done
else
    warning "✗ No Supabase services are running"
    info "Starting Supabase services..."
    
    # Generate random password for dashboard
    export SUPABASE_PASSWORD=$(openssl rand -base64 12)
    
    # Update .env file with dashboard credentials
    if [ -f ".env" ]; then
        # Remove existing dashboard credentials
        sed -i '/DASHBOARD_USERNAME/d' .env
        sed -i '/DASHBOARD_PASSWORD/d' .env
        
        # Add new credentials
        cat >> .env <<EOM
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=${SUPABASE_PASSWORD}
EOM
    else
        error "✗ .env file not found. Creating one..."
        cp .env.example .env
        cat >> .env <<EOM
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=${SUPABASE_PASSWORD}
EOM
    fi
    
    log "Dashboard credentials:"
    log "Username: supabase"
    log "Password: $SUPABASE_PASSWORD"
    
    # Start Supabase services
    log "Starting Supabase services (this may take a few minutes)..."
    docker-compose up -d
    
    # Wait for services to start
    log "Waiting for services to start..."
    sleep 30
    
    # Check if services are running
    if docker-compose ps | grep -q "Up"; then
        log "✓ Supabase services started successfully"
    else
        error "✗ Failed to start Supabase services"
        info "Checking logs..."
        docker-compose logs --tail=20
        exit 1
    fi
fi

# 3. Check Nginx configuration
section "Checking Nginx Configuration"

log "Checking Nginx status..."
if systemctl is-active --quiet nginx; then
    log "✓ Nginx is running"
else
    warning "✗ Nginx is not running. Starting Nginx..."
    systemctl start nginx
fi

# Check if Supabase site is enabled
log "Checking Nginx site configuration..."
if [ -f "/etc/nginx/sites-available/supabase" ]; then
    log "✓ Supabase Nginx configuration exists"
else
    error "✗ Supabase Nginx configuration missing"
    info "Creating Nginx configuration..."
    
    cat > /etc/nginx/sites-available/supabase <<'EOF'
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}
upstream kong {
    server localhost:8000;
}

server {
    listen       80;
    listen       [::]:80;
    server_name  _;
    access_log  /var/log/nginx/supabase.access.log;
    error_log   /var/log/nginx/supabase.error.log;
    gzip on;

    resolver 8.8.8.8;

    client_max_body_size 100m;
    
    # REST API
    location ~ ^/rest/v1/(.*)$ {
        proxy_set_header Host $host;
        proxy_pass http://kong;
        proxy_redirect off;
    }

    # Authentication
    location ~ ^/auth/v1/(.*)$ {
        proxy_set_header Host $host;
        proxy_pass http://kong;
        proxy_redirect off;
    }

    # Realtime
    location ~ ^/realtime/v1/(.*)$ {
        proxy_redirect off;
        proxy_pass http://kong;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
    }

    # Studio
    location / {
        proxy_set_header Host $host;
        proxy_pass http://kong;
        proxy_redirect off;
        proxy_set_header Upgrade $http_upgrade;
    }
}
EOF
    log "✓ Nginx configuration created"
fi

# Enable Supabase site and disable default
log "Configuring Nginx sites..."
ln -sf /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/supabase
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
log "Testing Nginx configuration..."
if nginx -t; then
    log "✓ Nginx configuration is valid"
else
    error "✗ Nginx configuration is invalid"
    nginx -t
    exit 1
fi

# Restart Nginx
log "Restarting Nginx..."
systemctl restart nginx

# 4. Check if Kong (Supabase API Gateway) is running
section "Checking Supabase API Gateway"

log "Checking if Kong is accessible..."
if curl -s --connect-timeout 5 http://localhost:8000 >/dev/null; then
    log "✓ Kong API Gateway is responding"
else
    warning "✗ Kong API Gateway is not responding"
    info "Checking Kong container status..."
    docker-compose ps | grep kong || echo "Kong container not found"
    
    info "Checking Kong logs..."
    docker-compose logs kong --tail=10
    
    warning "Kong may still be starting up. Waiting 30 seconds..."
    sleep 30
    
    if curl -s --connect-timeout 5 http://localhost:8000 >/dev/null; then
        log "✓ Kong API Gateway is now responding"
    else
        error "✗ Kong API Gateway is still not responding"
        info "Try restarting Supabase services:"
        info "cd /srv/supabase/supabase/docker && docker-compose restart"
    fi
fi

# 5. Test the complete setup
section "Testing Setup"

log "Testing Supabase endpoints..."

# Test API endpoint
if curl -s --connect-timeout 5 http://localhost:8000/rest/v1/ >/dev/null; then
    log "✓ Supabase REST API is responding"
else
    warning "✗ Supabase REST API is not responding"
fi

# Test Studio endpoint
if curl -s --connect-timeout 5 http://localhost:3000 >/dev/null; then
    log "✓ Supabase Studio is responding"
else
    warning "✗ Supabase Studio is not responding"
fi

# Test through Nginx
if curl -s --connect-timeout 5 http://localhost/rest/v1/ >/dev/null; then
    log "✓ Nginx proxy to Supabase API is working"
else
    warning "✗ Nginx proxy to Supabase API is not working"
fi

# 6. Show final status
section "Final Status"

log "Supabase services status:"
docker-compose ps

log "Nginx status:"
systemctl status nginx --no-pager -l

log "Access URLs:"
info "Supabase Studio: http://$(hostname -I | awk '{print $1}')"
info "API Endpoint: http://$(hostname -I | awk '{print $1}')/rest/v1/"
info "Auth Endpoint: http://$(hostname -I | awk '{print $1}')/auth/v1/"

if [ -n "$SUPABASE_PASSWORD" ]; then
    log "Dashboard credentials:"
    info "Username: supabase"
    info "Password: $SUPABASE_PASSWORD"
    info "Credentials saved to: /srv/supabase/supabase/docker/.env"
fi

section "Troubleshooting Tips"

info "If you still see the Nginx default page:"
info "1. Clear your browser cache"
info "2. Try accessing: http://your-server-ip/rest/v1/"
info "3. Check if Kong is running: curl http://localhost:8000"
info "4. View Supabase logs: cd /srv/supabase/supabase/docker && docker-compose logs"

info "If services won't start:"
info "1. Check Docker: sudo systemctl status docker"
info "2. Check logs: cd /srv/supabase/supabase/docker && docker-compose logs"
info "3. Restart services: cd /srv/supabase/supabase/docker && docker-compose restart"

log "Fix script completed!"
