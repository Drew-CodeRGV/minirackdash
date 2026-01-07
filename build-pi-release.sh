#!/bin/bash
# Build MiniRack Dashboard Raspberry Pi Release Package

set -e

VERSION="6.7.8-pi"
RELEASE_DIR="minirack-dashboard-pi-$VERSION"
DATE=$(date +%Y%m%d)

echo "🥧 Building MiniRack Dashboard Raspberry Pi Release v$VERSION"

# Create release directory
mkdir -p "$RELEASE_DIR"

# Copy all Pi-specific files
echo "📋 Copying files..."
cp raspberry-pi-install.sh "$RELEASE_DIR/"
cp pi-first-boot.sh "$RELEASE_DIR/"
cp create-pi-image.sh "$RELEASE_DIR/"
cp README_RASPBERRY_PI.md "$RELEASE_DIR/README.md"
cp RASPBERRY_PI_PROJECT_PLAN.md "$RELEASE_DIR/"

# Copy dashboard files
mkdir -p "$RELEASE_DIR/dashboard"
cp deploy/dashboard_minimal.py "$RELEASE_DIR/dashboard/"
cp deploy/index.html "$RELEASE_DIR/dashboard/"
cp deploy/requirements.txt "$RELEASE_DIR/dashboard/"

# Create installation instructions
cat > "$RELEASE_DIR/INSTALLATION.md" << 'EOF'
# MiniRack Dashboard - Raspberry Pi Installation

## Quick Installation (Recommended)

1. **Run the installer on your Pi:**
   ```bash
   chmod +x raspberry-pi-install.sh
   sudo ./raspberry-pi-install.sh
   ```

2. **Access dashboard:**
   - The script will display the IP address when complete
   - Open web browser to that IP address
   - Use π button to configure Eero networks

## Custom Image Creation

1. **Build custom Pi image (Linux required):**
   ```bash
   chmod +x create-pi-image.sh
   sudo ./create-pi-image.sh
   ```

2. **Flash and use:**
   - Flash the created .img.xz file to SD card
   - Configure WiFi if needed (edit wpa_supplicant.conf)
   - Boot Pi and wait for email notification

## Email Configuration

Edit `/etc/msmtprc` to configure email notifications:
```
account default
host smtp.gmail.com
port 587
from your-email@gmail.com
user your-email@gmail.com
password your-app-password
```

## Support

- Dashboard logs: `sudo journalctl -u eero-dashboard -f`
- Service status: `sudo systemctl status eero-dashboard`
- Manual IP notification: `sudo /usr/local/bin/notify-ip.sh`
EOF

# Create version info
cat > "$RELEASE_DIR/VERSION.txt" << EOF
MiniRack Dashboard - Raspberry Pi Edition
Version: $VERSION
Build Date: $(date)
Target: Raspberry Pi 5 (compatible with Pi 4)
Base OS: Raspberry Pi OS Lite (64-bit)

Features:
- Automatic installation and setup
- Email IP notifications to drew@drewlentz.com
- Web-based dashboard on port 80
- Multi-network Eero monitoring
- Mobile responsive design
- Real-time device analytics

Files:
- raspberry-pi-install.sh: Direct installation script
- create-pi-image.sh: Custom image builder
- pi-first-boot.sh: First-boot setup script
- dashboard/: Dashboard application files
EOF

# Create checksums
echo "🔍 Creating checksums..."
cd "$RELEASE_DIR"
find . -type f -exec sha256sum {} \; > SHA256SUMS
cd ..

# Create archive
echo "📦 Creating release archive..."
tar -czf "${RELEASE_DIR}.tar.gz" "$RELEASE_DIR"

# Create zip for Windows users
zip -r "${RELEASE_DIR}.zip" "$RELEASE_DIR"

# Calculate final checksums
sha256sum "${RELEASE_DIR}.tar.gz" > "${RELEASE_DIR}.tar.gz.sha256"
sha256sum "${RELEASE_DIR}.zip" > "${RELEASE_DIR}.zip.sha256"

echo ""
echo "🎉 Release package created successfully!"
echo ""
echo "📁 Files created:"
echo "  ${RELEASE_DIR}.tar.gz ($(du -h "${RELEASE_DIR}.tar.gz" | cut -f1))"
echo "  ${RELEASE_DIR}.zip ($(du -h "${RELEASE_DIR}.zip" | cut -f1))"
echo ""
echo "📋 Contents:"
echo "  - raspberry-pi-install.sh: Direct Pi installation"
echo "  - create-pi-image.sh: Custom image builder"
echo "  - README.md: Complete documentation"
echo "  - dashboard/: Application files"
echo ""
echo "🚀 Next steps:"
echo "1. Test installation on actual Pi hardware"
echo "2. Create custom image using create-pi-image.sh"
echo "3. Upload to GitHub releases"
echo "4. Update documentation with download links"
echo ""
echo "📧 Email notifications will be sent to: drew@drewlentz.com"