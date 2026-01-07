#!/bin/bash
# Diagnose Dashboard Installation Issues

echo "🔍 MiniRack Dashboard - Installation Diagnostics"
echo "=============================================="

# Check if directories exist
echo "📁 Directory Structure:"
if [ -d "/opt/eero" ]; then
    echo "   ✅ /opt/eero exists"
    ls -la /opt/eero/ 2>/dev/null || echo "   ❌ Cannot list /opt/eero contents"
    
    if [ -d "/opt/eero/app" ]; then
        echo "   ✅ /opt/eero/app exists"
        ls -la /opt/eero/app/ 2>/dev/null || echo "   ❌ Cannot list /opt/eero/app contents"
    else
        echo "   ❌ /opt/eero/app missing"
    fi
    
    if [ -d "/opt/eero/venv" ]; then
        echo "   ✅ /opt/eero/venv exists"
    else
        echo "   ❌ /opt/eero/venv missing"
    fi
else
    echo "   ❌ /opt/eero does not exist"
fi

echo ""
echo "📋 Required Files:"
files=("dashboard.py" "index.html" "config.json" "requirements.txt")
for file in "${files[@]}"; do
    if [ -f "/opt/eero/app/$file" ]; then
        size=$(wc -c < "/opt/eero/app/$file")
        echo "   ✅ $file exists ($size bytes)"
    else
        echo "   ❌ $file missing"
    fi
done

echo ""
echo "⚙️ Systemd Service:"
if [ -f "/etc/systemd/system/eero-dashboard.service" ]; then
    echo "   ✅ Service file exists"
    echo "   Status: $(sudo systemctl is-active eero-dashboard 2>/dev/null || echo 'inactive/failed')"
    echo "   Enabled: $(sudo systemctl is-enabled eero-dashboard 2>/dev/null || echo 'disabled')"
else
    echo "   ❌ Service file missing"
fi

echo ""
echo "🐍 Python Environment:"
if [ -f "/opt/eero/venv/bin/python" ]; then
    echo "   ✅ Virtual environment exists"
    if sudo -u www-data /opt/eero/venv/bin/python --version 2>/dev/null; then
        echo "   ✅ Python accessible"
    else
        echo "   ❌ Python not accessible"
    fi
else
    echo "   ❌ Virtual environment missing"
fi

echo ""
echo "🌐 Nginx Configuration:"
if [ -f "/etc/nginx/nginx.conf" ]; then
    echo "   ✅ Nginx config exists"
    if sudo nginx -t 2>/dev/null; then
        echo "   ✅ Nginx config valid"
    else
        echo "   ❌ Nginx config invalid"
    fi
else
    echo "   ❌ Nginx config missing"
fi

echo ""
echo "🔌 Network Tests:"
if curl -f http://localhost:5000/health >/dev/null 2>&1; then
    echo "   ✅ Dashboard responding on port 5000"
else
    echo "   ❌ Dashboard not responding on port 5000"
fi

if curl -f http://localhost/ >/dev/null 2>&1; then
    echo "   ✅ Nginx responding on port 80"
    RESPONSE=$(curl -s http://localhost/)
    if echo "$RESPONSE" | grep -q "Dashboard"; then
        echo "   ✅ Nginx serving dashboard content"
    elif echo "$RESPONSE" | grep -q "Welcome to nginx"; then
        echo "   ❌ Nginx serving default page"
    else
        echo "   ⚠️ Nginx serving unknown content"
    fi
else
    echo "   ❌ Nginx not responding on port 80"
fi

echo ""
echo "📊 Service Status:"
echo "   Dashboard: $(sudo systemctl is-active eero-dashboard 2>/dev/null || echo 'not found')"
echo "   Nginx: $(sudo systemctl is-active nginx 2>/dev/null || echo 'not found')"

echo ""
echo "🔧 RECOMMENDATION:"
if [ ! -f "/etc/systemd/system/eero-dashboard.service" ]; then
    echo "   Service file missing - run complete installation"
elif [ ! -d "/opt/eero/app" ]; then
    echo "   Application files missing - run complete installation"
elif [ ! -d "/opt/eero/venv" ]; then
    echo "   Python environment missing - run complete installation"
else
    echo "   Files exist but service issues - try service restart or complete reinstall"
fi

echo ""
echo "💡 To fix all issues, run:"
echo "   curl -s https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/complete_dashboard_install.sh | sudo bash"