# Supabase Installation Troubleshooting Guide

This guide helps you diagnose and fix common issues when installing Supabase on cloud servers.

## 🚨 Quick Diagnosis

### Step 1: Run the Debug Script
```bash
sudo ./debug-supabase.sh
```

This comprehensive diagnostic tool will:
- Check system requirements
- Test network connectivity
- Verify package installations
- Identify common cloud server issues
- Generate a detailed report

### Step 2: Check Installation Logs
```bash
# If you ran with debug mode
sudo cat /tmp/supabase-install-*.log

# Check system logs
sudo journalctl -u docker
sudo journalctl -u nginx
```

## 🔍 Common Issues and Solutions

### 1. Network Connectivity Issues

**Problem:** Installation fails due to network timeouts or connectivity issues.

**Symptoms:**
- `curl: (7) Failed to connect to...`
- `apt-get update` fails
- Docker image pulls fail

**Solutions:**

```bash
# Test basic connectivity
ping -c 3 8.8.8.8
ping -c 3 google.com

# Check DNS resolution
nslookup google.com

# Test HTTPS connectivity
curl -I https://github.com

# If behind a proxy, configure it
export http_proxy=http://proxy-server:port
export https_proxy=http://proxy-server:port

# For corporate networks, you may need to configure Docker proxy
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null <<EOF
[Service]
Environment="HTTP_PROXY=http://proxy-server:port"
Environment="HTTPS_PROXY=http://proxy-server:port"
Environment="NO_PROXY=localhost,127.0.0.1"
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 2. Package Manager Issues

**Problem:** `apt-get` commands fail or hang.

**Symptoms:**
- `E: Could not get lock /var/lib/dpkg/lock-frontend`
- `E: Unable to lock the administration directory`
- Package installation hangs

**Solutions:**

```bash
# Kill any running package manager processes
sudo pkill -f apt
sudo pkill -f dpkg

# Remove lock files
sudo rm -f /var/lib/dpkg/lock-frontend
sudo rm -f /var/lib/dpkg/lock
sudo rm -f /var/cache/apt/archives/lock

# Fix broken packages
sudo dpkg --configure -a
sudo apt-get -f install

# Clean package cache
sudo apt-get clean
sudo apt-get autoclean

# Update package lists
sudo apt-get update
```

### 3. Docker Installation Issues

**Problem:** Docker fails to install or start.

**Symptoms:**
- `docker: command not found`
- `Failed to start docker.service`
- Docker daemon won't start

**Solutions:**

```bash
# Check if Docker is installed
which docker
docker --version

# If not installed, install manually
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Check Docker status
sudo systemctl status docker

# Test Docker functionality
sudo docker run hello-world

# If Docker daemon fails to start, check logs
sudo journalctl -u docker.service

# Common fixes for Docker daemon issues
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 4. Port Conflicts

**Problem:** Required ports (80, 443, 3000, 5432, 8000) are already in use.

**Symptoms:**
- `Address already in use`
- Services fail to start
- Connection refused errors

**Solutions:**

```bash
# Check what's using the ports
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443
sudo netstat -tlnp | grep :3000
sudo netstat -tlnp | grep :5432
sudo netstat -tlnp | grep :8000

# Stop conflicting services
sudo systemctl stop apache2    # If Apache is using port 80
sudo systemctl stop nginx      # If Nginx is using port 80/443
sudo systemctl stop postgresql # If PostgreSQL is using port 5432

# Or kill processes by PID
sudo kill -9 <PID>

# Check for other web servers
sudo systemctl list-units --type=service | grep -E "(apache|nginx|httpd)"
```

### 5. Memory Issues

**Problem:** System runs out of memory during installation or operation.

**Symptoms:**
- `Cannot allocate memory`
- System becomes unresponsive
- Docker containers killed

**Solutions:**

```bash
# Check memory usage
free -h
htop

# Add swap space if needed
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make swap permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Optimize Docker memory usage
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
sudo systemctl restart docker
```

### 6. Disk Space Issues

**Problem:** Installation fails due to insufficient disk space.

**Symptoms:**
- `No space left on device`
- Package installation fails
- Docker image pulls fail

**Solutions:**

```bash
# Check disk usage
df -h
du -sh /var/lib/docker
du -sh /tmp

# Clean up Docker
sudo docker system prune -a
sudo docker volume prune

# Clean up package cache
sudo apt-get clean
sudo apt-get autoclean
sudo apt-get autoremove

# Clean up logs
sudo journalctl --vacuum-time=7d
sudo find /var/log -name "*.log" -type f -mtime +7 -delete

# Clean up temporary files
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
```

### 7. SSL Certificate Issues

**Problem:** SSL certificate generation fails.

**Symptoms:**
- `certbot: command not found`
- `Failed to obtain certificate`
- SSL configuration errors

**Solutions:**

```bash
# Install Certbot manually
sudo snap install core && sudo snap refresh core
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# Test certificate generation
sudo certbot --version

# For cloud servers, ensure ports 80 and 443 are open
sudo ufw allow 80
sudo ufw allow 443

# Check if domain points to your server
nslookup your-domain.com

# Test certificate generation manually
sudo certbot certonly --standalone --dry-run -d your-domain.com
```

### 8. Cloud Provider Specific Issues

#### AWS EC2
```bash
# Check security groups (ports 80, 443, 22 must be open)
# Check if instance has public IP
curl -s http://169.254.169.254/latest/meta-data/public-ipv4

# Check if cloud-init completed
sudo cloud-init status
```

