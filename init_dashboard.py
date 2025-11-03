#!/usr/bin/env python3
import os
import sys
import subprocess
import urllib.request
import re
import shutil
from pathlib import Path

SCRIPT_VERSION = "1.1.2"
GITHUB_REPO = "eero-drew/minirackdash"
GITHUB_RAW = f"https://raw.githubusercontent.com/{GITHUB_REPO}/main"
SCRIPT_URL = f"{GITHUB_RAW}/init_dashboard.py"
INSTALL_DIR = "/home/eero/dashboard"
NETWORK_ID = "18073602"
USER = "eero"

class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'

def print_color(color, message):
    print(f"{color}{message}{Colors.NC}")

def print_header(message):
    print("\n" + "=" * 60)
    print_color(Colors.BLUE, message.center(60))
    print("=" * 60 + "\n")

def print_success(message):
    print_color(Colors.GREEN, f"✓ {message}")

def print_error(message):
    print_color(Colors.RED, f"✗ {message}")

def print_warning(message):
    print_color(Colors.YELLOW, f"⚠ {message}")

def print_info(message):
    print_color(Colors.CYAN, f"ℹ {message}")

def extract_version_from_script(script_content):
    match = re.search(r'SCRIPT_VERSION\s*=\s*["\']([^"\']+)["\']', script_content)
    if match:
        return match.group(1)
    return None

def compare_versions(v1, v2):
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
    print_header("Version Check")
    print_info(f"Current Version: v{SCRIPT_VERSION}")
    print_info("Checking for updates from GitHub...")
    try:
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
            current_script = os.path.abspath(__file__)
            backup_script = f"{current_script}.backup"
            shutil.copy2(current_script, backup_script)
            with open(current_script, 'w') as f:
                f.write(latest_script)
            os.chmod(current_script, 0o755)
            print_success("Script updated successfully!")
            print_info("Restarting with new version...")
            os.execv(sys.executable, [sys.executable, current_script] + sys.argv[1:])
        else:
            print_warning("You are running a newer version than available online")
            return False
    except Exception as e:
        print_warning(f"Could not check for updates: {e}")
        print_info("Continuing with current version...")
        return False

def check_root():
    if os.geteuid() != 0:
        print_error("This script must be run as root (use sudo)")
        sys.exit(1)

def run_command(command, shell=True, check=True, timeout=300, show_output=False):
    try:
        if show_output:
            result = subprocess.run(command, shell=shell, check=check, timeout=timeout)
            return result.returncode == 0
        else:
            result = subprocess.run(command, shell=shell, check=check, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout)
            return result.returncode == 0
    except subprocess.TimeoutExpired:
        print_error(f"Command timed out after {timeout}s")
        return False
    except subprocess.CalledProcessError as e:
        if show_output:
            return False
        print_error(f"Command failed with exit code {e.returncode}")
        if e.stderr:
            print_error(f"Error output: {e.stderr[:200]}")
        return False

def create_user():
    print_info("Setting up user account...")
    result = subprocess.run(['id', USER], capture_output=True, text=True)
    if result.returncode != 0:
        if run_command(f'useradd -m -s /bin/bash {USER}'):
            print_success(f"Created user: {USER}")
    else:
        print_success(f"User already exists: {USER}")

def update_system():
    print_header("Updating System Packages")
    print_info("Updating package lists...")
    if run_command('apt-get update', timeout=120, show_output=True):
        print_success("Package lists updated")
    else:
        print_warning("Package list update had issues, continuing...")
    
    print_info("Upgrading packages (this may take several minutes)...")
    upgrade_cmd = 'DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"'
    if run_command(upgrade_cmd, timeout=600, show_output=True):
        print_success("System packages upgraded")
    else:
        print_warning("Package upgrade had issues, continuing with installation...")

