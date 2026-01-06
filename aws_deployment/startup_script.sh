#!/bin/bash
# MiniRack Dashboard - AWS Lightsail Startup Script

# Update system
apt-get update -y
apt-get upgrade -y

# Install Python and dependencies
apt-get install -y python3 python3-pip python3-venv git nginx

# Create user
useradd -m -s /bin/bash eero
mkdir -p /home/eero/dashboard
chown -R eero:eero /home/eero

# Setup Python environment
sudo -u eero python3 -m venv /home/eero/dashboard/venv
sudo -u eero /home/eero/dashboard/venv/bin/pip install flask flask-cors requests speedtest-cli gunicorn

# Create dashboard files
cat > /home/eero/dashboard/app.py << 'EOF'
# Your dashboard code will be inserted here
EOF

# Create frontend directory and files
mkdir -p /home/eero/dashboard/frontend
cat > /home/eero/dashboard/frontend/index.html << 'EOF'
# Your frontend HTML will be inserted here
EOF

# Create systemd service
cat > /etc/systemd/system/eero-dashboard.service << 'EOF'
[Unit]
Description=Eero Dashboard
After=network.target

[Service]
Type=simple
User=eero
WorkingDirectory=/home/eero/dashboard
Environment="PATH=/home/eero/dashboard/venv/bin"
ExecStart=/home/eero/dashboard/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx
cat > /etc/nginx/sites-available/eero-dashboard << 'EOF'
server {
    listen 80;
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
ln -sf /etc/nginx/sites-available/eero-dashboard /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Start services
systemctl daemon-reload
systemctl enable eero-dashboard
systemctl start eero-dashboard
systemctl enable nginx
systemctl restart nginx

# Open firewall
ufw allow 80
ufw allow 22
ufw --force enable

echo "Dashboard deployment complete!"
echo "Access at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
