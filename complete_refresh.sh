#!/bin/bash
# Complete Dashboard Refresh Script - Fix Everything
# This script completely refreshes the dashboard to ensure full functionality

set -e

echo "🔄 MiniRack Dashboard - Complete Refresh Starting..."

# Stop services
echo "⏹️ Stopping services..."
sudo systemctl stop eero-dashboard || true
sudo systemctl stop nginx || true

# Backup current files
echo "💾 Creating backups..."
sudo mkdir -p /opt/eero/backups/$(date +%Y%m%d_%H%M%S)
sudo cp -r /opt/eero/app/* /opt/eero/backups/$(date +%Y%m%d_%H%M%S)/ 2>/dev/null || true

# Download fresh files from GitHub
echo "📥 Downloading fresh files from GitHub..."
sudo curl -o /opt/eero/app/dashboard.py https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
sudo curl -o /opt/eero/app/index.html https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html
sudo curl -o /opt/eero/app/config.json https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/config.json

# Verify files are complete
echo "✅ Verifying file integrity..."
if ! grep -q "showAdmin" /opt/eero/app/index.html; then
    echo "❌ HTML file appears incomplete - missing admin functions"
    exit 1
fi

if ! grep -q "def index" /opt/eero/app/dashboard.py; then
    echo "❌ Python file appears incomplete"
    exit 1
fi

HTML_SIZE=$(wc -c < /opt/eero/app/index.html)
if [ "$HTML_SIZE" -lt 20000 ]; then
    echo "❌ HTML file too small ($HTML_SIZE bytes) - likely incomplete"
    exit 1
fi

echo "✅ Files verified - HTML: $HTML_SIZE bytes"

# Set proper permissions
echo "🔐 Setting permissions..."
sudo chown -R www-data:www-data /opt/eero
sudo chmod +x /opt/eero/app/dashboard.py
sudo chmod 644 /opt/eero/app/index.html
sudo chmod 644 /opt/eero/app/config.json

# Ensure virtual environment is working
echo "🐍 Checking Python environment..."
cd /opt/eero
if [ ! -d "venv" ]; then
    echo "Creating new virtual environment..."
    sudo -u www-data python3 -m venv venv
fi

# Fix pip cache permissions and install with proper flags
sudo mkdir -p /var/www/.cache
sudo chown -R www-data:www-data /var/www/.cache
sudo -H -u www-data /opt/eero/venv/bin/pip install --upgrade pip
sudo -H -u www-data /opt/eero/venv/bin/pip install -r app/requirements.txt

# Test Python file syntax
echo "🔍 Testing Python syntax..."
sudo -u www-data /opt/eero/venv/bin/python -m py_compile /opt/eero/app/dashboard.py

# Recreate systemd service to ensure it's correct
echo "⚙️ Recreating systemd service..."
sudo tee /etc/systemd/system/eero-dashboard.service > /dev/null << 'EOF'
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
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always
RestartSec=10
KillMode=mixed
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

# Recreate nginx config to ensure no conflicts
echo "🌐 Recreating nginx configuration..."
sudo tee /etc/nginx/nginx.conf > /dev/null << 'EOF'
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

# Remove any conflicting nginx sites
sudo rm -rf /etc/nginx/sites-enabled/*
sudo rm -rf /etc/nginx/sites-available/default

# Test nginx config
echo "✅ Testing nginx configuration..."
sudo nginx -t

# Reload systemd and start services
echo "🚀 Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable eero-dashboard
sudo systemctl start eero-dashboard

# Wait for dashboard to be ready
echo "⏳ Waiting for dashboard to start..."
sleep 5

# Check dashboard service
if ! sudo systemctl is-active --quiet eero-dashboard; then
    echo "❌ Dashboard service failed to start"
    sudo systemctl status eero-dashboard
    sudo journalctl -u eero-dashboard --no-pager -n 20
    exit 1
fi

# Test dashboard directly
echo "🔍 Testing dashboard on port 5000..."
for i in {1..10}; do
    if curl -f http://localhost:5000/health > /dev/null 2>&1; then
        echo "✅ Dashboard responding on port 5000"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "❌ Dashboard not responding after 10 attempts"
        sudo systemctl status eero-dashboard
        sudo journalctl -u eero-dashboard --no-pager -n 20
        exit 1
    fi
    echo "⏳ Attempt $i: Waiting for dashboard..."
    sleep 2
done

# Start nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# Wait for nginx
sleep 3

# Test complete dashboard functionality
echo "🔍 Testing complete dashboard..."
RESPONSE=$(curl -s http://localhost/)
if echo "$RESPONSE" | grep -q "showAdmin" && echo "$RESPONSE" | grep -q "π"; then
    echo "✅ Full dashboard detected with admin functionality"
else
    echo "❌ Dashboard missing admin functionality"
    echo "Response length: $(echo "$RESPONSE" | wc -c) characters"
    echo "First 200 chars: $(echo "$RESPONSE" | head -c 200)"
    exit 1
fi

# Final verification
if sudo systemctl is-active --quiet eero-dashboard && sudo systemctl is-active --quiet nginx; then
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    echo ""
    echo "✅ Complete refresh successful!"
    echo "🌐 Dashboard: http://$PUBLIC_IP"
    echo "📋 Version: 6.5.0-complete"
    echo "🔧 π Admin menu should now be fully functional"
    echo "📊 All charts and time ranges should work"
    echo ""
    echo "Test the π button in the bottom-right corner to access admin panel"
else
    echo "❌ Services not running properly"
    sudo systemctl status eero-dashboard nginx
    exit 1
fi