def install_dependencies():
    print_header("Installing Dependencies")
    
    required_packages = [
        'python3',
        'python3-pip',
        'python3-venv',
        'nginx',
        'git',
        'curl'
    ]
    
    optional_packages = [
        ('chromium-browser', 'chromium'),
        ('unclutter', None),
        ('x11-xserver-utils', None),
        ('xdotool', None)
    ]
    
    print_info(f"Installing {len(required_packages)} required packages...")
    cmd = f"DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' {' '.join(required_packages)}"
    if not run_command(cmd, timeout=600, show_output=True):
        print_error("Failed to install required dependencies")
        sys.exit(1)
    print_success("Required packages installed")
    
    print_info("Installing optional packages for kiosk mode...")
    for primary, alternative in optional_packages:
        if run_command(f"DEBIAN_FRONTEND=noninteractive apt-get install -y {primary}", timeout=300):
            print_success(f"Installed {primary}")
        elif alternative:
            print_warning(f"{primary} not available, trying {alternative}...")
            if run_command(f"DEBIAN_FRONTEND=noninteractive apt-get install -y {alternative}", timeout=300):
                print_success(f"Installed {alternative}")
            else:
                print_warning(f"Could not install {primary} or {alternative}")
        else:
            print_warning(f"Could not install {primary} (optional)")
    
    print_success("All dependencies processed")

def create_directory_structure():
    print_info("Creating directory structure...")
    for directory in [f"{INSTALL_DIR}/backend", f"{INSTALL_DIR}/frontend", f"{INSTALL_DIR}/logs"]:
        Path(directory).mkdir(parents=True, exist_ok=True)
    run_command(f'chown -R {USER}:{USER} /home/eero')
    print_success("Directory structure created")

def setup_python_environment():
    print_info("Setting up Python virtual environment...")
    venv_path = f"{INSTALL_DIR}/venv"
    if not run_command(f'sudo -u {USER} python3 -m venv {venv_path}', timeout=120):
        print_error("Failed to create virtual environment")
        sys.exit(1)
    print_success("Virtual environment created")
    print_info("Installing Python packages (this may take a few minutes)...")
    run_command(f'sudo -u {USER} {venv_path}/bin/pip install --quiet --upgrade pip', timeout=120)
    if run_command(f'sudo -u {USER} {venv_path}/bin/pip install --quiet flask flask-cors requests gunicorn', timeout=300):
        print_success("Python packages installed")
    else:
        print_error("Failed to install Python packages")
        sys.exit(1)

