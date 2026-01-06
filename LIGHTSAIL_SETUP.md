# 🚀 MiniRack Dashboard - New Lightsail Setup

## 📋 **Complete Setup Instructions**

### **Step 1: Create New Lightsail Instance**

1. **Go to AWS Lightsail**: https://lightsail.aws.amazon.com/
2. **Click "Create instance"**
3. **Select**:
   - Platform: Linux/Unix
   - Blueprint: Ubuntu 20.04 LTS
   - Instance plan: $3.50/month (512 MB RAM, 1 vCPU, 20 GB SSD)

### **Step 2: Add Boot Script**

1. **Scroll to "Launch script"**
2. **Click "Add launch script"**
3. **Copy and paste this script**:

```bash
#!/bin/bash
# MiniRack Dashboard - Lightsail Boot Script
# Repository: https://github.com/Drew-CodeRGV/minirackdash

set -e

echo "🚀 MiniRack Dashboard - Starting Installation"

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
```

### **Step 3: Launch Instance**

1. **Name your instance**: `eero-dashboard`
2. **Click "Create instance"**
3. **Wait 5-10 minutes** for installation to complete

### **Step 4: Create Static IP**

1. **Go to "Networking" tab**
2. **Click "Create static IP"**
3. **Attach to your instance**
4. **Note the static IP address**

### **Step 5: Access Dashboard**

1. **Visit**: `http://YOUR_STATIC_IP`
2. **You should see**: Beautiful MiniRack Dashboard
3. **Network ID**: Pre-configured to 20478317

### **Step 6: Configure API Authentication**

1. **Click "Setup API Auth"**
2. **Enter your Eero account email**
3. **Click "Send Code"**
4. **Check email for verification code**
5. **Enter code and click "Verify"**
6. **Success!** Dashboard will now show live device data

## 🎯 **What You Get**

✅ **Beautiful modern dashboard** with glassmorphism design
✅ **Real-time device monitoring** - Live device counts and details
✅ **Admin controls** - Change Network ID, reauthorize API
✅ **Speed test integration** - Built-in network speed testing
✅ **Production ready** - Runs with Gunicorn + Nginx on port 80
✅ **Auto-updates** - Easy updates from GitHub repository
✅ **Mobile responsive** - Works on all devices

## 🔄 **Future Updates**

To update your dashboard with new features:

```bash
# SSH into your instance
ssh -i your-key.pem ubuntu@YOUR_STATIC_IP

# Run update script
sudo /opt/eero/update.sh
```

## 📊 **Features Available**

- **Real-time device tracking** with OS detection
- **Network ID management** through web interface
- **API authentication** without SSH access
- **Speed testing** with live results
- **Device details** including IP, MAC, manufacturer
- **Responsive design** for desktop and mobile
- **Production logging** for troubleshooting

## 🛠️ **Troubleshooting**

### **Dashboard not loading:**
```bash
# SSH into instance
ssh -i your-key.pem ubuntu@YOUR_STATIC_IP

# Check services
sudo systemctl status eero-dashboard
sudo systemctl status nginx

# Restart if needed
sudo systemctl restart eero-dashboard nginx
```

### **No devices showing:**
1. Click "Setup API Auth" in dashboard
2. Enter your Eero account email
3. Verify with email code
4. Check Network ID is correct

### **502 Bad Gateway:**
```bash
# Check logs
sudo journalctl -u eero-dashboard -n 20

# Restart service
sudo systemctl restart eero-dashboard
```

## 📁 **File Structure**

```
/opt/eero/
├── app/
│   ├── dashboard.py        # Main application
│   ├── config.json         # Configuration
│   ├── requirements.txt    # Python dependencies
│   └── .eero_token        # API token (after auth)
├── logs/
│   └── dashboard.log      # Application logs
└── update.sh              # Update from GitHub
```

## 🎉 **Success Indicators**

✅ **Dashboard loads** at your static IP
✅ **Shows device count** (even if 0 before auth)
✅ **Admin buttons work** (modals open/close)
✅ **API auth flow** completes successfully
✅ **Devices appear** after authentication

## 🔧 **Configuration**

- **Default Network ID**: 20478317 (changeable via dashboard)
- **Environment**: Production (api-user.e2ro.com)
- **Port**: 80 (standard HTTP)
- **Service**: Auto-starts on boot
- **Updates**: Pull from GitHub repository

---

**Repository**: https://github.com/Drew-CodeRGV/minirackdash
**Boot Script Size**: ~800 bytes (well under 16KB limit)
**Installation Time**: 5-10 minutes
**Monthly Cost**: $3.50 + tax

Ready to create your new instance! 🚀