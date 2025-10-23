#!/bin/bash

# Supabase Installation Debug Script
# This script helps diagnose issues when installing Supabase on cloud servers

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
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

debug() {
    echo -e "${PURPLE}[DEBUG] $1${NC}"
}

section() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Create debug report file
DEBUG_REPORT="/tmp/supabase-debug-$(date +%Y%m%d-%H%M%S).txt"
echo "Supabase Installation Debug Report" > "$DEBUG_REPORT"
echo "Generated: $(date)" >> "$DEBUG_REPORT"
echo "=================================" >> "$DEBUG_REPORT"

# Function to append to debug report
append_report() {
    echo "$1" >> "$DEBUG_REPORT"
}

# Check if running as root
check_root() {
    section "Checking Root Access"
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        append_report "ERROR: Script not run as root"
        exit 1
    else
        log "Running as root ✓"
        append_report "✓ Running as root"
    fi
}

# System information
system_info() {
    section "System Information"
    
    info "Collecting system information..."
    
    echo "=== Operating System ===" >> "$DEBUG_REPORT"
    cat /etc/os-release >> "$DEBUG_REPORT"
    echo "" >> "$DEBUG_REPORT"
    
    echo "=== Kernel Information ===" >> "$DEBUG_REPORT"
    uname -a >> "$DEBUG_REPORT"
    echo "" >> "$DEBUG_REPORT"
    
    echo "=== CPU Information ===" >> "$DEBUG_REPORT"
    lscpu >> "$DEBUG_REPORT"
    echo "" >> "$DEBUG_REPORT"
    
    echo "=== Memory Information ===" >> "$DEBUG_REPORT"
    free -h >> "$DEBUG_REPORT"
    echo "" >> "$DEBUG_REPORT"
    
    echo "=== Disk Information ===" >> "$DEBUG_REPORT"
    df -h >> "$DEBUG_REPORT"
    echo "" >> "$DEBUG_REPORT"
    
    echo "=== Network Interfaces ===" >> "$DEBUG_REPORT"
    ip addr show >> "$DEBUG_REPORT"
    echo "" >> "$DEBUG_REPORT"
    
    # Display key information
    log "OS: $(lsb_release -d | cut -f2)"
    log "Kernel: $(uname -r)"
    log "Architecture: $(uname -m)"
    
    local memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    log "Memory: ${memory_gb}GB"
    
    local disk_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    log "Free Disk Space: ${disk_gb}GB"
    
    # Check if system meets requirements
    if [ $memory_gb -lt 2 ]; then
        warning "System has less than 2GB RAM. Supabase may not work properly."
        append_report "WARNING: Less than 2GB RAM"
    fi
    
    if [ $disk_gb -lt 10 ]; then
        warning "System has less than 10GB free disk space."
        append_report "WARNING: Less than 10GB free disk space"
    fi
}

# Network connectivity tests
network_tests() {
    section "Network Connectivity Tests"
    
    info "Testing network connectivity..."
    
    echo "=== Network Connectivity Tests ===" >> "$DEBUG_REPORT"
    
    # Test basic connectivity
    if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
        log "Internet connectivity ✓"
        append_report "✓ Internet connectivity working"
    else
        error "No internet connectivity"
        append_report "ERROR: No internet connectivity"
    fi
    
    # Test DNS resolution
    if nslookup google.com >/dev/null 2>&1; then
        log "DNS resolution ✓"
        append_report "✓ DNS resolution working"
    else
        error "DNS resolution failed"
        append_report "ERROR: DNS resolution failed"
    fi
    
    # Test HTTPS connectivity
    if curl -s --connect-timeout 10 https://github.com >/dev/null; then
        log "HTTPS connectivity ✓"
        append_report "✓ HTTPS connectivity working"
    else
        error "HTTPS connectivity failed"
        append_report "ERROR: HTTPS connectivity failed"
    fi
    
    # Test Docker Hub connectivity
    if curl -s --connect-timeout 10 https://registry-1.docker.io >/dev/null; then
        log "Docker Hub connectivity ✓"
        append_report "✓ Docker Hub connectivity working"
    else
        error "Docker Hub connectivity failed"
        append_report "ERROR: Docker Hub connectivity failed"
    fi
    
    # Test GitHub connectivity
    if curl -s --connect-timeout 10 https://github.com/supabase/supabase >/dev/null; then
        log "GitHub connectivity ✓"
        append_report "✓ GitHub connectivity working"
    else
        error "GitHub connectivity failed"
        append_report "ERROR: GitHub connectivity failed"
    fi
    
    # Check for proxy settings
    if [ -n "$http_proxy" ] || [ -n "$https_proxy" ]; then
        info "Proxy settings detected:"
        info "HTTP_PROXY: $http_proxy"
        info "HTTPS_PROXY: $https_proxy"
        append_report "Proxy settings: HTTP=$http_proxy, HTTPS=$https_proxy"
    fi
}