def create_backend_api():
    print_info("Creating backend API...")
    content = f"""#!/usr/bin/env python3
import os
import requests
from datetime import datetime, timedelta
from flask import Flask, jsonify
from flask_cors import CORS
import logging

app = Flask(__name__)
CORS(app)

logging.basicConfig(filename='/home/eero/dashboard/logs/backend.log', level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

NETWORK_ID = "{NETWORK_ID}"
EERO_API_BASE = "https://api-user.e2ro.com/2.2"
TOKEN_FILE = "/home/eero/dashboard/.eero_token"

class EeroAPI:
    def __init__(self):
        self.session = requests.Session()
        self.user_token = self.load_token()
    
    def load_token(self):
        try:
            if os.path.exists(TOKEN_FILE):
                with open(TOKEN_FILE, 'r') as f:
                    return f.read().strip()
        except Exception as e:
            logging.error(f"Error loading token: {{e}}")
        return None
    
    def get_headers(self):
        headers = {{
            'Content-Type': 'application/json',
            'User-Agent': 'Eero-Dashboard/1.0'
        }}
        if self.user_token:
            headers['X-User-Token'] = self.user_token
        return headers
    
    def get_devices(self):
        try:
            url = f"{{EERO_API_BASE}}/networks/{{NETWORK_ID}}/devices"
            response = self.session.get(url, headers=self.get_headers(), timeout=10)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logging.error(f"Error fetching devices: {{e}}")
            return None
    
    def get_bandwidth_usage(self):
        try:
            url = f"{{EERO_API_BASE}}/networks/{{NETWORK_ID}}/insights/usage"
            response = self.session.get(url, headers=self.get_headers(), timeout=10)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logging.error(f"Error fetching bandwidth: {{e}}")
            return None

eero_api = EeroAPI()
data_cache = {{'connected_users': [], 'wifi_versions': {{}}, 'bandwidth': [], 'last_update': None}}

def update_cache():
    global data_cache
    try:
        devices_data = eero_api.get_devices()
        if devices_data:
            connected = [d for d in devices_data.get('data', []) if d.get('connected')]
            current_time = datetime.now()
            data_cache['connected_users'].append({{'timestamp': current_time.isoformat(), 'count': len(connected)}})
            two_hours_ago = current_time - timedelta(hours=2)
            data_cache['connected_users'] = [entry for entry in data_cache['connected_users'] if datetime.fromisoformat(entry['timestamp']) > two_hours_ago]
            wifi_versions = {{}}
            for device in connected:
                wifi_std = device.get('connection', {{}}).get('wifi_standard', 'Unknown')
                wifi_label = f"WiFi {{wifi_std[-1]}}" if wifi_std != 'Unknown' else 'Unknown'
                wifi_versions[wifi_label] = wifi_versions.get(wifi_label, 0) + 1
            data_cache['wifi_versions'] = wifi_versions
        bandwidth_data = eero_api.get_bandwidth_usage()
        if bandwidth_data:
            current_time = datetime.now()
            usage = bandwidth_data.get('data', {{}})
            data_cache['bandwidth'].append({{'timestamp': current_time.isoformat(), 'download': usage.get('download', 0) / 1024 / 1024, 'upload': usage.get('upload', 0) / 1024 / 1024}})
            two_hours_ago = current_time - timedelta(hours=2)
            data_cache['bandwidth'] = [entry for entry in data_cache['bandwidth'] if datetime.fromisoformat(entry['timestamp']) > two_hours_ago]
        data_cache['last_update'] = datetime.now().isoformat()
        logging.info("Cache updated successfully")
    except Exception as e:
        logging.error(f"Error updating cache: {{e}}")

@app.route('/api/dashboard')
def get_dashboard_data():
    update_cache()
    return jsonify(data_cache)

@app.route('/api/health')
def health_check():
    return jsonify({{'status': 'ok', 'timestamp': datetime.now().isoformat()}})

@app.route('/api/version')
def get_version():
    return jsonify({{'version': '{SCRIPT_VERSION}', 'name': 'Eero Dashboard', 'repository': 'https://github.com/{GITHUB_REPO}'}})

if __name__ == '__main__':
    update_cache()
    app.run(host='127.0.0.1', port=5000, debug=False)
"""
    with open(f"{INSTALL_DIR}/backend/eero_api.py", 'w') as f:
        f.write(content)
    os.chmod(f"{INSTALL_DIR}/backend/eero_api.py", 0o755)
    run_command(f'chown {USER}:{USER} {INSTALL_DIR}/backend/eero_api.py')
    print_success("Backend API created")

def create_frontend():
    print_info("Creating frontend dashboard...")
    content = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Eero Network Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            background: linear-gradient(135deg, #001a33 0%, #003366 100%); 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            color: #ffffff; 
            overflow: hidden; 
            height: 400px;
            width: 1280px;
        }
        .version-badge { 
            position: fixed; 
            top: 5px; 
            left: 5px; 
            padding: 4px 10px; 
            background: rgba(0, 0, 0, 0.5); 
            border-radius: 12px; 
            font-size: 10px; 
            z-index: 1000; 
        }
        .status-indicator { 
            position: fixed; 
            top: 5px; 
            right: 5px; 
            padding: 4px 10px; 
            background: rgba(0, 0, 0, 0.5); 
            border-radius: 12px; 
            font-size: 10px; 
            display: flex; 
            align-items: center; 
            gap: 6px; 
            z-index: 1000; 
        }
        .status-dot { 
            width: 8px; 
            height: 8px; 
            border-radius: 50%; 
            background: #4CAF50; 
            animation: pulse 2s infinite; 
        }
        @keyframes pulse { 
            0%, 100% { opacity: 1; } 
            50% { opacity: 0.5; } 
        }
        .dashboard-container { 
            display: grid; 
            grid-template-columns: 1fr 1fr 1fr 1fr; 
            grid-template-rows: 1fr; 
            gap: 10px; 
            padding: 10px; 
            height: 400px; 
            padding-top: 30px;
            width: 1280px;
        }
        .chart-card { 
            background: rgba(0, 40, 80, 0.7); 
            border-radius: 10px; 
            padding: 10px; 
            box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3); 
            border: 1px solid rgba(255, 255, 255, 0.1); 
            display: flex; 
            flex-direction: column;
            min-width: 0;
        }
        .chart-title { 
            font-size: 14px; 
            font-weight: 600; 
            margin-bottom: 8px; 
            text-align: center; 
            color: #4da6ff; 
            text-transform: uppercase; 
            letter-spacing: 0.5px; 
        }
        .chart-container { 
            flex: 1; 
            position: relative; 
            min-height: 0;
            min-width: 0;
        }
        canvas { 
            max-width: 100%; 
            max-height: 100%; 
        }
    </style>
