#!/bin/bash
# Quick Permission Fix for Dashboard Installation

set -e

echo "🔧 Fixing permissions for MiniRack Dashboard..."

# Stop services
sudo systemctl stop eero-dashboard 2>/dev/null || echo "Dashboard service not running"
sudo systemctl stop nginx 2>/dev/null || echo "Nginx not running"

# Fix directory ownership and permissions
echo "🔐 Fixing directory permissions..."
sudo chown -R www-data:www-data /opt/eero 2>/dev/null || echo "Directory doesn't exist yet"
sudo chmod -R 755 /opt/eero 2>/dev/null || echo "Directory doesn't exist yet"

# Remove problematic venv if it exists
if [ -d "/opt/eero/venv" ]; then
    echo "🗑️ Removing existing venv with permission issues..."
    sudo rm -rf /opt/eero/venv
fi

# Recreate directories with proper permissions
echo "📁 Recreating directories with proper permissions..."
sudo mkdir -p /opt/eero/{app,logs,backups}
sudo chown -R www-data:www-data /opt/eero
sudo chmod 755 /opt/eero /opt/eero/app /opt/eero/logs /opt/eero/backups

# Download files if missing
echo "📥 Ensuring all files are present..."
if [ ! -f "/opt/eero/app/dashboard.py" ]; then
    sudo curl -o /opt/eero/app/dashboard.py https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
fi

if [ ! -f "/opt/eero/app/index.html" ]; then
    sudo curl -o /opt/eero/app/index.html https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html
fi

if [ ! -f "/opt/eero/app/config.json" ]; then
    sudo curl -o /opt/eero/app/config.json https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/config.json
fi

if [ ! -f "/opt/eero/app/requirements.txt" ]; then
    sudo curl -o /opt/eero/app/requirements.txt https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/requirements.txt
fi

# Set proper file permissions
sudo chown -R www-data:www-data /opt/eero/app
sudo chmod +x /opt/eero/app/dashboard.py
sudo chmod 644 /opt/eero/app/index.html /opt/eero/app/config.json /opt/eero/app/requirements.txt

# Create fresh virtual environment
echo "🐍 Creating fresh Python virtual environment..."
cd /opt/eero
sudo -u www-data python3 -m venv venv

# Install packages
echo "📦 Installing Python packages..."
sudo -u www-data /opt/eero/venv/bin/pip install --upgrade pip
sudo -u www-data /opt/eero/venv/bin/pip install -r app/requirements.txt

# Create/update systemd service
echo "⚙️ Creating systemd service..."
sudo tee /etc/systemd/system/eero-dashboard.service > /dev/null << 'EOF'
[Unit]
Description=MiniRack Dashboard
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/eero/app
Environment=PATH=/opt/eero/venv/bin
ExecStart=/opt/eero/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 dashboard:app
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always
RestartSec=10
KillMode=mixed
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

# Test Python environment
echo "🔍 Testing Python environment..."
sudo -u www-data /opt/eero/venv/bin/python -c "import sys; sys.path.insert(0, '/opt/eero/app'); import dashboard; print('✅ Python environment working')"

# Start services
echo "🚀 Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable eero-dashboard
sudo systemctl start eero-dashboard

# Wait for service
echo "⏳ Waiting for dashboard service..."
for i in {1..20}; do
    if sudo systemctl is-active --quiet eero-dashboard; then
        echo "✅ Dashboard service is running"
        break
    fi
    if [ $i -eq 20 ]; then
        echo "❌ Dashboard service failed to start"
        sudo systemctl status eero-dashboard
        exit 1
    fi
    sleep 2
done

# Test dashboard
echo "🔍 Testing dashboard..."
for i in {1..10}; do
    if curl -f http://localhost:5000/health > /dev/null 2>&1; then
        echo "✅ Dashboard responding on port 5000"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "❌ Dashboard not responding"
        sudo systemctl status eero-dashboard
        exit 1
    fi
    sleep 2
done

echo ""
echo "🎉 Permission fix completed successfully!"
echo "✅ Virtual environment recreated with proper permissions"
echo "✅ All files have correct ownership (www-data:www-data)"
echo "✅ Dashboard service is running"
echo ""
echo "Next step: Run the nginx fix if needed:"
echo "curl -s https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/fix_nginx_default_page.sh | sudo bash"