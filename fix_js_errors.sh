#!/bin/bash
# Direct Fix for JavaScript Syntax Errors

set -e

echo "🔧 Fixing JavaScript syntax errors..."

# Stop dashboard
sudo systemctl stop eero-dashboard

# Download the corrected file
echo "📥 Downloading corrected JavaScript..."
sudo curl -o /opt/eero/app/index.html https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html
sudo curl -o /opt/eero/app/dashboard.py https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py

# Set permissions
sudo chown www-data:www-data /opt/eero/app/index.html /opt/eero/app/dashboard.py
sudo chmod 644 /opt/eero/app/index.html
sudo chmod +x /opt/eero/app/dashboard.py

# Verify the fixes
echo "✅ Verifying JavaScript fixes..."
if grep -q "const lastSuccessful.*const lastSuccessful" /opt/eero/app/index.html; then
    echo "❌ Still has duplicate lastSuccessful - fixing manually..."
    sudo sed -i '/const lastSuccessful = data\.last_successful_update.*lastUpdate;/d' /opt/eero/app/index.html
fi

# Check version
VERSION=$(grep "Network Dashboard v" /opt/eero/app/index.html | head -1)
echo "📋 Version: $VERSION"

# Start dashboard
sudo systemctl start eero-dashboard
sleep 3

# Test
if curl -s http://localhost:5000/ | grep -q "6.5.2"; then
    echo "✅ Version 6.5.2 is live"
    echo "✅ JavaScript errors should be fixed"
    echo "🔘 Try the π button now - it should work!"
    
    # Restart nginx to clear any proxy cache
    sudo systemctl restart nginx
    
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    echo "🌐 Dashboard: http://$PUBLIC_IP"
    echo "💡 If still not working, hard refresh with Ctrl+F5"
else
    echo "❌ Update may have failed"
    sudo systemctl status eero-dashboard
fi