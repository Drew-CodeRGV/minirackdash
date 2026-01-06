#!/usr/bin/env python3
"""
MiniRack Dashboard - macOS Version
Adapted from v5.2.4 for macOS compatibility with network ID admin functionality
"""
import os
import sys
import json
import requests
import speedtest
import threading
import subprocess
import urllib.request
import re
import time
import socket
from datetime import datetime, timedelta
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import logging
from pathlib import Path

# Configuration
CURRENT_VERSION = "5.2.4-macos"
GITHUB_REPO = "eero-drew/minirackdash"
GITHUB_RAW = f"https://raw.githubusercontent.com/{GITHUB_REPO}/main"
SCRIPT_URL_V5 = f"{GITHUB_RAW}/v5/init_dashboard.py"

# macOS-compatible paths
HOME_DIR = os.path.expanduser("~")
INSTALL_DIR = os.path.join(HOME_DIR, "eero_dashboard")
CONFIG_FILE = os.path.join(INSTALL_DIR, ".config.json")
API_TOKEN_FILE = os.path.join(INSTALL_DIR, ".eero_token")
LOG_DIR = os.path.join(INSTALL_DIR, "logs")
FRONTEND_DIR = os.path.join(INSTALL_DIR, "frontend")

# Create directories
os.makedirs(INSTALL_DIR, exist_ok=True)
os.makedirs(LOG_DIR, exist_ok=True)
os.makedirs(FRONTEND_DIR, exist_ok=True)

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(LOG_DIR, 'backend.log')),
        logging.StreamHandler()
    ]
)

# Flask app setup
app = Flask(__name__, static_folder=FRONTEND_DIR, static_url_path='')
CORS(app)

