#!/usr/bin/env python3
"""
MiniRack Dashboard - Production Version
Auto-deployable from GitHub
"""
import os
import sys
import json
import requests
import speedtest
import threading
import time
import socket
from datetime import datetime, timedelta
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import logging

# Configuration
CURRENT_VERSION = "5.2.4-github"
INSTALL_DIR = "/opt/eero"
CONFIG_FILE = f"{INSTALL_DIR}/app/config.json"
TOKEN_FILE = f"{INSTALL_DIR}/app/.eero_token"
LOG_DIR = f"{INSTALL_DIR}/logs"

# Create directories
os.makedirs(LOG_DIR, exist_ok=True)

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
app = Flask(__name__)
CORS(app)

def load_config():
    """Load configuration from file"""
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, 'r') as f:
                return json.load(f)
    except Exception as e:
        logging.error(f"Config load error: {e}")
    
    # Default configuration
    return {
        "network_id": "20478317",
        "environment": "production",
        "api_url": "api-user.e2ro.com",
        "last_updated": datetime.now().isoformat()
    }

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
            if os.path.exists(TOKEN_FILE):
                with open(TOKEN_FILE, 'r') as f:
                    token = f.read().strip()
                    logging.info("Token loaded successfully")
                    return token
        except Exception as e:
            logging.error(f"Token load error: {e}")
        return None
    
    def load_network_id(self):
        """Load network ID from config"""
        config = load_config()
        return config.get('network_id', '20478317')
    
    def reload_network_id(self):
        """Reload network ID from config"""
        self.network_id = self.load_network_id()
    
    def reload_token(self):
        """Reload API token"""
        self.api_token = self.load_token()
    
    def get_headers(self):
        """Get request headers"""
        headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'Eero-Dashboard-GitHub/5.2.4'
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

# Initialize Eero API
try:
    eero_api = EeroAPI()
    logging.info("Eero API initialized successfully")
