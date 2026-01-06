# 🚀 GitHub Auto-Deploy Setup for MiniRack Dashboard

Your dashboard is running at **http://54.69.107.92** - now let's set up auto-updates from your GitHub fork!

## 📋 **Step 1: Push Files to Your GitHub Fork**

Push these files to your GitHub repository:

```
your-repo/
├── deploy/
│   ├── install.sh          # Full installer script
│   ├── app.py             # Main dashboard application
│   ├── config.json        # Default configuration
│   └── update_lightsail.sh # Update script for existing instances
└── README_GITHUB_DEPLOY.md # This file
```

## 🔧 **Step 2: Update Your Lightsail Instance**

SSH into your Lightsail instance and run:

```bash
# Download the update script
curl -o update_to_github.sh https://raw.githubusercontent.com/YOUR_USERNAME/minirackdash/main/deploy/update_lightsail.sh

# Make it executable
chmod +x update_to_github.sh

# Edit the script to use your GitHub repository
nano update_to_github.sh
# Change: REPO_URL="https://github.com/YOUR_USERNAME/minirackdash.git"

# Run the update
./update_to_github.sh
```

## 🎯 **Step 3: Verify the Update**

1. **Visit your dashboard**: http://54.69.107.92
2. **Check the version**: Should show "5.2.4-github"
3. **Test functionality**: Admin panel, device list, etc.

## 🔄 **Step 4: Set Up Auto-Updates**

### **Option A: Manual Updates**
```bash
# SSH into your Lightsail instance
ssh -i your-key.pem ubuntu@54.69.107.92

# Run update script
/opt/eero/update.sh
```

### **Option B: Webhook Auto-Updates (Advanced)**

1. **Add webhook endpoint** to your GitHub repository:
   - Go to Settings → Webhooks
   - Add webhook: `http://54.69.107.92:8080/webhook`
   - Content type: `application/json`
   - Secret: `your-secret-key`

2. **Start webhook listener** on Lightsail:
   ```bash
   # SSH into instance
   cd /opt/eero
   python3 webhook.py &
   ```

### **Option C: Scheduled Updates**
```bash
# SSH into your Lightsail instance
# Add to crontab for daily updates at 2 AM
echo "0 2 * * * /opt/eero/update.sh" | crontab -
```

## 📁 **File Structure After Update**

```
/opt/eero/
├── app/
│   ├── app.py              # Main application
│   ├── config.json         # Configuration
│   └── .eero_token        # API token (created after auth)
├── repo/                   # Your GitHub repository
│   └── deploy/            # Deployment files
├── logs/
│   └── backend.log        # Application logs
├── update.sh              # Manual update script
└── webhook.py             # Webhook listener (optional)
```

## 🎨 **New Features Available**

After the GitHub update, your dashboard will have:

✅ **Enhanced UI** with better styling and layout
✅ **Improved admin panel** with all controls in one place
✅ **Better error handling** and user feedback
✅ **Speed test integration** with real-time results
✅ **Device management** with detailed information
✅ **Network ID changes** through web interface
✅ **API reauthorization** without SSH access
✅ **Auto-update capability** from GitHub

## 🔧 **Development Workflow**

1. **Make changes** to files in your local repository
2. **Test locally** if needed
3. **Push to GitHub**:
   ```bash
   git add .
   git commit -m "Update dashboard features"
   git push origin main
   ```
4. **Update Lightsail**:
   ```bash
   # SSH into instance
   /opt/eero/update.sh
   ```

## 📊 **Monitoring & Logs**

```bash
# Check service status
systemctl status eero

# View logs
tail -f /opt/eero/logs/backend.log

# Check system logs
journalctl -u eero -f
```

## 🛡️ **Security Notes**

- **Repository**: Keep your repository public or set up deploy keys for private repos
- **Secrets**: Don't commit API tokens or sensitive data
- **Updates**: Test changes locally before pushing to production
- **Backups**: Lightsail automatically backs up your instance

## 🚀 **Next Steps**

1. **Push the deploy files** to your GitHub fork
2. **Update your Lightsail instance** using the update script
3. **Set up your preferred update method** (manual, webhook, or scheduled)
4. **Start developing** new features!

## 🆘 **Troubleshooting**

### **Update fails:**
```bash
# Check repository access
cd /opt/eero/repo
git status
git pull origin main

# Check permissions
ls -la /opt/eero/
sudo chown -R www-data:www-data /opt/eero/
```

### **Service won't start:**
```bash
# Check logs
journalctl -u eero -n 50

# Restart service
systemctl restart eero
```

### **Dashboard not accessible:**
```bash
# Check if service is running
systemctl status eero

# Check nginx
systemctl status nginx

# Check port
netstat -tlnp | grep :80
```

---

**Your Dashboard**: http://54.69.107.92
**GitHub Repository**: Update the REPO_URL in scripts
**Update Command**: `/opt/eero/update.sh`

Happy coding! 🎉