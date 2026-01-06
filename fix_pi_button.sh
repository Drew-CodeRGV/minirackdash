#!/bin/bash
# Direct Fix for π Button and JavaScript Issues

set -e

echo "🔧 Fixing π button and JavaScript functionality..."

# Stop dashboard service
echo "⏹️ Stopping dashboard service..."
sudo systemctl stop eero-dashboard

# Download the exact HTML file and verify it's complete
echo "📥 Downloading fresh HTML file..."
sudo curl -o /tmp/index_new.html https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html

# Verify the HTML file has the required functions
echo "✅ Verifying HTML file integrity..."
if ! grep -q "function showAdmin()" /tmp/index_new.html; then
    echo "❌ HTML file missing showAdmin function"
    exit 1
fi

if ! grep -q "onclick=\"showAdmin()\"" /tmp/index_new.html; then
    echo "❌ HTML file missing π button onclick handler"
    exit 1
fi

if ! grep -q "function openModal" /tmp/index_new.html; then
    echo "❌ HTML file missing modal functions"
    exit 1
fi

HTML_SIZE=$(wc -c < /tmp/index_new.html)
if [ "$HTML_SIZE" -lt 25000 ]; then
    echo "❌ HTML file too small ($HTML_SIZE bytes) - likely incomplete"
    exit 1
fi

echo "✅ HTML file verified - Size: $HTML_SIZE bytes with all required functions"

# Replace the HTML file
sudo cp /tmp/index_new.html /opt/eero/app/index.html
sudo chown www-data:www-data /opt/eero/app/index.html
sudo chmod 644 /opt/eero/app/index.html

# Also update the Python file to ensure proper serving
echo "📥 Updating Python dashboard file..."
sudo curl -o /opt/eero/app/dashboard.py https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
sudo chown www-data:www-data /opt/eero/app/dashboard.py
sudo chmod +x /opt/eero/app/dashboard.py

# Test Python syntax
echo "🔍 Testing Python syntax..."
sudo -u www-data /opt/eero/venv/bin/python -c "import sys; sys.path.insert(0, '/opt/eero/app'); import dashboard; print('✅ Python file syntax OK')"

# Clear any browser cache by adding a cache-busting parameter
echo "🧹 Adding cache-busting to prevent browser cache issues..."
TIMESTAMP=$(date +%s)
sudo sed -i "s/Network Dashboard v6\.5\.0 (Complete)/Network Dashboard v6.5.0 (Complete) - $TIMESTAMP/g" /opt/eero/app/index.html

# Start dashboard service
echo "🚀 Starting dashboard service..."
sudo systemctl start eero-dashboard

# Wait for service to be ready
echo "⏳ Waiting for dashboard to start..."
sleep 5

# Check service status
if ! sudo systemctl is-active --quiet eero-dashboard; then
    echo "❌ Dashboard service failed to start"
    sudo systemctl status eero-dashboard
    sudo journalctl -u eero-dashboard --no-pager -n 10
    exit 1
fi

# Test the dashboard response
echo "🔍 Testing dashboard response..."
RESPONSE=$(curl -s http://localhost:5000/)
if echo "$RESPONSE" | grep -q "function showAdmin" && echo "$RESPONSE" | grep -q "onclick=\"showAdmin()\""; then
    echo "✅ Dashboard serving complete HTML with π button functionality"
    echo "✅ Response size: $(echo "$RESPONSE" | wc -c) characters"
else
    echo "❌ Dashboard not serving complete HTML"
    echo "Response size: $(echo "$RESPONSE" | wc -c) characters"
    echo "First 500 chars:"
    echo "$RESPONSE" | head -c 500
    exit 1
fi

# Restart nginx to ensure clean proxy
echo "🔄 Restarting nginx..."
sudo systemctl restart nginx
sleep 2

# Final test through nginx
echo "🔍 Final test through nginx..."
FINAL_RESPONSE=$(curl -s http://localhost/)
if echo "$FINAL_RESPONSE" | grep -q "function showAdmin" && echo "$FINAL_RESPONSE" | grep -q "π"; then
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    echo ""
    echo "✅ π Button fix completed successfully!"
    echo "🌐 Dashboard: http://$PUBLIC_IP"
    echo "🔘 The π button in the bottom-right corner should now work"
    echo "📱 Try clicking it to open the admin panel"
    echo "🔄 If browser cache is an issue, try Ctrl+F5 or Cmd+Shift+R to force refresh"
    echo ""
else
    echo "❌ Final test failed - π button may still not work"
    echo "Response size: $(echo "$FINAL_RESPONSE" | wc -c) characters"
    exit 1
fi

# Clean up
rm -f /tmp/index_new.html

echo "🎉 Fix complete! The π admin menu should now be fully functional."