except Exception as e:
    logging.error(f"Failed to initialize Eero API: {e}")

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
        device_list = []
        
        # Process each wireless device
        for device in wireless_devices:
            # OS categorization
            os_type = categorize_device_os(device)
            device_os[os_type] += 1
            
            # Basic frequency analysis (simplified)
            interface = device.get('interface', {}) or {}
            freq = interface.get('frequency', 0)
            if 2.4 <= freq < 2.5:
                freq_distribution['2.4GHz'] += 1
            elif 5.0 <= freq < 6.0:
                freq_distribution['5GHz'] += 1
            elif 6.0 <= freq < 7.0:
                freq_distribution['6GHz'] += 1
            else:
                freq_distribution['Unknown'] += 1
            
            # Signal strength
            connectivity = device.get('connectivity', {}) or {}
            signal_dbm = connectivity.get('signal_avg')
            score_bars = connectivity.get('score_bars', 0)
            signal_percent = convert_signal_dbm_to_percent(signal_dbm)
            
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
                'frequency': f"{freq} GHz" if freq else 'N/A',
                'frequency_band': 'Unknown'
            })
        
        # Update cache
        data_cache['device_os'] = device_os
        data_cache['frequency_distribution'] = freq_distribution
        data_cache['devices'] = sorted(device_list, key=lambda x: x['name'].lower())
        data_cache['signal_strength_avg'] = [{'timestamp': current_time.isoformat(), 'avg_dbm': -50}]
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
    return '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Eero Dashboard (GitHub Auto-Deploy)</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            background: linear-gradient(135deg, #001a33 0%, #003366 100%); 
            font-family: Arial, sans-serif; 
            color: #fff; 
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 30px; }
        .header h1 { color: #4da6ff; margin-bottom: 10px; }
        .stats { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }
        .stat-card { 
            background: rgba(0,40,80,.7); 
            padding: 20px; 
            border-radius: 10px; 
            text-align: center;
            border: 1px solid rgba(77,166,255,.3);
        }
        .stat-value { font-size: 2em; font-weight: bold; color: #4da6ff; }
        .stat-label { margin-top: 10px; color: #ccc; }
        .admin-panel {
            background: rgba(0,40,80,.7);
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            border: 1px solid rgba(77,166,255,.3);
        }
        .btn {
            background: #4da6ff;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            margin: 5px;
            transition: all 0.3s;
        }
        .btn:hover { background: #357abd; transform: translateY(-2px); }
        .form-group { margin: 15px 0; }
        .form-input {
            width: 100%;
            padding: 10px;
            background: rgba(0,40,80,.5);
            border: 1px solid rgba(77,166,255,.3);
            border-radius: 5px;
            color: white;
            margin: 5px 0;
        }
        .alert {
            padding: 10px;
            margin: 10px 0;
            border-radius: 5px;
            border: 1px solid;
        }
        .alert-success { background: rgba(81,207,102,.2); border-color: #51cf66; color: #51cf66; }
        .alert-error { background: rgba(255,107,107,.2); border-color: #ff6b6b; color: #ff6b6b; }
        .devices { margin-top: 20px; }
        .device-item {
            background: rgba(0,40,80,.5);
            padding: 15px;
            margin: 10px 0;
            border-radius: 5px;
            border: 1px solid rgba(77,166,255,.2);
        }
        .device-name { font-weight: bold; color: #4da6ff; margin-bottom: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌐 Eero Network Dashboard</h1>
            <p>GitHub Auto-Deploy Version • Network ID: <span id="networkId">Loading...</span></p>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-value" id="deviceCount">-</div>
                <div class="stat-label">Connected Devices</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="lastUpdate">-</div>
                <div class="stat-label">Last Updated</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="version">-</div>
                <div class="stat-label">Version</div>
            </div>
        </div>
        
        <div class="admin-panel">
            <h3>🔧 Admin Panel</h3>
            <button class="btn" onclick="showNetworkForm()">Change Network ID</button>
            <button class="btn" onclick="showAuthForm()">Setup API Authentication</button>
            <button class="btn" onclick="runSpeedTest()">Run Speed Test</button>
            <button class="btn" onclick="loadDevices()">Show Devices</button>
            
            <div id="formContainer"></div>
            <div id="alerts"></div>
        </div>
        
        <div class="devices">
            <h3>📱 Connected Devices</h3>
            <div id="devicesList">Click "Show Devices" to load...</div>
        </div>
    </div>
    
    <script>
        function showAlert(message, type = 'success') {
            const alerts = document.getElementById('alerts');
            alerts.innerHTML = `<div class="alert alert-${type}">${message}</div>`;
            setTimeout(() => alerts.innerHTML = '', 5000);
        }
        
        function showNetworkForm() {
            document.getElementById('formContainer').innerHTML = `
                <div class="form-group">
                    <label>New Network ID:</label>
                    <input type="text" id="newNetworkId" class="form-input" placeholder="Enter network ID" value="20478317">
                    <button class="btn" onclick="changeNetworkId()">Update Network ID</button>
                </div>
            `;
        }
        
        function showAuthForm() {
            document.getElementById('formContainer').innerHTML = `
                <div class="form-group">
                    <label>Email Address:</label>
                    <input type="email" id="authEmail" class="form-input" placeholder="Enter your Eero account email">
                    <button class="btn" onclick="sendAuthCode()">Send Verification Code</button>
                </div>
                <div id="codeForm"></div>
            `;
        }
        
        async function changeNetworkId() {
            const newId = document.getElementById('newNetworkId').value.trim();
            if (!newId || !newId.match(/^\\d+$/)) {
                showAlert('Invalid network ID', 'error');
                return;
            }
            
            try {
                const response = await fetch('/api/admin/network-id', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ network_id: newId })
                });
                const data = await response.json();
                showAlert(data.message, data.success ? 'success' : 'error');
                if (data.success) {
                    document.getElementById('formContainer').innerHTML = '';
                    loadDashboard();
                }
            } catch (error) {
                showAlert('Failed to update network ID', 'error');
            }
        }
        
        async function sendAuthCode() {
            const email = document.getElementById('authEmail').value.trim();
            if (!email || !email.includes('@')) {
                showAlert('Invalid email address', 'error');
                return;
            }
            
            try {
                const response = await fetch('/api/admin/reauthorize', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ step: 'send', email })
                });
                const data = await response.json();
                showAlert(data.message, data.success ? 'success' : 'error');
                
                if (data.success) {
                    document.getElementById('codeForm').innerHTML = `
                        <div class="form-group">
                            <label>Verification Code:</label>
                            <input type="text" id="authCode" class="form-input" placeholder="Enter code from email">
                            <button class="btn" onclick="verifyAuthCode()">Verify Code</button>
                        </div>
                    `;
                }
            } catch (error) {
                showAlert('Failed to send verification code', 'error');
            }
        }
        
        async function verifyAuthCode() {
            const code = document.getElementById('authCode').value.trim();
            if (!code) {
                showAlert('Verification code required', 'error');
                return;
            }
            
            try {
                const response = await fetch('/api/admin/reauthorize', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ step: 'verify', code })
                });
                const data = await response.json();
                showAlert(data.message, data.success ? 'success' : 'error');
                
                if (data.success) {
                    document.getElementById('formContainer').innerHTML = '';
                    loadDashboard();
                }
            } catch (error) {
                showAlert('Failed to verify code', 'error');
            }
        }
        
        async function runSpeedTest() {
            showAlert('Starting speed test...', 'success');
            try {
                await fetch('/api/speedtest/start', { method: 'POST' });
                
                const checkStatus = async () => {
                    const response = await fetch('/api/speedtest/status');
                    const data = await response.json();
                    
                    if (!data.running && data.result) {
                        if (data.result.error) {
                            showAlert(`Speed test error: ${data.result.error}`, 'error');
                        } else {
                            showAlert(`Speed test complete! Download: ${data.result.download} Mbps, Upload: ${data.result.upload} Mbps, Ping: ${data.result.ping} ms`, 'success');
                        }
                    } else if (data.running) {
                        setTimeout(checkStatus, 2000);
                    }
                };
                
                setTimeout(checkStatus, 2000);
            } catch (error) {
                showAlert('Failed to start speed test', 'error');
            }
        }
        
        async function loadDevices() {
            try {
                const response = await fetch('/api/devices');
                const data = await response.json();
                const container = document.getElementById('devicesList');
                
                if (!data.devices || data.devices.length === 0) {
                    container.innerHTML = '<p>No devices found or API not authenticated.</p>';
                } else {
                    container.innerHTML = data.devices.map(device => `
                        <div class="device-item">
                            <div class="device-name">${device.name}</div>
                            <div>IP: ${device.ip} | MAC: ${device.mac}</div>
                            <div>Manufacturer: ${device.manufacturer} | OS: ${device.device_os}</div>
                            <div>Signal: ${device.signal_quality} (${device.signal_avg_dbm})</div>
                        </div>
                    `).join('');
                }
            } catch (error) {
                document.getElementById('devicesList').innerHTML = '<p>Error loading devices</p>';
            }
        }
        
        async function loadDashboard() {
            try {
                const [dashboardResponse, versionResponse] = await Promise.all([
                    fetch('/api/dashboard'),
                    fetch('/api/version')
                ]);
                
                const dashboardData = await dashboardResponse.json();
                const versionData = await versionResponse.json();
                
                document.getElementById('deviceCount').textContent = 
                    dashboardData.connected_users[0]?.count || 0;
                document.getElementById('lastUpdate').textContent = 
                    new Date(dashboardData.last_update).toLocaleTimeString();
                document.getElementById('version').textContent = versionData.version;
                document.getElementById('networkId').textContent = versionData.network_id;
                
            } catch (error) {
                console.error('Dashboard load error:', error);
            }
        }
        
        // Initialize
        window.addEventListener('load', () => {
            loadDashboard();
            setInterval(loadDashboard, 60000); // Refresh every minute
        });
    </script>
