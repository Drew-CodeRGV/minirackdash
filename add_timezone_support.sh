#!/bin/bash
# Add Timezone Support to Dashboard

set -e

echo "🕒 Adding timezone support to MiniRack Dashboard..."

# Stop dashboard
sudo systemctl stop eero-dashboard

# Download updated files
echo "📥 Downloading v6.6.0 with timezone support..."
sudo curl -o /opt/eero/app/dashboard.py https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
sudo curl -o /opt/eero/app/index.html https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html
sudo curl -o /opt/eero/app/requirements.txt https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/requirements.txt

# Set permissions
sudo chown www-data:www-data /opt/eero/app/dashboard.py /opt/eero/app/index.html /opt/eero/app/requirements.txt
sudo chmod +x /opt/eero/app/dashboard.py
sudo chmod 644 /opt/eero/app/index.html /opt/eero/app/requirements.txt

# Install new Python dependency (pytz)
echo "🐍 Installing pytz for timezone support..."
cd /opt/eero
sudo -H -u www-data /opt/eero/venv/bin/pip install pytz==2023.3

# Test Python syntax
echo "🔍 Testing Python syntax..."
sudo -u www-data /opt/eero/venv/bin/python -c "import sys; sys.path.insert(0, '/opt/eero/app'); import dashboard; print('✅ Python syntax OK')"

# Start dashboard
echo "🚀 Starting dashboard with timezone support..."
sudo systemctl start eero-dashboard
sleep 3

# Test
if curl -s http://localhost:5000/ | grep -q "6.6.0"; then
    echo "✅ Version 6.6.0 is live with timezone support"
    
    # Restart nginx
    sudo systemctl restart nginx
    
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    echo ""
    echo "🎉 Timezone support added successfully!"
    echo "🌐 Dashboard: http://$PUBLIC_IP"
    echo "🕒 New features:"
    echo "   • Click π button → Change Timezone"
    echo "   • Admin panel shows current timezone and local time"
    echo "   • All timestamps now use configured timezone"
    echo "   • Supports major timezones (US, Europe, Asia, Australia)"
    echo ""
    echo "💡 Configure your timezone in the π admin menu"
else
    echo "❌ Update may have failed"
    sudo systemctl status eero-dashboard
fi