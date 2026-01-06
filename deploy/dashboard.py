#!/usr/bin/env python3
"""
MiniRack Dashboard - Production Ready
Optimized for Lightsail deployment with Gunicorn
"""
import os
import sys
import json
import requests
import speedtest
import threading
import time
from datetime import datetime, timedelta
from flask import Flask, jsonify, request
from flask_cors import CORS
import logging

# Configuration
VERSION = "5.2.4-production"
CONFIG_FILE = "/opt/eero/app/config.json"
TOKEN_FILE = "/opt/eero/app/.eero_token"

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/eero/logs/dashboard.log'),
        logging.StreamHandler()
    ]
)

# Flask app
app = Flask(__name__)
CORS(app)

def load_config():
    """Load configuration"""
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, 'r') as f:
                return json.load(f)
    except Exception as e:
        logging.error(f"Config load error: {e}")
    
    return {
        "network_id": "20478317",
        "environment": "production",
        "api_url": "api-user.e2ro.com"
    }

def save_config(config):
    """Save configuration"""
    try:
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)
        os.chmod(CONFIG_FILE, 0o600)
        return True
    except Exception as e:
        logging.error(f"Config save error: {e}")
        return False

class EeroAPI:
    def __init__(self):
        self.session = requests.Session()
        self.config = load_config()
        self.api_token = self.load_token()
        self.network_id = self.config.get('network_id', '20478317')
        self.api_url = self.config.get('api_url', 'api-user.e2ro.com')
        self.api_base = f"https://{self.api_url}/2.2"
    
    def load_token(self):
        """Load API token"""
        try:
            if os.path.exists(TOKEN_FILE):
                with open(TOKEN_FILE, 'r') as f:
                    return f.read().strip()
        except Exception as e:
            logging.error(f"Token load error: {e}")
        return None
    
    def get_headers(self):
        """Get request headers"""
        headers = {
            'Content-Type': 'application/json',
            'User-Agent': f'MiniRack-Dashboard/{VERSION}'
        }
        if self.api_token:
            headers['X-User-Token'] = self.api_token
        return headers
    
    def get_devices(self):
        """Get all devices"""
        try:
            url = f"{self.api_base}/networks/{self.network_id}/devices"
            response = self.session.get(url, headers=self.get_headers(), timeout=10)
            response.raise_for_status()
            data = response.json()
            
            if 'data' in data:
                devices = data['data'] if isinstance(data['data'], list) else data['data'].get('devices', [])
                logging.info(f"Retrieved {len(devices)} devices")
                return devices
            return []
        except Exception as e:
            logging.error(f"Device fetch error: {e}")
            return []

# Initialize API
eero_api = EeroAPI()

# Data cache
cache = {
    'devices': [],
    'last_update': None,
    'speedtest_running': False,
    'speedtest_result': None
}

def update_cache():
    """Update device cache"""
    global cache
    try:
        devices = eero_api.get_devices()
        wireless = [d for d in devices if d.get('connected') and d.get('wireless')]
        
        # Process devices
        device_list = []
        os_counts = {'iOS': 0, 'Android': 0, 'Windows': 0, 'Other': 0}
        
        for device in wireless:
            # Simple OS detection
            text = str(device.get('manufacturer', '') + ' ' + device.get('hostname', '')).lower()
            if any(k in text for k in ['apple', 'iphone', 'ipad', 'mac']):
                os_type = 'iOS'
            elif any(k in text for k in ['android', 'samsung', 'google']):
                os_type = 'Android'
            elif any(k in text for k in ['windows', 'microsoft', 'dell', 'hp']):
                os_type = 'Windows'
            else:
                os_type = 'Other'
            
            os_counts[os_type] += 1
            
            device_list.append({
                'name': device.get('nickname') or device.get('hostname') or 'Unknown',
                'ip': ', '.join(device.get('ips', [])) if device.get('ips') else 'N/A',
                'mac': device.get('mac', 'N/A'),
                'manufacturer': device.get('manufacturer', 'Unknown'),
                'os': os_type
            })
        
        cache.update({
            'devices': device_list,
            'device_count': len(wireless),
            'os_distribution': os_counts,
            'last_update': datetime.now().isoformat()
        })
        
        logging.info(f"Cache updated: {len(wireless)} devices")
    except Exception as e:
        logging.error(f"Cache update error: {e}")

