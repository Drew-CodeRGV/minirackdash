#!/bin/bash
# MiniRack Dashboard - Ultra Minimal Lightsail Launch Script (Under 16KB)
# Downloads and installs the full dashboard from GitHub

set -e
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Update and install essentials
apt-get update -y
apt-get install -y python3-pip nginx curl python3-venv

# Create directories
mkdir -p /opt/eero/{app,logs}

# Download application files from GitHub
echo "Downloading dashboard files..."
curl -o /opt/eero/app/dashboard.py https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
curl -o /opt/eero/app/index.html https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html
curl -o /opt/eero/app/config.json https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/config.json
curl -o /opt/eero/app/requirements.txt https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/requirements.txt

# Verify downloads
if [ ! -f "/opt/eero/app/dashboard.py" ] || [ ! -f "/opt/eero/app/index.html" ]; then
    echo "❌ Download failed"
    exit 1
fi

# Setup Python environment
cd /opt/eero
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r app/requirements.txt

# Set permissions
chown -R www-data:www-data /opt/eero
chmod +x /opt/eero/app/dashboard.py

# Create systemd service
cat > /etc/systemd/system/eero-dashboard.service << 'EOF'
[Unit]
Description=MiniRack Dashboard
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/eero/app
Environment=PATH=/opt/eero/venv/bin
ExecStart=/opt/eero/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 dashboard:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx - AGGRESSIVELY prevent default page
sudo systemctl stop nginx || true
sudo rm -rf /var/www/html/* /var/www/* /etc/nginx/sites-enabled/* /etc/nginx/sites-available/default* /etc/nginx/conf.d/*
cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    gzip on;

    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;
        root /nonexistent;
        
        location / {
            proxy_pass http://127.0.0.1:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
            proxy_buffering off;
        }
    }
}
EOF

# Start services with verification
systemctl daemon-reload
systemctl enable eero-dashboard
systemctl start eero-dashboard

# Wait for Flask app
echo "⏳ Starting dashboard..."
for i in {1..20}; do
    if curl -f http://localhost:5000/health > /dev/null 2>&1; then
        echo "✅ Dashboard ready"
        break
    fi
    [ $i -eq 20 ] && { echo "❌ Dashboard failed"; systemctl status eero-dashboard; exit 1; }
    sleep 2
done

# Start nginx
systemctl enable nginx
systemctl restart nginx

# Verify complete setup
echo "🔍 Testing setup with anti-default-page verification..."
for i in {1..10}; do
    RESPONSE=$(curl -s http://localhost/)
    if echo "$RESPONSE" | grep -q "Dashboard" && ! echo "$RESPONSE" | grep -q "Welcome to nginx"; then
        echo "✅ Setup complete and verified!"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "❌ Still getting nginx default page"
        echo "Response: $(echo "$RESPONSE" | head -c 200)"
        exit 1
    fi
    echo "⏳ Test $i: Verifying proper setup..."
    sleep 2
done

# Configure firewall
ufw allow 80/tcp
ufw allow 22/tcp
ufw --force enable

# Success message
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "your-ip")
echo ""
echo "🎉 MiniRack Dashboard v6.7.1 installed successfully!"
echo "🌐 Access: http://$PUBLIC_IP"
echo "🔧 Configure via π admin menu (bottom-right)"
echo "📋 Features: Multi-network support, timezone config, data persistence"