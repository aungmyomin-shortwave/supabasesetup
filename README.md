# Supabase Self-Hosted Installation

A comprehensive, production-ready installation and management solution for self-hosted Supabase instances. This package converts the DigitalOcean 1-Click Supabase configuration into a standalone shell script solution that can be deployed on any Ubuntu system.

## 🚀 Quick Start

### Prerequisites

- Ubuntu 20.04 or later
- Minimum 2GB RAM (4GB recommended)
- Minimum 10GB free disk space
- Root access or sudo privileges
- Internet connection

### Installation

1. **Clone or download this repository:**
   ```bash
   git clone <repository-url>
   cd supabase-installer
   ```

2. **Run the quick setup:**
   ```bash
   sudo ./setup.sh
   ```

3. **Or run the full installation manually:**
   ```bash
   sudo ./install-supabase.sh
   ```

4. **Start Supabase services:**
   ```bash
   sudo ./manage-supabase.sh start
   ```

5. **Access your Supabase instance:**
   - **Supabase Studio:** http://your-server-ip
   - **API Endpoint:** http://your-server-ip/rest/v1/
   - **Auth Endpoint:** http://your-server-ip/auth/v1/
   - **Realtime Endpoint:** http://your-server-ip/realtime/v1/

## 📋 Management Commands

Use the `manage-supabase.sh` script for all management operations:

```bash
# Service Management
sudo ./manage-supabase.sh start      # Start all Supabase services
sudo ./manage-supabase.sh stop       # Stop all Supabase services
sudo ./manage-supabase.sh restart    # Restart all services
sudo ./manage-supabase.sh status     # Show service status

# Monitoring & Debugging
sudo ./manage-supabase.sh logs       # View real-time logs
sudo ./manage-supabase.sh help       # Show all available commands

# Configuration
sudo ./manage-supabase.sh ssl        # Configure SSL certificates
sudo ./manage-supabase.sh update     # Update to latest Supabase version

# Data Management
sudo ./manage-supabase.sh backup     # Create database backup
sudo ./manage-supabase.sh restore    # Restore from backup (coming soon)
```

## 🔐 SSL Configuration

To enable HTTPS for your Supabase instance:

1. **Ensure your domain points to your server:**
   ```bash
   # Check if your domain resolves to your server
   nslookup your-domain.com
   ```

2. **Run the SSL configuration:**
   ```bash
   sudo ./manage-supabase.sh ssl
   ```

3. **Follow the prompts:**
   - Enter your domain name (e.g., `supabase.example.com`)
   - Enter your email address for Let's Encrypt

4. **Access your secure Supabase instance:**
   - **HTTPS Studio:** https://your-domain.com
   - **Secure API:** https://your-domain.com/rest/v1/

## 🔑 Default Credentials

After starting Supabase, the dashboard credentials are automatically generated and saved to:
```
/srv/supabase/supabase/docker/.env
```

**Default credentials:**
- **Username:** `supabase`
- **Password:** Generated randomly (check the .env file)

To view the credentials:
```bash
sudo cat /srv/supabase/supabase/docker/.env | grep DASHBOARD
```

## 📁 File Structure

```
supabase-installer/
├── install-supabase.sh              # Main installation script
├── setup.sh                         # Quick setup wrapper
├── manage-supabase.sh               # Management script (created during install)
├── README.md                        # This documentation
├── configs/
│   ├── supabase.env                 # Environment configuration template
│   └── docker-compose.override.yml  # Docker Compose overrides
├── scripts/                         # Management scripts (created during install)
│   ├── configure-ssl.sh             # SSL configuration script
│   └── start-supabase.sh            # Service startup script
└── templates/                       # Configuration templates (created during install)
    └── nginx-ssl.conf               # SSL-enabled Nginx configuration
```

## ⚙️ Configuration

### Environment Variables

Edit `/srv/supabase/supabase/docker/.env` to customize your Supabase instance:

```bash
# Database Configuration
POSTGRES_PASSWORD=your_secure_password_here
POSTGRES_DB=postgres

# Supabase Configuration
SUPABASE_URL=http://localhost:8000
SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here

# Dashboard Configuration
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=your_dashboard_password_here

# API Configuration
API_EXTERNAL_URL=http://localhost:8000
SITE_URL=http://localhost:3000

# Security Configuration
JWT_SECRET=your_jwt_secret_here
JWT_EXPIRY=3600
DISABLE_SIGNUP=false
```

### Nginx Configuration

The installation automatically configures Nginx as a reverse proxy. Configuration files are located at:
- **HTTP Config:** `/etc/nginx/sites-available/supabase`
- **SSL Config:** Created during SSL setup

### Firewall Configuration

UFW firewall is automatically configured with the following rules:
- SSH access (limited)
- HTTP (port 80)
- HTTPS (port 443)

## 🔧 Troubleshooting

### Common Issues

**1. Services won't start:**
```bash
# Check service status
sudo ./manage-supabase.sh status

# View detailed logs
sudo ./manage-supabase.sh logs

# Check Docker status
sudo systemctl status docker
```