</head>
<body>
    <div class="version-badge"><span id="versionInfo">Loading...</span></div>
    <div class="status-indicator"><div class="status-dot"></div><span id="lastUpdate">Loading...</span></div>
    <div class="dashboard-container">
        <div class="chart-card">
            <div class="chart-title">Connected Users</div>
            <div class="chart-container"><canvas id="usersChart"></canvas></div>
        </div>
        <div class="chart-card">
            <div class="chart-title">WiFi Distribution</div>
            <div class="chart-container"><canvas id="wifiChart"></canvas></div>
        </div>
        <div class="chart-card">
            <div class="chart-title">Download (Mbps)</div>
            <div class="chart-container"><canvas id="downloadChart"></canvas></div>
        </div>
        <div class="chart-card">
            <div class="chart-title">Upload (Mbps)</div>
            <div class="chart-container"><canvas id="uploadChart"></canvas></div>
        </div>
    </div>
    <script>
        let charts = { users: null, wifi: null, download: null, upload: null };
        const chartColors = { primary: '#4da6ff', secondary: '#ff6b6b', success: '#51cf66', warning: '#ffd43b', info: '#74c0fc' };
        const commonOptions = { 
            responsive: true, 
            maintainAspectRatio: false, 
            plugins: { 
                legend: { 
                    display: false
                } 
            }, 
            scales: { 
                y: { 
                    ticks: { 
                        color: '#ffffff',
                        font: { size: 10 }
                    }, 
                    grid: { 
                        color: 'rgba(255, 255, 255, 0.1)' 
                    } 
                }, 
                x: { 
                    ticks: { 
                        color: '#ffffff',
                        font: { size: 9 },
                        maxRotation: 0,
                        autoSkip: true,
                        maxTicksLimit: 6
                    }, 
                    grid: { 
                        color: 'rgba(255, 255, 255, 0.1)' 
                    } 
                } 
            } 
        };
        
        async function fetchVersion() { 
            try { 
                const response = await fetch('/api/version'); 
                const data = await response.json(); 
                document.getElementById('versionInfo').textContent = `v${data.version}`; 
            } catch (error) { 
                console.error('Error fetching version:', error); 
            } 
        }
        
        function initCharts() {
            const usersCtx = document.getElementById('usersChart').getContext('2d');
            charts.users = new Chart(usersCtx, { 
                type: 'line', 
                data: { 
                    labels: [], 
                    datasets: [{ 
                        label: 'Users', 
                        data: [], 
                        borderColor: chartColors.primary, 
                        backgroundColor: 'rgba(77, 166, 255, 0.1)', 
                        tension: 0.4, 
                        fill: true, 
                        borderWidth: 2,
                        pointRadius: 2
                    }] 
                }, 
                options: commonOptions 
            });
            
            const wifiCtx = document.getElementById('wifiChart').getContext('2d');
            charts.wifi = new Chart(wifiCtx, { 
                type: 'doughnut', 
                data: { 
                    labels: [], 
                    datasets: [{ 
                        data: [], 
                        backgroundColor: [chartColors.primary, chartColors.success, chartColors.warning, chartColors.secondary, chartColors.info], 
                        borderWidth: 2, 
                        borderColor: '#001a33' 
                    }] 
                }, 
                options: { 
                    responsive: true, 
                    maintainAspectRatio: false, 
                    plugins: { 
                        legend: { 
                            position: 'bottom', 
                            labels: { 
                                color: '#ffffff', 
                                font: { size: 10 }, 
                                padding: 5,
                                boxWidth: 12
                            } 
                        } 
                    } 
                } 
            });
            
            const downloadCtx = document.getElementById('downloadChart').getContext('2d');
            charts.download = new Chart(downloadCtx, { 
                type: 'line', 
                data: { 
                    labels: [], 
                    datasets: [{ 
                        label: 'Download', 
                        data: [], 
                        borderColor: chartColors.success, 
                        backgroundColor: 'rgba(81, 207, 102, 0.1)', 
                        tension: 0.4, 
                        fill: true, 
                        borderWidth: 2,
                        pointRadius: 2
                    }] 
                }, 
                options: commonOptions 
            });
            
            const uploadCtx = document.getElementById('uploadChart').getContext('2d');
            charts.upload = new Chart(uploadCtx, { 
                type: 'line', 
                data: { 
                    labels: [], 
                    datasets: [{ 
                        label: 'Upload', 
                        data: [], 
                        borderColor: chartColors.secondary, 
                        backgroundColor: 'rgba(255, 107, 107, 0.1)', 
                        tension: 0.4, 
                        fill: true, 
                        borderWidth: 2,
                        pointRadius: 2
                    }] 
                }, 
                options: commonOptions 
            });
        }
        
        async function updateDashboard() {
            try {
                const response = await fetch('/api/dashboard');
                const data = await response.json();
                
                const userLabels = data.connected_users.map(entry => { 
                    const date = new Date(entry.timestamp); 
                    return date.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}); 
                });
                const userCounts = data.connected_users.map(entry => entry.count);
                charts.users.data.labels = userLabels;
                charts.users.data.datasets[0].data = userCounts;
                charts.users.update('none');
                
                const wifiLabels = Object.keys(data.wifi_versions);
                const wifiData = Object.values(data.wifi_versions);
                charts.wifi.data.labels = wifiLabels;
                charts.wifi.data.datasets[0].data = wifiData;
                charts.wifi.update('none');
                
                const bandwidthLabels = data.bandwidth.map(entry => { 
                    const date = new Date(entry.timestamp); 
                    return date.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}); 
                });
                const downloadData = data.bandwidth.map(entry => entry.download);
                const uploadData = data.bandwidth.map(entry => entry.upload);
                
                charts.download.data.labels = bandwidthLabels;
                charts.download.data.datasets[0].data = downloadData;
                charts.download.update('none');
                
                charts.upload.data.labels = bandwidthLabels;
                charts.upload.data.datasets[0].data = uploadData;
                charts.upload.update('none');
                
                const lastUpdate = new Date(data.last_update);
                document.getElementById('lastUpdate').textContent = lastUpdate.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
            } catch (error) { 
                console.error('Error updating dashboard:', error); 
            }
        }
        
        window.addEventListener('load', () => { 
            fetchVersion(); 
            initCharts(); 
            updateDashboard(); 
            setInterval(updateDashboard, 60000); 
        });
    </script>