# Package manager tests
package_manager_tests() {
    section "Package Manager Tests"
    
    info "Testing package manager..."
    
    echo "=== Package Manager Tests ===" >> "$DEBUG_REPORT"
    
    # Test apt update
    if apt-get update -qq >/dev/null 2>&1; then
        log "Package manager (apt) working ✓"
        append_report "✓ Package manager working"
    else
        error "Package manager (apt) failed"
        append_report "ERROR: Package manager failed"
        
        # Check for common issues
        if [ -f /var/lib/dpkg/lock-frontend ]; then
            warning "Package manager lock file exists"
            append_report "WARNING: Package manager lock file exists"
        fi
    fi
    
    # Check for broken packages
    if dpkg --configure -a 2>&1 | grep -q "broken"; then
        warning "Broken packages detected"
        append_report "WARNING: Broken packages detected"
    fi
}

# Docker tests
docker_tests() {
    section "Docker Tests"
    
    info "Testing Docker installation and functionality..."
    
    echo "=== Docker Tests ===" >> "$DEBUG_REPORT"
    
    # Check if Docker is installed
    if command -v docker >/dev/null 2>&1; then
        log "Docker installed ✓"
        append_report "✓ Docker installed"
        
        # Check Docker version
        local docker_version=$(docker --version)
        log "Docker version: $docker_version"
        append_report "Docker version: $docker_version"
        
        # Check if Docker daemon is running
        if systemctl is-active --quiet docker; then
            log "Docker daemon running ✓"
            append_report "✓ Docker daemon running"
        else
            error "Docker daemon not running"
            append_report "ERROR: Docker daemon not running"
            
            # Try to start Docker
            info "Attempting to start Docker daemon..."
            if systemctl start docker; then
                log "Docker daemon started ✓"
                append_report "✓ Docker daemon started successfully"
            else
                error "Failed to start Docker daemon"
                append_report "ERROR: Failed to start Docker daemon"
            fi
        fi
        
        # Test Docker functionality
        if docker run --rm hello-world >/dev/null 2>&1; then
            log "Docker functionality test ✓"
            append_report "✓ Docker functionality working"
        else
            error "Docker functionality test failed"
            append_report "ERROR: Docker functionality test failed"
        fi
        
    else
        error "Docker not installed"
        append_report "ERROR: Docker not installed"
    fi
    
    # Check Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        log "Docker Compose installed ✓"
        append_report "✓ Docker Compose installed"
        
        local compose_version=$(docker-compose --version)
        log "Docker Compose version: $compose_version"
        append_report "Docker Compose version: $compose_version"
    else
        error "Docker Compose not installed"
        append_report "ERROR: Docker Compose not installed"
    fi
}

# Port availability tests
port_tests() {
    section "Port Availability Tests"
    
    info "Testing port availability..."
    
    echo "=== Port Availability Tests ===" >> "$DEBUG_REPORT"
    
    local ports=(80 443 3000 5432 8000)
    
    for port in "${ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            warning "Port $port is already in use"
            append_report "WARNING: Port $port is in use"
            
            # Show what's using the port
            local process=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | head -1)
            info "Port $port is used by: $process"
            append_report "Port $port used by: $process"
        else
            log "Port $port available ✓"
            append_report "✓ Port $port available"
        fi
    done
}

# Firewall tests
firewall_tests() {
    section "Firewall Tests"
    
    info "Checking firewall configuration..."
    
    echo "=== Firewall Tests ===" >> "$DEBUG_REPORT"
    
    # Check UFW status
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status=$(ufw status 2>/dev/null | head -1)
        log "UFW status: $ufw_status"
        append_report "UFW status: $ufw_status"
        
        if ufw status | grep -q "Status: active"; then
            info "UFW is active"
            append_report "UFW is active"
            
            # Check specific rules
            if ufw status | grep -q "80/tcp"; then
                log "HTTP (80) allowed ✓"
                append_report "✓ HTTP (80) allowed"
            else
                warning "HTTP (80) not allowed"
                append_report "WARNING: HTTP (80) not allowed"
            fi
            
            if ufw status | grep -q "443/tcp"; then
                log "HTTPS (443) allowed ✓"
                append_report "✓ HTTPS (443) allowed"
            else
                warning "HTTPS (443) not allowed"
                append_report "WARNING: HTTPS (443) not allowed"
            fi
        fi
    else
        warning "UFW not installed"
        append_report "WARNING: UFW not installed"
    fi
    
    # Check iptables
    if command -v iptables >/dev/null 2>&1; then
        local iptables_rules=$(iptables -L | wc -l)
        log "iptables rules count: $iptables_rules"
        append_report "iptables rules count: $iptables_rules"
    fi
}