**2. SSL certificate issues:**
```bash
# Test SSL configuration
sudo nginx -t

# Check certificate status
sudo certbot certificates

# Renew certificates manually
sudo certbot renew
```

**3. Database connection issues:**
```bash
# Check database container
sudo docker ps | grep postgres

# View database logs
sudo docker logs supabase_db_1
```

**4. Port conflicts:**
```bash
# Check what's using ports
sudo netstat -tlnp | grep :8000
sudo netstat -tlnp | grep :3000
```

### Log Locations

- **Supabase Logs:** `sudo ./manage-supabase.sh logs`
- **Nginx Logs:** `/var/log/nginx/supabase.access.log` and `/var/log/nginx/supabase.error.log`
- **System Logs:** `/var/log/syslog`
- **Docker Logs:** `sudo docker logs <container-name>`

### Performance Optimization

**For small servers (1-2GB RAM):**
```bash
# Edit Docker Compose file to reduce memory usage
sudo nano /srv/supabase/supabase/docker/docker-compose.yml

# Add memory limits to services
services:
  db:
    deploy:
      resources:
        limits:
          memory: 512M
```

**For production deployments:**
- Use at least 4GB RAM
- Enable swap space
- Configure proper backup strategies
- Set up monitoring and alerting

## 🔄 Updates and Maintenance

### Updating Supabase

```bash
# Update to latest version
sudo ./manage-supabase.sh update
```

### Regular Maintenance

**Daily:**
- Monitor service status: `sudo ./manage-supabase.sh status`
- Check logs for errors: `sudo ./manage-supabase.sh logs`

**Weekly:**
- Create backups: `sudo ./manage-supabase.sh backup`
- Check disk space: `df -h`

**Monthly:**
- Update system packages: `sudo apt update && sudo apt upgrade`
- Review and rotate logs

### Backup and Restore

**Create Backup:**
```bash
sudo ./manage-supabase.sh backup
```

**Manual Backup:**
```bash
# Create backup directory
sudo mkdir -p /var/backups/supabase

# Backup database
cd /srv/supabase/supabase/docker
sudo docker compose exec -T postgres pg_dumpall -U postgres > /var/backups/supabase/backup_$(date +%Y%m%d_%H%M%S).sql
```

## 🌐 API Usage

### REST API

**Base URL:** `http://your-server-ip/rest/v1/`

**Example requests:**
```bash
# Get all tables
curl -H "apikey: YOUR_ANON_KEY" \
     -H "Authorization: Bearer YOUR_ANON_KEY" \
     http://your-server-ip/rest/v1/

# Insert data
curl -X POST \
     -H "apikey: YOUR_ANON_KEY" \
     -H "Authorization: Bearer YOUR_ANON_KEY" \
     -H "Content-Type: application/json" \
     -d '{"name": "John Doe", "email": "john@example.com"}' \
     http://your-server-ip/rest/v1/users
```

### Authentication

**Base URL:** `http://your-server-ip/auth/v1/`

**Example:**
```bash
# Sign up a new user
curl -X POST \
     -H "apikey: YOUR_ANON_KEY" \
     -H "Content-Type: application/json" \
     -d '{"email": "user@example.com", "password": "password123"}' \
     http://your-server-ip/auth/v1/signup
```

### Realtime

**WebSocket URL:** `ws://your-server-ip/realtime/v1/`

## 🔒 Security Considerations

### Production Security Checklist

- [ ] Change default passwords
- [ ] Configure SSL certificates
- [ ] Set up proper firewall rules
- [ ] Enable database backups
- [ ] Configure log monitoring
- [ ] Set up intrusion detection
- [ ] Regular security updates
- [ ] Configure rate limiting
- [ ] Set up monitoring alerts

### Security Best Practices

1. **Regular Updates:**
   ```bash
   sudo apt update && sudo apt upgrade
   sudo ./manage-supabase.sh update
   ```

2. **Firewall Configuration:**
   ```bash
   # Check firewall status
   sudo ufw status
   
   # Allow only necessary ports
   sudo ufw allow ssh
   sudo ufw allow 80
   sudo ufw allow 443
   ```

3. **SSL/TLS Configuration:**
   - Use strong SSL ciphers
   - Enable HSTS headers
   - Regular certificate renewal

## 📞 Support and Resources

### Documentation

- **Supabase Official Docs:** https://supabase.com/docs
- **Supabase GitHub:** https://github.com/supabase/supabase
- **Docker Documentation:** https://docs.docker.com/

### Community

- **Supabase Discord:** https://discord.supabase.com/
- **Supabase GitHub Discussions:** https://github.com/supabase/supabase/discussions

### Issues and Bug Reports

If you encounter issues with this installation script:

1. Check the troubleshooting section above
2. Review the logs: `sudo ./manage-supabase.sh logs`
3. Search existing issues in the repository
4. Create a new issue with:
   - System information (`uname -a`)
   - Installation logs
   - Error messages
   - Steps to reproduce

## 📄 License

This project is based on the DigitalOcean 1-Click Supabase configuration and is provided under the MIT License. See the original DigitalOcean repository for more information.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

**Happy coding with Supabase! 🎉**

For questions or support, please refer to the Supabase community resources or create an issue in this repository.