#### Google Cloud Platform
```bash
# Check firewall rules
gcloud compute firewall-rules list

# Check if instance has external IP
curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip
```

#### DigitalOcean
```bash
# Check if droplet has public IP
curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address

# Check firewall settings in DigitalOcean control panel
```

#### Azure
```bash
# Check network security groups
# Ensure ports 80, 443, 22 are open
# Check if VM has public IP
```

### 9. Firewall Issues

**Problem:** Services are blocked by firewall rules.

**Symptoms:**
- Connection refused from external IPs
- Services work locally but not remotely
- UFW configuration errors

**Solutions:**

```bash
# Check UFW status
sudo ufw status verbose

# Allow required ports
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS

# If UFW is not active, enable it
sudo ufw --force enable

# Check iptables rules
sudo iptables -L -n

# Reset firewall if needed
sudo ufw --force reset
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable
```

### 10. Service Startup Issues

**Problem:** Supabase services fail to start.

**Symptoms:**
- Docker containers exit immediately
- Services show as failed
- Connection refused errors

**Solutions:**

```bash
# Check service status
sudo ./manage-supabase.sh status

# View detailed logs
sudo ./manage-supabase.sh logs

# Check individual container logs
sudo docker logs supabase_db_1
sudo docker logs supabase_kong_1
sudo docker logs supabase_studio_1

# Restart services
sudo ./manage-supabase.sh restart

# Check Docker Compose file
cd /srv/supabase/supabase/docker
sudo docker-compose config

# Test with minimal configuration
sudo docker-compose up -d db
sudo docker-compose logs db
```

## 🔧 Advanced Debugging

### Enable Verbose Logging
```bash
# Run installation with debug mode
sudo ./install-supabase.sh --debug

# Check debug log
sudo cat /tmp/supabase-install-*.log
```

### Manual Service Testing
```bash
# Test database connection
sudo docker exec -it supabase_db_1 psql -U postgres -c "SELECT version();"

# Test API endpoint
curl -I http://localhost:8000/rest/v1/

# Test Studio
curl -I http://localhost:3000

# Check Nginx configuration
sudo nginx -t
sudo systemctl status nginx
```

### Network Debugging
```bash
# Check listening ports
sudo netstat -tlnp
sudo ss -tlnp

# Test local connectivity
curl -I http://localhost:8000
curl -I http://localhost:3000

# Test external connectivity
curl -I http://your-server-ip:8000
```

## 📞 Getting Help

### 1. Collect Debug Information
```bash
# Run comprehensive diagnostics
sudo ./debug-supabase.sh

# Save the output
sudo ./debug-supabase.sh > debug-report.txt 2>&1
```

### 2. Check Logs
```bash
# System logs
sudo journalctl -u docker --since "1 hour ago"
sudo journalctl -u nginx --since "1 hour ago"

# Application logs
sudo ./manage-supabase.sh logs

# Installation logs (if debug mode was used)
sudo cat /tmp/supabase-install-*.log
```

### 3. System Information
```bash
# OS information
cat /etc/os-release
uname -a

# Resource usage
free -h
df -h
top

# Network information
ip addr show
ip route show
```

### 4. Create Support Request
When asking for help, include:
- Output from `sudo ./debug-supabase.sh`
- System information (`uname -a`, `cat /etc/os-release`)
- Error messages and logs
- Steps to reproduce the issue
- Cloud provider and instance type

## 🚀 Prevention Tips

### Before Installation
1. **Check system requirements:**
   - Minimum 2GB RAM (4GB recommended)
   - Minimum 10GB free disk space
   - Ubuntu 20.04 or later

2. **Ensure network connectivity:**
   - Test internet connection
   - Check DNS resolution
   - Verify no proxy issues

3. **Check for conflicts:**
   - Ensure ports 80, 443, 3000, 5432, 8000 are free
   - Stop conflicting services
   - Check firewall settings

### During Installation
1. **Use debug mode:**
   ```bash
   sudo ./install-supabase.sh --debug
   ```

2. **Monitor system resources:**
   ```bash
   # In another terminal
   watch -n 1 'free -h && df -h'
   ```

3. **Check logs regularly:**
   ```bash
   tail -f /tmp/supabase-install-*.log
   ```

### After Installation
1. **Verify all services:**
   ```bash
   sudo ./manage-supabase.sh status
   ```

2. **Test functionality:**
   ```bash
   curl -I http://your-server-ip
   ```

3. **Set up monitoring:**
   ```bash
   # Create a simple health check script
   cat > /usr/local/bin/supabase-health.sh << 'EOF'
   #!/bin/bash
   curl -f http://localhost:8000/rest/v1/ > /dev/null 2>&1
   if [ $? -eq 0 ]; then
       echo "Supabase is healthy"
   else
       echo "Supabase is not responding"
       exit 1
   fi
   EOF
   chmod +x /usr/local/bin/supabase-health.sh
   ```

## 📚 Additional Resources

- [Supabase Documentation](https://supabase.com/docs)
- [Docker Troubleshooting](https://docs.docker.com/config/troubleshooting/)
- [Nginx Troubleshooting](https://nginx.org/en/docs/http/ngx_http_core_module.html)
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)

---

**Remember:** Most issues can be resolved by running the debug script and following the recommendations it provides. The debug script is designed to identify common cloud server issues and provide specific solutions.
