#!/bin/bash
# Fix Mobile CSS Display Issue - Emergency Patch

set -e

echo "🔧 Fixing mobile CSS display issue..."

# Stop dashboard
sudo systemctl stop eero-dashboard

# Download fixed files
echo "📥 Downloading v6.7.5-mobile with improved alignment and network stats..."
sudo curl -o /opt/eero/app/dashboard.py https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
sudo curl -o /opt/eero/app/index.html https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html

# Set permissions
sudo chown www-data:www-data /opt/eero/app/dashboard.py /opt/eero/app/index.html
sudo chmod +x /opt/eero/app/dashboard.py
sudo chmod 644 /opt/eero/app/index.html

# Start dashboard
echo "🚀 Starting dashboard with CSS fix..."
sudo systemctl start eero-dashboard
sleep 3

# Test
if curl -s http://localhost:5000/ | grep -q "6.7.5" 2>/dev/null; then
    echo "✅ Alignment and network stats update applied successfully - v6.7.5-mobile"
    
    # Restart nginx
    sudo systemctl restart nginx
    
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    echo ""
    echo "🎉 Chart alignment and network statistics improvements applied!"
    echo "🌐 Dashboard: http://$PUBLIC_IP"
    echo ""
    echo "✅ Improved chart alignment and spacing"
    echo "✅ Per-network device and frequency breakdowns"
    echo "📲 Test on mobile device to verify improvements"
else
    echo "❌ Fix may have failed"
    sudo systemctl status eero-dashboard --no-pager -l
fi