#!/bin/bash
# Add Email Authentication Enhancement

set -e

echo "📧 Adding email authentication enhancement to MiniRack Dashboard..."

# Stop dashboard
sudo systemctl stop eero-dashboard

# Download updated files
echo "📥 Downloading v6.7.2 with email authentication enhancement..."
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
echo "🚀 Starting dashboard with email authentication enhancement..."
sudo systemctl start eero-dashboard
sleep 3

# Test
if curl -s http://localhost:5000/ | grep -q "6.7.2"; then
    echo "✅ Version 6.7.2 is live with email authentication enhancement"
    
    # Restart nginx
    sudo systemctl restart nginx
    
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    echo ""
    echo "🎉 Email authentication enhancement added successfully!"
    echo "🌐 Dashboard: http://$PUBLIC_IP"
    echo ""
    echo "🆕 NEW FEATURE:"
    echo "   📧 Custom email input during network authentication"
    echo "   🔄 No longer limited to stored email addresses"
    echo "   ✨ Flexible authentication for different networks"
    echo ""
    echo "📋 HOW TO USE:"
    echo "   1. Click π button → Manage Networks"
    echo "   2. Click 'Authenticate with Email' for any network"
    echo "   3. Enter the email address you want to use"
    echo "   4. Receive and enter the verification code"
    echo ""
    echo "💡 BENEFITS:"
    echo "   • Use different emails for different networks"
    echo "   • Update authentication without changing network config"
    echo "   • More flexible multi-network management"
    echo "   • Better support for shared network access"
else
    echo "❌ Update may have failed"
    sudo systemctl status eero-dashboard
fi