def run_speedtest():
    """Run speed test"""
    global cache
    try:
        cache['speedtest_running'] = True
        st = speedtest.Speedtest()
        st.get_best_server()
        
        cache['speedtest_result'] = {
            'download': round(st.download() / 1_000_000, 2),
            'upload': round(st.upload() / 1_000_000, 2),
            'ping': round(st.results.ping, 2),
            'timestamp': datetime.now().isoformat()
        }
    except Exception as e:
        cache['speedtest_result'] = {'error': str(e)}
    finally:
        cache['speedtest_running'] = False

# Routes
@app.route('/')
def home():
    """Main dashboard page"""
    return '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>MiniRack Dashboard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white; min-height: 100vh; padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 40px; }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; text-shadow: 2px 2px 4px rgba(0,0,0,0.3); }
        .header p { opacity: 0.9; font-size: 1.1em; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 40px; }
        .stat-card { 
            background: rgba(255,255,255,0.1); backdrop-filter: blur(10px);
            padding: 30px; border-radius: 15px; text-align: center;
            border: 1px solid rgba(255,255,255,0.2); transition: transform 0.3s;
        }
        .stat-card:hover { transform: translateY(-5px); }
        .stat-value { font-size: 3em; font-weight: bold; margin-bottom: 10px; }
        .stat-label { font-size: 1.1em; opacity: 0.9; }
        .controls { 
            display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); 
            gap: 15px; margin-bottom: 40px; 
        }
        .btn { 
            background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.3);
            color: white; padding: 15px 25px; border-radius: 10px; cursor: pointer;
            font-size: 1em; transition: all 0.3s; text-decoration: none; text-align: center;
        }
        .btn:hover { background: rgba(255,255,255,0.3); transform: translateY(-2px); }
        .devices { 
            background: rgba(255,255,255,0.1); backdrop-filter: blur(10px);
            padding: 30px; border-radius: 15px; border: 1px solid rgba(255,255,255,0.2);
        }
        .device-item { 
            background: rgba(255,255,255,0.1); padding: 15px; margin: 10px 0; 
            border-radius: 10px; border: 1px solid rgba(255,255,255,0.2);
        }
        .device-name { font-weight: bold; margin-bottom: 5px; }
        .device-info { font-size: 0.9em; opacity: 0.9; }
        .modal { 
            display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.8); z-index: 1000; align-items: center; justify-content: center;
        }
        .modal.active { display: flex; }
        .modal-content { 
            background: rgba(255,255,255,0.1); backdrop-filter: blur(20px);
            padding: 30px; border-radius: 15px; max-width: 500px; width: 90%;
            border: 1px solid rgba(255,255,255,0.2);
        }
        .form-group { margin: 20px 0; }
        .form-input { 
            width: 100%; padding: 12px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.3);
            background: rgba(255,255,255,0.1); color: white; font-size: 1em;
        }
        .form-input::placeholder { color: rgba(255,255,255,0.7); }
        .alert { padding: 15px; margin: 15px 0; border-radius: 8px; }
        .alert-success { background: rgba(76, 175, 80, 0.3); border: 1px solid #4CAF50; }
        .alert-error { background: rgba(244, 67, 54, 0.3); border: 1px solid #f44336; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌐 MiniRack Dashboard</h1>
            <p>Real-time Eero Network Monitoring • Network ID: <span id="networkId">Loading...</span></p>
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
        </div>
        
        <div class="controls">
            <button class="btn" onclick="showNetworkForm()">Change Network ID</button>
            <button class="btn" onclick="showAuthForm()">Setup API Auth</button>
            <button class="btn" onclick="runSpeedTest()">Speed Test</button>
            <button class="btn" onclick="loadDevices()">Refresh Devices</button>
        </div>
        
        <div class="devices">
            <h3>📱 Connected Devices</h3>
            <div id="devicesList">Loading devices...</div>
        </div>
    </div>
    
    <!-- Modals -->
    <div id="networkModal" class="modal">
        <div class="modal-content">
            <h3>Change Network ID</h3>
            <div class="form-group">
                <input type="text" id="newNetworkId" class="form-input" placeholder="Enter Network ID" value="20478317">
                <button class="btn" onclick="changeNetworkId()" style="width:100%;margin-top:10px;">Update</button>
            </div>
            <button class="btn" onclick="closeModal('networkModal')" style="width:100%;">Cancel</button>
        </div>
    </div>
    
    <div id="authModal" class="modal">
        <div class="modal-content">
            <h3>API Authentication</h3>
            <div class="form-group">
                <input type="email" id="authEmail" class="form-input" placeholder="Eero Account Email">
                <button class="btn" onclick="sendAuthCode()" style="width:100%;margin-top:10px;">Send Code</button>
            </div>
            <div id="codeForm"></div>
            <div id="authAlerts"></div>
            <button class="btn" onclick="closeModal('authModal')" style="width:100%;">Cancel</button>
        </div>
    </div>
    
    <script>
        function showModal(id) { document.getElementById(id).classList.add('active'); }
        function closeModal(id) { document.getElementById(id).classList.remove('active'); }
        function showNetworkForm() { showModal('networkModal'); }
        function showAuthForm() { showModal('authModal'); }
        
        function showAlert(message, type = 'success', container = 'authAlerts') {
            document.getElementById(container).innerHTML = `<div class="alert alert-${type}">${message}</div>`;
            setTimeout(() => document.getElementById(container).innerHTML = '', 5000);
        }
        
        async function changeNetworkId() {
            const newId = document.getElementById('newNetworkId').value.trim();
            if (!newId.match(/^\\d+$/)) return alert('Invalid Network ID');
            
            try {
                const response = await fetch('/api/network-id', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ network_id: newId })
                });
                const data = await response.json();
                alert(data.message);
                if (data.success) {
                    closeModal('networkModal');
                    loadDashboard();
                }
            } catch (error) {
                alert('Failed to update Network ID');
            }
        }
        
        async function sendAuthCode() {
            const email = document.getElementById('authEmail').value.trim();
            if (!email.includes('@')) return showAlert('Invalid email', 'error');
            
            try {
                const response = await fetch('/api/auth', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ step: 'send', email })
                });
                const data = await response.json();
                showAlert(data.message, data.success ? 'success' : 'error');
                
                if (data.success) {
                    document.getElementById('codeForm').innerHTML = `
                        <div class="form-group">
                            <input type="text" id="authCode" class="form-input" placeholder="Verification Code">
                            <button class="btn" onclick="verifyCode()" style="width:100%;margin-top:10px;">Verify</button>
                        </div>
                    `;
                }
            } catch (error) {
                showAlert('Failed to send code', 'error');
            }
        }
        
        async function verifyCode() {
            const code = document.getElementById('authCode').value.trim();
            if (!code) return showAlert('Code required', 'error');
            
            try {
                const response = await fetch('/api/auth', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ step: 'verify', code })
                });
                const data = await response.json();
                showAlert(data.message, data.success ? 'success' : 'error');
                
                if (data.success) {
                    closeModal('authModal');
                    loadDashboard();
                }
            } catch (error) {
                showAlert('Failed to verify code', 'error');
            }
        }
        
        async function runSpeedTest() {
            alert('Starting speed test...');
            try {
                await fetch('/api/speedtest', { method: 'POST' });
                setTimeout(checkSpeedTest, 2000);
            } catch (error) {
                alert('Failed to start speed test');
            }
        }
        
        async function checkSpeedTest() {
            try {
                const response = await fetch('/api/speedtest');
                const data = await response.json();
                
                if (!data.running && data.result) {
                    if (data.result.error) {
                        alert(`Speed test error: ${data.result.error}`);
                    } else {
                        alert(`Speed Test Results:\\nDownload: ${data.result.download} Mbps\\nUpload: ${data.result.upload} Mbps\\nPing: ${data.result.ping} ms`);
                    }
                } else if (data.running) {
                    setTimeout(checkSpeedTest, 2000);
                }
            } catch (error) {
                console.error('Speed test check error:', error);
            }
        }
        
        async function loadDevices() {
            try {
                const response = await fetch('/api/devices');
                const data = await response.json();
                const container = document.getElementById('devicesList');
                
                if (!data.devices || data.devices.length === 0) {
                    container.innerHTML = '<p>No devices found. Please authenticate API first.</p>';
                } else {
                    container.innerHTML = data.devices.map(device => `
                        <div class="device-item">
                            <div class="device-name">${device.name}</div>
                            <div class="device-info">
                                IP: ${device.ip} | MAC: ${device.mac}<br>
                                Manufacturer: ${device.manufacturer} | OS: ${device.os}
                            </div>
                        </div>
                    `).join('');
                }
            } catch (error) {
                document.getElementById('devicesList').innerHTML = '<p>Error loading devices</p>';
            }
        }
        
        async function loadDashboard() {
            try {
                const [dashResponse, configResponse] = await Promise.all([
                    fetch('/api/dashboard'),
                    fetch('/api/config')
                ]);
                
                const dashData = await dashResponse.json();
                const configData = await configResponse.json();
                
                document.getElementById('deviceCount').textContent = dashData.device_count || 0;
                document.getElementById('lastUpdate').textContent = 
                    dashData.last_update ? new Date(dashData.last_update).toLocaleTimeString() : 'Never';
                document.getElementById('networkId').textContent = configData.network_id || 'Not set';
                
                loadDevices();
            } catch (error) {
                console.error('Dashboard load error:', error);
            }
        }
        
        // Initialize
        window.addEventListener('load', () => {
            loadDashboard();
            setInterval(loadDashboard, 60000);
        });
        
        // Close modals on outside click
        window.onclick = function(event) {
            if (event.target.classList.contains('modal')) {
                event.target.classList.remove('active');
            }
        }
    </script>
