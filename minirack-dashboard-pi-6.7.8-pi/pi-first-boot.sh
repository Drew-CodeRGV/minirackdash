#!/bin/bash
# MiniRack Dashboard - First Boot Setup for Raspberry Pi
# This runs automatically on first boot to set up the dashboard

set -e

LOG_FILE="/var/log/dashboard-setup.log"
EMAIL_TO="drew@drewlentz.com"

# Redirect all output to log file
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "$(date): Starting MiniRack Dashboard first boot setup..."

# Wait for network connectivity
echo "$(date): Waiting for network connectivity..."
for i in {1..30}; do
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo "$(date): Network connectivity established"
        break
    fi
    echo "$(date): Waiting for network... ($i/30)"
    sleep 10
done

# Update package list
echo "$(date): Updating package list..."
apt update

# Install required packages
echo "$(date): Installing packages..."
apt install -y python3 python3-pip python3-venv nginx curl msmtp msmtp-mta mailutils

# Create dashboard user and directories
echo "$(date): Setting up dashboard user..."
useradd -r -s /bin/false -d /opt/eero dashboard || true
mkdir -p /opt/eero/{app,logs}
chown -R dashboard:dashboard /opt/eero

# Set up Python environment
echo "$(date): Setting up Python environment..."
sudo -u dashboard python3 -m venv /opt/eero/venv
sudo -u dashboard /opt/eero/venv/bin/pip install flask flask-cors requests gunicorn pytz

# Download dashboard files
echo "$(date): Downloading dashboard files..."
sudo -u dashboard curl -o /opt/eero/app/dashboard.py \
    https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
sudo -u dashboard curl -o /opt/eero/app/index.html \
    https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html

chmod +x /opt/eero/app/dashboard.py

# Create configuration
echo "$(date): Creating configuration..."
sudo -u dashboard tee /opt/eero/app/config.json > /dev/null << 'EOF'
{
    "networks": [{
        "id": "20478317",
        "name": "Primary Network",
        "email": "",
        "token": "",
        "active": true
    }],
    "environment": "raspberry-pi",
    "api_url": "api-user.e2ro.com",
    "timezone": "UTC"
}
EOF

# Configure Nginx
echo "$(date): Configuring Nginx..."
tee /etc/nginx/sites-available/dashboard > /dev/null << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/dashboard /etc/nginx/sites-enabled/

# Create systemd service
echo "$(date): Creating systemd service..."
tee /etc/systemd/system/eero-dashboard.service > /dev/null << 'EOF'
[Unit]
Description=MiniRack Dashboard
After=network.target

[Service]
Type=exec
User=dashboard
Group=dashboard
WorkingDirectory=/opt/eero/app
Environment=PATH=/opt/eero/venv/bin
ExecStart=/opt/eero/venv/bin/python dashboard.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure email
echo "$(date): Configuring email..."
tee /etc/msmtprc > /dev/null << 'EOF'
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        default
host           smtp.gmail.com
port           587
from           pi-dashboard@example.com
user           your-email@gmail.com
password       your-app-password

account default : default
EOF

chmod 600 /etc/msmtprc

# Enable and start services
echo "$(date): Starting services..."
systemctl daemon-reload
systemctl enable nginx eero-dashboard
systemctl start nginx eero-dashboard

# Wait for dashboard to start
sleep 10

# Get IP addresses and send notification
echo "$(date): Sending IP notification..."
HOSTNAME=$(hostname)
ETH_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || echo "Not connected")

# Send email notification
cat << EMAIL_EOF | msmtp "$EMAIL_TO" 2>/dev/null || echo "Email send failed"
To: $EMAIL_TO
Subject: MiniRack Dashboard Pi Ready - $HOSTNAME
Content-Type: text/html

<h2>🥧 MiniRack Dashboard is Ready!</h2>
<p><strong>Hostname:</strong> $HOSTNAME</p>
<p><strong>IP Address:</strong> $ETH_IP</p>
<p><strong>Dashboard URL:</strong> <a href="http://$ETH_IP">http://$ETH_IP</a></p>
<p><strong>Setup Time:</strong> $(date)</p>
<p>The dashboard is ready for Eero network configuration!</p>
EMAIL_EOF

echo "$(date): Setup complete! Dashboard available at http://$ETH_IP"

# Disable this service so it doesn't run again
systemctl disable first-boot-setup.service

echo "$(date): First boot setup completed successfully"