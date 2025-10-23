#!/bin/bash

# Quick Manual Fix for Docker Compose Issues
echo "🔧 Quick Fix for Docker Compose Issues"
echo "======================================"

# Navigate to Supabase directory
cd /srv/supabase/supabase/docker

echo "📝 Fixing Docker Compose file..."

# Remove the problematic 'name' field
sed -i '/^name:/d' docker-compose.yml

# Fix boolean environment variables
sed -i 's/NEXT_PUBLIC_ENABLE_LOGS: true/NEXT_PUBLIC_ENABLE_LOGS: "true"/g' docker-compose.yml
sed -i 's/LOGFLARE_SINGLE_TENANT: true/LOGFLARE_SINGLE_TENANT: "true"/g' docker-compose.yml
sed -i 's/SEED_SELF_HOST: true/SEED_SELF_HOST: "true"/g' docker-compose.yml
sed -i 's/CLUSTER_POSTGRES: true/CLUSTER_POSTGRES: "true"/g' docker-compose.yml

echo "✅ Docker Compose file fixed"

# Test the file
echo "🧪 Testing Docker Compose file..."
if docker-compose config >/dev/null 2>&1; then
    echo "✅ Docker Compose file is valid"
else
    echo "❌ Still has issues"
    exit 1
fi

# Start services
echo "🚀 Starting Supabase services..."
export SUPABASE_PASSWORD=$(openssl rand -base64 12)

# Add dashboard credentials
cat >> .env <<EOM
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=${SUPABASE_PASSWORD}
EOM

docker-compose up -d

echo "✅ Services started"
echo "🔑 Dashboard credentials:"
echo "   Username: supabase"
echo "   Password: $SUPABASE_PASSWORD"

# Fix Nginx
echo "🌐 Fixing Nginx..."
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/supabase
sudo systemctl restart nginx

echo "✅ Nginx fixed"
echo "🎉 Done! Access Supabase at: http://$(hostname -I | awk '{print $1}')"
