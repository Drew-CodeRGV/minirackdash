#!/bin/bash
# Quick Raspberry Pi Installation - Fixed Download Method

set -e

echo "🥧 MiniRack Dashboard - Quick Pi Installation"

# Use curl instead of wget for better reliability
echo "📥 Downloading installation script..."

# Method 1: Direct curl download
if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o raspberry-pi-install.sh \
        "https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/raspberry-pi-install.sh"
    chmod +x raspberry-pi-install.sh
    echo "✅ Downloaded with curl"
elif command -v wget >/dev/null 2>&1; then
    wget -O raspberry-pi-install.sh \
        "https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/raspberry-pi-install.sh"
    chmod +x raspberry-pi-install.sh
    echo "✅ Downloaded with wget"
else
    echo "❌ Neither curl nor wget available"
    exit 1
fi

# Verify download
if [ ! -f "raspberry-pi-install.sh" ] || [ ! -s "raspberry-pi-install.sh" ]; then
    echo "❌ Download failed or file is empty"
    exit 1
fi

echo "🚀 Running installation..."
sudo ./raspberry-pi-install.sh

echo "✅ Installation complete!"