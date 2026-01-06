#!/bin/bash
# Force Update with Full Debugging - No More Games

set -e

echo "🔥 FORCE UPDATE - Debugging Everything"
echo "======================================"

# Stop everything
echo "⏹️ Stopping all services..."
sudo systemctl stop eero-dashboard || true
sudo systemctl stop nginx || true

# Show current file info
echo "📋 Current file info BEFORE update:"
if [ -f "/opt/eero/app/dashboard.py" ]; then
    echo "Dashboard.py size: $(wc -c < /opt/eero/app/dashboard.py) bytes"
    grep "VERSION = " /opt/eero/app/dashboard.py || echo "No VERSION found"
fi

if [ -f "/opt/eero/app/index.html" ]; then
    echo "Index.html size: $(wc -c < /opt/eero/app/index.html) bytes"
    grep "Network Dashboard v" /opt/eero/app/index.html | head -1 || echo "No version found"
fi

# Force download with verbose output
echo "📥 Force downloading files with debugging..."
TIMESTAMP=$(date +%s)
echo "Using cache-busting timestamp: $TIMESTAMP"

echo "Downloading dashboard.py..."
sudo curl -v -H "Cache-Control: no-cache" -o /opt/eero/app/dashboard.py "https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py?t=$TIMESTAMP"
echo "Dashboard.py download exit code: $?"

echo "Downloading index.html..."
sudo curl -v -H "Cache-Control: no-cache" -o /opt/eero/app/index.html "https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html?t=$TIMESTAMP"
echo "Index.html download exit code: $?"

# Show file info AFTER download
echo "📋 File info AFTER download:"
echo "Dashboard.py size: $(wc -c < /opt/eero/app/dashboard.py) bytes"
grep "VERSION = " /opt/eero/app/dashboard.py || echo "❌ No VERSION found in dashboard.py"

echo "Index.html size: $(wc -c < /opt/eero/app/index.html) bytes"
grep "Network Dashboard v" /opt/eero/app/index.html | head -1 || echo "❌ No version found in index.html"

# Check for the JavaScript fix
echo "🔍 Checking JavaScript regex fix..."
if grep -q 'match(/^\\d+$/)' /opt/eero/app/index.html; then
    echo "❌ BROKEN: Still has double backslash regex"
    echo "Fixing manually..."
    sudo sed -i 's/match(\/\^\\\\d\+\$\/)/match(\/\^\\d\+\$\/)/g' /opt/eero/app/index.html
else
    echo "✅ JavaScript regex appears correct"
fi

# Check for showAdmin function
echo "🔍 Checking showAdmin function..."
if grep -q "function showAdmin()" /opt/eero/app/index.html; then
    echo "✅ showAdmin function found"
else
    echo "❌ showAdmin function missing"
fi

# Check for π button
echo "🔍 Checking π button..."
if grep -q 'onclick="showAdmin()"' /opt/eero/app/index.html; then
    echo "✅ π button onclick handler found"
else
    echo "❌ π button onclick handler missing"
fi

# Set permissions
echo "🔐 Setting permissions..."
sudo chown -R www-data:www-data /opt/eero
sudo chmod +x /opt/eero/app/dashboard.py
sudo chmod 644 /opt/eero/app/index.html

# Test Python syntax
echo "🐍 Testing Python syntax..."
cd /opt/eero
if sudo -u www-data /opt/eero/venv/bin/python -m py_compile app/dashboard.py; then
    echo "✅ Python syntax OK"
else
    echo "❌ Python syntax error"
    exit 1
fi

# Add timestamp to force browser cache refresh
TIMESTAMP=$(date +%s)
echo "🕒 Adding timestamp $TIMESTAMP to force cache refresh..."
sudo sed -i "s/Network Dashboard v6\.5\.1 (Fixed JS)/Network Dashboard v6.5.1 (Fixed JS) - $TIMESTAMP/g" /opt/eero/app/index.html

# Start dashboard
echo "🚀 Starting dashboard..."
sudo systemctl start eero-dashboard

# Wait and check
sleep 5
if ! sudo systemctl is-active --quiet eero-dashboard; then
    echo "❌ Dashboard failed to start"
    sudo systemctl status eero-dashboard
    sudo journalctl -u eero-dashboard --no-pager -n 20
    exit 1
fi

# Test dashboard directly
echo "🔍 Testing dashboard on port 5000..."
RESPONSE=$(curl -s http://localhost:5000/)
echo "Response size: $(echo "$RESPONSE" | wc -c) characters"

if echo "$RESPONSE" | grep -q "6.5.1"; then
    echo "✅ Version 6.5.1 detected in response"
else
    echo "❌ Version 6.5.1 NOT found in response"
    echo "Version info found:"
    echo "$RESPONSE" | grep -i "version\|dashboard" | head -5
fi

if echo "$RESPONSE" | grep -q "function showAdmin"; then
    echo "✅ showAdmin function found in response"
else
    echo "❌ showAdmin function NOT found in response"
fi

# Start nginx
echo "🌐 Starting nginx..."
sudo systemctl start nginx
sleep 2

# Final test
echo "🔍 Final test through nginx..."
FINAL_RESPONSE=$(curl -s http://localhost/)
echo "Final response size: $(echo "$FINAL_RESPONSE" | wc -c) characters"

if echo "$FINAL_RESPONSE" | grep -q "6.5.1"; then
    echo "✅ Version 6.5.1 visible through nginx"
else
    echo "❌ Version 6.5.1 NOT visible through nginx"
    echo "Version found:"
    echo "$FINAL_RESPONSE" | grep -i "version\|dashboard" | head -3
fi

# Check for JavaScript errors
echo "🔍 Checking for JavaScript syntax issues..."
if echo "$FINAL_RESPONSE" | grep -q 'match(/^\\d+$/)'; then
    echo "❌ STILL HAS BROKEN REGEX - Manual fix needed"
    # Force fix the regex issue
    sudo sed -i 's/match(\/\^\\\\d\+\$\/)/match(\/\^\d\+\$\/)/g' /opt/eero/app/index.html
    sudo systemctl restart eero-dashboard
    sleep 3
    sudo systemctl restart nginx
    echo "🔄 Applied manual regex fix and restarted services"
else
    echo "✅ JavaScript regex looks correct"
fi

# Show final status
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
echo ""
echo "🎯 FINAL STATUS:"
echo "=================="
echo "🌐 Dashboard: http://$PUBLIC_IP"
echo "📋 Expected version: 6.5.1-fixed-js"
echo "🔘 π button location: bottom-right corner"
echo ""
echo "🔍 Debug info:"
echo "- Dashboard service: $(sudo systemctl is-active eero-dashboard)"
echo "- Nginx service: $(sudo systemctl is-active nginx)"
echo "- Dashboard file size: $(wc -c < /opt/eero/app/dashboard.py) bytes"
echo "- HTML file size: $(wc -c < /opt/eero/app/index.html) bytes"
echo ""
echo "If π button still doesn't work:"
echo "1. Try hard refresh: Ctrl+F5 or Cmd+Shift+R"
echo "2. Open browser console (F12) and check for JavaScript errors"
echo "3. Verify the version shows 6.5.1 in the header"