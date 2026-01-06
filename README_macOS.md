# MiniRack Dashboard - macOS Version

A macOS-compatible version of the MiniRack Eero Network Dashboard with full admin functionality including network ID management.

## Features

- **Real-time network monitoring** - Live device tracking and statistics
- **Beautiful web interface** - Modern dashboard with charts and visualizations  
- **Admin panel** - Change network ID, reauthorize API, and manage settings
- **Speed testing** - Integrated speed test functionality
- **Device management** - Detailed device information and signal strength
- **macOS optimized** - No sudo required, runs on port 5000

## Quick Start

### 1. Install Dependencies

Make sure you have Python 3.7+ installed:

```bash
# Check Python version
python3 --version

# Install required packages
pip3 install flask flask-cors requests speedtest-cli
```

### 2. Run Setup

```bash
# Make setup script executable
chmod +x setup_macos.py

# Run setup
python3 setup_macos.py
```

The setup script will:
- Check dependencies and install if needed
- Create necessary directories
- Set up configuration
- Authenticate with Eero API
- Create launch scripts

### 3. Start Dashboard

```bash
# Navigate to dashboard directory
cd ~/eero_dashboard

# Start the dashboard
./start_dashboard.sh
```

Or run directly:
```bash
python3 macos_dashboard.py
```

### 4. Access Dashboard

Open your browser and go to: **http://localhost:5000**

## Admin Panel Features

Click the **π** icon in the bottom right to access the admin panel:

### Change Network ID
- Update your Eero network ID without reinstalling
- Validates input and saves configuration
- Automatically reloads dashboard with new settings

### Reauthorize API
- Refresh your Eero API authentication
- Two-step process: email verification + code entry
- Secure token storage

### System Information
- View current version and configuration
- Check environment (Production/Staging)
- Monitor API connectivity

## Configuration

The dashboard stores configuration in `~/eero_dashboard/.config.json`:

```json
{
  "network_id": "your_network_id",
  "environment": "production",
  "api_url": "api-user.e2ro.com",
  "last_updated": "2024-01-01T00:00:00"
}
```

## File Structure

```
~/eero_dashboard/
├── macos_dashboard.py          # Main dashboard application
├── frontend/
│   └── index.html             # Web interface
├── logs/
│   └── backend.log            # Application logs
├── .config.json               # Configuration file
├── .eero_token               # API authentication token
└── start_dashboard.sh        # Launch script
```

## API Endpoints

The dashboard provides a REST API:

- `GET /` - Main dashboard interface
- `GET /api/dashboard` - Dashboard data (devices, charts)
- `GET /api/devices` - Device list
- `GET /api/version` - Version and configuration info
- `POST /api/speedtest/start` - Start speed test
- `GET /api/speedtest/status` - Speed test status
- `POST /api/admin/network-id` - Change network ID
- `POST /api/admin/reauthorize` - Reauthorize API access

## Troubleshooting

### Port 5000 in use
If port 5000 is already in use, edit `macos_dashboard.py` and change:
```python
port = 5000  # Change to another port like 5001
```

### Authentication Issues
1. Check your email for verification codes
2. Ensure you're using the correct Eero account
3. Try the staging environment if production fails
4. Use the admin panel to reauthorize

### No Devices Showing
1. Verify your network ID is correct
2. Check that you're connected to the same network
3. Ensure API authentication is working
4. Check logs: `tail -f ~/eero_dashboard/logs/backend.log`

### Dependencies Missing
```bash
pip3 install flask flask-cors requests speedtest-cli
```

## Development

To modify the dashboard:

1. **Backend changes**: Edit `macos_dashboard.py`
2. **Frontend changes**: Edit `frontend/index.html`
3. **Restart**: Stop (Ctrl+C) and restart the dashboard

## Security Notes

- API tokens are stored with restricted permissions (600)
- Configuration files are protected
- No external network access required except to Eero API
- Runs on localhost only by default

## Differences from Raspberry Pi Version

- **Port**: Uses 5000 instead of 80 (no sudo required)
- **Paths**: Uses `~/eero_dashboard` instead of `/home/eero/dashboard`
- **Services**: No systemd service (manual start/stop)
- **Kiosk**: No automatic kiosk mode setup
- **Updates**: Manual update process

## Support

For issues or questions:
1. Check the logs: `~/eero_dashboard/logs/backend.log`
2. Verify configuration: `~/eero_dashboard/.config.json`
3. Test API connectivity through admin panel
4. Ensure all dependencies are installed

## License

MIT License - Same as original MiniRack Dashboard project.