#!/bin/bash
# Create MiniRack Dashboard Raspberry Pi Image
# This script creates a custom Pi image with the dashboard pre-installed

set -e

# Configuration
BASE_IMAGE_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2024-03-15/2024-03-15-raspios-bookworm-arm64-lite.img.xz"
BASE_IMAGE="2024-03-15-raspios-bookworm-arm64-lite.img.xz"
CUSTOM_IMAGE="minirack-dashboard-pi5-$(date +%Y%m%d).img"
MOUNT_POINT="/tmp/pi-mount"
WORK_DIR="/tmp/pi-build"

echo "🥧 Creating MiniRack Dashboard Raspberry Pi Image..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

# Create work directory
mkdir -p $WORK_DIR
cd $WORK_DIR

# Download base image if not exists
if [ ! -f "$BASE_IMAGE" ]; then
    echo "📥 Downloading Raspberry Pi OS base image..."
    wget "$BASE_IMAGE_URL"
fi

# Extract image
echo "📦 Extracting base image..."
if [ ! -f "${BASE_IMAGE%.xz}" ]; then
    xz -d -k "$BASE_IMAGE"
fi

# Copy to custom image name
echo "📋 Creating custom image..."
cp "${BASE_IMAGE%.xz}" "$CUSTOM_IMAGE"

# Create loop device
echo "🔧 Setting up loop device..."
LOOP_DEVICE=$(losetup -f --show "$CUSTOM_IMAGE")
echo "Using loop device: $LOOP_DEVICE"

# Wait for partitions to be recognized
sleep 2
partprobe $LOOP_DEVICE

# Mount the root partition (usually partition 2)
echo "📁 Mounting root partition..."
mkdir -p $MOUNT_POINT
mount ${LOOP_DEVICE}p2 $MOUNT_POINT

# Mount boot partition
echo "📁 Mounting boot partition..."
mkdir -p $MOUNT_POINT/boot
mount ${LOOP_DEVICE}p1 $MOUNT_POINT/boot

# Enable SSH
echo "🔑 Enabling SSH..."
touch $MOUNT_POINT/boot/ssh

# Create installation script in image
echo "📝 Adding installation script to image..."
cp ../raspberry-pi-install.sh $MOUNT_POINT/home/pi/
chmod +x $MOUNT_POINT/home/pi/raspberry-pi-install.sh

# Create first-boot service
echo "🔧 Creating first-boot service..."
cat > $MOUNT_POINT/etc/systemd/system/first-boot-setup.service << 'EOF'
[Unit]
Description=First Boot Dashboard Setup
After=network-online.target
Wants=network-online.target
Before=getty@tty1.service

[Service]
Type=oneshot
ExecStart=/home/pi/raspberry-pi-install.sh
ExecStartPost=/bin/systemctl disable first-boot-setup.service
StandardOutput=journal
StandardError=journal
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable first-boot service
echo "🔧 Enabling first-boot service..."
chroot $MOUNT_POINT systemctl enable first-boot-setup.service

# Create WiFi configuration template
echo "📶 Creating WiFi configuration template..."
cat > $MOUNT_POINT/boot/wpa_supplicant.conf.template << 'EOF'
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="YOUR_WIFI_NAME"
    psk="YOUR_WIFI_PASSWORD"
}
EOF

# Create setup instructions
echo "📋 Creating setup instructions..."
cat > $MOUNT_POINT/home/pi/SETUP_INSTRUCTIONS.txt << 'EOF'
MiniRack Dashboard - Raspberry Pi Setup Instructions

1. WIFI SETUP (if using WiFi):
   - Edit /boot/wpa_supplicant.conf.template
   - Add your WiFi credentials
   - Rename to wpa_supplicant.conf
   - Reboot

2. ETHERNET SETUP:
   - Simply connect Ethernet cable
   - Dashboard will auto-configure

3. FIRST BOOT:
   - The dashboard will install automatically on first boot
   - This may take 5-10 minutes
   - You will receive an email with the IP address when ready

4. ACCESS DASHBOARD:
   - Open web browser to the IP address from email
   - Use admin panel (π button) to configure Eero networks

5. TROUBLESHOOTING:
   - SSH: ssh pi@[IP_ADDRESS] (default password: raspberry)
   - Logs: sudo journalctl -u eero-dashboard -f
   - Status: sudo systemctl status eero-dashboard

Email notifications will be sent to: drew@drewlentz.com
EOF

# Set ownership
chroot $MOUNT_POINT chown pi:pi /home/pi/SETUP_INSTRUCTIONS.txt
chroot $MOUNT_POINT chown pi:pi /home/pi/raspberry-pi-install.sh

# Create version file
echo "📋 Creating version file..."
echo "MiniRack Dashboard Pi Image v6.7.8-pi" > $MOUNT_POINT/home/pi/VERSION.txt
echo "Built: $(date)" >> $MOUNT_POINT/home/pi/VERSION.txt
echo "Base: Raspberry Pi OS Lite (64-bit)" >> $MOUNT_POINT/home/pi/VERSION.txt

# Unmount filesystems
echo "📁 Unmounting filesystems..."
umount $MOUNT_POINT/boot
umount $MOUNT_POINT
rmdir $MOUNT_POINT

# Detach loop device
echo "🔧 Detaching loop device..."
losetup -d $LOOP_DEVICE

# Compress final image
echo "📦 Compressing final image..."
xz -9 -T 0 "$CUSTOM_IMAGE"

# Calculate checksums
echo "🔍 Calculating checksums..."
sha256sum "${CUSTOM_IMAGE}.xz" > "${CUSTOM_IMAGE}.xz.sha256"

echo ""
echo "🎉 Custom Raspberry Pi image created successfully!"
echo "📁 Image file: ${CUSTOM_IMAGE}.xz"
echo "📊 Image size: $(du -h "${CUSTOM_IMAGE}.xz" | cut -f1)"
echo "🔍 SHA256: $(cat "${CUSTOM_IMAGE}.xz.sha256")"
echo ""
echo "📋 To use this image:"
echo "1. Flash ${CUSTOM_IMAGE}.xz to SD card using Raspberry Pi Imager"
echo "2. Edit wpa_supplicant.conf.template on boot partition for WiFi"
echo "3. Insert SD card and boot Pi"
echo "4. Wait for email notification with IP address"
echo "5. Access dashboard at provided IP address"
echo ""
echo "📧 Email notifications will be sent to: drew@drewlentz.com"