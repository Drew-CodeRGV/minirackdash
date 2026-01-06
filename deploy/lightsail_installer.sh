#!/bin/bash
# Complete Lightsail installer - runs from GitHub repository
# This script is called by the boot script

set -e

echo "📦 Setting up MiniRack Dashboard from GitHub..."

# Create directories
mkdir -p /opt/eero/{app,logs,backups}

# Copy application files from repository
cp deploy/dashboard.py /opt/eero/app/
cp deploy/config.json /opt/eero/app/
cp deploy/requirements.txt /opt/eero/app/

# Install Python dependencies
cd /opt/eero/app
pip3 install -r requirements.txt

# Set permissions
chown -R www-data:www-data /opt/eero
chmod +x /opt/eero/app/dashboard.py

# Create systemd service
cat > /etc/systemd/system/eero-dashboard.service << 'EOF'
[Unit]
Description=MiniRack Dashboard
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/eero/app
ExecStart=/usr/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 dashboard:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx for port 80
cat > /etc/nginx/sites-available/eero-dashboard << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Enable site
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/eero-dashboard /etc/nginx/sites-enabled/

# Test nginx config
nginx -t

# Create update script
cat > /opt/eero/update.sh << 'EOF'
#!/bin/bash
echo "🔄 Updating from GitHub..."
cd /tmp
rm -rf minirackdash
git clone https://github.com/Drew-CodeRGV/minirackdash.git
cd minirackdash
cp deploy/dashboard.py /opt/eero/app/
systemctl restart eero-dashboard
echo "✅ Update complete!"
EOF
chmod +x /opt/eero/update.sh

# Start services
systemctl daemon-reload
systemctl enable eero-dashboard
systemctl start eero-dashboard
systemctl enable nginx
systemctl restart nginx

# Configure firewall
ufw allow 80/tcp
ufw allow 22/tcp
ufw --force enable

echo "✅ MiniRack Dashboard installed successfully!"
echo "🌐 Access at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"