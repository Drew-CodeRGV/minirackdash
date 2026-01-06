#!/bin/bash
# MiniRack Dashboard - Lightsail Boot Script - BULLETPROOF VERSION
# Repository: https://github.com/Drew-CodeRGV/minirackdash

set -e
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/minirack-install.log
}

log "🚀 MiniRack Dashboard - Starting BULLETPROOF Installation"

# Update system and install essentials
log "📦 Updating system packages..."
apt-get update -y >> /var/log/minirack-install.log 2>&1

log "📦 Installing system packages..."
apt-get install -y python3-pip nginx git curl python3-venv >> /var/log/minirack-install.log 2>&1

# Create directories first
log "📁 Creating directories..."
mkdir -p /opt/eero/{app,logs,backups}

# Download application files directly from GitHub
log "📥 Downloading application files..."
curl -o /opt/eero/app/dashboard.py https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py >> /var/log/minirack-install.log 2>&1
curl -o /opt/eero/app/index.html https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html >> /var/log/minirack-install.log 2>&1
curl -o /opt/eero/app/config.json https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/config.json >> /var/log/minirack-install.log 2>&1
curl -o /opt/eero/app/requirements.txt https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/requirements.txt >> /var/log/minirack-install.log 2>&1

# Verify files downloaded
if [ ! -f "/opt/eero/app/dashboard.py" ]; then
    log "❌ Failed to download application files"
    exit 1
fi

log "✅ Application files downloaded successfully"
# Create Python virtual environment
log "🐍 Creating Python virtual environment..."
cd /opt/eero
python3 -m venv venv >> /var/log/minirack-install.log 2>&1
source venv/bin/activate

# Install Python dependencies in virtual environment
log "📦 Installing Python dependencies..."
pip install --upgrade pip >> /var/log/minirack-install.log 2>&1
pip install -r app/requirements.txt >> /var/log/minirack-install.log 2>&1

# Set permissions
log "🔐 Setting permissions..."
chown -R www-data:www-data /opt/eero
chmod +x /opt/eero/app/dashboard.py

# Create systemd service
log "⚙️ Creating systemd service..."
cat > /etc/systemd/system/eero-dashboard.service << 'SERVICE_EOF'
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
SERVICE_EOF

# Configure Nginx for port 80
log "🌐 Configuring Nginx..."

# COMPLETELY remove nginx defaults
systemctl stop nginx || true
rm -rf /etc/nginx/sites-enabled/*
rm -rf /etc/nginx/sites-available/default
rm -f /var/www/html/index.nginx-debian.html
rm -f /var/www/html/index.html

# Create nginx config that ONLY serves our dashboard
cat > /etc/nginx/nginx.conf << 'NGINX_EOF'
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
NGINX_EOF

# Enable our site and disable default
log "🔗 Enabling Nginx site..."
ln -sf /etc/nginx/sites-available/eero-dashboard /etc/nginx/sites-enabled/

# Ensure no other sites are enabled
find /etc/nginx/sites-enabled/ -type l ! -name "eero-dashboard" -delete

# Test nginx config
log "✅ Testing Nginx configuration..."
if ! nginx -t >> /var/log/minirack-install.log 2>&1; then
    log "❌ Nginx configuration test failed"
    cat /var/log/nginx/error.log >> /var/log/minirack-install.log 2>&1 || true
    exit 1
fi

# Configure firewall
log "🔥 Configuring firewall..."
ufw allow 80/tcp >> /var/log/minirack-install.log 2>&1
ufw allow 22/tcp >> /var/log/minirack-install.log 2>&1
ufw --force enable >> /var/log/minirack-install.log 2>&1

# Start services
log "🚀 Starting services..."
systemctl daemon-reload

# Enable and start eero-dashboard
systemctl enable eero-dashboard
if ! systemctl start eero-dashboard; then
    log "❌ Failed to start eero-dashboard service"
    journalctl -u eero-dashboard --no-pager -n 20 >> /var/log/minirack-install.log 2>&1
    systemctl status eero-dashboard >> /var/log/minirack-install.log 2>&1 || true
    exit 1
fi

# Wait for service to be ready
log "⏳ Waiting for dashboard service to start..."
sleep 5

# Check if service is actually running
if ! systemctl is-active --quiet eero-dashboard; then
    log "❌ Dashboard service is not active"
    systemctl status eero-dashboard >> /var/log/minirack-install.log 2>&1 || true
    journalctl -u eero-dashboard --no-pager -n 20 >> /var/log/minirack-install.log 2>&1
    exit 1
fi

# Test if dashboard is responding on port 5000
log "🔍 Testing dashboard on port 5000..."
for i in {1..10}; do
    if curl -f http://localhost:5000/health > /dev/null 2>&1; then
        log "✅ Dashboard responding on port 5000"
        break
    fi
    if [ $i -eq 10 ]; then
        log "❌ Dashboard not responding on port 5000 after 10 attempts"
        systemctl status eero-dashboard >> /var/log/minirack-install.log 2>&1 || true
        journalctl -u eero-dashboard --no-pager -n 20 >> /var/log/minirack-install.log 2>&1
        exit 1
    fi
    log "⏳ Attempt $i: Dashboard not ready, waiting..."
    sleep 2
done

# Enable and restart nginx
systemctl enable nginx
if ! systemctl restart nginx; then
    log "❌ Failed to restart nginx service"
    journalctl -u nginx --no-pager -n 10 >> /var/log/minirack-install.log 2>&1
    nginx -t >> /var/log/minirack-install.log 2>&1 || true
    exit 1
fi

# Wait for nginx to be ready
log "⏳ Waiting for nginx to be ready..."
sleep 3

# Verify nginx is running and configured correctly
if ! systemctl is-active --quiet nginx; then
    log "❌ Nginx service is not active"
    systemctl status nginx >> /var/log/minirack-install.log 2>&1 || true
    exit 1
fi

# Test local connection multiple times
log "🔍 Testing local HTTP connection..."
for i in {1..5}; do
    if curl -f -s http://localhost/ | grep -q "MiniRack Dashboard" 2>/dev/null; then
        log "✅ Local HTTP test successful - Dashboard content detected"
        break
    fi
    if [ $i -eq 5 ]; then
        log "❌ Local HTTP test failed - Dashboard not loading properly"
        log "🔍 Debugging information:"
        curl -v http://localhost/ >> /var/log/minirack-install.log 2>&1 || true
        systemctl status eero-dashboard nginx >> /var/log/minirack-install.log 2>&1 || true
        journalctl -u eero-dashboard --no-pager -n 10 >> /var/log/minirack-install.log 2>&1
        journalctl -u nginx --no-pager -n 10 >> /var/log/minirack-install.log 2>&1
        exit 1
    fi
    log "⏳ Attempt $i: Testing connection..."
    sleep 3
done

# Final verification
log "🔍 Verifying installation..."
if systemctl is-active --quiet eero-dashboard && systemctl is-active --quiet nginx; then
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "unknown")
    log "✅ Services are running"
    log "🌐 Dashboard: http://$PUBLIC_IP"
    echo "✅ Installation complete!"
    echo "🌐 Dashboard: http://$PUBLIC_IP"
    echo "📋 Version: 6.3.0-bulletproof"
    echo "🔧 Configure your Network ID and API authentication via the web interface"
else
    log "❌ Services failed to start properly"
    systemctl status eero-dashboard >> /var/log/minirack-install.log 2>&1 || true
    systemctl status nginx >> /var/log/minirack-install.log 2>&1 || true
    exit 1
fi