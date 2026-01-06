# 🚀 MiniRack Dashboard - Lightsail Installation

Your dashboard repository: **https://github.com/Drew-CodeRGV/minirackdash**
Your Lightsail IP: **54.69.107.92**

## 🎯 **One-Line Fresh Install**

SSH into your Lightsail instance and run this single command:

```bash
curl -sSL https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/main/deploy/fresh_install.sh | sudo bash
```

This will:
- ✅ **Completely wipe** any existing installation
- ✅ **Install all dependencies** (Python, Nginx, etc.)
- ✅ **Clone your GitHub repository**
- ✅ **Set up the dashboard** with your Network ID (20478317)
- ✅ **Configure services** to auto-start
- ✅ **Create update scripts** for future use

## 📋 **Step-by-Step Instructions**

### **1. SSH into your Lightsail instance:**
```bash
ssh -i your-key.pem ubuntu@54.69.107.92
```

### **2. Run the fresh install:**
```bash
curl -sSL https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/main/deploy/fresh_install.sh | sudo bash
```

### **3. Wait for completion (3-5 minutes)**
The script will show progress and end with:
```
🎉 Installation Complete!
🌐 Dashboard URL: http://54.69.107.92
```

### **4. Access your dashboard:**
Visit: **http://54.69.107.92**

### **5. Configure API authentication:**
1. Click the **"Setup API Authentication"** button
2. Enter your **Eero account email**
3. Click **"Send Verification Code"**
4. Check your email and enter the **verification code**
5. Click **"Verify Code"**

## 🔄 **Future Updates**

After installation, you can update your dashboard anytime:

```bash
# SSH into your instance
ssh -i your-key.pem ubuntu@54.69.107.92

# Run the update script
sudo /opt/eero/update.sh
```

This will:
- Pull latest changes from your GitHub repository
- Update the dashboard application
- Restart services
- Preserve your configuration and API tokens

## 🛠️ **Maintenance Commands**

```bash
# Check status
sudo /opt/eero/maintenance.sh status

# View logs
sudo /opt/eero/maintenance.sh logs

# Restart services
sudo /opt/eero/maintenance.sh restart

# Create backup
sudo /opt/eero/maintenance.sh backup
```

## 🎨 **Development Workflow**

1. **Make changes** to your local repository
2. **Commit and push** to GitHub:
   ```bash
   git add .
   git commit -m "Update dashboard features"
   git push origin main
   ```
3. **Update Lightsail**:
   ```bash
   ssh -i your-key.pem ubuntu@54.69.107.92
   sudo /opt/eero/update.sh
   ```

## 📊 **What You'll Get**

After installation, your dashboard will have:

✅ **Real-time network monitoring** - Live device tracking
✅ **Beautiful web interface** - Modern, responsive design
✅ **Admin panel** - Change Network ID, reauthorize API
✅ **Speed test integration** - Built-in speed testing
✅ **Device management** - Detailed device information
✅ **Auto-updates** - Easy updates from GitHub
✅ **24/7 availability** - Runs continuously on Lightsail

## 🔧 **Configuration**

The dashboard comes pre-configured with:
- **Network ID**: 20478317 (changeable via admin panel)
- **Environment**: Production (api-user.e2ro.com)
- **Port**: 80 (standard HTTP)
- **Auto-start**: Enabled on boot

## 🆘 **Troubleshooting**

### **Dashboard not loading:**
```bash
# Check service status
sudo systemctl status eero
sudo systemctl status nginx

# Restart services
sudo systemctl restart eero nginx
```

### **502 Bad Gateway:**
```bash
# Check logs
sudo journalctl -u eero -n 20

# Restart the app
sudo systemctl restart eero
```

### **Can't authenticate:**
```bash
# Check if token file exists
ls -la /opt/eero/app/.eero_token

# Check configuration
cat /opt/eero/app/config.json
```

### **Need to start completely over:**
```bash
# Run fresh install again
curl -sSL https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/main/deploy/fresh_install.sh | sudo bash
```

## 📁 **File Structure**

After installation:
```
/opt/eero/
├── app/
│   ├── app.py              # Main dashboard application
│   ├── config.json         # Configuration file
│   └── .eero_token        # API token (created after auth)
├── repo/                   # Your GitHub repository
│   └── deploy/            # Deployment files
├── logs/                   # Application logs
├── backups/               # Configuration backups
├── update.sh              # Update from GitHub
└── maintenance.sh         # Maintenance commands
```

## 🎉 **Success!**

Once installed, you'll have:
- **Dashboard URL**: http://54.69.107.92
- **GitHub Repository**: https://github.com/Drew-CodeRGV/minirackdash
- **Update Command**: `sudo /opt/eero/update.sh`
- **Maintenance**: `sudo /opt/eero/maintenance.sh status`

Your dashboard will be accessible 24/7 and automatically update from your GitHub repository!

---

**Ready to install?** Run the one-line command above! 🚀