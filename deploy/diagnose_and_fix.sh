#!/bin/bash
# Diagnose and fix connection refused error
# Run this on your Lightsail instance

echo "🔍 Diagnosing connection refused error..."
echo "=========================================="

# Check if services are running
echo "📊 Service Status:"
echo "Eero service:"
if systemctl is-active --quiet eero; then
    echo "✅ Eero service is running"
else
    echo "❌ Eero service is NOT running"
    echo "Starting eero service..."
    systemctl start eero
    sleep 2
    if systemctl is-active --quiet eero; then
        echo "✅ Eero service started successfully"
    else
        echo "❌ Failed to start eero service"
        echo "Checking logs:"
        journalctl -u eero -n 10 --no-pager
    fi
fi

echo ""
echo "Nginx service:"
if systemctl is-active --quiet nginx; then
    echo "✅ Nginx is running"
else
    echo "❌ Nginx is NOT running"
    echo "Starting nginx..."
    systemctl start nginx
    sleep 2
    if systemctl is-active --quiet nginx; then
        echo "✅ Nginx started successfully"
    else
        echo "❌ Failed to start nginx"
        echo "Checking nginx config:"
        nginx -t
    fi
fi

# Check ports
echo ""
echo "🔌 Port Status:"
echo "Port 5000 (Python app):"
if netstat -tlnp | grep -q :5000; then
    echo "✅ Something is listening on port 5000"
    netstat -tlnp | grep :5000
else
    echo "❌ Nothing listening on port 5000"
    echo "Trying to start Python app manually..."
    cd /opt/eero/app
    timeout 5 python3 app.py &
    sleep 2
    if netstat -tlnp | grep -q :5000; then
        echo "✅ Python app started manually"
        pkill -f "python3 app.py"
    else
        echo "❌ Python app failed to start"
        echo "Checking Python app:"
        python3 -c "import flask; print('Flask OK')" || echo "Flask not installed"
        python3 -c "import requests; print('Requests OK')" || echo "Requests not installed"
        if [ -f "/opt/eero/app/app.py" ]; then
            echo "App file exists, checking syntax:"
            python3 -m py_compile /opt/eero/app/app.py && echo "Syntax OK" || echo "Syntax error"
        else
            echo "❌ App file missing: /opt/eero/app/app.py"
        fi
    fi
fi

echo ""
echo "Port 80 (Nginx):"
if netstat -tlnp | grep -q :80; then
    echo "✅ Something is listening on port 80"
    netstat -tlnp | grep :80
else
    echo "❌ Nothing listening on port 80"
fi

# Check firewall
echo ""
echo "🛡️ Firewall Status:"
ufw status || echo "UFW not configured"

# Check if files exist
echo ""
echo "📁 File Check:"
if [ -f "/opt/eero/app/app.py" ]; then
    echo "✅ App file exists: /opt/eero/app/app.py"
    ls -la /opt/eero/app/app.py
else
    echo "❌ App file missing: /opt/eero/app/app.py"
fi

if [ -f "/etc/systemd/system/eero.service" ]; then
    echo "✅ Service file exists"
else
    echo "❌ Service file missing"
fi

# Try to fix common issues
echo ""
echo "🔧 Attempting fixes..."

# Install missing packages
echo "Installing/updating packages..."
apt-get update -y > /dev/null 2>&1
apt-get install -y python3-pip nginx > /dev/null 2>&1
pip3 install flask flask-cors requests > /dev/null 2>&1

# Create minimal working app if missing
if [ ! -f "/opt/eero/app/app.py" ]; then
    echo "Creating minimal app..."
    mkdir -p /opt/eero/app
    cat > /opt/eero/app/app.py << 'EOF'
#!/usr/bin/env python3
from flask import Flask
app = Flask(__name__)

@app.route('/')
def home():
    return '''
    <html>
    <head><title>Eero Dashboard - Working</title></head>
    <body style="font-family:Arial;background:#1a1a1a;color:white;text-align:center;padding:50px;">
        <h1 style="color:#4da6ff;">🎉 Dashboard is Working!</h1>
        <p>Your Lightsail instance is now responding correctly.</p>
        <p>IP: 54.69.107.92</p>
        <p>Status: Ready for full installation</p>
    </body>
    </html>
    '''

@app.route('/health')
def health():
    return {'status': 'ok'}

if __name__ == '__main__':
    print("Starting minimal Eero Dashboard...")
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF
    chmod +x /opt/eero/app/app.py
fi

# Create/fix systemd service
echo "Creating systemd service..."
cat > /etc/systemd/system/eero.service << 'EOF'
[Unit]
Description=Eero Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/eero/app
ExecStart=/usr/bin/python3 /opt/eero/app/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Create/fix nginx config
echo "Creating nginx config..."
cat > /etc/nginx/sites-enabled/default << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

# Restart everything
echo "Restarting services..."
systemctl daemon-reload
systemctl enable eero
systemctl restart eero
systemctl restart nginx

# Wait and test
echo "Waiting for services to start..."
sleep 5

echo ""
echo "🧪 Final Test:"
if curl -s http://localhost > /dev/null; then
    echo "✅ Local connection working"
else
    echo "❌ Local connection still failing"
fi

if curl -s http://localhost/health > /dev/null; then
    echo "✅ Health check working"
else
    echo "❌ Health check failing"
fi

# Get public IP and test
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "54.69.107.92")

echo ""
echo "🎯 Results:"
echo "Dashboard URL: http://$PUBLIC_IP"
echo ""
echo "If still not working, check:"
echo "1. Lightsail firewall settings in AWS console"
echo "2. Security group allows port 80"
echo "3. Instance is running"
echo ""
echo "Manual commands to try:"
echo "sudo systemctl status eero"
echo "sudo systemctl status nginx"
echo "sudo journalctl -u eero -f"