def check_port_available(port):
    """Check if a port is available"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.bind(('0.0.0.0', port))
        sock.close()
        return True
    except OSError:
        return False

def load_config():
    """Load configuration from file"""
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, 'r') as f:
                return json.load(f)
    except Exception as e:
        logging.error(f"Config load error: {e}")
    return {}

def save_config(config):
    """Save configuration to file"""
    try:
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)
        os.chmod(CONFIG_FILE, 0o600)
        return True
    except Exception as e:
        logging.error(f"Config save error: {e}")
        return False

def get_api_url():
    """Get API URL from config"""
    config = load_config()
    return config.get('api_url', 'api-user.e2ro.com')

class EeroAPI:
    def __init__(self):
        self.session = requests.Session()
        self.api_token = self.load_token()
        self.network_id = self.load_network_id()
        self.api_url = get_api_url()
        self.api_base = f"https://{self.api_url}/2.2"
        logging.info(f"EeroAPI initialized - API: {self.api_url}, Network: {self.network_id}")
    
    def load_token(self):
        """Load API token from file"""
        try:
            if os.path.exists(API_TOKEN_FILE):
                with open(API_TOKEN_FILE, 'r') as f:
                    token = f.read().strip()
                    logging.info("Token loaded successfully")
                    return token
        except Exception as e:
            logging.error(f"Token load error: {e}")
        return None
    
    def load_network_id(self):
        """Load network ID from config"""
        config = load_config()
        return config.get('network_id', '')
    
    def reload_network_id(self):
        """Reload network ID from config"""
        self.network_id = self.load_network_id()
    
    def reload_token(self):
        """Reload API token"""
        self.api_token = self.load_token()
    
    def reload_api_url(self):
        """Reload API URL"""
        self.api_url = get_api_url()
        self.api_base = f"https://{self.api_url}/2.2"
    
    def get_headers(self):
        """Get request headers"""
        headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'Eero-Dashboard/5.2.4-macos'
        }
        if self.api_token:
            headers['X-User-Token'] = self.api_token
        return headers
    
    def get_all_devices(self):
        """Fetch all devices from Eero API"""
        try:
            url = f"{self.api_base}/networks/{self.network_id}/devices"
            logging.info(f"Fetching devices from: {url}")
            response = self.session.get(url, headers=self.get_headers(), timeout=10)
            response.raise_for_status()
            devices_data = response.json()
            
            if 'data' in devices_data:
                if isinstance(devices_data['data'], list):
                    logging.info(f"Retrieved {len(devices_data['data'])} devices")
                    return devices_data['data']
                elif isinstance(devices_data['data'], dict) and 'devices' in devices_data['data']:
                    logging.info(f"Retrieved {len(devices_data['data']['devices'])} devices")
                    return devices_data['data']['devices']
            
            logging.warning("No device data in response")
            return []
        except Exception as e:
            logging.error(f"Device fetch error: {e}")
            return []

def safe_str(value, default=''):
    """Safely convert value to string"""
    return default if value is None else str(value)

def safe_lower(value, default=''):
    """Safely convert value to lowercase string"""
    return default if value is None else str(value).lower()

def categorize_device_os(device):
    """Categorize device operating system"""
    all_text = f"{safe_lower(device.get('manufacturer'))} {safe_lower(device.get('device_type'))} {safe_lower(device.get('hostname'))} {safe_lower(device.get('model_name'))} {safe_lower(device.get('display_name'))}"
    
    # iOS detection
    for keyword in ['apple', 'iphone', 'ipad', 'mac', 'macbook', 'ios']:
        if keyword in all_text:
            return 'iOS'
    
    # Android detection
    for keyword in ['android', 'samsung', 'google', 'pixel', 'xiaomi', 'lg', 'motorola', 'sony', 'oneplus']:
        if keyword in all_text:
            return 'Android'
    
    # Windows detection
    for keyword in ['windows', 'microsoft', 'dell', 'hp', 'lenovo', 'asus', 'surface', 'pc', 'laptop']:
        if keyword in all_text:
            return 'Windows'
    
    return 'Other'

def estimate_signal_from_bars(score_bars):
    """Estimate signal strength from score bars"""
    mapping = {5: -45, 4: -55, 3: -65, 2: -75, 1: -85, 0: -90}
    return mapping.get(score_bars, -90)

def get_signal_quality(score_bars):
    """Get signal quality description"""
    if score_bars is None:
        return 'Unknown'
    try:
        bars = int(score_bars)
        if bars >= 5:
            return 'Excellent'
        elif bars == 4:
            return 'Very Good'
        elif bars == 3:
            return 'Good'
        elif bars == 2:
            return 'Fair'
        elif bars == 1:
            return 'Poor'
    except:
        pass
    return 'Unknown'

def convert_signal_dbm_to_percent(signal_dbm):
    """Convert dBm to percentage"""
    try:
        if not signal_dbm or signal_dbm == 'N/A':
            return 0
        dbm = float(str(signal_dbm).replace(' dBm', '').strip())
        if dbm >= -50:
            return 100
        elif dbm <= -100:
            return 0
        else:
            return int(2 * (dbm + 100))
    except:
        return 0

def parse_frequency(interface_info):
    """Parse frequency information"""
    try:
        if interface_info is None:
            return 'N/A', 'Unknown'
        
        freq = interface_info.get('frequency')
        if freq is None or freq == 'N/A' or freq == '':
            return 'N/A', 'Unknown'
        
        freq_value = float(freq)
        if 2.4 <= freq_value < 2.5:
            band = '2.4GHz'
        elif 5.0 <= freq_value < 6.0:
            band = '5GHz'
        elif 6.0 <= freq_value < 7.0:
            band = '6GHz'
        else:
            band = 'Unknown'
        
        return f"{freq} GHz", band
    except:
        return 'N/A', 'Unknown'

def extract_version_from_script(script_content):
    """Extract version from script content"""
    match = re.search(r'SCRIPT_VERSION\s*=\s*["\']([^"\']+)["\']', script_content)
    return match.group(1) if match else None

def compare_versions(v1, v2):
    """Compare two version strings"""
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

# Initialize Eero API
try:
    eero_api = EeroAPI()
    logging.info("Eero API initialized successfully")
except Exception as e:
    logging.error(f"Failed to initialize Eero API: {e}")
    # Don't exit, allow configuration through web interface

# Data cache
data_cache = {
    'connected_users': [],
    'device_os': {},
    'frequency_distribution': {},
    'signal_strength_avg': [],
    'devices': [],
    'last_update': None,
    'speedtest_running': False,
    'speedtest_result': None
}

def update_cache():
    """Update data cache with latest device information"""
    global data_cache
    try:
        all_devices = eero_api.get_all_devices()
        if not all_devices:
            logging.warning("No devices returned from API")
            return
        
        # Filter for wireless connected devices
        wireless_devices = [
            device for device in all_devices 
            if device.get('connected') and (
                safe_lower(device.get('connection_type')) == 'wireless' or 
                device.get('wireless')
            )
        ]
        
        current_time = datetime.now()
        
        # Update connected users over time
        data_cache['connected_users'].append({
            'timestamp': current_time.isoformat(),
            'count': len(wireless_devices)
        })
        
        # Keep only last 2 hours of data
        two_hours_ago = current_time - timedelta(hours=2)
        data_cache['connected_users'] = [
            entry for entry in data_cache['connected_users']
            if datetime.fromisoformat(entry['timestamp']) > two_hours_ago
        ]
        
        # Initialize counters
        device_os = {'iOS': 0, 'Android': 0, 'Windows': 0, 'Other': 0}
        freq_distribution = {'2.4GHz': 0, '5GHz': 0, '6GHz': 0, 'Unknown': 0}
        signal_strengths = []
        device_list = []
        
        # Process each wireless device
        for device in wireless_devices:
            # OS categorization
            os_type = categorize_device_os(device)
            device_os[os_type] += 1
            
            # Frequency analysis
            connectivity = device.get('connectivity', {}) or {}
            interface = device.get('interface', {}) or {}
            freq_display, freq_band = parse_frequency(interface)
            
            if freq_band in freq_distribution:
                freq_distribution[freq_band] += 1
            
            # Signal strength processing
            signal_dbm = connectivity.get('signal_avg')
            score_bars = connectivity.get('score_bars', 0)
            
            if signal_dbm is None and score_bars:
                signal_dbm = estimate_signal_from_bars(score_bars)
            
            signal_percent = convert_signal_dbm_to_percent(signal_dbm)
            
            if signal_dbm is not None:
                try:
                    if isinstance(signal_dbm, (int, float)):
                        signal_strengths.append(float(signal_dbm))
                    else:
                        signal_strengths.append(float(str(signal_dbm).replace(' dBm', '').strip()))
                except:
                    pass
            
            # Build device info
            device_list.append({
                'name': safe_str(
                    device.get('nickname') or 
                    device.get('hostname') or 
                    device.get('display_name') or 
                    'Unknown'
                ),
                'ip': ', '.join(device.get('ips', [])) if device.get('ips') else 'N/A',
                'mac': safe_str(device.get('mac'), 'N/A'),
                'manufacturer': safe_str(device.get('manufacturer'), 'Unknown'),
                'signal_avg': signal_percent,
                'signal_avg_dbm': f"{signal_dbm} dBm" if signal_dbm else 'N/A',
                'score_bars': score_bars,
                'signal_quality': get_signal_quality(score_bars),
                'device_os': os_type,
                'frequency': freq_display,
                'frequency_band': freq_band
            })
        
        # Update cache
        data_cache['device_os'] = device_os
        data_cache['frequency_distribution'] = freq_distribution
        data_cache['devices'] = sorted(device_list, key=lambda x: x['name'].lower())
        
        # Update signal strength average
        if signal_strengths:
            avg_signal = sum(signal_strengths) / len(signal_strengths)
            data_cache['signal_strength_avg'].append({
                'timestamp': current_time.isoformat(),
                'avg_dbm': round(avg_signal, 2)
            })
            
            # Keep only last 2 hours
            data_cache['signal_strength_avg'] = [
                entry for entry in data_cache['signal_strength_avg']
                if datetime.fromisoformat(entry['timestamp']) > two_hours_ago
            ]
        
        data_cache['last_update'] = current_time.isoformat()
        logging.info(f"Cache updated: {len(wireless_devices)} wireless devices")
        
    except Exception as e:
        logging.error(f"Cache update error: {e}")

def run_speedtest():
    """Run speed test in background"""
    global data_cache
    try:
        data_cache['speedtest_running'] = True
        logging.info("Starting speedtest")
        
        st = speedtest.Speedtest()
        st.get_best_server()
        
        data_cache['speedtest_result'] = {
            'download': round(st.download() / 1_000_000, 2),
            'upload': round(st.upload() / 1_000_000, 2),
            'ping': round(st.results.ping, 2),
            'timestamp': datetime.now().isoformat()
        }
        
        logging.info(f"Speedtest complete: {data_cache['speedtest_result']}")
        
    except Exception as e:
        logging.error(f"Speedtest error: {e}")
        data_cache['speedtest_result'] = {'error': str(e)}
    finally:
        data_cache['speedtest_running'] = False

# API Routes
@app.route('/')
def index():
    """Serve main page"""
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/assets/<path:path>')
def send_assets(path):
    """Serve static assets"""
    return send_from_directory(os.path.join(app.static_folder, 'assets'), path)

@app.route('/api/dashboard')
def get_dashboard_data():
    """Get dashboard data"""
    update_cache()
    return jsonify(data_cache)

@app.route('/api/devices')
def get_devices():
    """Get device list"""
    return jsonify({
        'devices': data_cache.get('devices', []),
        'count': len(data_cache.get('devices', []))
    })

@app.route('/api/speedtest/start', methods=['POST'])
def start_speedtest():
    """Start speed test"""
    if data_cache['speedtest_running']:
        return jsonify({'status': 'running'}), 409
    
    threading.Thread(target=run_speedtest, daemon=True).start()
    return jsonify({'status': 'started'})

@app.route('/api/speedtest/status')
def get_speedtest_status():
    """Get speed test status"""
    return jsonify({
        'running': data_cache['speedtest_running'],
        'result': data_cache['speedtest_result']
    })

@app.route('/api/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'ok',
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/version')
def get_version():
    """Get version information"""
    config = load_config()
    environment = config.get('environment', 'production')
    
    return jsonify({
        'version': CURRENT_VERSION,
        'name': 'Eero Dashboard (macOS)',
        'network_id': config.get('network_id', eero_api.network_id),
        'environment': environment,
        'api_url': config.get('api_url', 'api-user.e2ro.com')
    })

@app.route('/api/admin/check-update')
def check_update():
    """Check for updates"""
    try:
        with urllib.request.urlopen(SCRIPT_URL_V5, timeout=10) as response:
            latest_script = response.read().decode('utf-8')
        
        latest_version = extract_version_from_script(latest_script)
        
        return jsonify({
            'current_version': CURRENT_VERSION,
            'latest_version': latest_version or CURRENT_VERSION,
            'update_available': compare_versions(latest_version or CURRENT_VERSION, CURRENT_VERSION) > 0
        })
    except:
        return jsonify({
            'current_version': CURRENT_VERSION,
            'latest_version': CURRENT_VERSION,
            'update_available': False
        })

@app.route('/api/admin/network-id', methods=['POST'])
def change_network_id():
    """Change network ID"""
    try:
        data = request.get_json()
        new_id = data.get('network_id', '').strip()
        
        if not new_id or not new_id.isdigit():
            return jsonify({'success': False, 'message': 'Invalid network ID'}), 400
        
        config = load_config()
        config['network_id'] = new_id
        config['last_updated'] = datetime.now().strftime('%Y-%m-%dT%H:%M:%S')
        
        if save_config(config):
            eero_api.reload_network_id()
            return jsonify({'success': True, 'message': f'Network ID updated to {new_id}'})
        
        return jsonify({'success': False, 'message': 'Failed to save configuration'}), 500
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/admin/reauthorize', methods=['POST'])
def reauthorize():
    """Reauthorize API access"""
    try:
        data = request.get_json()
        email = data.get('email', '').strip()
        code = data.get('code', '').strip()
        step = data.get('step', 'send')
        api_url = get_api_url()
        
        if step == 'send':
            if not email or '@' not in email:
                return jsonify({'success': False, 'message': 'Invalid email address'}), 400
            
            response = requests.post(
                f"https://{api_url}/2.2/pro/login",
                json={"login": email},
                timeout=10
            )
            response.raise_for_status()
            response_data = response.json()
            
            if 'data' not in response_data or 'user_token' not in response_data['data']:
                return jsonify({'success': False, 'message': 'Failed to generate token'}), 500
            
            # Store temporary token
            temp_token_file = API_TOKEN_FILE + '.temp'
            with open(temp_token_file, 'w') as f:
                f.write(response_data['data']['user_token'])
            
            return jsonify({'success': True, 'message': 'Verification code sent', 'step': 'verify'})
            
        elif step == 'verify':
            if not code:
                return jsonify({'success': False, 'message': 'Verification code required'}), 400
            
            temp_token_file = API_TOKEN_FILE + '.temp'
            if not os.path.exists(temp_token_file):
                return jsonify({'success': False, 'message': 'Please restart the process'}), 400
            
            with open(temp_token_file, 'r') as f:
                token = f.read().strip()
            
            verify_response = requests.post(
                f"https://{api_url}/2.2/login/verify",
                headers={"X-User-Token": token},
                data={"code": code},
                timeout=10
            )
            verify_response.raise_for_status()
            verify_data = verify_response.json()
            
            if verify_data.get('data', {}).get('email', {}).get('verified'):
                # Save verified token
                with open(API_TOKEN_FILE, 'w') as f:
                    f.write(token)
                os.chmod(API_TOKEN_FILE, 0o600)
                
                # Clean up temp file
                if os.path.exists(temp_token_file):
                    os.remove(temp_token_file)
                
                eero_api.reload_token()
                return jsonify({'success': True, 'message': 'Successfully reauthorized!'})
            
            return jsonify({'success': False, 'message': 'Verification failed'}), 400
            
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

if __name__ == '__main__':
    logging.info("=" * 60)
    logging.info(f"Starting Eero Dashboard Backend {CURRENT_VERSION}")
    logging.info(f"Install Directory: {INSTALL_DIR}")
    logging.info(f"API URL: {eero_api.api_url if 'eero_api' in globals() else 'Not configured'}")
    logging.info(f"Network ID: {eero_api.network_id if 'eero_api' in globals() else 'Not configured'}")
    logging.info("=" * 60)
    
    # Check port availability
    port = 3000  # Use port 3000 for macOS (no sudo required)
    if not check_port_available(port):
        logging.error(f"Port {port} is not available!")
        logging.error("Another service may be using it. Please stop other services or use a different port.")
        sys.exit(1)
    
    logging.info(f"Port {port} is available")
    logging.info("Performing initial cache update...")
    
    try:
        if 'eero_api' in globals() and eero_api.network_id:
            update_cache()
            logging.info("Initial cache update complete")
        else:
            logging.warning("Eero API not configured - please configure through web interface")
    except Exception as e:
        logging.error(f"Initial cache update failed: {e}")
    
    logging.info(f"Starting Flask server on 0.0.0.0:{port}")
    logging.info("=" * 60)
    
    try:
        app.run(host='0.0.0.0', port=port, debug=False, threaded=True)
    except Exception as e:
        logging.error(f"Failed to start server: {e}")
        sys.exit(1)