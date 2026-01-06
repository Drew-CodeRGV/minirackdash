#!/bin/bash
# MiniRack Dashboard - Minimal Lightsail Bootstrap (Under 1KB)

# Update and install git
apt-get update -y
apt-get install -y git python3 python3-pip python3-venv nginx curl

# Clone deployment repo (we'll create this)
cd /tmp
git clone https://github.com/eero-drew/minirackdash.git
cd minirackdash

# Run the full installer
chmod +x install_lightsail.sh
./install_lightsail.sh

echo "Deployment complete! Check your public IP in Lightsail console."