# Cloud provider detection
cloud_provider_detection() {
    section "Cloud Provider Detection"
    
    info "Detecting cloud provider..."
    
    echo "=== Cloud Provider Detection ===" >> "$DEBUG_REPORT"
    
    # Check for cloud provider metadata
    if curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/ >/dev/null 2>&1; then
        log "AWS EC2 detected ✓"
        append_report "✓ AWS EC2 detected"
        
        # Get instance metadata
        local instance_id=$(curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
        local instance_type=$(curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo "unknown")
        log "Instance ID: $instance_id"
        log "Instance Type: $instance_type"
        append_report "AWS Instance ID: $instance_id"
        append_report "AWS Instance Type: $instance_type"
        
    elif curl -s --connect-timeout 5 http://metadata.google.internal/computeMetadata/v1/ >/dev/null 2>&1; then
        log "Google Cloud Platform detected ✓"
        append_report "✓ Google Cloud Platform detected"
        
    elif curl -s --connect-timeout 5 http://169.254.169.254/metadata/instance >/dev/null 2>&1; then
        log "Azure detected ✓"
        append_report "✓ Azure detected"
        
    elif curl -s --connect-timeout 5 http://169.254.169.254/v1/ >/dev/null 2>&1; then
        log "DigitalOcean detected ✓"
        append_report "✓ DigitalOcean detected"
        
    else
        info "No cloud provider metadata detected (likely bare metal or VPS)"
        append_report "No cloud provider detected"
    fi
    
    # Check for cloud-init
    if command -v cloud-init >/dev/null 2>&1; then
        log "cloud-init installed ✓"
        append_report "✓ cloud-init installed"
        
        local cloud_init_status=$(cloud-init status 2>/dev/null || echo "unknown")
        log "cloud-init status: $cloud_init_status"
        append_report "cloud-init status: $cloud_init_status"
    else
        warning "cloud-init not installed"
        append_report "WARNING: cloud-init not installed"
    fi
}

# Supabase specific tests
supabase_tests() {
    section "Supabase Installation Tests"
    
    info "Testing Supabase installation..."
    
    echo "=== Supabase Tests ===" >> "$DEBUG_REPORT"
    
    # Check if Supabase directory exists
    if [ -d "/srv/supabase" ]; then
        log "Supabase directory exists ✓"
        append_report "✓ Supabase directory exists"
        
        # Check if repository is cloned
        if [ -d "/srv/supabase/supabase" ]; then
            log "Supabase repository cloned ✓"
            append_report "✓ Supabase repository cloned"
            
            # Check if .env file exists
            if [ -f "/srv/supabase/supabase/docker/.env" ]; then
                log "Supabase .env file exists ✓"
                append_report "✓ Supabase .env file exists"
            else
                warning "Supabase .env file missing"
                append_report "WARNING: Supabase .env file missing"
            fi
        else
            error "Supabase repository not cloned"
            append_report "ERROR: Supabase repository not cloned"
        fi
    else
        error "Supabase directory not found"
        append_report "ERROR: Supabase directory not found"
    fi
    
    # Check if Docker containers are running
    if command -v docker >/dev/null 2>&1; then
        local running_containers=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep -v "NAMES" | wc -l)
        log "Running Docker containers: $running_containers"
        append_report "Running Docker containers: $running_containers"
        
        if [ $running_containers -gt 0 ]; then
            info "Docker containers:"
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | while read line; do
                info "  $line"
                append_report "Container: $line"
            done
        fi
    fi
}

