#!/bin/bash
# Emergency fix for connection refused
# This creates a minimal working dashboard

echo "🚨 Emergency Fix - Creating minimal working dashboard"

# Stop everything
systemctl stop eero 2>/dev/null
systemctl stop nginx 2>/dev/null

# Install essentials
apt-get update -y
apt-get install -y python3-pip nginx
pip3 install flask

# Create minimal app
mkdir -p /opt/eero/app
cat > /opt/eero/app/app.py << 'EOF'
from flask import Flask
app = Flask(__name__)

@app.route('/')
def home():
    return '''<!DOCTYPE html>
<html>
<head>
    <title>Eero Dashboard - Emergency Mode</title>
    <style>
        body { font-family: Arial; background: #1a1a1a; color: white; text-align: center; padding: 50px; }
        h1 { color: #4da6ff; }
        .box { background: #2a2a2a; padding: 20px; border-radius: 10px; margin: 20px auto; max-width: 600px; }
    </style>
</head>
<body>
    <h1>🌐 Eero Dashboard</h1>
    <div class="box">
        <h2>✅ Connection Restored!</h2>
        <p>Your Lightsail instance is now responding.</p>
        <p><strong>IP:</strong> 54.69.107.92</p>
        <p><strong>Status:</strong> Emergency mode - basic functionality</p>
    </div>
    <div class="box">
        <h3>🔧 Next Steps:</h3>
        <p>1. SSH into your instance</p>
        <p>2. Run the full installation script</p>
        <p>3. Configure your network settings</p>
    </div>
</body>
</html>'''

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# Simple service
cat > /etc/systemd/system/eero.service << 'EOF'
[Unit]
Description=Eero Dashboard Emergency
[Service]
ExecStart=/usr/bin/python3 /opt/eero/app/app.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# Simple nginx
cat > /etc/nginx/sites-enabled/default << 'EOF'
server {
    listen 80;
    location / { proxy_pass http://127.0.0.1:5000; }
}
EOF

# Start everything
systemctl daemon-reload
systemctl enable eero
systemctl start eero
systemctl start nginx

echo "✅ Emergency fix complete!"
echo "🌐 Try: http://54.69.107.92"