#!/bin/bash

# Supabase Self-Hosted Installation Script
# Based on DigitalOcean 1-Click Supabase Configuration
# 
# This script installs and configures a self-hosted Supabase instance
# with Docker, Nginx, SSL certificates, and all necessary components.

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
SUPABASE_DIR="/srv/supabase"
NGINX_CONFIG_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check Ubuntu version
    if ! grep -q "Ubuntu" /etc/os-release; then
        error "This script is designed for Ubuntu systems"
    fi
    
    # Check available memory (minimum 2GB recommended)
    local memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local memory_gb=$((memory_kb / 1024 / 1024))
    
    if [ $memory_gb -lt 2 ]; then
        warning "System has less than 2GB RAM. Supabase may not perform optimally."
    fi
    
    # Check available disk space (minimum 10GB recommended)
    local disk_space=$(df / | awk 'NR==2 {print $4}')
    local disk_gb=$((disk_space / 1024 / 1024))
    
    if [ $disk_gb -lt 10 ]; then
        warning "System has less than 10GB free disk space. Consider freeing up space."
    fi
    
    log "System requirements check completed"
}

# Update system packages
update_system() {
    log "Updating system packages..."
    
    export DEBIAN_FRONTEND=noninteractive
    export LC_ALL=C
    export LANG=en_US.UTF-8
    export LC_CTYPE=en_US.UTF-8
    
    apt-get update -qq
    apt-get upgrade -qq -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'
    
    log "System packages updated"
}

# Install required packages
install_packages() {
    log "Installing required packages..."
    
    local packages=(
        "apt-transport-https"
        "ca-certificates"
        "curl"
        "jq"
        "linux-image-extra-virtual"
        "software-properties-common"
        "git"
        "ufw"
        "dirmngr"
        "gnupg2"
        "lsb-release"
        "debian-archive-keyring"
        "snapd"
        "nginx"
    )
    
    apt-get install -qq -y "${packages[@]}"
    apt-get clean -qq
    
    log "Required packages installed"
}

# Install Docker
install_docker() {
    log "Installing Docker..."
    
    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    
    # Add Docker repository
    cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -c -s) stable
EOF
    
    # Update package list and install Docker
    apt-get update -qq
    apt-get install -y docker-ce
    
    # Install Docker Compose
    apt-get install -y docker-compose
    
    # Start and enable Docker
    systemctl enable docker
    systemctl start docker
    
    log "Docker installed and started"
}

# Install Certbot for SSL certificates
install_certbot() {
    log "Installing Certbot for SSL certificates..."
    
    snap install core && snap refresh core
    snap install --classic certbot
    ln -sf /snap/bin/certbot /usr/bin/certbot
    
    log "Certbot installed"
}

# Clone Supabase repository
setup_supabase() {
    log "Setting up Supabase..."
    
    # Create Supabase directory
    mkdir -p "$SUPABASE_DIR"
    cd "$SUPABASE_DIR"
    
    # Clone Supabase repository
    if [ ! -d "supabase" ]; then
        git clone --depth 1 https://github.com/supabase/supabase.git
    fi
    
    cd supabase/docker
    
    # Copy environment file
    if [ ! -f ".env" ]; then
        cp .env.example .env
    fi
    
    log "Supabase repository cloned and configured"
}

# Configure firewall
configure_firewall() {
    log "Configuring firewall..."
    
    ufw limit ssh
    ufw allow http
    ufw allow https
    ufw --force enable
    
    log "Firewall configured"
}

# Create nginx configurations
create_nginx_configs() {
    log "Creating Nginx configurations..."
    
    # Create HTTP configuration (redirects to HTTPS)
    cat > "$NGINX_CONFIG_DIR/supabase" <<'EOF'
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

    # Create SSL configuration template
    cat > "$SCRIPT_DIR/templates/nginx-ssl.conf" <<'EOF'
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}
upstream kong {
    server localhost:8000;
}

# enforce HTTPS
server {
    listen       80; 
    listen       [::]:80;
    server_name  DOMAIN_PLACEHOLDER;
    return 301   https://$host$request_uri;
}

server {
    listen       443 ssl http2;
    listen       [::]:443 ssl http2;
    server_name  DOMAIN_PLACEHOLDER;

    access_log  /var/log/nginx/supabase.access.log;
    error_log   /var/log/nginx/supabase.error.log;
    
    gzip on;
    
    # SSL
    ssl_certificate      /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key  /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/chain.pem;
    ssl_session_timeout  5m;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets off;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_ecdh_curve X25519:prime256v1:secp384r1:secp521r1;
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;
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

    log "Nginx configurations created"
}

