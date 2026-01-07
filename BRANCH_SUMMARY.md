# Eero EventDash Branch - v6.8.0

This branch contains the enhanced MiniRack Dashboard with comprehensive multi-network monitoring and data export capabilities.

## 🚀 Key Features

### Dashboard Layout
- **Full-Height Per-Network Display**: Replaced signal strength chart with comprehensive network information panel
- **Mobile-First Responsive Design**: Optimized for all screen sizes
- **Real-Time Multi-Network Monitoring**: Support for up to 6 networks simultaneously

### Network Integration
- **Eero Insight Links**: Clickable network IDs that link directly to https://insight.eero.com/networks/NETWORKID
- **Production API Authentication**: Real Eero API integration with email verification
- **Individual Network Management**: Add, remove, enable/disable networks independently

### Data Export
- **CSV Export Feature**: Comprehensive data export with timestamped filenames
- **Complete Network Statistics**: All device counts, types, and frequencies per network
- **Direct Insight Links**: CSV includes direct links to Eero network management

## 📊 Dashboard Components

1. **Connected Devices Chart**: Timeline of device connections across all networks
2. **Device Types Chart**: Pie chart showing OS distribution (iOS, Android, Windows, Amazon, Gaming, Streaming, Other)
3. **Frequency Distribution Chart**: Wireless frequency usage (2.4GHz, 5GHz, 6GHz)
4. **Per-Network Information Panel**: Full-height static display with:
   - Network authentication status
   - Device counts (total, wireless, wired)
   - Device type breakdown by network
   - Frequency distribution by network
   - Clickable Eero Insight links
   - Last update timestamps

## 🔧 Technical Implementation

### Local Development
- **File**: `dashboard_simple_local.py`
- **Config**: `~/.minirack/` directory
- **Port**: localhost:3000
- **Authentication**: Real Eero API with production endpoints

### Production Deployment
- **File**: `deploy/dashboard_minimal.py`
- **Config**: `/opt/eero/app/` directory
- **Service**: systemd with nginx proxy
- **Port**: 80 (public access)

### API Endpoints
- `/api/dashboard` - Main dashboard data
- `/api/networks` - Network configuration
- `/api/network-stats` - Per-network statistics
- `/api/export/csv` - CSV data export
- `/api/admin/networks` - Network management (CRUD)
- `/api/admin/networks/<id>/auth` - Network authentication

## 📱 Mobile Features
- **Responsive Grid Layout**: 1 column (mobile) → 2 columns (tablet) → 4 columns (desktop)
- **Touch-Friendly Controls**: Optimized button sizes and spacing
- **Clamp Typography**: Fluid font sizing across all devices
- **Mobile-Optimized Modals**: Full-screen forms on small devices

## 🔐 Security Features
- **Secure Token Storage**: Individual tokens per network
- **Email Verification**: Production Eero API authentication
- **Permission Management**: Individual network enable/disable
- **Encrypted Configuration**: Secure config file storage

## 📈 Data Export Format

CSV includes the following columns:
- Network Name, Network ID, API Name, Authenticated
- Total Devices, Wireless Devices, Wired Devices
- iOS/Android/Windows/Amazon/Gaming/Streaming/Other Device counts
- 2.4GHz/5GHz/6GHz Device counts
- Last Update timestamp
- Direct Eero Insight link

## 🚀 Deployment Options

### AWS Lightsail (Production)
```bash
# Use the lightsail launch script
curl -s https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eero-eventdash/lightsail_launch_script.sh | bash
```

### Local macOS Development
```bash
# Simple local version
python3 dashboard_simple_local.py

# Access at http://localhost:3000
```

## 📋 Version History
- **v6.8.0**: Full-height per-network display, Eero Insight links, CSV export
- **v6.7.9**: Real production authentication for local development
- **v6.7.8**: Mobile responsive design and chart stability fixes
- **v6.7.7**: Multi-network support and enhanced device detection
- **v6.7.6**: Timezone support and data persistence

## 🔗 Repository Structure
```
minirackdash/
├── dashboard_simple_local.py     # ⭐ Recommended local version
├── deploy/
│   ├── dashboard_minimal.py     # Production version
│   ├── index.html              # Mobile-responsive frontend
│   └── requirements.txt        # Python dependencies
├── README_macOS_Local.md        # Local setup guide
└── BRANCH_SUMMARY.md           # This file
```

This branch represents the most complete and feature-rich version of the MiniRack Dashboard with production-ready multi-network monitoring capabilities.