</body>
</html>'''

@app.route('/api/dashboard')
def get_dashboard():
    """Get dashboard data"""
    update_cache()
    return jsonify(cache)

@app.route('/api/devices')
def get_devices():
    """Get devices"""
    return jsonify({
        'devices': cache.get('devices', []),
        'count': cache.get('device_count', 0)
    })

@app.route('/api/config')
def get_config():
    """Get configuration"""
    config = load_config()
    return jsonify({
        'network_id': config.get('network_id', '20478317'),
        'environment': config.get('environment', 'production'),
        'version': VERSION
    })

@app.route('/api/network-id', methods=['POST'])
def change_network_id():
    """Change network ID"""
    try:
        data = request.get_json()
        new_id = data.get('network_id', '').strip()
        
        if not new_id or not new_id.isdigit():
            return jsonify({'success': False, 'message': 'Invalid network ID'}), 400
        
        config = load_config()
        config['network_id'] = new_id
        
        if save_config(config):
            eero_api.network_id = new_id
            return jsonify({'success': True, 'message': f'Network ID updated to {new_id}'})
        
        return jsonify({'success': False, 'message': 'Failed to save'}), 500
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/auth', methods=['POST'])
def authenticate():
    """API authentication"""
    try:
        data = request.get_json()
        step = data.get('step', 'send')
        
        if step == 'send':
            email = data.get('email', '').strip()
            if not email or '@' not in email:
                return jsonify({'success': False, 'message': 'Invalid email'}), 400
            
            response = requests.post(
                f"https://{eero_api.api_url}/2.2/pro/login",
                json={"login": email},
                timeout=10
            )
            response.raise_for_status()
            response_data = response.json()
            
            if 'data' not in response_data or 'user_token' not in response_data['data']:
                return jsonify({'success': False, 'message': 'Failed to generate token'}), 500
            
            with open(TOKEN_FILE + '.temp', 'w') as f:
                f.write(response_data['data']['user_token'])
            
            return jsonify({'success': True, 'message': 'Verification code sent to email'})
            
        elif step == 'verify':
            code = data.get('code', '').strip()
            if not code:
                return jsonify({'success': False, 'message': 'Code required'}), 400
            
            temp_file = TOKEN_FILE + '.temp'
            if not os.path.exists(temp_file):
                return jsonify({'success': False, 'message': 'Please restart process'}), 400
            
            with open(temp_file, 'r') as f:
                token = f.read().strip()
            
            verify_response = requests.post(
                f"https://{eero_api.api_url}/2.2/login/verify",
                headers={"X-User-Token": token},
                data={"code": code},
                timeout=10
            )
            verify_response.raise_for_status()
            verify_data = verify_response.json()
            
            if verify_data.get('data', {}).get('email', {}).get('verified'):
                with open(TOKEN_FILE, 'w') as f:
                    f.write(token)
                os.chmod(TOKEN_FILE, 0o600)
                
                if os.path.exists(temp_file):
                    os.remove(temp_file)
                
                eero_api.api_token = token
                return jsonify({'success': True, 'message': 'Authentication successful!'})
            
            return jsonify({'success': False, 'message': 'Verification failed'}), 400
            
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/speedtest', methods=['GET', 'POST'])
def speedtest_endpoint():
    """Speed test endpoint"""
    if request.method == 'POST':
        if cache['speedtest_running']:
            return jsonify({'status': 'already running'}), 409
        
        threading.Thread(target=run_speedtest, daemon=True).start()
        return jsonify({'status': 'started'})
    
    return jsonify({
        'running': cache['speedtest_running'],
        'result': cache['speedtest_result']
    })

@app.route('/health')
def health():
    """Health check"""
    return jsonify({'status': 'ok', 'version': VERSION})

if __name__ == '__main__':
    logging.info(f"Starting MiniRack Dashboard {VERSION}")
    
    # Initial cache update
    try:
        update_cache()
        logging.info("Initial cache update complete")
    except Exception as e:
        logging.warning(f"Initial cache update failed: {e}")
    
    app.run(host='0.0.0.0', port=5000, debug=False)