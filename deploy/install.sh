#!/bin/bash
# Auto-deployment script for MiniRack Dashboard
# This script pulls from GitHub and updates the Lightsail instance

set -e

REPO_URL="https://github.com/Drew-CodeRGV/minirackdash.git"
INSTALL_DIR="/opt/eero"
SERVICE_NAME="eero"

echo "🚀 Starting MiniRack Dashboard deployment..."

# Update system
apt-get update -y
apt-get install -y python3-pip nginx git curl

# Install Python packages
pip3 install flask flask-cors requests speedtest-cli gunicorn

# Create directories
mkdir -p $INSTALL_DIR/{app,logs}

# Clone or update repository
if [ -d "$INSTALL_DIR/repo" ]; then
    echo "📦 Updating repository..."
    cd $INSTALL_DIR/repo
    git pull origin main
else
    echo "📦 Cloning repository..."
    git clone $REPO_URL $INSTALL_DIR/repo
fi

# Copy application files
echo "📋 Copying application files..."
cp $INSTALL_DIR/repo/deploy/app.py $INSTALL_DIR/app/
cp $INSTALL_DIR/repo/deploy/config.json $INSTALL_DIR/app/ 2>/dev/null || echo "No config file found, using defaults"

# Set permissions
chown -R www-data:www-data $INSTALL_DIR
chmod +x $INSTALL_DIR/app/app.py

# Create systemd service
echo "⚙️ Creating systemd service..."
cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=Eero Dashboard
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$INSTALL_DIR/app
ExecStart=/usr/bin/python3 $INSTALL_DIR/app/app.py
Restart=always
RestartSec=10
Environment=PYTHONPATH=$INSTALL_DIR/app

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx
echo "🌐 Configuring Nginx..."
cat > /etc/nginx/sites-available/eero-dashboard << EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/eero-dashboard /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Reload and start services
echo "🔄 Starting services..."
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME
systemctl enable nginx
systemctl restart nginx

# Create update script
echo "📝 Creating update script..."
cat > $INSTALL_DIR/update.sh << 'EOF'
#!/bin/bash
cd /opt/eero/repo
git pull origin main
cp deploy/app.py /opt/eero/app/
systemctl restart eero
echo "✅ Dashboard updated successfully!"
EOF

chmod +x $INSTALL_DIR/update.sh

# Create webhook endpoint for auto-updates
echo "🔗 Setting up webhook..."
cat > $INSTALL_DIR/webhook.py << 'EOF'
#!/usr/bin/env python3
from flask import Flask, request
import subprocess
import hmac
import hashlib
import os

app = Flask(__name__)
WEBHOOK_SECRET = os.environ.get('WEBHOOK_SECRET', 'your-secret-key')

@app.route('/webhook', methods=['POST'])
def webhook():
    signature = request.headers.get('X-Hub-Signature-256')
    if signature:
        expected = 'sha256=' + hmac.new(
            WEBHOOK_SECRET.encode(),
            request.data,
            hashlib.sha256
        ).hexdigest()
        if hmac.compare_digest(signature, expected):
            subprocess.run(['/opt/eero/update.sh'], check=True)
            return 'Updated', 200
    return 'Unauthorized', 401

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOF

echo "✅ Deployment complete!"
echo "🌐 Dashboard: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "🔄 To update: /opt/eero/update.sh"