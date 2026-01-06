#!/bin/bash
# Fresh Install Script for MiniRack Dashboard
# This completely wipes and reinstalls everything from GitHub
# Usage: curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/minirackdash/main/deploy/fresh_install.sh | sudo bash

set -e

# Configuration - UPDATE THESE WITH YOUR DETAILS
GITHUB_USER="YOUR_USERNAME"  # Replace with your GitHub username
REPO_NAME="minirackdash"     # Replace with your repository name
GITHUB_REPO="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"

echo "🚀 MiniRack Dashboard - Fresh Installation"
echo "=========================================="
echo "Repository: ${GITHUB_REPO}"
echo "Target IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'Unknown')"
echo ""

# Stop and remove all existing services
echo "🧹 Cleaning up existing installation..."
systemctl stop eero 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true
systemctl disable eero 2>/dev/null || true

# Remove old files
rm -rf /opt/eero
rm -f /etc/systemd/system/eero.service
rm -f /etc/nginx/sites-enabled/eero-dashboard
rm -f /etc/nginx/sites-available/eero-dashboard

# Update system
echo "📦 Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install dependencies
echo "📦 Installing dependencies..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    nginx \
    git \
    curl \
    htop \
    ufw

# Install Python packages globally
echo "🐍 Installing Python packages..."
pip3 install --upgrade pip
pip3 install \
    flask \
    flask-cors \
    requests \
    speedtest-cli \
    gunicorn

# Create directories
echo "📁 Creating directories..."
mkdir -p /opt/eero/{app,logs,backups}
mkdir -p /var/log/eero

# Clone repository
echo "📦 Cloning repository from GitHub..."
if [ -d "/opt/eero/repo" ]; then
    rm -rf /opt/eero/repo
fi

git clone ${GITHUB_REPO} /opt/eero/repo
cd /opt/eero/repo

# Copy application files
echo "📋 Installing application files..."
cp deploy/app.py /opt/eero/app/
cp deploy/config.json /opt/eero/app/ 2>/dev/null || echo "No config file found, will create default"

# Create default config if it doesn't exist
if [ ! -f "/opt/eero/app/config.json" ]; then
    echo "📝 Creating default configuration..."
    cat > /opt/eero/app/config.json << 'EOF'
{
  "network_id": "20478317",
  "environment": "production",
  "api_url": "api-user.e2ro.com",
  "last_updated": "2024-01-01T00:00:00"
}
EOF
fi

# Set permissions
echo "🔐 Setting permissions..."
chown -R www-data:www-data /opt/eero
chmod +x /opt/eero/app/app.py
chmod 600 /opt/eero/app/config.json

# Create systemd service
echo "⚙️ Creating systemd service..."
cat > /etc/systemd/system/eero.service << 'EOF'
[Unit]
Description=MiniRack Dashboard - Eero Network Monitor
Documentation=https://github.com/eero-drew/minirackdash
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/eero/app
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
Environment="PYTHONPATH=/opt/eero/app"
ExecStart=/usr/bin/python3 /opt/eero/app/app.py
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=eero-dashboard

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/eero

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx
echo "🌐 Configuring Nginx..."
cat > /etc/nginx/sites-available/eero-dashboard << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    # Logging
    access_log /var/log/nginx/eero_access.log;
    error_log /var/log/nginx/eero_error.log;
    
    # Main application
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        access_log off;
    }
    
    # Static files (if any)
    location /static/ {
        alias /opt/eero/app/static/;
        expires 1d;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable site and remove default
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/eero-dashboard /etc/nginx/sites-enabled/

# Test nginx configuration
echo "🧪 Testing Nginx configuration..."
nginx -t

# Configure firewall
echo "🛡️ Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Create update script
echo "📝 Creating update script..."
cat > /opt/eero/update.sh << EOF
#!/bin/bash
# Update MiniRack Dashboard from GitHub

echo "🔄 Updating MiniRack Dashboard..."

# Backup current config
cp /opt/eero/app/config.json /opt/eero/backups/config.json.backup.\$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
cp /opt/eero/app/.eero_token /opt/eero/backups/.eero_token.backup.\$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

# Update repository
cd /opt/eero/repo
git fetch origin
git reset --hard origin/main
git pull origin main

# Copy new files
cp deploy/app.py /opt/eero/app/
# Don't overwrite existing config
if [ ! -f "/opt/eero/app/config.json" ]; then
    cp deploy/config.json /opt/eero/app/
fi

# Set permissions
chown -R www-data:www-data /opt/eero
chmod +x /opt/eero/app/app.py

# Restart service
systemctl restart eero

echo "✅ Update complete!"
echo "🌐 Dashboard: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
EOF

chmod +x /opt/eero/update.sh

# Create maintenance script
echo "📝 Creating maintenance script..."
cat > /opt/eero/maintenance.sh << 'EOF'
#!/bin/bash
# Maintenance script for MiniRack Dashboard

case "$1" in
    status)
        echo "📊 Service Status:"
        systemctl status eero --no-pager
        echo ""
        echo "🌐 Nginx Status:"
        systemctl status nginx --no-pager
        echo ""
        echo "🔌 Port Status:"
        netstat -tlnp | grep -E ":(80|5000)"
        ;;
    logs)
        echo "📋 Recent logs:"
        journalctl -u eero -n 50 --no-pager
        ;;
    restart)
        echo "🔄 Restarting services..."
        systemctl restart eero
        systemctl restart nginx
        echo "✅ Services restarted"
        ;;
    backup)
        echo "💾 Creating backup..."
        tar -czf /opt/eero/backups/backup_$(date +%Y%m%d_%H%M%S).tar.gz \
            /opt/eero/app/config.json \
            /opt/eero/app/.eero_token 2>/dev/null
        echo "✅ Backup created"
        ;;
    *)
        echo "Usage: $0 {status|logs|restart|backup}"
        exit 1
        ;;
esac
EOF

chmod +x /opt/eero/maintenance.sh

# Reload systemd and start services
echo "🔄 Starting services..."
systemctl daemon-reload
systemctl enable eero
systemctl start eero
systemctl enable nginx
systemctl restart nginx

# Wait for services to start
echo "⏳ Waiting for services to start..."
sleep 5

# Check service status
echo ""
echo "📊 Final Status Check:"
if systemctl is-active --quiet eero; then
    echo "✅ Eero service: Running"
else
    echo "❌ Eero service: Failed"
    journalctl -u eero -n 5 --no-pager
fi

if systemctl is-active --quiet nginx; then
    echo "✅ Nginx service: Running"
else
    echo "❌ Nginx service: Failed"
fi

# Test local connection
echo ""
echo "🧪 Testing connection..."
if curl -s http://localhost/health > /dev/null; then
    echo "✅ Local connection: Working"
else
    echo "❌ Local connection: Failed"
fi

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "Unknown")

echo ""
echo "🎉 Installation Complete!"
echo "=========================================="
echo "🌐 Dashboard URL: http://${PUBLIC_IP}"
echo "📝 Update command: /opt/eero/update.sh"
echo "🔧 Maintenance: /opt/eero/maintenance.sh status"
echo ""
echo "📋 Next Steps:"
echo "1. Visit http://${PUBLIC_IP}"
echo "2. Use the admin panel to configure API authentication"
echo "3. Set your network ID if different from 20478317"
echo ""
echo "🆘 Troubleshooting:"
echo "- Check logs: journalctl -u eero -f"
echo "- Service status: /opt/eero/maintenance.sh status"
echo "- Restart: /opt/eero/maintenance.sh restart"
echo "=========================================="