# Create setup script for SSL configuration
create_ssl_setup_script() {
    log "Creating SSL setup script..."
    
    cat > "$SCRIPT_DIR/scripts/configure-ssl.sh" <<'EOF'
#!/bin/bash

# SSL Configuration Script for Supabase
# This script configures SSL certificates and updates Nginx configuration

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

echo "=================================================="
echo "Supabase SSL Configuration"
echo "=================================================="
echo "This setup requires a domain name. If you do not have one yet, you may"
echo "cancel this setup, press Ctrl+C. This script will run again on your next login"
echo "=================================================="
echo "Enter the domain name for your new Supabase site."
echo "(ex. example.org or test.example.org) do not include www or http/s"
echo "=================================================="

# Get domain name
while true; do
    read -p "Domain/Subdomain name: " domain
    if [ -n "$domain" ]; then
        break
    fi
    echo "Please provide a valid domain or subdomain name to continue or press Ctrl+C to cancel"
done

# Get email address
while [ -z "$email" ]; do
    echo -en "\n"
    read -p "Your Email Address: " email
done

log "Configuring SSL for domain: $domain"

# Stop nginx temporarily
service nginx stop

# Generate SSL certificate
log "Generating SSL certificate..."
certbot certonly --standalone --agree-tos --no-eff-email --staple-ocsp --preferred-challenges http -m "$email" -d "$domain"

if [ $? -eq 0 ]; then
    log "SSL certificate generated successfully"
else
    error "SSL certificate generation failed"
fi

# Generate DH parameters
log "Generating DH parameters..."
openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096

if [ $? -eq 0 ]; then
    log "DH parameters generated successfully"
else
    error "DH parameters generation failed"
fi

# Create Let's Encrypt directory
mkdir -p /var/lib/letsencrypt

# Create certificate renewal cron job
cat > /etc/cron.daily/certbot-renew <<EOM
#!/bin/sh
certbot renew --cert-name $domain --webroot -w /var/lib/letsencrypt/ --post-hook "systemctl reload nginx" 
EOM
chmod +x /etc/cron.daily/certbot-renew

# Update nginx configuration with domain
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sed "s/DOMAIN_PLACEHOLDER/$domain/g" "$SCRIPT_DIR/../templates/nginx-ssl.conf" > /etc/nginx/sites-available/supabase

# Start nginx
service nginx start

log "SSL configuration completed successfully!"
log "Your Supabase instance is now available at: https://$domain"
EOF

    chmod +x "$SCRIPT_DIR/scripts/configure-ssl.sh"
    
    log "SSL setup script created"
}

# Create startup script
create_startup_script() {
    log "Creating startup script..."
    
    cat > "$SCRIPT_DIR/scripts/start-supabase.sh" <<'EOF'
#!/bin/bash

# Supabase Startup Script
# This script starts the Supabase services

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

SUPABASE_DIR="/srv/supabase"

log "Starting Supabase services..."

cd "$SUPABASE_DIR/supabase/docker"

# Generate random password for dashboard
export SUPABASE_PASSWORD=$(openssl rand -base64 12)

# Update environment file with dashboard credentials
cat >> .env <<EOM
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=${SUPABASE_PASSWORD}
EOM

log "Dashboard credentials:"
log "Username: supabase"
log "Password: $SUPABASE_PASSWORD"

# Start Supabase services
docker compose up -d

# Configure nginx
ln -sf /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/supabase
rm -f /etc/nginx/sites-enabled/default

# Restart nginx
systemctl restart nginx

log "Supabase services started successfully!"
log "Access your Supabase Studio at: http://$(hostname -I | awk '{print $1}')"
log "Dashboard credentials saved to: $SUPABASE_DIR/supabase/docker/.env"
EOF

    chmod +x "$SCRIPT_DIR/scripts/start-supabase.sh"
    
    log "Startup script created"
}

# Create management script
create_management_script() {
    log "Creating management script..."
    
    cat > "$SCRIPT_DIR/manage-supabase.sh" <<'EOF'
#!/bin/bash

# Supabase Management Script
# This script provides easy management commands for Supabase

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SUPABASE_DIR="/srv/supabase"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

show_help() {
    echo "Supabase Management Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start       Start Supabase services"
    echo "  stop        Stop Supabase services"
    echo "  restart     Restart Supabase services"
    echo "  status      Show service status"
    echo "  logs        Show service logs"
    echo "  ssl         Configure SSL certificates"
    echo "  update      Update Supabase to latest version"
    echo "  backup      Backup Supabase data"
    echo "  restore     Restore Supabase data"
    echo "  help        Show this help message"
}

start_services() {
    log "Starting Supabase services..."
    cd "$SUPABASE_DIR/supabase/docker"
    docker compose up -d
    log "Services started"
}

stop_services() {
    log "Stopping Supabase services..."
    cd "$SUPABASE_DIR/supabase/docker"
    docker compose down
    log "Services stopped"
}

restart_services() {
    log "Restarting Supabase services..."
    stop_services
    start_services
}

show_status() {
    log "Supabase service status:"
    cd "$SUPABASE_DIR/supabase/docker"
    docker compose ps
}

show_logs() {
    log "Showing Supabase logs:"
    cd "$SUPABASE_DIR/supabase/docker"
    docker compose logs -f
}

configure_ssl() {
    log "Starting SSL configuration..."
    "$SCRIPT_DIR/scripts/configure-ssl.sh"
}

update_supabase() {
    log "Updating Supabase..."
    cd "$SUPABASE_DIR"
    git pull origin main
    cd docker
    docker compose pull
    docker compose up -d
    log "Supabase updated"
}

backup_data() {
    log "Creating backup..."
    local backup_dir="/var/backups/supabase"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$backup_dir"
    
    cd "$SUPABASE_DIR/supabase/docker"
    docker compose exec -T postgres pg_dumpall -U postgres > "$backup_dir/supabase_backup_$timestamp.sql"
    
    log "Backup created: $backup_dir/supabase_backup_$timestamp.sql"
}

restore_data() {
    error "Restore functionality not implemented yet"
}

# Main script logic
case "${1:-help}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    ssl)
        configure_ssl
        ;;
    update)
        update_supabase
        ;;
    backup)
        backup_data
        ;;
    restore)
        restore_data
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        error "Unknown command: $1"
        show_help
        ;;
