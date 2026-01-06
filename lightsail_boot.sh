#!/bin/bash
# MiniRack Dashboard - Lightsail Boot Script
# Repository: https://github.com/Drew-CodeRGV/minirackdash

set -e
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/minirack-install.log
}

log "🚀 MiniRack Dashboard - Starting Installation"
log "Repository: https://github.com/Drew-CodeRGV/minirackdash"

# Update system and install essentials
log "📦 Updating system packages..."
apt-get update -y >> /var/log/minirack-install.log 2>&1

log "📦 Installing system packages..."
apt-get install -y python3-pip nginx git curl >> /var/log/minirack-install.log 2>&1

# Install Python packages
log "🐍 Installing Python packages..."
apt-get install -y python3-flask python3-requests python3-venv >> /var/log/minirack-install.log 2>&1
pip3 install --break-system-packages flask-cors gunicorn >> /var/log/minirack-install.log 2>&1

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
cat > /etc/systemd/system/eero-dashboard.service << 'EOF'
[Unit]
Description=MiniRack Dashboard
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/eero/app
Environment=PATH=/opt/eero/venv/bin
ExecStart=/opt/eero/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 dashboard:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx for port 80
log "🌐 Configuring Nginx..."
cat > /etc/nginx/sites-available/eero-dashboard << 'EOF'
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
EOF

# Enable site
log "🔗 Enabling Nginx site..."
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/eero-dashboard /etc/nginx/sites-enabled/

# Test nginx config
log "✅ Testing Nginx configuration..."
if ! nginx -t >> /var/log/minirack-install.log 2>&1; then
    log "❌ Nginx configuration test failed"
    exit 1
fi

# Create update script
log "🔄 Creating update script..."
cat > /opt/eero/update.sh << 'EOF'
#!/bin/bash
echo "🔄 Updating MiniRack Dashboard from GitHub..."
curl -o /opt/eero/app/dashboard.py https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
curl -o /opt/eero/app/index.html https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html
systemctl restart eero-dashboard
echo "✅ Update complete!"
EOF
chmod +x /opt/eero/update.sh

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
    journalctl -u eero-dashboard --no-pager -n 10 >> /var/log/minirack-install.log 2>&1
    exit 1
fi

# Enable and restart nginx
systemctl enable nginx
if ! systemctl restart nginx; then
    log "❌ Failed to restart nginx service"
    journalctl -u nginx --no-pager -n 10 >> /var/log/minirack-install.log 2>&1
    exit 1
fi

# Wait for services to be ready
log "⏳ Waiting for services to be ready..."
sleep 10

# Test local connection
log "🔍 Testing local connection..."
if curl -f http://localhost/ > /dev/null 2>&1; then
    log "✅ Local HTTP test successful"
else
    log "❌ Local HTTP test failed"
    systemctl status eero-dashboard >> /var/log/minirack-install.log 2>&1
    systemctl status nginx >> /var/log/minirack-install.log 2>&1
    exit 1
fi

# Final verification
log "🔍 Verifying installation..."
if systemctl is-active --quiet eero-dashboard && systemctl is-active --quiet nginx; then
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "unknown")
    log "✅ Services are running"
    log "🌐 Dashboard: http://$PUBLIC_IP"
    echo "✅ Installation complete!"
    echo "🌐 Dashboard: http://$PUBLIC_IP"
else
    log "❌ Services failed to start properly"
    systemctl status eero-dashboard >> /var/log/minirack-install.log 2>&1 || true
    systemctl status nginx >> /var/log/minirack-install.log 2>&1 || true
    exit 1
fi