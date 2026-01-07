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
