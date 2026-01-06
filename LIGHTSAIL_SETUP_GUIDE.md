# 🚀 Complete Lightsail Setup Guide

I'll walk you through setting up your MiniRack Dashboard on AWS Lightsail. This will cost **$3.50/month** and give you a 24/7 accessible dashboard.

## Step 1: Go to AWS Lightsail

1. **Open your browser** and go to: https://lightsail.aws.amazon.com/
2. **Sign in** to your AWS account (or create one if needed)

## Step 2: Create Your Instance

1. **Click "Create instance"**
2. **Select platform**: Linux/Unix
3. **Select blueprint**: Ubuntu 20.04 LTS
4. **Choose instance plan**: $3.50/month (512 MB RAM, 1 vCPU, 20 GB SSD)

## Step 3: Add the Startup Script

1. **Scroll down** to "Launch script" section
2. **Click "Add launch script"**
3. **Copy and paste** the entire contents of `lightsail_complete_deploy.sh`
   - This script will automatically install everything
   - It includes your Network ID (20478317)
   - It sets up the complete dashboard

## Step 4: Name and Create

1. **Name your instance**: `eero-dashboard`
2. **Click "Create instance"**
3. **Wait 3-5 minutes** for it to launch and run the setup script

## Step 5: Create Static IP (Free)

1. **Go to "Networking" tab** in Lightsail
2. **Click "Create static IP"**
3. **Attach it to your instance**
4. **Note the static IP address** - this is your dashboard URL

## Step 6: Access Your Dashboard

1. **Open browser** and go to: `http://YOUR_STATIC_IP`
2. **You should see** the dashboard interface
3. **If you see a setup notice**, proceed to authentication

## Step 7: Authenticate with Eero API

1. **Click the π icon** (bottom right corner)
2. **Click "Reauthorize API"**
3. **Enter your email** (the one associated with your Eero account)
4. **Click "Send Code"**
5. **Check your email** for the verification code
6. **Enter the code** and click "Verify"
7. **Success!** Your dashboard should now show live data

## 🎉 You're Done!

Your dashboard is now:
- ✅ **Running 24/7** on AWS Lightsail
- ✅ **Accessible from anywhere** at your static IP
- ✅ **Showing real-time data** from your network
- ✅ **Costing only $3.50/month**

## 📱 Bookmark Your Dashboard

Add `http://YOUR_STATIC_IP` to your bookmarks for easy access!

## 🔧 Admin Features Available

Click the π icon to access:
- **Change Network ID** - Switch to different Eero networks
- **Reauthorize API** - Refresh authentication if needed
- **View System Info** - Check version and configuration

## 🛡️ Security Notes

- Your dashboard is accessible from the internet
- API tokens are stored securely
- Consider adding HTTPS later with Let's Encrypt
- Monitor the Lightsail console for usage

## 📊 What You'll See

- **Real-time device count** and connection history
- **Device OS breakdown** (iOS, Android, Windows, Other)
- **Frequency distribution** (2.4GHz, 5GHz, 6GHz)
- **Signal strength trends** over time
- **Detailed device list** with signal quality
- **Built-in speed test** functionality

## 🆘 Troubleshooting

### Dashboard not loading?
- Wait 5-10 minutes for full deployment
- Check Lightsail instance is "running"
- Verify static IP is attached

### No devices showing?
- Click π icon → "Reauthorize API"
- Verify your Network ID is correct
- Check that you're using the right Eero account

### Need to change Network ID?
- Click π icon → "Change Network ID"
- Enter new ID and click "Update"

## 💰 Cost Breakdown

- **Instance**: $3.50/month
- **Static IP**: FREE (while attached)
- **Data transfer**: 1TB/month included
- **Total**: $3.50/month

## 🔄 Future Updates

The dashboard will automatically check for updates. You can also:
- SSH into the instance for manual updates
- Take snapshots before major changes
- Scale up to larger instances if needed

---

**Your Network ID**: 20478317 (pre-configured)
**Dashboard URL**: http://YOUR_STATIC_IP
**Admin Panel**: Click the π icon

Enjoy your new cloud-hosted network dashboard! 🎉