</body>
</html>"""
    
    frontend_path = f"{INSTALL_DIR}/frontend/index.html"
    with open(frontend_path, 'w') as f:
        f.write(content)
    
    # Set proper permissions
    os.chmod(frontend_path, 0o644)
    run_command(f'chown {USER}:{USER} {frontend_path}')
    
    # Verify file was created
    if os.path.exists(frontend_path):
        file_size = os.path.getsize(frontend_path)
        print_success(f"Frontend created: {frontend_path} ({file_size} bytes)")
    else:
        print_error(f"Failed to create: {frontend_path}")
        sys.exit(1)

def configure_nginx():
    print_info("Configuring NGINX...")
    
    # Create the nginx config with explicit string formatting
    nginx_config = """server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    root /home/eero/dashboard/frontend;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /api/ {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    access_log /home/eero/dashboard/logs/nginx_access.log;
    error_log /home/eero/dashboard/logs/nginx_error.log;
}"""
    
    nginx_config_path = '/etc/nginx/sites-available/eero-dashboard'
    
    # Write the config
    with open(nginx_config_path, 'w') as f:
        f.write(nginx_config)
    
    print_info(f"NGINX config written to: {nginx_config_path}")
    
    # Show what was written
    print_info("NGINX config content:")
    with open(nginx_config_path, 'r') as f:
        config_content = f.read()
        for line in config_content.split('\n')[:10]:  # Show first 10 lines
            print(f"  {line}")
    
    # Remove default site
    if os.path.exists('/etc/nginx/sites-enabled/default'):
        os.remove('/etc/nginx/sites-enabled/default')
        print_info("Removed default nginx site")
    
    # Remove old symlink if exists
    if os.path.exists('/etc/nginx/sites-enabled/eero-dashboard'):
        os.remove('/etc/nginx/sites-enabled/eero-dashboard')
    
    # Create new symlink
    os.symlink(nginx_config_path, '/etc/nginx/sites-enabled/eero-dashboard')
    print_success("Created symlink to sites-enabled")
    
    # Verify the symlink
    if os.path.islink('/etc/nginx/sites-enabled/eero-dashboard'):
        link_target = os.readlink('/etc/nginx/sites-enabled/eero-dashboard')
        print_success(f"Symlink verified: -> {link_target}")
    
    # Test nginx configuration
    print_info("Testing nginx configuration...")
    result = subprocess.run(['nginx', '-t'], capture_output=True, text=True)
    print(result.stdout)
    print(result.stderr)
    
    if result.returncode == 0:
        print_success("NGINX configuration is valid")
        run_command('systemctl restart nginx')
        run_command('systemctl enable nginx')
        print_success("NGINX restarted")
        
        # Wait a moment for nginx to start
        import time
        time.sleep(2)
        
        # Verify nginx is running
        if run_command('systemctl is-active --quiet nginx'):
            print_success("NGINX is running")
            
            # Test if we can access the index.html
            print_info("Testing file access...")
            test_result = subprocess.run(['sudo', '-u', 'www-data', 'test', '-r', f'{INSTALL_DIR}/frontend/index.html'], capture_output=True)
            if test_result.returncode == 0:
                print_success("www-data can read index.html")
            else:
                print_warning("www-data cannot read index.html - fixing permissions...")
                run_command(f'chmod 755 {INSTALL_DIR}')
                run_command(f'chmod 755 {INSTALL_DIR}/frontend')
                run_command(f'chmod 644 {INSTALL_DIR}/frontend/index.html')
                
        else:
            print_error("NGINX failed to start")
            run_command('systemctl status nginx', show_output=True)
            sys.exit(1)
    else:
        print_error("NGINX configuration test failed")
        sys.exit(1)

def create_systemd_service():
    print_info("Creating systemd service...")
    content = f"""[Unit]
