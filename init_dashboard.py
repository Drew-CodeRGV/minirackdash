#!/usr/bin/env python3
"""
Eero Dashboard Initialization Script
Repository: https://github.com/eero-drew/minirackdash
Author: Drew
License: MIT

This script sets up the complete Eero Network Dashboard on a fresh Raspberry Pi.
It includes auto-update functionality and creates all necessary files and configurations.

Usage:
    wget https://raw.githubusercontent.com/eero-drew/minirackdash/main/init_dashboard.py
    sudo python3 init_dashboard.py
"""

import os
import sys
import subprocess
import urllib.request
import json
import re
import shutil
from pathlib import Path

# ============================================================================
# VERSION INFORMATION
# ============================================================================
SCRIPT_VERSION = "1.0.0"
GITHUB_REPO = "eero-drew/minirackdash"
GITHUB_RAW = f"https://raw.githubusercontent.com/{GITHUB_REPO}/main"
SCRIPT_URL = f"{GITHUB_RAW}/init_dashboard.py"

# ============================================================================
# CONFIGURATION
# ============================================================================
INSTALL_DIR = "/home/eero/dashboard"
NETWORK_ID = "18073602"
USER = "eero"

# ============================================================================
# COLOR CODES FOR OUTPUT
# ============================================================================
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color

def print_color(color, message):
    """Print colored message"""
    print(f"{color}{message}{Colors.NC}")

def print_header(message):
    """Print header with formatting"""
    print("\n" + "=" * 60)
    print_color(Colors.BLUE, message.center(60))
    print("=" * 60 + "\n")

def print_success(message):
    """Print success message"""
    print_color(Colors.GREEN, f"✓ {message}")

def print_error(message):
    """Print error message"""
    print_color(Colors.RED, f"✗ {message}")

def print_warning(message):
    """Print warning message"""
    print_color(Colors.YELLOW, f"⚠ {message}")

def print_info(message):
    """Print info message"""
    print_color(Colors.CYAN, f"ℹ {message}")

# ============================================================================
# VERSION CHECKING AND AUTO-UPDATE
# ============================================================================
def extract_version_from_script(script_content):
    """Extract version from script content"""
    match = re.search(r'SCRIPT_VERSION\s*=\s*["\']([^"\']+)["\']', script_content)
    if match:
        return match.group(1)
    return None

def compare_versions(v1, v2):
    """Compare two version strings. Returns 1 if v1 > v2, -1 if v1 < v2, 0 if equal"""
    parts1 = [int(x) for x in v1.split('.')]
    parts2 = [int(x) for x in v2.split('.')]
    
    for i in range(max(len(parts1), len(parts2))):
        p1 = parts1[i] if i < len(parts1) else 0
        p2 = parts2[i] if i < len(parts2) else 0
        
        if p1 > p2:
            return 1
        elif p1 < p2:
            return -1
    return 0

def check_for_updates():
    """Check for script updates on GitHub"""
    print_header("Version Check")
    print_info(f"Current Version: v{SCRIPT_VERSION}")
    print_info("Checking for updates from GitHub...")
    
    try:
        # Download the latest script
        with urllib.request.urlopen(SCRIPT_URL, timeout=10) as response:
            latest_script = response.read().decode('utf-8')
        
        latest_version = extract_version_from_script(latest_script)
        
        if not latest_version:
            print_warning("Could not determine latest version. Continuing...")
            return False
        
        print_info(f"Latest Version: v{latest_version}")
        
        comparison = compare_versions(latest_version, SCRIPT_VERSION)
        
        if comparison == 0:
            print_success("You are running the latest version!")
            return False
        elif comparison > 0:
            print_warning(f"New version available: v{latest_version}")
            print_info("Downloading and installing update...")
            
            # Get the current script path
            current_script = os.path.abspath(__file__)
            backup_script = f"{current_script}.backup"
            
            # Backup current script
            shutil.copy2(current_script, backup_script)
            
            # Write new script
            with open(current_script, 'w') as f:
                f.write(latest_script)
            
            os.chmod(current_script, 0o755)
            
            print_success("Script updated successfully!")
            print_info("Restarting with new version...")
            
            # Re-execute with same arguments
            os.execv(sys.executable, [sys.executable, current_script] + sys.argv[1:])
        else:
            print_warning("You are running a newer version than available online")
            print_info("This might be a development version")
            return False
            
    except Exception as e:
        print_warning(f"Could not check for updates: {e}")
        print_info("Continuing with current version...")
        return False

