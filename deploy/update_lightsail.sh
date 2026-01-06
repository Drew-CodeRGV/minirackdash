#!/bin/bash
# Update script for existing Lightsail instance
# Run this on your Lightsail instance to update to the GitHub version

set -e

echo "🔄 Updating MiniRack Dashboard to GitHub auto-deploy version..."

# Stop current service
systemctl stop eero 2>/dev/null || true

# Backup current installation
if [ -f "/opt/eero/app.py" ]; then
    echo "📦 Backing up current installation..."
    cp /opt/eero/app.py /opt/eero/app.py.backup
fi

# Install git if not present
apt-get update -y
apt-get install -y git

# Set your GitHub repository URL
REPO_URL="https://github.com/YOUR_USERNAME/minirackdash.git"

# Clone or update repository
if [ -d "/opt/eero/repo" ]; then
    echo "📦 Updating repository..."
    cd /opt/eero/repo
    git pull origin main
else
    echo "📦 Cloning repository..."
    git clone $REPO_URL /opt/eero/repo
fi

# Copy new application files
echo "📋 Installing new application..."
mkdir -p /opt/eero/app
cp /opt/eero/repo/deploy/app.py /opt/eero/app/
cp /opt/eero/repo/deploy/config.json /opt/eero/app/ 2>/dev/null || echo "Using existing config"

# Install additional dependencies
pip3 install speedtest-cli gunicorn

# Update systemd service
echo "⚙️ Updating systemd service..."
cat > /etc/systemd/system/eero.service << 'EOF'
[Unit]
Description=Eero Dashboard (GitHub Auto-Deploy)
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/eero/app
ExecStart=/usr/bin/python3 /opt/eero/app/app.py
Restart=always
RestartSec=10
Environment=PYTHONPATH=/opt/eero/app

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R www-data:www-data /opt/eero
chmod +x /opt/eero/app/app.py

# Create update script for future use
cat > /opt/eero/update.sh << 'EOF'
#!/bin/bash
echo "🔄 Updating dashboard from GitHub..."
cd /opt/eero/repo
git pull origin main
cp deploy/app.py /opt/eero/app/
systemctl restart eero
echo "✅ Update complete!"
EOF

chmod +x /opt/eero/update.sh

# Reload and start services
echo "🔄 Starting services..."
systemctl daemon-reload
systemctl enable eero
systemctl start eero

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "your-lightsail-ip")

echo "✅ Update complete!"
echo "🌐 Dashboard: http://$PUBLIC_IP"
echo "🔄 To update in future: /opt/eero/update.sh"
echo ""
echo "📝 Next steps:"
echo "1. Update the REPO_URL in this script with your GitHub fork"
echo "2. Push your changes to GitHub"
echo "3. Run /opt/eero/update.sh to pull updates"