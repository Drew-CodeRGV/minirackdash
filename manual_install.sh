#!/bin/bash
# Manual installation script for Lightsail
# Run this directly on your instance if boot script failed

set -e

echo "🚀 MiniRack Dashboard - Manual Installation"
echo "=========================================="

# Check if we're root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root: sudo ./manual_install.sh"
    exit 1
fi

echo "📦 Installing system packages..."
apt-get update -y
apt-get install -y python3-pip nginx git curl

echo "🐍 Installing Python packages..."
# Use system packages first, then pip with --break-system-packages for missing ones
apt-get install -y python3-flask python3-requests python3-pip

# Install remaining packages with override flag
pip3 install --break-system-packages flask-cors speedtest-cli gunicorn

echo "📁 Creating directories..."
mkdir -p /opt/eero/{app,logs,backups}

echo "📥 Downloading application files..."
cd /tmp
rm -rf minirackdash
git clone https://github.com/Drew-CodeRGV/minirackdash.git
cd minirackdash

echo "📋 Copying application files..."
cp deploy/dashboard.py /opt/eero/app/
cp deploy/config.json /opt/eero/app/
cp deploy/requirements.txt /opt/eero/app/

echo "🔐 Setting permissions..."
chown -R www-data:www-data /opt/eero
chmod +x /opt/eero/app/dashboard.py

echo "⚙️ Creating systemd service..."
cat > /etc/systemd/system/eero-dashboard.service << 'EOF'
[Unit]
Description=MiniRack Dashboard
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/eero/app
ExecStart=/usr/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 dashboard:app
Restart=always
RestartSec=10
Environment=PYTHONPATH=/opt/eero/app

[Install]
WantedBy=multi-user.target
EOF

echo "🌐 Configuring Nginx..."
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

echo "🔗 Enabling Nginx site..."
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/eero-dashboard /etc/nginx/sites-enabled/

echo "✅ Testing Nginx configuration..."
nginx -t

echo "🔄 Creating update script..."
cat > /opt/eero/update.sh << 'EOF'
#!/bin/bash
echo "🔄 Updating MiniRack Dashboard from GitHub..."
cd /tmp
rm -rf minirackdash
git clone https://github.com/Drew-CodeRGV/minirackdash.git
cd minirackdash
cp deploy/dashboard.py /opt/eero/app/
cp deploy/config.json /opt/eero/app/
chown -R www-data:www-data /opt/eero
systemctl restart eero-dashboard
echo "✅ Update complete!"
EOF
chmod +x /opt/eero/update.sh

echo "🔥 Configuring firewall..."
ufw allow 80/tcp
ufw allow 22/tcp
ufw --force enable

echo "🚀 Starting services..."
systemctl daemon-reload
systemctl enable eero-dashboard
systemctl start eero-dashboard
systemctl enable nginx
systemctl restart nginx

echo "⏳ Waiting for services to start..."
sleep 5

echo ""
echo "📊 Service Status:"
echo "-----------------"
systemctl status eero-dashboard --no-pager -l
echo ""
systemctl status nginx --no-pager -l

echo ""
echo "🌐 Network Status:"
echo "-----------------"
netstat -tlnp | grep -E ":(80|5000)" || echo "No services listening on ports 80 or 5000"

echo ""
echo "🎯 Testing Dashboard:"
echo "--------------------"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "unknown")
echo "Public IP: $PUBLIC_IP"

# Test local connection
echo "Testing local HTTP connection..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Local test successful (HTTP $HTTP_STATUS)"
    echo "🌐 Dashboard should be available at: http://$PUBLIC_IP"
else
    echo "❌ Local test failed (HTTP $HTTP_STATUS)"
    echo "🔍 Checking logs..."
    journalctl -u eero-dashboard --no-pager -n 5
fi

echo ""
echo "=========================================="
echo "🎉 Installation complete!"
echo "🌐 Access your dashboard at: http://$PUBLIC_IP"
echo "🔄 To update later: sudo /opt/eero/update.sh"
echo "=========================================="