esac
EOF

    chmod +x "$SCRIPT_DIR/manage-supabase.sh"
    
    log "Management script created"
}

# Create README file
create_readme() {
    log "Creating README file..."
    
    cat > "$SCRIPT_DIR/README.md" <<'EOF'
# Supabase Self-Hosted Installation

This package provides a complete installation and management solution for self-hosted Supabase instances.

## Quick Start

1. **Install Supabase:**
   ```bash
   sudo ./install-supabase.sh
   ```

2. **Start Supabase services:**
   ```bash
   sudo ./manage-supabase.sh start
   ```

3. **Configure SSL (optional):**
   ```bash
   sudo ./manage-supabase.sh ssl
   ```

## Management Commands

Use the `manage-supabase.sh` script for all management tasks:

```bash
# Start services
sudo ./manage-supabase.sh start

# Stop services
sudo ./manage-supabase.sh stop

# Restart services
sudo ./manage-supabase.sh restart

# Check status
sudo ./manage-supabase.sh status

# View logs
sudo ./manage-supabase.sh logs

# Configure SSL
sudo ./manage-supabase.sh ssl

# Update Supabase
sudo ./manage-supabase.sh update

# Backup data
sudo ./manage-supabase.sh backup
```

## Accessing Supabase

- **Supabase Studio:** http://your-server-ip
- **API:** http://your-server-ip/rest/v1/
- **Auth:** http://your-server-ip/auth/v1/
- **Realtime:** http://your-server-ip/realtime/v1/

## SSL Configuration

To enable HTTPS:

1. Ensure your domain points to your server
2. Run: `sudo ./manage-supabase.sh ssl`
3. Follow the prompts to enter your domain and email

## Default Credentials

After starting Supabase, check the dashboard credentials in:
```
/srv/supabase/supabase/docker/.env
```

Default username: `supabase`
Password: Generated randomly and saved to the .env file

## File Structure

```
supabase-installer/
├── install-supabase.sh          # Main installation script
├── manage-supabase.sh           # Management script
├── scripts/
│   ├── configure-ssl.sh         # SSL configuration
│   └── start-supabase.sh        # Startup script
├── templates/
│   └── nginx-ssl.conf           # SSL nginx template
└── README.md                    # This file
```

## Requirements

- Ubuntu 20.04 or later
- Minimum 2GB RAM (4GB recommended)
- Minimum 10GB free disk space
- Root access or sudo privileges

## Troubleshooting

### Check service status:
```bash
sudo ./manage-supabase.sh status
```

### View logs:
```bash
sudo ./manage-supabase.sh logs
```

### Restart services:
```bash
sudo ./manage-supabase.sh restart
```

### Check nginx configuration:
```bash
sudo nginx -t
```

## Support

For issues and questions:
- Supabase Documentation: https://supabase.com/docs
- Supabase GitHub: https://github.com/supabase/supabase
EOF

    log "README file created"
}

# Main installation function
main() {
    log "Starting Supabase installation..."
    
    check_root
    check_requirements
    update_system
    install_packages
    install_docker
    install_certbot
    setup_supabase
    configure_firewall
    create_nginx_configs
    create_ssl_setup_script
    create_startup_script
    create_management_script
    create_readme
    
    log "Installation completed successfully!"
    echo ""
    info "Next steps:"
    info "1. Start Supabase services: sudo ./manage-supabase.sh start"
    info "2. Configure SSL (optional): sudo ./manage-supabase.sh ssl"
    info "3. Access Supabase Studio at: http://$(hostname -I | awk '{print $1}')"
    echo ""
    info "For management commands, use: sudo ./manage-supabase.sh help"
}

# Run main function
main "$@"
