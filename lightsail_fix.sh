#!/bin/bash
# Quick fix script for common Lightsail issues

echo "🔧 MiniRack Dashboard - Quick Fix"
echo "================================="

# Check if we're root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root: sudo ./lightsail_fix.sh"
    exit 1
fi

echo "🔄 Attempting to fix common issues..."

# 1. Ensure all services are stopped
echo "Stopping services..."
systemctl stop eero-dashboard 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true

# 2. Check if installation completed
if [ ! -d "/opt/eero/app" ]; then
    echo "🚀 Installation incomplete - running installer..."
    
    # Re-run installation
    cd /tmp
    rm -rf minirackdash
    git clone https://github.com/Drew-CodeRGV/minirackdash.git
    cd minirackdash
    chmod +x deploy/lightsail_installer.sh
    ./deploy/lightsail_installer.sh
    
    echo "✅ Installation completed"
fi

# 3. Fix permissions
echo "🔐 Fixing permissions..."
chown -R www-data:www-data /opt/eero
chmod +x /opt/eero/app/dashboard.py

# 4. Reload systemd and restart services
echo "🔄 Restarting services..."
systemctl daemon-reload
systemctl enable eero-dashboard
systemctl start eero-dashboard
systemctl enable nginx
systemctl restart nginx

# 5. Check firewall
echo "🔥 Configuring firewall..."
ufw allow 80/tcp
ufw allow 22/tcp
ufw --force enable

# 6. Wait and test
echo "⏳ Waiting 10 seconds for services to start..."
sleep 10

# 7. Show status
echo ""
echo "📊 Service Status:"
echo "-----------------"
systemctl status eero-dashboard --no-pager -l
echo ""
systemctl status nginx --no-pager -l

echo ""
echo "🌐 Network Status:"
echo "-----------------"
netstat -tlnp | grep -E ":(80|5000)"

echo ""
echo "🎯 Test Dashboard:"
echo "-----------------"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Dashboard should be available at: http://$PUBLIC_IP"

# Test local connection
echo "Testing local connection..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost/ || echo "❌ Local test failed"

echo ""
echo "🔧 Fix complete! Try accessing your dashboard now."