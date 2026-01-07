#!/bin/bash
# MiniRack Dashboard - Raspberry Pi 5 Installation Script
# Optimized for Pi 5 with email notification

set -e

# Configuration
DASHBOARD_USER="dashboard"
DASHBOARD_DIR="/opt/eero"
EMAIL_TO="drew@drewlentz.com"
VERSION="6.7.8-pi"

echo "🥧 Installing MiniRack Dashboard for Raspberry Pi 5..."
echo "📧 Will email IP address to: $EMAIL_TO"

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "📦 Installing dependencies..."
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    nginx \
    git \
    curl \
    msmtp \
    msmtp-mta \
    mailutils \
    net-tools \
    wireless-tools

# Create dashboard user
echo "👤 Creating dashboard user..."
sudo useradd -r -s /bin/false -d $DASHBOARD_DIR $DASHBOARD_USER || true

# Create directories
echo "📁 Creating directories..."
sudo mkdir -p $DASHBOARD_DIR/{app,logs,venv}
sudo chown -R $DASHBOARD_USER:$DASHBOARD_USER $DASHBOARD_DIR

# Create Python virtual environment
echo "🐍 Setting up Python environment..."
sudo -u $DASHBOARD_USER python3 -m venv $DASHBOARD_DIR/venv
sudo -u $DASHBOARD_USER $DASHBOARD_DIR/venv/bin/pip install --upgrade pip

# Install Python dependencies
echo "📦 Installing Python packages..."
sudo -u $DASHBOARD_USER $DASHBOARD_DIR/venv/bin/pip install \
    flask==2.3.3 \
    flask-cors==4.0.0 \
    requests==2.31.0 \
    gunicorn==21.2.0 \
    pytz==2023.3

# Download dashboard files
echo "📥 Downloading dashboard files..."
sudo -u $DASHBOARD_USER curl -o $DASHBOARD_DIR/app/dashboard.py \
    https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py

sudo -u $DASHBOARD_USER curl -o $DASHBOARD_DIR/app/index.html \
    https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html

# Set permissions
sudo chmod +x $DASHBOARD_DIR/app/dashboard.py

# Create default configuration
echo "⚙️ Creating configuration..."
sudo -u $DASHBOARD_USER tee $DASHBOARD_DIR/app/config.json > /dev/null << EOF
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
echo "🌐 Configuring Nginx..."
sudo tee /etc/nginx/sites-available/dashboard > /dev/null << 'EOF'
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

# Enable Nginx site
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/dashboard /etc/nginx/sites-enabled/

# Create systemd service
echo "🔧 Creating systemd service..."
sudo tee /etc/systemd/system/eero-dashboard.service > /dev/null << EOF
[Unit]
Description=MiniRack Dashboard (Raspberry Pi)
After=network.target

[Service]
Type=exec
User=$DASHBOARD_USER
Group=$DASHBOARD_USER
WorkingDirectory=$DASHBOARD_DIR/app
Environment=PATH=$DASHBOARD_DIR/venv/bin
ExecStart=$DASHBOARD_DIR/venv/bin/python dashboard.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure email (using Gmail SMTP)
echo "📧 Configuring email notifications..."
sudo tee /etc/msmtprc > /dev/null << 'EOF'
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        gmail
host           smtp.gmail.com
port           587
from           pi-dashboard@gmail.com
user           pi.dashboard.notifications@gmail.com
password       your-app-password-here

account default : gmail
EOF

sudo chmod 600 /etc/msmtprc

# Create IP notification script
echo "📧 Creating IP notification script..."
sudo tee /usr/local/bin/notify-ip.sh > /dev/null << 'EOF'
#!/bin/bash

EMAIL_TO="drew@drewlentz.com"
HOSTNAME=$(hostname)

# Get IP addresses
ETH_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || echo "Not connected")
WIFI_IP=$(iwgetid -r 2>/dev/null && ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 || echo "Not connected")

# Create email content
cat << EMAIL_EOF | msmtp "$EMAIL_TO"
To: $EMAIL_TO
Subject: MiniRack Dashboard Pi Ready - $HOSTNAME
Content-Type: text/html

<h2>🥧 MiniRack Dashboard is Ready!</h2>

<p><strong>Hostname:</strong> $HOSTNAME</p>
<p><strong>Ethernet IP:</strong> $ETH_IP</p>
<p><strong>WiFi IP:</strong> $WIFI_IP</p>

<h3>Dashboard Access:</h3>
<ul>
$([ "$ETH_IP" != "Not connected" ] && echo "<li><a href=\"http://$ETH_IP\">http://$ETH_IP</a></li>")
$([ "$WIFI_IP" != "Not connected" ] && echo "<li><a href=\"http://$WIFI_IP\">http://$WIFI_IP</a></li>")
</ul>

<p><strong>Version:</strong> $VERSION</p>
<p><strong>Boot Time:</strong> $(date)</p>

<p>The dashboard is ready for configuration!</p>
EMAIL_EOF

echo "IP notification sent to $EMAIL_TO"
EOF

sudo chmod +x /usr/local/bin/notify-ip.sh

# Create boot notification service
sudo tee /etc/systemd/system/ip-notification.service > /dev/null << 'EOF'
[Unit]
Description=Send IP notification email
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 30
ExecStart=/usr/local/bin/notify-ip.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable services
echo "🔧 Enabling services..."
sudo systemctl daemon-reload
sudo systemctl enable nginx
sudo systemctl enable eero-dashboard
sudo systemctl enable ip-notification

# Start services
echo "🚀 Starting services..."
sudo systemctl start nginx
sudo systemctl start eero-dashboard

# Test installation
echo "🧪 Testing installation..."
sleep 5

if curl -s http://localhost/ | grep -q "Network Dashboard"; then
    echo "✅ Dashboard is running successfully!"
else
    echo "❌ Dashboard may not be running correctly"
    sudo systemctl status eero-dashboard
fi

# Get current IP for immediate display
CURRENT_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || echo "localhost")

echo ""
echo "🎉 MiniRack Dashboard installation complete!"
echo "🌐 Dashboard URL: http://$CURRENT_IP"
echo "📧 IP notification will be sent to: $EMAIL_TO"
echo ""
echo "📋 Next steps:"
echo "1. Configure email settings in /etc/msmtprc if needed"
echo "2. Access dashboard to configure Eero networks"
echo "3. Use admin panel (π button) to add networks"
echo ""
echo "🔧 Useful commands:"
echo "  sudo systemctl status eero-dashboard  # Check dashboard status"
echo "  sudo journalctl -u eero-dashboard -f  # View dashboard logs"
echo "  sudo /usr/local/bin/notify-ip.sh      # Send IP notification manually"