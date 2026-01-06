# 🚀 MiniRack Dashboard - Lightsail Setup

## Quick Setup Guide

### 1. Create Lightsail Instance
- **Platform**: Linux/Unix
- **Blueprint**: Ubuntu 20.04 LTS
- **Plan**: $5.00/month (1 GB RAM, IPv4 enabled)

### 2. Boot Script
Copy this into the launch script field:

```bash
#!/bin/bash
# MiniRack Dashboard - Lightsail Boot Script
# Repository: https://github.com/Drew-CodeRGV/minirackdash

set -e

echo "🚀 MiniRack Dashboard - Starting Installation"

# Update system and install essentials
apt-get update -y
apt-get install -y python3-flask python3-requests python3-pip nginx git curl
pip3 install --break-system-packages flask-cors speedtest-cli gunicorn

# Clone repository
cd /tmp
git clone -b eeroNetworkDash https://github.com/Drew-CodeRGV/minirackdash.git
cd minirackdash

# Run the full installer from GitHub
chmod +x deploy/lightsail_installer.sh
./deploy/lightsail_installer.sh

echo "✅ Installation complete!"
echo "🌐 Dashboard: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
```

### 3. Access Dashboard
1. Create static IP and attach to instance
2. Wait 5-10 minutes for installation
3. Access at `http://YOUR_STATIC_IP`
4. Click π button to configure Network ID and API authentication

## Manual Installation (if boot script fails)

```bash
ssh -i your-key.pem ubuntu@YOUR_IP
curl -O https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/manual_install_venv.sh
chmod +x manual_install_venv.sh
sudo ./manual_install_venv.sh
```

## Features
- Real-time network monitoring with 4 live charts
- Device tracking and signal strength monitoring  
- Built-in speed testing
- Admin panel with update functionality
- Modern glassmorphism UI design

**Cost**: $5/month | **Setup Time**: 5-10 minutes