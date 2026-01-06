#!/bin/bash
# MiniRack Dashboard - FINAL WORKING Launch Script
# Copy and paste this ENTIRE script into the Lightsail "Launch script" field

set -e
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Update system and install packages
apt-get update -y
apt-get install -y python3-pip nginx git curl python3-venv

# Create directories
mkdir -p /opt/eero/{app,logs}

# Download the WORKING files directly from GitHub
curl -o /opt/eero/app/dashboard.py https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
curl -o /opt/eero/app/index.html https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html
curl -o /opt/eero/app/config.json https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/config.json
curl -o /opt/eero/app/requirements.txt https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/requirements.txt

# Verify files downloaded
if [ ! -f "/opt/eero/app/dashboard.py" ]; then
    echo "Failed to download files"
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

# COMPLETELY remove nginx defaults
systemctl stop nginx || true
rm -rf /etc/nginx/sites-enabled/*
rm -rf /etc/nginx/sites-available/default
rm -f /var/www/html/index.nginx-debian.html

# Create nginx config that ONLY serves our dashboard
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

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;
        
        location / {
            proxy_pass http://127.0.0.1:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }
    }
}
EOF

# Start services in correct order
systemctl daemon-reload
systemctl enable eero-dashboard
systemctl start eero-dashboard

# Wait for Flask app to be ready
echo "Waiting for dashboard to start..."
for i in {1..30}; do
    if curl -f http://localhost:5000/health > /dev/null 2>&1; then
        echo "Dashboard is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Dashboard failed to start"
        systemctl status eero-dashboard
        exit 1
    fi
    sleep 2
done

# Start nginx
systemctl enable nginx
systemctl start nginx

# Test final result
echo "Testing final setup..."
for i in {1..10}; do
    if curl -s http://localhost/ | grep -q "Network Dashboard" 2>/dev/null; then
        echo "SUCCESS: Dashboard is working!"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "FAILED: Dashboard not accessible"
        exit 1
    fi
    sleep 2
done

# Configure firewall
ufw allow 80/tcp
ufw allow 22/tcp
ufw --force enable

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "unknown")

echo "=========================================="
echo "✅ MiniRack Dashboard Installation Complete!"
echo "🌐 Access your dashboard at: http://$PUBLIC_IP"
echo "🔧 Click the π button to configure your API"
echo "=========================================="