# ============================================================================
# SYSTEM CHECKS
# ============================================================================
def check_root():
    """Check if script is running as root"""
    if os.geteuid() != 0:
        print_error("This script must be run as root (use sudo)")
        sys.exit(1)

def run_command(command, shell=True, check=True):
    """Run a shell command"""
    try:
        result = subprocess.run(
            command,
            shell=shell,
            check=check,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return result.returncode == 0
    except subprocess.CalledProcessError as e:
        print_error(f"Command failed: {command}")
        print_error(f"Error: {e.stderr}")
        return False

# ============================================================================
# FILE TEMPLATES
# ============================================================================

BACKEND_API_TEMPLATE = '''#!/usr/bin/env python3
import os
import json
import time
import requests
from datetime import datetime, timedelta
from flask import Flask, jsonify
from flask_cors import CORS
import logging

app = Flask(__name__)
CORS(app)

# Configure logging
logging.basicConfig(
    filename='/home/eero/dashboard/logs/backend.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

# Configuration
NETWORK_ID = "{network_id}"
EERO_API_BASE = "https://api-user.e2ro.com/2.2"
SESSION_COOKIE_FILE = "/home/eero/dashboard/.eero_session"

class EeroAPI:
    def __init__(self):
        self.session = requests.Session()
        self.session_cookie = self.load_session()
        
    def load_session(self):
        """Load session cookie from file"""
        try:
            if os.path.exists(SESSION_COOKIE_FILE):
                with open(SESSION_COOKIE_FILE, 'r') as f:
                    return f.read().strip()
        except Exception as e:
            logging.error(f"Error loading session: {{e}}")
        return None
    
    def save_session(self, cookie):
        """Save session cookie to file"""
        try:
            with open(SESSION_COOKIE_FILE, 'w') as f:
                f.write(cookie)
            os.chmod(SESSION_COOKIE_FILE, 0o600)
        except Exception as e:
            logging.error(f"Error saving session: {{e}}")
    
    def get_headers(self):
        """Get headers for API requests"""
        headers = {{
            'Content-Type': 'application/json',
            'User-Agent': 'Eero-Dashboard/1.0'
        }}
        if self.session_cookie:
            headers['Cookie'] = f's={{self.session_cookie}}'
        return headers
    
    def get_network_data(self):
        """Get network overview data"""
        try:
            url = f"{{EERO_API_BASE}}/networks/{{NETWORK_ID}}"
            response = self.session.get(url, headers=self.get_headers(), timeout=10)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logging.error(f"Error fetching network data: {{e}}")
            return None
    
    def get_devices(self):
        """Get all devices on the network"""
        try:
            url = f"{{EERO_API_BASE}}/networks/{{NETWORK_ID}}/devices"
            response = self.session.get(url, headers=self.get_headers(), timeout=10)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logging.error(f"Error fetching devices: {{e}}")
            return None
    
    def get_bandwidth_usage(self):
        """Get bandwidth usage data"""
        try:
            url = f"{{EERO_API_BASE}}/networks/{{NETWORK_ID}}/insights/usage"
            response = self.session.get(url, headers=self.get_headers(), timeout=10)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logging.error(f"Error fetching bandwidth: {{e}}")
            return None

# Initialize API
eero_api = EeroAPI()

# Data cache
data_cache = {{
    'connected_users': [],
    'wifi_versions': {{}},
    'bandwidth': [],
    'last_update': None
}}

def update_cache():
    """Update cached data"""
    global data_cache
    
    try:
        # Get connected devices
        devices_data = eero_api.get_devices()
        if devices_data:
            connected = [d for d in devices_data.get('data', []) if d.get('connected')]
            
            # Count connected users
            current_time = datetime.now()
            data_cache['connected_users'].append({{
                'timestamp': current_time.isoformat(),
                'count': len(connected)
            }})
            
            # Keep only last 2 hours of data
            two_hours_ago = current_time - timedelta(hours=2)
            data_cache['connected_users'] = [
                entry for entry in data_cache['connected_users']
                if datetime.fromisoformat(entry['timestamp']) > two_hours_ago
            ]
            
            # Count WiFi versions
            wifi_versions = {{}}
            for device in connected:
                wifi_std = device.get('connection', {{}}).get('wifi_standard', 'Unknown')
                wifi_label = f"WiFi {{wifi_std[-1]}}" if wifi_std != 'Unknown' else 'Unknown'
                wifi_versions[wifi_label] = wifi_versions.get(wifi_label, 0) + 1
            
            data_cache['wifi_versions'] = wifi_versions
        
        # Get bandwidth data
        bandwidth_data = eero_api.get_bandwidth_usage()
        if bandwidth_data:
            current_time = datetime.now()
            usage = bandwidth_data.get('data', {{}})
            
            data_cache['bandwidth'].append({{
                'timestamp': current_time.isoformat(),
                'download': usage.get('download', 0) / 1024 / 1024,  # Convert to MB
                'upload': usage.get('upload', 0) / 1024 / 1024
            }})
            
            # Keep only last 2 hours
            two_hours_ago = current_time - timedelta(hours=2)
            data_cache['bandwidth'] = [
                entry for entry in data_cache['bandwidth']
                if datetime.fromisoformat(entry['timestamp']) > two_hours_ago
            ]
        
        data_cache['last_update'] = datetime.now().isoformat()
        logging.info("Cache updated successfully")
        
    except Exception as e:
        logging.error(f"Error updating cache: {{e}}")

@app.route('/api/dashboard')
def get_dashboard_data():
    """API endpoint to get all dashboard data"""
    update_cache()
    return jsonify(data_cache)

@app.route('/api/health')
def health_check():
    """Health check endpoint"""
    return jsonify({{'status': 'ok', 'timestamp': datetime.now().isoformat()}})

@app.route('/api/version')
def get_version():
    """Get version information"""
    return jsonify({{
        'version': '{version}',
        'name': 'Eero Dashboard',
        'repository': 'https://github.com/{repo}'
    }})

if __name__ == '__main__':
    # Initial cache update
    update_cache()
    
    # Run Flask app
    app.run(host='127.0.0.1', port=5000, debug=False)
'''

FRONTEND_HTML_TEMPLATE = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Eero Network Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}

        body {{
            background: linear-gradient(135deg, #001a33 0%, #003366 100%);
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            color: #ffffff;
            overflow: hidden;
            height: 100vh;
        }}

        .version-badge {{
            position: fixed;
            top: 10px;
            left: 10px;
            padding: 8px 15px;
            background: rgba(0, 0, 0, 0.5);
            border-radius: 20px;
            font-size: 12px;
            z-index: 1000;
        }}

        .dashboard-container {{
            display: grid;
            grid-template-columns: 1fr 1fr;
            grid-template-rows: 1fr 1fr;
            gap: 20px;
            padding: 20px;
            height: 100vh;
            padding-top: 50px;
        }}

        .chart-card {{
            background: rgba(0, 40, 80, 0.7);
            border-radius: 15px;
            padding: 20px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(255, 255, 255, 0.1);
            display: flex;
            flex-direction: column;
        }}

        .chart-title {{
            font-size: 24px;
            font-weight: 600;
            margin-bottom: 15px;
            text-align: center;
            color: #4da6ff;
            text-transform: uppercase;
            letter-spacing: 1px;
        }}

        .chart-container {{
            flex: 1;
            position: relative;
            min-height: 0;
        }}

        canvas {{
            max-width: 100%;
            max-height: 100%;
        }}

        .status-indicator {{
            position: fixed;
            top: 10px;
            right: 10px;
            padding: 8px 15px;
            background: rgba(0, 0, 0, 0.5);
            border-radius: 20px;
            font-size: 12px;
            display: flex;
            align-items: center;
            gap: 8px;
            z-index: 1000;
        }}

        .status-dot {{
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: #4CAF50;
            animation: pulse 2s infinite;
        }}

        @keyframes pulse {{
            0%, 100% {{ opacity: 1; }}
            50% {{ opacity: 0.5; }}
        }}
    </style>
</head>
<body>
    <div class="version-badge">
        <span id="versionInfo">Loading...</span>
    </div>

    <div class="status-indicator">
        <div class="status-dot"></div>
        <span id="lastUpdate">Loading...</span>
    </div>

    <div class="dashboard-container">
        <div class="chart-card">
            <div class="chart-title">Connected Users</div>
            <div class="chart-container">
                <canvas id="usersChart"></canvas>
            </div>
        </div>

        <div class="chart-card">
            <div class="chart-title">WiFi Version Distribution</div>
            <div class="chart-container">
                <canvas id="wifiChart"></canvas>
            </div>
        </div>

        <div class="chart-card">
            <div class="chart-title">Download Bandwidth</div>
            <div class="chart-container">
                <canvas id="downloadChart"></canvas>
            </div>
        </div>

        <div class="chart-card">
            <div class="chart-title">Upload Bandwidth</div>
            <div class="chart-container">
                <canvas id="uploadChart"></canvas>
            </div>
        </div>
    </div>

    <script>
        let charts = {{
            users: null,
            wifi: null,
            download: null,
            upload: null
        }};

        const chartColors = {{
            primary: '#4da6ff',
            secondary: '#ff6b6b',
            success: '#51cf66',
            warning: '#ffd43b',
            info: '#74c0fc'
        }};

        const commonOptions = {{
            responsive: true,
            maintainAspectRatio: false,
            plugins: {{
                legend: {{
                    labels: {{
                        color: '#ffffff',
                        font: {{ size: 14 }}
                    }}
                }}
            }},
            scales: {{
                y: {{
                    ticks: {{ color: '#ffffff' }},
                    grid: {{ color: 'rgba(255, 255, 255, 0.1)' }}
                }},
                x: {{
                    ticks: {{ color: '#ffffff' }},
                    grid: {{ color: 'rgba(255, 255, 255, 0.1)' }}
                }}
            }}
        }};

        async function fetchVersion() {{
            try {{
                const response = await fetch('/api/version');
                const data = await response.json();
                document.getElementById('versionInfo').textContent = 
                    `v${{data.version}} - ${{data.name}}`;
            }} catch (error) {{
                console.error('Error fetching version:', error);
            }}
        }}

        function initCharts() {{
            const usersCtx = document.getElementById('usersChart').getContext('2d');
            charts.users = new Chart(usersCtx, {{
                type: 'line',
                data: {{
                    labels: [],
                    datasets: [{{
                        label: 'Connected Users',
                        data: [],
                        borderColor: chartColors.primary,
                        backgroundColor: 'rgba(77, 166, 255, 0.1)',
                        tension: 0.4,
                        fill: true,
                        borderWidth: 3
                    }}]
                }},
                options: commonOptions
            }});

            const wifiCtx = document.getElementById('wifiChart').getContext('2d');
            charts.wifi = new Chart(wifiCtx, {{
                type: 'doughnut',
                data: {{
                    labels: [],
                    datasets: [{{
                        data: [],
                        backgroundColor: [
                            chartColors.primary,
                            chartColors.success,
                            chartColors.warning,
                            chartColors.secondary,
                            chartColors.info
                        ],
                        borderWidth: 2,
                        borderColor: '#001a33'
                    }}]
                }},
                options: {{
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {{
                        legend: {{
                            position: 'right',
                            labels: {{
                                color: '#ffffff',
                                font: {{ size: 16 }},
                                padding: 15
                            }}
                        }}
                    }}
                }}
            }});

            const downloadCtx = document.getElementById('downloadChart').getContext('2d');
            charts.download = new Chart(downloadCtx, {{
                type: 'line',
                data: {{
                    labels: [],
                    datasets: [{{
                        label: 'Download (Mbps)',
                        data: [],
                        borderColor: chartColors.success,
                        backgroundColor: 'rgba(81, 207, 102, 0.1)',
                        tension: 0.4,
                        fill: true,
                        borderWidth: 3
                    }}]
                }},
                options: commonOptions
            }});

            const uploadCtx = document.getElementById('uploadChart').getContext('2d');
            charts.upload = new Chart(uploadCtx, {{
                type: 'line',
                data: {{
                    labels: [],
                    datasets: [{{
                        label: 'Upload (Mbps)',
                        data: [],
                        borderColor: chartColors.secondary,
                        backgroundColor: 'rgba(255, 107, 107, 0.1)',
                        tension: 0.4,
                        fill: true,
                        borderWidth: 3
                    }}]
                }},
                options: commonOptions
            }});
        }}

        async function updateDashboard() {{
            try {{
                const response = await fetch('/api/dashboard');
                const data = await response.json();

                const userLabels = data.connected_users.map(entry => {{
                    const date = new Date(entry.timestamp);
                    return date.toLocaleTimeString();
                }});
                const userCounts = data.connected_users.map(entry => entry.count);

                charts.users.data.labels = userLabels;
                charts.users.data.datasets[0].data = userCounts;
                charts.users.update();

                const wifiLabels = Object.keys(data.wifi_versions);
                const wifiData = Object.values(data.wifi_versions);

                charts.wifi.data.labels = wifiLabels;
                charts.wifi.data.datasets[0].data = wifiData;
                charts.wifi.update();

                const bandwidthLabels = data.bandwidth.map(entry => {{
                    const date = new Date(entry.timestamp);
                    return date.toLocaleTimeString();
                }});
                const downloadData = data.bandwidth.map(entry => entry.download);
                const uploadData = data.bandwidth.map(entry => entry.upload);

                charts.download.data.labels = bandwidthLabels;
                charts.download.data.datasets[0].data = downloadData;
                charts.download.update();

                charts.upload.data.labels = bandwidthLabels;
                charts.upload.data.datasets[0].data = uploadData;
                charts.upload.update();

                const lastUpdate = new Date(data.last_update);
                document.getElementById('lastUpdate').textContent = 
                    `Last updated: ${{lastUpdate.toLocaleTimeString()}}`;

            }} catch (error) {{
                console.error('Error updating dashboard:', error);
            }}
        }}

        window.addEventListener('load', () => {{
            fetchVersion();
            initCharts();
            updateDashboard();
            setInterval(updateDashboard, 60000);
        }});
    </script>
</body>
</html>
'''

NGINX_CONFIG_TEMPLATE = '''server {{
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    root /home/eero/dashboard/frontend;
    index index.html;

    location / {{
        try_files $uri $uri/ =404;
    }}

    location /api/ {{
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }}

    access_log /home/eero/dashboard/logs/nginx_access.log;
    error_log /home/eero/dashboard/logs/nginx_error.log;
}}
'''

SYSTEMD_SERVICE_TEMPLATE = '''[Unit]
Description=Eero Dashboard Backend
After=network.target

[Service]
Type=simple
User={user}
WorkingDirectory={install_dir}/backend
Environment="PATH={install_dir}/venv/bin"
ExecStart={install_dir}/venv/bin/gunicorn -w 2 -b 127.0.0.1:5000 eero_api:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
'''

KIOSK_SCRIPT_TEMPLATE = '''#!/bin/bash
# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Hide cursor
unclutter -idle 0.1 &

# Start chromium in kiosk mode
chromium-browser \\
    --kiosk \\
    --noerrdialogs \\
    --disable-infobars \\
    --no-first-run \\
    --fast \\
    --fast-start \\
    --disable-features=TranslateUI \\
    --disk-cache-dir=/dev/null \\
    --password-store=basic \\
    http://localhost
'''

AUTH_HELPER_TEMPLATE = '''#!/usr/bin/env python3
import requests
import json

def authenticate_eero():
    """Helper script to authenticate with Eero API"""
    print("=" * 50)
    print("Eero API Authentication Setup")
    print("=" * 50)
    print()
    
    phone_or_email = input("Enter your Eero account (phone or email): ")
    
    # Request login
    url = "https://api-user.e2ro.com/2.2/login"
    payload = {{"login": phone_or_email}}
    
    try:
        response = requests.post(url, json=payload)
        response.raise_for_status()
        
        print("\\n✓ Verification code sent to your phone/email!")
        code = input("Enter the verification code: ")
        
        # Verify code
        verify_url = "https://api-user.e2ro.com/2.2/login/verify"
        verify_payload = {{"code": code}}
        
        verify_response = requests.post(verify_url, json=verify_payload)
        verify_response.raise_for_status()
        
        # Extract session cookie
        session_cookie = verify_response.cookies.get('s')
        
        if session_cookie:
            # Save session
            with open('/home/eero/dashboard/.eero_session', 'w') as f:
                f.write(session_cookie)
            print("\\n✓ Authentication successful! Session saved.")
        else:
            print("\\n✗ Failed to get session cookie.")
            
    except Exception as e:
        print(f"\\n✗ Error: {{e}}")

if __name__ == "__main__":
    authenticate_eero()
'''

DESKTOP_AUTOSTART_TEMPLATE = '''[Desktop Entry]
Type=Application
Name=Eero Dashboard
Exec={install_dir}/start_kiosk.sh
X-GNOME-Autostart-enabled=true
'''

README_TEMPLATE = '''# Eero Network Dashboard

## Installation Complete!

Version: v{version}
Repository: https://github.com/{repo}

### Next Steps:

1. **Authenticate with Eero API:**
   ```bash
   sudo -u eero {install_dir}/venv/bin/python3 {install_dir}/setup_eero_auth.py
