#!/bin/bash
# Debug script for Lightsail instance
# Run this on your Lightsail instance to check status

echo "🔍 MiniRack Dashboard - Debug Information"
echo "========================================"

echo "📅 Current time: $(date)"
echo "🌐 Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'Unable to get IP')"

echo ""
echo "📦 Installation Status:"
echo "----------------------"

# Check if repository was cloned
if [ -d "/tmp/minirackdash" ]; then
    echo "✅ Repository cloned successfully"
else
    echo "❌ Repository not found in /tmp"
fi

# Check if app directory exists
if [ -d "/opt/eero" ]; then
    echo "✅ App directory created"
    ls -la /opt/eero/
else
    echo "❌ App directory not found"
fi

echo ""
echo "🔧 Service Status:"
echo "-----------------"

# Check systemd services
echo "Eero Dashboard Service:"
systemctl status eero-dashboard --no-pager -l || echo "❌ Service not found"

echo ""
echo "Nginx Service:"
systemctl status nginx --no-pager -l || echo "❌ Nginx not found"

echo ""
echo "🌐 Network Status:"
echo "-----------------"

# Check if ports are listening
echo "Port 80 (HTTP):"
netstat -tlnp | grep :80 || echo "❌ Nothing listening on port 80"

echo ""
echo "Port 5000 (Flask):"
netstat -tlnp | grep :5000 || echo "❌ Nothing listening on port 5000"

echo ""
echo "📋 Process List:"
echo "---------------"
ps aux | grep -E "(python|gunicorn|nginx)" | grep -v grep

echo ""
echo "📝 Recent Logs:"
echo "--------------"

echo "Boot log (last 20 lines):"
tail -20 /var/log/cloud-init-output.log 2>/dev/null || echo "❌ Boot log not found"

echo ""
echo "Dashboard logs:"
if [ -f "/opt/eero/logs/dashboard.log" ]; then
    tail -10 /opt/eero/logs/dashboard.log
else
    echo "❌ Dashboard log not found"
fi

echo ""
echo "System journal (eero-dashboard):"
journalctl -u eero-dashboard --no-pager -n 10 2>/dev/null || echo "❌ No journal entries"

echo ""
echo "🔥 Firewall Status:"
echo "------------------"
ufw status || echo "❌ UFW not configured"

echo ""
echo "💾 Disk Usage:"
echo "-------------"
df -h

echo ""
echo "🧠 Memory Usage:"
echo "---------------"
free -h

echo "========================================"
echo "🔍 Debug complete!"