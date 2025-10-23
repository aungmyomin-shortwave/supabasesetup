# Supabase Debugging Quick Reference

## 🚨 Emergency Commands

### If Installation Fails
```bash
# Run comprehensive diagnostics
sudo ./debug-supabase.sh

# Check installation logs
sudo cat /tmp/supabase-install-*.log

# Check system resources
free -h && df -h
```

### If Services Won't Start
```bash
# Check service status
sudo ./manage-supabase.sh status

# View logs
sudo ./manage-supabase.sh logs

# Restart services
sudo ./manage-supabase.sh restart
```

### If Can't Access Supabase
```bash
# Check if services are running
sudo docker ps

# Test local connectivity
curl -I http://localhost:8000
curl -I http://localhost:3000

# Check firewall
sudo ufw status
```

## 🔍 Quick Diagnostics

### System Check
```bash
# Memory and disk
free -h
df -h

# Network
ping -c 3 8.8.8.8
curl -I https://github.com

# Ports
sudo netstat -tlnp | grep -E ":(80|443|3000|5432|8000)"
```

### Docker Check
```bash
# Docker status
sudo systemctl status docker
sudo docker --version
sudo docker ps

# Test Docker
sudo docker run hello-world
```

### Service Check
```bash
# Check all services
sudo systemctl status docker nginx

# Check Supabase containers
cd /srv/supabase/supabase/docker
sudo docker-compose ps
```

## 🛠️ Common Fixes

### Package Manager Issues
```bash
sudo pkill -f apt
sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock
sudo apt-get update
```

### Port Conflicts
```bash
# Find what's using ports
sudo lsof -i :80
sudo lsof -i :443

# Stop conflicting services
sudo systemctl stop apache2
sudo systemctl stop nginx
```

### Memory Issues
```bash
# Add swap
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Docker Issues
```bash
# Restart Docker
sudo systemctl restart docker

# Clean up Docker
sudo docker system prune -a
```

## 📊 Log Locations

| Service | Log Location |
|---------|-------------|
| Installation | `/tmp/supabase-install-*.log` |
| Docker | `sudo journalctl -u docker` |
| Nginx | `/var/log/nginx/` |
| Supabase | `sudo ./manage-supabase.sh logs` |
| System | `sudo journalctl` |

## 🌐 Network Tests

### Local Tests
```bash
curl -I http://localhost:8000/rest/v1/
curl -I http://localhost:3000
```

### External Tests
```bash
curl -I http://your-server-ip:8000
curl -I http://your-server-ip:3000
```

### SSL Tests
```bash
curl -I https://your-domain.com
openssl s_client -connect your-domain.com:443
```

## 🔧 Cloud Provider Specific

### AWS EC2
```bash
# Check public IP
curl -s http://169.254.169.254/latest/meta-data/public-ipv4

# Check security groups (in AWS console)
# Ensure ports 22, 80, 443 are open
```

### Google Cloud
```bash
# Check external IP
curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip

# Check firewall rules
gcloud compute firewall-rules list
```

### DigitalOcean
```bash
# Check droplet IP
curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address

# Check firewall in DO control panel
```

## 🚀 Recovery Commands

### Complete Reset
```bash
# Stop all services
sudo ./manage-supabase.sh stop

# Remove Supabase
sudo rm -rf /srv/supabase

# Clean Docker
sudo docker system prune -a

# Reinstall
sudo ./install-supabase.sh --debug
```

### Partial Reset
```bash
# Reset just Supabase
cd /srv/supabase/supabase/docker
sudo docker-compose down
sudo docker-compose up -d
```

## 📞 Support Information

When asking for help, provide:

1. **System Info:**
   ```bash
   uname -a
   cat /etc/os-release
   free -h
   df -h
   ```

2. **Debug Report:**
   ```bash
   sudo ./debug-supabase.sh > debug-report.txt 2>&1
   ```

3. **Service Status:**
   ```bash
   sudo ./manage-supabase.sh status
   sudo docker ps
   ```

4. **Error Messages:**
   - Copy exact error messages
   - Include relevant log snippets
   - Describe what you were doing when the error occurred

## 🎯 Most Common Issues

1. **Port 80/443 in use** → Stop Apache/Nginx
2. **Out of memory** → Add swap space
3. **Network issues** → Check firewall/security groups
4. **Docker won't start** → Restart Docker service
5. **SSL fails** → Check domain DNS and firewall

---

**Pro Tip:** Run `sudo ./debug-supabase.sh` first - it will identify 90% of common issues automatically!
