#!/bin/bash
# Debug script for Lightsail 502 error
# Run this on your Lightsail instance to diagnose the issue

echo "🔍 Debugging MiniRack Dashboard - 502 Bad Gateway"
echo "=================================================="

# Check if services are running
echo "📊 Service Status:"
echo "Eero service:"
systemctl is-active eero || echo "❌ Eero service not running"
systemctl is-enabled eero || echo "❌ Eero service not enabled"

echo "Nginx service:"
systemctl is-active nginx || echo "❌ Nginx not running"

# Check what's listening on ports
echo ""
echo "🔌 Port Status:"
echo "Port 5000 (Python app):"
netstat -tlnp | grep :5000 || echo "❌ Nothing listening on port 5000"

echo "Port 80 (Nginx):"
netstat -tlnp | grep :80 || echo "❌ Nothing listening on port 80"

# Check service logs
echo ""
echo "📋 Recent Logs:"
echo "Eero service logs (last 10 lines):"
journalctl -u eero -n 10 --no-pager

echo ""
echo "Nginx error logs (last 5 lines):"
tail -n 5 /var/log/nginx/error.log 2>/dev/null || echo "No nginx error log found"

# Check if Python app file exists and is executable
echo ""
echo "📁 File Status:"
if [ -f "/opt/eero/app.py" ]; then
    echo "✅ /opt/eero/app.py exists"
    ls -la /opt/eero/app.py
    echo "Testing Python syntax:"
    python3 -m py_compile /opt/eero/app.py && echo "✅ Python syntax OK" || echo "❌ Python syntax error"
else
    echo "❌ /opt/eero/app.py not found"
fi

# Check Python dependencies
echo ""
echo "🐍 Python Dependencies:"
python3 -c "import flask; print('✅ Flask installed')" 2>/dev/null || echo "❌ Flask not installed"
python3 -c "import requests; print('✅ Requests installed')" 2>/dev/null || echo "❌ Requests not installed"

# Try to start the app manually
echo ""
echo "🧪 Manual Test:"
echo "Trying to start Python app manually (will timeout after 5 seconds)..."
cd /opt/eero
timeout 5 python3 app.py 2>&1 | head -10 || echo "App startup test completed"

echo ""
echo "🔧 Quick Fix Commands:"
echo "1. Restart services:"
echo "   sudo systemctl restart eero"
echo "   sudo systemctl restart nginx"
echo ""
echo "2. Check detailed logs:"
echo "   sudo journalctl -u eero -f"
echo ""
echo "3. Test app manually:"
echo "   cd /opt/eero && python3 app.py"