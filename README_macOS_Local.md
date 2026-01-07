# MiniRack Dashboard - macOS Local Setup

Run the complete MiniRack Dashboard locally on your Mac with full mobile responsive design and multi-network support.

## 🚀 Quick Start

### Option 1: Automatic Setup (Recommended)
```bash
# Run the setup script
python3 setup_macos_local.py

# Start the dashboard
./run_local.sh
```

### Option 2: Manual Setup
```bash
# Install dependencies
pip3 install flask==2.3.3 flask-cors==4.0.0 requests==2.31.0 pytz==2023.3

# Run the dashboard
python3 dashboard_local.py
```

## 📱 Access Your Dashboard

- **URL**: http://localhost:3000
- **Admin Panel**: Click the π button
- **Mobile Responsive**: Works on all devices
- **Multi-Network**: Support for up to 6 networks

## ⚙️ Configuration

### Local Configuration Directory
- **Location**: `~/.minirack/`
- **Config File**: `~/.minirack/config.json`
- **Logs**: `~/.minirack/dashboard.log`
- **Cache**: `~/.minirack/data_cache.json`

### Network Setup
1. Open http://localhost:3000
2. Click the π button (bottom right)
3. Click "Manage Networks"
4. Add your network ID and email
5. Authenticate with the verification code

## 🔧 Features

### ✅ Complete Feature Set
- **Mobile Responsive Design** - Perfect on all screen sizes
- **Multi-Network Support** - Monitor up to 6 networks
- **Real-time Device Monitoring** - Wired and wireless devices
- **Signal Strength Analysis** - RSSI data and charts
- **Frequency Distribution** - 2.4GHz, 5GHz, 6GHz breakdown
- **Device Type Detection** - iOS, Android, Windows, Amazon, etc.
- **Time Range Selection** - 1h, 4h, 8h, 12h, 24h, week
- **Per-Network Statistics** - Individual network breakdowns

### 📊 Dashboard Charts
1. **Connected Devices** - Timeline of device connections
2. **Device Types** - Pie chart of device OS distribution
3. **Frequency Distribution** - Wireless frequency usage
4. **Average Signal Strength** - RSSI over time

### 🔐 Network Authentication
- Email-based verification
- Secure token storage
- Multiple network support
- Individual network enable/disable

## 🛠️ Troubleshooting

### Dependencies Issues
```bash
# If you get import errors
pip3 install --upgrade flask flask-cors requests pytz

# For Python version issues
python3 --version  # Should be 3.8+
```

### Port Conflicts
If port 3000 is in use, edit `dashboard_local.py` and change:
```python
app.run(host='127.0.0.1', port=3001, debug=True)  # Use port 3001
```

### Configuration Issues
```bash
# Reset configuration
rm -rf ~/.minirack/
python3 dashboard_local.py  # Will recreate defaults
```

### Network Authentication
1. Make sure your email is correct
2. Check spam folder for verification codes
3. Codes expire after a few minutes
4. Try the authentication process again

## 📁 File Structure

```
minirackdash/
├── dashboard_local.py          # Local macOS runner
├── run_local.sh               # Convenience script
├── setup_macos_local.py       # Automatic setup
├── deploy/
│   ├── dashboard_minimal.py   # Main dashboard code
│   ├── index.html            # Frontend (mobile responsive)
│   └── requirements.txt      # Dependencies
└── ~/.minirack/              # Local config directory
    ├── config.json           # Network configuration
    ├── dashboard.log         # Application logs
    ├── data_cache.json       # Cached data
    └── .eero_token*          # Authentication tokens
```

## 🔄 Updates

To update to the latest version:
```bash
git pull origin eeroNetworkDash
python3 dashboard_local.py  # Restart with new code
```

## 🌐 Deployment vs Local

| Feature | Local macOS | AWS Lightsail |
|---------|-------------|---------------|
| **URL** | localhost:3000 | Public IP |
| **Config** | ~/.minirack/ | /opt/eero/ |
| **Service** | Manual start | systemd |
| **Logs** | ~/.minirack/dashboard.log | /opt/eero/logs/ |
| **Updates** | git pull | Deployment scripts |

## 📞 Support

- **Version**: 6.7.8-mobile-local
- **Features**: All production features included
- **Mobile**: Fully responsive design
- **Networks**: Multi-network support
- **Debug**: Console logging and debug endpoints

Your local dashboard has the same features as the production AWS version!