#!/bin/bash
# Add Multi-Network Support to Dashboard

set -e

echo "🌐 Adding multi-network support to MiniRack Dashboard..."

# Stop dashboard
sudo systemctl stop eero-dashboard

# Download updated files
echo "📥 Downloading v6.7.0 with multi-network support..."
sudo curl -o /opt/eero/app/dashboard.py https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
sudo curl -o /opt/eero/app/index.html https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html

# Set permissions
sudo chown www-data:www-data /opt/eero/app/dashboard.py /opt/eero/app/index.html
sudo chmod +x /opt/eero/app/dashboard.py
sudo chmod 644 /opt/eero/app/index.html

# Test Python syntax
echo "🔍 Testing Python syntax..."
sudo -u www-data /opt/eero/venv/bin/python -c "import sys; sys.path.insert(0, '/opt/eero/app'); import dashboard; print('✅ Python syntax OK')"

# Start dashboard
echo "🚀 Starting dashboard with multi-network support..."
sudo systemctl start eero-dashboard
sleep 3

# Test
if curl -s http://localhost:5000/ | grep -q "6.7.0"; then
    echo "✅ Version 6.7.0 is live with multi-network support"
    
    # Restart nginx
    sudo systemctl restart nginx
    
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    echo ""
    echo "🎉 Multi-Network support added successfully!"
    echo "🌐 Dashboard: http://$PUBLIC_IP"
    echo ""
    echo "🆕 NEW FEATURES:"
    echo "   • Monitor up to 6 different Eero networks"
    echo "   • Individual API authentication per network"
    echo "   • Combined dashboard showing all network data"
    echo "   • Enable/disable networks individually"
    echo "   • Network-specific device identification"
    echo ""
    echo "📋 HOW TO USE:"
    echo "   1. Click π button → Manage Networks"
    echo "   2. Click 'Add New Network'"
    echo "   3. Enter Network ID and Email"
    echo "   4. Click 'Authenticate' for each network"
    echo "   5. Enter verification codes from emails"
    echo ""
    echo "💡 Your existing network will be automatically migrated"
    echo "💡 Dashboard shows combined data from all active networks"
    echo "💡 Device list shows which network each device belongs to"
else
    echo "❌ Update may have failed"
    sudo systemctl status eero-dashboard
fi