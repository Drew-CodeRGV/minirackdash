# 🌐 MiniRack Dashboard

A beautiful, real-time network monitoring dashboard for Eero networks. Features a modern glassmorphism design with live charts, device tracking, and admin controls.

![Network Dashboard](https://img.shields.io/badge/Version-5.2.4-blue) ![Platform](https://img.shields.io/badge/Platform-AWS%20Lightsail-orange) ![Python](https://img.shields.io/badge/Python-3.8+-green)

## ✨ Features

- **📊 Real-time Charts** - Connected users, device OS distribution, frequency bands, signal strength
- **📱 Device Monitoring** - Live device tracking with detailed information
- **🚀 Speed Testing** - Built-in network speed testing
- **⚙️ Admin Panel** - Network ID management, API authentication, dashboard updates
- **🎨 Modern UI** - Glassmorphism design with smooth animations
- **📱 Responsive** - Works perfectly on desktop and mobile

## 🚀 Quick Deploy to AWS Lightsail

### 1. Create Lightsail Instance
- **Platform**: Linux/Unix
- **Blueprint**: Ubuntu 20.04 LTS  
- **Instance Plan**: $5.00/month (1 GB RAM, IPv4 enabled)

### 2. Add Boot Script
Copy and paste this into the Lightsail launch script field:

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

### 3. Launch & Access
1. **Create static IP** and attach to instance
2. **Wait 5-10 minutes** for installation
3. **Access dashboard** at `http://YOUR_STATIC_IP`

## ⚙️ Configuration

### Initial Setup
1. **Click the π button** (bottom right) to open admin panel
2. **Change Network ID** if needed (default: 20478317)
3. **Setup API Authentication**:
   - Enter your Eero account email
   - Check email for verification code
   - Enter code to complete authentication
4. **Start monitoring!** Charts will populate with live data

### Admin Features
- **Update Dashboard** - Pull latest updates from GitHub
- **Change Network ID** - Switch to different Eero network
- **Reauthorize API** - Refresh authentication tokens

## 🔧 Manual Installation

If the boot script fails, use the manual installer:

```bash
# SSH into your instance
ssh -i your-key.pem ubuntu@YOUR_IP

# Download and run manual installer
curl -O https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/manual_install_venv.sh
chmod +x manual_install_venv.sh
sudo ./manual_install_venv.sh
```

## 📊 Dashboard Overview

### Charts
- **Connected Users** - Line chart showing device count over time
- **Device OS** - Doughnut chart of iOS, Android, Windows, Other
- **Frequency Distribution** - 2.4GHz, 5GHz, 6GHz usage
- **Signal Strength** - Average network signal quality over time

### Device Details
- Real-time device list with IP, MAC, manufacturer
- Signal strength indicators and quality ratings
- OS detection and frequency band information

### Speed Testing
- Integrated speed test with download/upload/ping metrics
- Real-time progress indicators
- Historical results tracking

## 🛠️ Technical Details

### Architecture
- **Backend**: Python Flask with Gunicorn
- **Frontend**: Vanilla JavaScript with Chart.js
- **Proxy**: Nginx for production serving
- **Environment**: Python virtual environment for isolation

### File Structure
```
/opt/eero/
├── app/
│   ├── dashboard.py        # Main Flask application
│   ├── index.html         # Frontend template
│   ├── config.json        # Configuration
│   └── .eero_token       # API token (after auth)
├── logs/
│   └── dashboard.log     # Application logs
└── update.sh             # Update script
```

### API Endpoints
- `GET /` - Main dashboard page
- `GET /api/dashboard` - Dashboard data (charts, devices)
- `GET /api/devices` - Device list
- `POST /api/speedtest/start` - Start speed test
- `GET /api/speedtest/status` - Speed test status
- `POST /api/admin/update` - Update dashboard
- `POST /api/admin/network-id` - Change network ID
- `POST /api/admin/reauthorize` - API authentication

## 🔄 Updates

The dashboard includes a built-in update mechanism:

1. **Via Admin Panel**: Click π → "Update Dashboard"
2. **Via SSH**: `sudo /opt/eero/update.sh`

Updates pull the latest code from the `eeroNetworkDash` branch automatically.

## 🐛 Troubleshooting

### Dashboard Not Loading
```bash
# Check services
sudo systemctl status eero-dashboard nginx

# Restart services
sudo systemctl restart eero-dashboard nginx

# Check logs
sudo journalctl -u eero-dashboard -n 20
```

### No Devices Showing
1. Verify Network ID is correct in admin panel
2. Complete API authentication process
3. Check that devices are connected to Eero network

### 502 Bad Gateway
```bash
# Check if Python app is running
sudo systemctl status eero-dashboard

# Check application logs
tail -f /opt/eero/logs/dashboard.log
```

## 📝 Requirements

- **AWS Lightsail** instance ($5/month minimum for IPv4)
- **Eero network** with admin access
- **Email access** for API authentication

## 🎯 Cost

- **Lightsail Instance**: $5.00/month
- **Static IP**: Free (included with instance)
- **Total**: ~$5.00/month

## 📄 License

MIT License - Feel free to modify and distribute.

---

**Repository**: https://github.com/Drew-CodeRGV/minirackdash  
**Branch**: eeroNetworkDash  
**Version**: 5.2.4-production