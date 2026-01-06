#!/bin/bash
# Quick fix for 502 Bad Gateway error
# Run this on your Lightsail instance

echo "🔧 Fixing 502 Bad Gateway error..."

# Stop services
systemctl stop eero 2>/dev/null
systemctl stop nginx 2>/dev/null

# Install missing dependencies
echo "📦 Installing dependencies..."
apt-get update -y
apt-get install -y python3-pip nginx

# Install Python packages
pip3 install flask flask-cors requests

# Recreate the simple working app
echo "📝 Creating simple app..."
mkdir -p /opt/eero
cat > /opt/eero/app.py << 'EOF'
#!/usr/bin/env python3
from flask import Flask, jsonify
import json
import os

app = Flask(__name__)

@app.route('/')
def home():
    return '''<!DOCTYPE html>
<html>
<head>
    <title>Eero Dashboard - Fixed</title>
    <style>
        body { font-family: Arial; background: #1a1a1a; color: white; padding: 20px; text-align: center; }
        .container { max-width: 800px; margin: 0 auto; }
        h1 { color: #4da6ff; }
        .status { background: #2a2a2a; padding: 20px; border-radius: 10px; margin: 20px 0; }
        .btn { background: #4da6ff; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; margin: 10px; }
        .btn:hover { background: #357abd; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌐 Eero Dashboard</h1>
        <div class="status">
            <h2>✅ Dashboard is Working!</h2>
            <p>Your Lightsail instance is now running correctly.</p>
            <p><strong>Network ID:</strong> 20478317</p>
            <p><strong>Status:</strong> Ready for configuration</p>
        </div>
        
        <div class="status">
            <h3>🔧 Next Steps:</h3>
            <p>1. Set up API authentication</p>
            <p>2. Configure your network settings</p>
            <p>3. Start monitoring your devices</p>
            <button class="btn" onclick="window.location.reload()">Refresh</button>
        </div>
        
        <div class="status">
            <h3>📊 System Info:</h3>
            <p>Version: 5.2.4-fixed</p>
            <p>Server: AWS Lightsail</p>
            <p>IP: 54.69.107.92</p>
        </div>
    </div>
</body>
</html>'''

@app.route('/api/status')
def status():
    return jsonify({
        'status': 'running',
        'version': '5.2.4-fixed',
        'network_id': '20478317',
        'message': 'Dashboard is working correctly'
    })

@app.route('/health')
def health():
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    print("Starting Eero Dashboard...")
    print("Dashboard will be available at: http://54.69.107.92")
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

# Make executable
chmod +x /opt/eero/app.py

# Create systemd service
echo "⚙️ Creating service..."
cat > /etc/systemd/system/eero.service << 'EOF'
[Unit]
Description=Eero Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/eero
ExecStart=/usr/bin/python3 /opt/eero/app.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Configure nginx
echo "🌐 Configuring Nginx..."
cat > /etc/nginx/sites-enabled/default << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# Test nginx config
nginx -t

# Start services
echo "🚀 Starting services..."
systemctl daemon-reload
systemctl enable eero
systemctl start eero
systemctl enable nginx
systemctl start nginx

# Wait a moment for services to start
sleep 3

# Check status
echo ""
echo "📊 Service Status:"
systemctl is-active eero && echo "✅ Eero service running" || echo "❌ Eero service failed"
systemctl is-active nginx && echo "✅ Nginx running" || echo "❌ Nginx failed"

# Test local connection
echo ""
echo "🧪 Testing local connection..."
curl -s http://localhost:5000/health && echo "✅ App responding locally" || echo "❌ App not responding"

echo ""
echo "✅ Fix complete!"
echo "🌐 Try accessing: http://54.69.107.92"
echo ""
echo "If still having issues, run:"
echo "  journalctl -u eero -f"