Description=Eero Dashboard Backend
After=network.target

[Service]
Type=simple
User={USER}
WorkingDirectory={INSTALL_DIR}/backend
Environment="PATH={INSTALL_DIR}/venv/bin"
ExecStart={INSTALL_DIR}/venv/bin/gunicorn -w 2 -b 127.0.0.1:5000 eero_api:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
"""
    with open('/etc/systemd/system/eero-dashboard.service', 'w') as f:
        f.write(content)
    run_command('systemctl daemon-reload')
    run_command('systemctl enable eero-dashboard.service')
    run_command('systemctl start eero-dashboard.service')
    print_success("Systemd service created and started")
    
    # Verify service is running
    import time
    time.sleep(2)
    if run_command('systemctl is-active --quiet eero-dashboard'):
        print_success("Backend service is running")
    else:
        print_warning("Backend service may not be running (expected if not authenticated yet)")

def create_kiosk_mode():
    print_info("Setting up kiosk mode...")
    content = """#!/bin/bash
xset s off 2>/dev/null
xset -dpms 2>/dev/null
xset s noblank 2>/dev/null
unclutter -idle 0.1 2>/dev/null &
if command -v chromium-browser &> /dev/null; then
    BROWSER="chromium-browser"
elif command -v chromium &> /dev/null; then
    BROWSER="chromium"
