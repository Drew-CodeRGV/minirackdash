# MiniRack Dashboard - Raspberry Pi 5 Edition

A standalone Raspberry Pi image with the MiniRack Dashboard pre-installed and ready to use.

## 🥧 What You Get

- **Plug & Play**: Flash SD card, boot Pi, get email with IP address
- **Zero Configuration**: Dashboard starts automatically on boot
- **Email Notifications**: Automatic IP address notification to drew@drewlentz.com
- **Web Interface**: Full dashboard accessible via web browser
- **Multi-Network Support**: Monitor up to 6 Eero networks
- **Mobile Responsive**: Works perfectly on phones, tablets, and desktops

## 🚀 Quick Start

### Option 1: Use Pre-Built Image (Recommended)
1. **Download** the latest image from GitHub releases
2. **Flash** to SD card using Raspberry Pi Imager
3. **Configure WiFi** (optional - edit wpa_supplicant.conf on boot partition)
4. **Boot Pi** and wait for email notification
5. **Access Dashboard** at the IP address from email

### Option 2: Build Your Own Image
```bash
# Clone repository
git clone https://github.com/Drew-CodeRGV/minirackdash.git
cd minirackdash

# Build custom image (requires Linux with root access)
sudo ./create-pi-image.sh
```

## 📋 Setup Instructions

### WiFi Configuration (if needed)
1. After flashing SD card, edit `wpa_supplicant.conf.template` on boot partition
2. Add your WiFi credentials:
   ```
   network={
       ssid="Your_WiFi_Name"
       psk="Your_WiFi_Password"
   }
   ```
3. Rename file to `wpa_supplicant.conf`
4. Safely eject SD card and boot Pi

### Ethernet Configuration
- Simply connect Ethernet cable - no configuration needed
- Dashboard will auto-configure and send IP notification

## 📧 Email Notifications

You'll receive an email at **drew@drewlentz.com** when:
- Pi boots and dashboard is ready
- IP address is assigned
- Dashboard is accessible

Email includes:
- Pi hostname
- IP address (Ethernet and/or WiFi)
- Direct dashboard link
- Setup timestamp

## 🌐 Dashboard Access

Once you receive the email notification:
1. Click the dashboard link or navigate to the IP address
2. Use the **π (pi) button** to access admin panel
3. Add your Eero networks using Network ID and email
4. Monitor your networks in real-time

## 🔧 Features

### Dashboard Capabilities
- **Real-time Monitoring**: Live device counts and network status
- **Multi-Network Support**: Monitor up to 6 Eero networks simultaneously
- **Device Analytics**: Device types, frequency distribution, signal strength
- **Time Range Selection**: 1h, 4h, 8h, 12h, 24h, 1 week views
- **Per-Network Stats**: Individual network breakdowns when multiple networks configured

### Mobile Responsive Design
- **Adaptive Layout**: 1 column (mobile) → 2 columns (tablet) → 4 columns (desktop)
- **Touch-Friendly**: 44px minimum touch targets
- **Scalable Typography**: Perfect sizing across all devices
- **Optimized Performance**: Fast loading and smooth operation

## 🛠️ Technical Details

### Hardware Requirements
- **Raspberry Pi 5** (recommended) or Pi 4
- **8GB+ SD Card** (Class 10 or better)
- **Network Connection** (Ethernet or WiFi)
- **Power Supply** (official Pi power adapter recommended)

### Software Stack
- **OS**: Raspberry Pi OS Lite (64-bit)
- **Python**: 3.11+ with Flask web framework
- **Web Server**: Nginx reverse proxy
- **Services**: Systemd for auto-start
- **Email**: msmtp for notifications

### Network Requirements
- Internet connection for initial setup
- Access to Eero API (api-user.e2ro.com)
- SMTP access for email notifications

## 🔍 Troubleshooting

### SSH Access
```bash
# Default credentials (change after first login)
ssh pi@[IP_ADDRESS]
# Password: raspberry
```

### Service Management
```bash
# Check dashboard status
sudo systemctl status eero-dashboard

# View dashboard logs
sudo journalctl -u eero-dashboard -f

# Restart dashboard
sudo systemctl restart eero-dashboard

# Check nginx status
sudo systemctl status nginx
```

### Manual IP Notification
```bash
# Send IP notification manually
sudo /usr/local/bin/notify-ip.sh
```

### Configuration Files
- **Dashboard Config**: `/opt/eero/app/config.json`
- **Email Config**: `/etc/msmtprc`
- **Nginx Config**: `/etc/nginx/sites-available/dashboard`
- **Service Config**: `/etc/systemd/system/eero-dashboard.service`

## 📁 File Structure

```
/opt/eero/
├── app/
│   ├── dashboard.py      # Main dashboard application
│   ├── index.html        # Web interface
│   └── config.json       # Dashboard configuration
├── logs/                 # Application logs
└── venv/                 # Python virtual environment

/home/pi/
├── SETUP_INSTRUCTIONS.txt
├── VERSION.txt
└── raspberry-pi-install.sh
```

## 🔄 Updates

### Automatic Updates
The dashboard includes a built-in update mechanism:
1. Access admin panel (π button)
2. Click "Check for Updated Dashboard Code"
3. Updates are downloaded and applied automatically

### Manual Updates
```bash
# SSH into Pi and run
sudo systemctl stop eero-dashboard
sudo -u dashboard curl -o /opt/eero/app/dashboard.py \
    https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
sudo -u dashboard curl -o /opt/eero/app/index.html \
    https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html
sudo systemctl start eero-dashboard
```

## 🆘 Support

### Common Issues
1. **No email received**: Check network connectivity and email configuration
2. **Dashboard not accessible**: Verify Pi is powered on and connected to network
3. **Eero authentication fails**: Ensure correct Network ID and email address
4. **Charts not updating**: Check Eero API connectivity and authentication

### Getting Help
- Check logs: `sudo journalctl -u eero-dashboard -f`
- Verify network: `ping 8.8.8.8`
- Test dashboard: `curl http://localhost/`
- Check email config: `sudo cat /etc/msmtprc`

## 📊 Version Information

- **Current Version**: 6.7.8-pi
- **Base OS**: Raspberry Pi OS Lite (64-bit)
- **Python Version**: 3.11+
- **Dashboard Features**: Full feature parity with cloud version
- **Email Integration**: Automatic IP notifications

## 🎯 Perfect For

- **Home Network Monitoring**: Keep tabs on your Eero network
- **Remote Locations**: Monitor networks at vacation homes, offices
- **IT Professionals**: Network monitoring and troubleshooting
- **Tech Enthusiasts**: Self-hosted network analytics
- **Small Businesses**: Simple network monitoring solution

---

**Ready to monitor your Eero networks with a dedicated Raspberry Pi dashboard!** 🥧📊