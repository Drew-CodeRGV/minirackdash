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
pip3 install flask flask-cors requests speedtest-cli gunicorn

# Clone repository
cd /tmp
git clone https://github.com/Drew-CodeRGV/minirackdash.git
cd minirackdash

# Run the full installer from GitHub
chmod +x deploy/lightsail_installer.sh
./deploy/lightsail_installer.sh

echo "✅ Installation complete!"
echo "🌐 Dashboard: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"