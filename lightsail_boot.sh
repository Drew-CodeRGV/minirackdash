#!/bin/bash
# MiniRack Dashboard - Lightsail Boot Script
# Minimal script that pulls everything from GitHub
# Repository: https://github.com/Drew-CodeRGV/minirackdash

set -e

echo "🚀 MiniRack Dashboard - Starting Installation"
echo "Repository: https://github.com/Drew-CodeRGV/minirackdash"

# Update system and install essentials
apt-get update -y
apt-get install -y python3-pip nginx git curl

# Install Python packages
apt-get install -y python3-flask python3-requests python3-pip
pip3 install --break-system-packages flask-cors speedtest-cli gunicorn

# Clone repository
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
cd /tmp
rm -rf minirackdash
git clone -b eeroNetworkDash https://github.com/Drew-CodeRGV/minirackdash.git
cd minirackdash

# Run the full installer from GitHub
chmod +x deploy/lightsail_installer.sh
./deploy/lightsail_installer.sh

echo "✅ Installation complete!"
echo "🌐 Dashboard: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"