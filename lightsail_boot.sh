#!/bin/bash
# MiniRack Dashboard - Lightsail Boot Script
# Repository: https://github.com/Drew-CodeRGV/minirackdash

set -e
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/minirack-install.log
}

log "🚀 MiniRack Dashboard - Starting Installation"
log "Repository: https://github.com/Drew-CodeRGV/minirackdash"

# Update system and install essentials
log "📦 Updating system packages..."
apt-get update -y >> /var/log/minirack-install.log 2>&1

log "📦 Installing system packages..."
apt-get install -y python3-pip nginx git curl >> /var/log/minirack-install.log 2>&1

# Install Python packages
log "🐍 Installing Python packages..."
apt-get install -y python3-flask python3-requests python3-venv >> /var/log/minirack-install.log 2>&1
pip3 install --break-system-packages flask-cors gunicorn >> /var/log/minirack-install.log 2>&1

# Create directories first
log "📁 Creating directories..."
mkdir -p /opt/eero/{app,logs,backups}

# Clone repository with retry logic
log "📥 Cloning repository..."
cd /tmp
rm -rf minirackdash
for i in {1..3}; do
    if git clone -b eeroNetworkDash https://github.com/Drew-CodeRGV/minirackdash.git >> /var/log/minirack-install.log 2>&1; then
        log "✅ Repository cloned successfully"
        break
    else
        log "⚠️ Clone attempt $i failed, retrying..."
        sleep 5
    fi
done

if [ ! -d "minirackdash" ]; then
    log "❌ Failed to clone repository after 3 attempts"
    exit 1
fi

cd minirackdash

# Check if installer exists
if [ ! -f "deploy/lightsail_installer.sh" ]; then
    log "❌ Installer script not found"
    exit 1
fi

# Run the full installer from GitHub
log "🔧 Running installer..."
chmod +x deploy/lightsail_installer.sh
if ./deploy/lightsail_installer.sh >> /var/log/minirack-install.log 2>&1; then
    log "✅ Installation completed successfully"
else
    log "❌ Installation failed"
    exit 1
fi

# Final verification
log "🔍 Verifying installation..."
if systemctl is-active --quiet eero-dashboard && systemctl is-active --quiet nginx; then
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "unknown")
    log "✅ Services are running"
    log "🌐 Dashboard: http://$PUBLIC_IP"
    echo "✅ Installation complete!"
    echo "🌐 Dashboard: http://$PUBLIC_IP"
else
    log "❌ Services failed to start properly"
    systemctl status eero-dashboard >> /var/log/minirack-install.log 2>&1 || true
    systemctl status nginx >> /var/log/minirack-install.log 2>&1 || true
    exit 1
fi