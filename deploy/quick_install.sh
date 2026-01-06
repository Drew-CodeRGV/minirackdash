#!/bin/bash
# Quick installer - downloads and runs the fresh install script
# Usage: curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/minirackdash/main/deploy/quick_install.sh | sudo bash

# Configuration
GITHUB_USER="Drew-CodeRGV"
REPO_NAME="minirackdash"

echo "🚀 MiniRack Dashboard - Quick Install"
echo "Downloading fresh installer from GitHub..."

# Download and run the fresh install script
curl -sSL "https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/main/deploy/fresh_install.sh" | \
sed "s/YOUR_USERNAME/${GITHUB_USER}/g" | \
sed "s/minirackdash/${REPO_NAME}/g" | \
bash