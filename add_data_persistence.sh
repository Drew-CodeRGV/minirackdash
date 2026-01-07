#!/bin/bash
# Add Data Persistence and Chart Reliability Fixes

set -e

echo "💾 Adding data persistence and chart reliability fixes..."

# Stop dashboard
sudo systemctl stop eero-dashboard

# Backup current data if it exists
if [ -f "/opt/eero/app/data_cache.json" ]; then
    echo "📋 Backing up existing data..."
    sudo cp /opt/eero/app/data_cache.json /opt/eero/app/data_cache_backup_$(date +%s).json
fi

# Download updated files
echo "📥 Downloading v6.7.1 with persistence and reliability fixes..."
sudo curl -o /opt/eero/app/dashboard.py https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
sudo curl -o /opt/eero/app/index.html https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html

# Set permissions
sudo chown www-data:www-data /opt/eero/app/dashboard.py /opt/eero/app/index.html
sudo chmod +x /opt/eero/app/dashboard.py
sudo chmod 644 /opt/eero/app/index.html

# Ensure data directory permissions
sudo chown -R www-data:www-data /opt/eero/app/
sudo chmod 755 /opt/eero/app/

# Test Python syntax
echo "🔍 Testing Python syntax..."
sudo -u www-data /opt/eero/venv/bin/python -c "import sys; sys.path.insert(0, '/opt/eero/app'); import dashboard; print('✅ Python syntax OK')"

# Start dashboard
echo "🚀 Starting dashboard with persistence features..."
sudo systemctl start eero-dashboard
sleep 5

# Test
if curl -s http://localhost:5000/ | grep -q "6.7.1"; then
    echo "✅ Version 6.7.1 is live with persistence features"
    
    # Restart nginx
    sudo systemctl restart nginx
    
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    echo ""
    echo "🎉 Data persistence and reliability fixes applied!"
    echo "🌐 Dashboard: http://$PUBLIC_IP"
    echo ""
    echo "🆕 IMPROVEMENTS:"
    echo "   • Data persistence - historical data survives restarts"
    echo "   • Chart reliability - better error handling and retry logic"
    echo "   • Automatic data backup before updates"
    echo "   • Improved chart initialization with fallback mechanisms"
    echo "   • Better error recovery and retry attempts"
    echo "   • Performance optimizations for chart updates"
    echo ""
    echo "💾 Data is now automatically saved to disk and restored on restart"
    echo "🔄 Charts will retry loading if they fail initially"
    echo "📊 Historical data is preserved across service restarts"
else
    echo "❌ Update may have failed"
    sudo systemctl status eero-dashboard
fi