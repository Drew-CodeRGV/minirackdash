# Lightsail Launch Script Options

Choose the best launch script for your needs:

## 🚀 Option 1: Main Launch Script (Recommended)
**File:** `lightsail_launch_script.sh` (4.8KB)
**Features:** Downloads full v6.7.1 dashboard with all features

```bash
# Copy and paste this entire script into Lightsail launch script field
# Gets you the complete dashboard with all features
```

## ⚡ Option 2: Ultra Minimal (177 bytes)
**File:** `lightsail_launch_minimal.sh` (177 bytes)
**Features:** Downloads and runs the full installation script

```bash
#!/bin/bash
curl -s https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/lightsail_boot.sh | bash
```

## 🔧 Option 3: Alternative Minimal (4KB)
**File:** `lightsail_launch_minimal_v2.sh` (4KB)
**Features:** Similar to main script but more compact

## 📋 What You Get:

### ✅ All Options Include:
- **MiniRack Dashboard v6.7.1-persistent**
- Multi-network support (up to 6 networks)
- Individual API authentication per network
- Timezone configuration
- Data persistence across restarts
- Chart reliability improvements
- π Admin panel with full management
- Automatic nginx and systemd configuration

### 🌐 Access:
After installation completes, access your dashboard at:
`http://YOUR-LIGHTSAIL-IP`

### 🔧 Configuration:
1. Click the π button (bottom-right corner)
2. Go to "Manage Networks" to add your networks
3. Configure timezone in admin panel
4. Authenticate each network individually

## 💡 Recommendation:
Use **Option 1** (main launch script) for the most reliable installation with clear progress feedback and error handling.

Use **Option 2** (ultra minimal) if you want the smallest possible launch script that still gets you the full dashboard.

Both options result in the exact same fully-featured dashboard installation.