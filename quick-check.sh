#!/bin/bash

# Quick Check Script - Run this to see what's wrong

echo "🔍 Quick Supabase Status Check"
echo "================================"

# Check if Supabase directory exists
if [ -d "/srv/supabase" ]; then
    echo "✅ Supabase directory exists"
else
    echo "❌ Supabase directory missing - installation incomplete"
    exit 1
fi

# Check if Docker is running
if systemctl is-active --quiet docker; then
    echo "✅ Docker is running"
else
    echo "❌ Docker is not running"
    echo "   Fix: sudo systemctl start docker"
fi

# Check Supabase services
echo ""
echo "🐳 Supabase Services Status:"
cd /srv/supabase/supabase/docker 2>/dev/null && docker-compose ps || echo "❌ Cannot access Supabase Docker directory"

# Check Nginx
echo ""
echo "🌐 Nginx Status:"
if systemctl is-active --quiet nginx; then
    echo "✅ Nginx is running"
else
    echo "❌ Nginx is not running"
fi

# Check Nginx configuration
echo ""
echo "📋 Nginx Configuration:"
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    echo "❌ Default Nginx site is enabled (this is the problem!)"
    echo "   Fix: sudo rm /etc/nginx/sites-enabled/default"
fi

if [ -f "/etc/nginx/sites-enabled/supabase" ]; then
    echo "✅ Supabase Nginx site is enabled"
else
    echo "❌ Supabase Nginx site is not enabled"
fi

# Check if Kong is responding
echo ""
echo "🚪 Kong API Gateway:"
if curl -s --connect-timeout 3 http://localhost:8000 >/dev/null; then
    echo "✅ Kong is responding"
else
    echo "❌ Kong is not responding"
fi

# Check ports
echo ""
echo "🔌 Port Status:"
netstat -tlnp 2>/dev/null | grep -E ":(80|443|3000|5432|8000)" | while read line; do
    echo "   $line"
done

echo ""
echo "🔧 Quick Fix Commands:"
echo "sudo ./fix-nginx-supabase.sh"
echo ""
echo "Or manual fixes:"
echo "cd /srv/supabase/supabase/docker && sudo docker-compose up -d"
echo "sudo rm /etc/nginx/sites-enabled/default"
echo "sudo ln -s /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/supabase"
echo "sudo systemctl restart nginx"