# Nginx tests
nginx_tests() {
    section "Nginx Tests"
    
    info "Testing Nginx configuration..."
    
    echo "=== Nginx Tests ===" >> "$DEBUG_REPORT"
    
    # Check if Nginx is installed
    if command -v nginx >/dev/null 2>&1; then
        log "Nginx installed ✓"
        append_report "✓ Nginx installed"
        
        # Check Nginx version
        local nginx_version=$(nginx -v 2>&1)
        log "Nginx version: $nginx_version"
        append_report "Nginx version: $nginx_version"
        
        # Check if Nginx is running
        if systemctl is-active --quiet nginx; then
            log "Nginx service running ✓"
            append_report "✓ Nginx service running"
        else
            warning "Nginx service not running"
            append_report "WARNING: Nginx service not running"
        fi
        
        # Test Nginx configuration
        if nginx -t >/dev/null 2>&1; then
            log "Nginx configuration valid ✓"
            append_report "✓ Nginx configuration valid"
        else
            error "Nginx configuration invalid"
            append_report "ERROR: Nginx configuration invalid"
            
            # Show configuration errors
            info "Nginx configuration errors:"
            nginx -t 2>&1 | while read line; do
                error "  $line"
                append_report "Nginx error: $line"
            done
        fi
        
        # Check for Supabase site configuration
        if [ -f "/etc/nginx/sites-available/supabase" ]; then
            log "Supabase Nginx configuration exists ✓"
            append_report "✓ Supabase Nginx configuration exists"
        else
            warning "Supabase Nginx configuration missing"
            append_report "WARNING: Supabase Nginx configuration missing"
        fi
        
    else
        error "Nginx not installed"
        append_report "ERROR: Nginx not installed"
    fi
}

# SSL certificate tests
ssl_tests() {
    section "SSL Certificate Tests"
    
    info "Testing SSL certificates..."
    
    echo "=== SSL Certificate Tests ===" >> "$DEBUG_REPORT"
    
    # Check if Certbot is installed
    if command -v certbot >/dev/null 2>&1; then
        log "Certbot installed ✓"
        append_report "✓ Certbot installed"
        
        # Check certificate status
        if [ -d "/etc/letsencrypt/live" ]; then
            local cert_count=$(find /etc/letsencrypt/live -name "*.pem" | wc -l)
            log "SSL certificates found: $cert_count"
            append_report "SSL certificates found: $cert_count"
            
            # List certificates
            certbot certificates 2>/dev/null | while read line; do
                info "  $line"
                append_report "Certificate: $line"
            done
        else
            warning "No SSL certificates found"
            append_report "WARNING: No SSL certificates found"
        fi
    else
        warning "Certbot not installed"
        append_report "WARNING: Certbot not installed"
    fi
}

# Generate recommendations
generate_recommendations() {
    section "Recommendations"
    
    info "Generating recommendations based on test results..."
    
    echo "=== Recommendations ===" >> "$DEBUG_REPORT"
    
    # Check memory
    local memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [ $memory_gb -lt 2 ]; then
        warning "RECOMMENDATION: Upgrade to at least 2GB RAM for better performance"
        append_report "RECOMMENDATION: Upgrade to at least 2GB RAM"
    fi
    
    # Check disk space
    local disk_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [ $disk_gb -lt 10 ]; then
        warning "RECOMMENDATION: Free up disk space or upgrade storage"
        append_report "RECOMMENDATION: Free up disk space"
    fi
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        warning "RECOMMENDATION: Install Docker first"
        append_report "RECOMMENDATION: Install Docker"
    fi
    
    # Check ports
    if netstat -tlnp 2>/dev/null | grep -q ":80 "; then
        warning "RECOMMENDATION: Port 80 is in use. Check what's using it and stop if needed"
        append_report "RECOMMENDATION: Port 80 conflict"
    fi
    
    if netstat -tlnp 2>/dev/null | grep -q ":443 "; then
        warning "RECOMMENDATION: Port 443 is in use. Check what's using it and stop if needed"
        append_report "RECOMMENDATION: Port 443 conflict"
    fi
    
    log "Recommendations generated ✓"
}

# Main function
main() {
    section "Supabase Installation Debug Tool"
    
    info "Starting comprehensive system diagnostics..."
    info "Debug report will be saved to: $DEBUG_REPORT"
    
    check_root
    system_info
    network_tests
    package_manager_tests
    docker_tests
    port_tests
    firewall_tests
    cloud_provider_detection
    supabase_tests
    nginx_tests
    ssl_tests
    generate_recommendations
    
    section "Debug Report Complete"
    
    log "Debug report saved to: $DEBUG_REPORT"
    info "Report contents:"
    echo ""
    cat "$DEBUG_REPORT"
    echo ""
    
    info "To share this report, copy the contents above or send the file:"
    info "cat $DEBUG_REPORT"
    
    log "Debug analysis complete!"
}

# Run main function
main "$@"
