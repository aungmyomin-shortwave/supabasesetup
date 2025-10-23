#!/bin/bash

# Fix Docker Compose Compatibility Issues
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}" >&2; }
warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }

if [[ $EUID -ne 0 ]]; then
    error "Run as root: sudo $0"
    exit 1
fi

log "Fixing Docker Compose compatibility issues..."

# Check Docker Compose version
COMPOSE_VERSION=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
log "Docker Compose version: $COMPOSE_VERSION"

# Navigate to Supabase directory
cd /srv/supabase/supabase/docker

# Backup original compose file
cp docker-compose.yml docker-compose.yml.backup

# Fix the compose file
log "Fixing Docker Compose file..."

# Remove the 'name' field that's causing issues
sed -i '/^name:/d' docker-compose.yml

# Fix boolean environment variables
sed -i 's/NEXT_PUBLIC_ENABLE_LOGS: true/NEXT_PUBLIC_ENABLE_LOGS: "true"/g' docker-compose.yml
sed -i 's/LOGFLARE_SINGLE_TENANT: true/LOGFLARE_SINGLE_TENANT: "true"/g' docker-compose.yml
sed -i 's/SEED_SELF_HOST: true/SEED_SELF_HOST: "true"/g' docker-compose.yml
sed -i 's/CLUSTER_POSTGRES: true/CLUSTER_POSTGRES: "true"/g' docker-compose.yml

# Test the compose file
log "Testing Docker Compose file..."
if docker-compose config >/dev/null 2>&1; then
    log "✓ Docker Compose file is now valid"
else
    error "Docker Compose file still has issues"
    exit 1
fi

# Start Supabase services
log "Starting Supabase services..."
export SUPABASE_PASSWORD=$(openssl rand -base64 12)

# Update .env file
cat >> .env <<EOM
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=${SUPABASE_PASSWORD}
EOM

docker-compose up -d

log "✓ Supabase services started"
log "Dashboard credentials:"
log "Username: supabase"
log "Password: $SUPABASE_PASSWORD"

# Fix Nginx configuration
log "Fixing Nginx configuration..."
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/supabase
systemctl restart nginx

log "✓ Nginx configured"

# Wait for services to start
log "Waiting for services to start..."
sleep 30

# Test endpoints
if curl -s http://localhost:8000 >/dev/null; then
    log "✓ Supabase API is responding"
else
    warning "Supabase API not responding yet"
fi

log "Fix completed! Access Supabase at: http://$(hostname -I | awk '{print $1}')"