</body>
</html>'''

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

@app.route('/api/version')
def get_version():
    """Get version information"""
    config = load_config()
    
    return jsonify({
        'version': CURRENT_VERSION,
        'name': 'Eero Dashboard (GitHub)',
        'network_id': config.get('network_id', '20478317'),
        'environment': config.get('environment', 'production'),
        'api_url': config.get('api_url', 'api-user.e2ro.com')
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
            temp_token_file = TOKEN_FILE + '.temp'
            with open(temp_token_file, 'w') as f:
                f.write(response_data['data']['user_token'])
            
            return jsonify({'success': True, 'message': 'Verification code sent to your email', 'step': 'verify'})
            
        elif step == 'verify':
            if not code:
                return jsonify({'success': False, 'message': 'Verification code required'}), 400
            
            temp_token_file = TOKEN_FILE + '.temp'
            if not os.path.exists(temp_token_file):
                return jsonify({'success': False, 'message': 'Please restart the authentication process'}), 400
            
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
                with open(TOKEN_FILE, 'w') as f:
                    f.write(token)
                os.chmod(TOKEN_FILE, 0o600)
                
                # Clean up temp file
                if os.path.exists(temp_token_file):
                    os.remove(temp_token_file)
                
                eero_api.reload_token()
                return jsonify({'success': True, 'message': 'API authentication successful!'})
            
            return jsonify({'success': False, 'message': 'Verification failed'}), 400
            
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

if __name__ == '__main__':
    logging.info("=" * 60)
    logging.info(f"Starting Eero Dashboard Backend {CURRENT_VERSION}")
    logging.info(f"Install Directory: {INSTALL_DIR}")
    logging.info(f"Config File: {CONFIG_FILE}")
    logging.info("=" * 60)
    
    logging.info("Performing initial cache update...")
    
    try:
        if eero_api.network_id:
            update_cache()
            logging.info("Initial cache update complete")
        else:
            logging.warning("No network ID configured - please configure through web interface")
    except Exception as e:
        logging.error(f"Initial cache update failed: {e}")
    
    logging.info("Starting Flask server on 0.0.0.0:5000")
    logging.info("=" * 60)
    
    try:
        app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
    except Exception as e:
        logging.error(f"Failed to start server: {e}")
        sys.exit(1)