else
    echo "No chromium browser found"
    exit 1
fi
$BROWSER --kiosk --noerrdialogs --disable-infobars --no-first-run --fast --fast-start --disable-features=TranslateUI --disk-cache-dir=/dev/null --password-store=basic --window-size=1280,400 --window-position=0,0 http://localhost
"""
    with open(f"{INSTALL_DIR}/start_kiosk.sh", 'w') as f:
        f.write(content)
    os.chmod(f"{INSTALL_DIR}/start_kiosk.sh", 0o755)
    run_command(f'chown {USER}:{USER} {INSTALL_DIR}/start_kiosk.sh')
    autostart_dir = f'/home/{USER}/.config/autostart'
    Path(autostart_dir).mkdir(parents=True, exist_ok=True)
    desktop_content = f"""[Desktop Entry]
Type=Application
Name=Eero Dashboard
Exec={INSTALL_DIR}/start_kiosk.sh
X-GNOME-Autostart-enabled=true
"""
    with open(f'{autostart_dir}/dashboard.desktop', 'w') as f:
        f.write(desktop_content)
    run_command(f'chown -R {USER}:{USER} /home/{USER}/.config')
    print_success("Kiosk mode configured for 1280x400 resolution")

def create_auth_helper():
    print_info("Creating authentication helper...")
    content = """#!/usr/bin/env python3
import requests
import os

TOKEN_FILE = "/home/eero/dashboard/.eero_token"

def authenticate_eero():
    print("=" * 60)
    print("Eero API Authentication Setup")
    print("=" * 60)
    print()
    print("This uses the official eero API authentication flow.")
    print("You'll need your API development email address.")
    print()
    
    email = input("Enter your API development email address: ").strip()
    
    print()
    print("Step 1: Generating unverified access token...")
    
    try:
        # Step 1: Generate unverified token
        login_url = "https://api-user.e2ro.com/2.2/pro/login"
        login_payload = {"login": email}
        
        response = requests.post(login_url, json=login_payload, timeout=10)
        response.raise_for_status()
        
        response_data = response.json()
        
        if 'data' not in response_data or 'user_token' not in response_data['data']:
            print("✗ Error: Could not get user token from response")
            print(f"Response: {response_data}")
            return False
        
        unverified_token = response_data['data']['user_token']
        print(f"✓ Unverified token received: {unverified_token[:20]}...")
        print()
        print("Step 2: Check your email for verification code")
        print(f"An email has been sent to {email}")
        print()
        
        # Step 2: Verify with code
        code = input("Enter the verification code from your email: ").strip()
        
        print()
        print("Step 3: Verifying access token...")
        
        verify_url = "https://api-user.e2ro.com/2.2/login/verify"
        verify_headers = {"X-User-Token": unverified_token}
        verify_payload = {"code": code}
        
        verify_response = requests.post(
            verify_url, 
            headers=verify_headers, 
            data=verify_payload,
            timeout=10
        )
        verify_response.raise_for_status()
        
        verify_data = verify_response.json()
        
        if 'data' in verify_data and verify_data['data'].get('email', {}).get('verified'):
            print("✓ Email verified successfully!")
            print()
            
            # Save the verified token
            with open(TOKEN_FILE, 'w') as f:
                f.write(unverified_token)
            
            # Set proper permissions
            os.chmod(TOKEN_FILE, 0o600)
            
            print(f"✓ Token saved to {TOKEN_FILE}")
            print()
            print("=" * 60)
            print("Authentication completed successfully!")
            print("=" * 60)
            print()
            print("Next steps:")
            print("  1. Restart the dashboard: sudo systemctl restart eero-dashboard")
            print("  2. Access your dashboard at: http://localhost")
            print()
            return True
        else:
            print(f"✗ Verification failed: {verify_data}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"✗ Network error: {e}")
        return False
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    # Check if running as eero user
    if os.geteuid() == 0:
        print("⚠ Warning: This script should be run as the 'eero' user, not root")
        print("Please run: sudo -u eero /home/eero/dashboard/venv/bin/python3 /home/eero/dashboard/setup_eero_auth.py")
        print()
        response = input("Continue anyway? (y/N): ").strip().lower()
        if response != 'y':
            return
    
    authenticate_eero()

if __name__ == "__main__":
    main()
"""
    with open(f"{INSTALL_DIR}/setup_eero_auth.py", 'w') as f:
        f.write(content)
    os.chmod(f"{INSTALL_DIR}/setup_eero_auth.py", 0o755)
    run_command(f'chown {USER}:{USER} {INSTALL_DIR}/setup_eero_auth.py')
    print_success("Authentication helper created")

def setup_logs():
    print_info("Configuring logs...")
    for log_file in [f"{INSTALL_DIR}/logs/backend.log", f"{INSTALL_DIR}/logs/nginx_access.log", f"{INSTALL_DIR}/logs/nginx_error.log"]:
        Path(log_file).touch()
    run_command(f'chown -R www-data:www-data {INSTALL_DIR}/logs')
    run_command(f'chmod 755 {INSTALL_DIR}/logs')
    run_command(f'chmod 644 {INSTALL_DIR}/logs/*.log')
    print_success("Logs configured")

def print_completion_message():
    print_header("Installation Complete!")
    print_success(f"Eero Dashboard v{SCRIPT_VERSION} installed")
    print()
    print_info("Dashboard optimized for 1280x400 resolution")
    print()
    print_info("Verification:")
    print(f"  Frontend: ls -la {INSTALL_DIR}/frontend/index.html")
    print(f"  NGINX config: cat /etc/nginx/sites-enabled/eero-dashboard | grep root")
    print(f"  Test URL: curl -I http://localhost/")
    print()
    print_info("Next steps:")
    print(f"  1. Authenticate: sudo -u {USER} {INSTALL_DIR}/venv/bin/python3 {INSTALL_DIR}/setup_eero_auth.py")
    print(f"  2. Restart: sudo systemctl restart eero-dashboard")
    print(f"  3. Access: http://localhost")
    print()
    print_info("Troubleshooting:")
    print(f"  - Check nginx: sudo systemctl status nginx")
    print(f"  - Check backend: sudo systemctl status eero-dashboard")
    print(f"  - Check nginx error: sudo tail -f {INSTALL_DIR}/logs/nginx_error.log")
    print(f"  - Check permissions: sudo -u www-data test -r {INSTALL_DIR}/frontend/index.html && echo OK")
    print()
    print_warning("Important: You need an API development email registered with eero")
    print()

def main():
    os.system('clear')
    print_header(f"Eero Dashboard Installer v{SCRIPT_VERSION}")
    print_info(f"Repository: https://github.com/{GITHUB_REPO}")
    print()
    if '--no-update' not in sys.argv:
        check_for_updates()
    check_root()
    print_header("Starting Installation")
    try:
        create_user()
        update_system()
        install_dependencies()
        create_directory_structure()
        setup_python_environment()
        create_backend_api()
        create_frontend()
        configure_nginx()
        create_systemd_service()
        create_kiosk_mode()
        create_auth_helper()
        setup_logs()
        print_completion_message()
    except KeyboardInterrupt:
        print()
        print_error("Installation cancelled")
        sys.exit(1)
    except Exception as e:
        print()
        print_error(f"Installation failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
