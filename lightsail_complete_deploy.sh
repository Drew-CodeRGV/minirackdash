#!/bin/bash
# Complete MiniRack Dashboard Deployment for AWS Lightsail
# Network ID: 20478317 (from your current setup)
# This script will be used as the Lightsail startup script

# Update system
apt-get update -y
apt-get upgrade -y

# Install dependencies
apt-get install -y python3 python3-pip python3-venv git nginx curl

# Create user and directories
useradd -m -s /bin/bash eero
mkdir -p /home/eero/dashboard/{backend,frontend,logs}
chown -R eero:eero /home/eero

# Setup Python environment
sudo -u eero python3 -m venv /home/eero/dashboard/venv
sudo -u eero /home/eero/dashboard/venv/bin/pip install --upgrade pip
sudo -u eero /home/eero/dashboard/venv/bin/pip install flask flask-cors requests speedtest-cli gunicorn

# Create backend application
cat > /home/eero/dashboard/backend/app.py << 'EOF'
#!/usr/bin/env python3
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

# Configuration
CURRENT_VERSION = "5.2.4-lightsail"
INSTALL_DIR = "/home/eero/dashboard"
CONFIG_FILE = f"{INSTALL_DIR}/.config.json"
API_TOKEN_FILE = f"{INSTALL_DIR}/.eero_token"
LOG_DIR = f"{INSTALL_DIR}/logs"
FRONTEND_DIR = f"{INSTALL_DIR}/frontend"

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

def load_config():
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, 'r') as f:
                return json.load(f)
    except Exception as e:
        logging.error(f"Config load error: {e}")
    return {}

def save_config(config):
    try:
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)
        os.chmod(CONFIG_FILE, 0o600)
        subprocess.run(['chown', 'eero:eero', CONFIG_FILE], check=False)
        return True
    except Exception as e:
        logging.error(f"Config save error: {e}")
        return False

def get_api_url():
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
        config = load_config()
        return config.get('network_id', '20478317')  # Your current network ID
    
    def reload_network_id(self):
        self.network_id = self.load_network_id()
    
    def reload_token(self):
        self.api_token = self.load_token()
    
    def reload_api_url(self):
        self.api_url = get_api_url()
        self.api_base = f"https://{self.api_url}/2.2"
    
    def get_headers(self):
        headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'Eero-Dashboard-Lightsail/5.2.4'
        }
        if self.api_token:
            headers['X-User-Token'] = self.api_token
        return headers
    
    def get_all_devices(self):
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
    return default if value is None else str(value)

def safe_lower(value, default=''):
    return default if value is None else str(value).lower()

def categorize_device_os(device):
    all_text = f"{safe_lower(device.get('manufacturer'))} {safe_lower(device.get('device_type'))} {safe_lower(device.get('hostname'))} {safe_lower(device.get('model_name'))} {safe_lower(device.get('display_name'))}"
    
    for keyword in ['apple', 'iphone', 'ipad', 'mac', 'macbook', 'ios']:
        if keyword in all_text:
            return 'iOS'
    
    for keyword in ['android', 'samsung', 'google', 'pixel', 'xiaomi', 'lg', 'motorola', 'sony', 'oneplus']:
        if keyword in all_text:
            return 'Android'
    
    for keyword in ['windows', 'microsoft', 'dell', 'hp', 'lenovo', 'asus', 'surface', 'pc', 'laptop']:
        if keyword in all_text:
            return 'Windows'
    
    return 'Other'

def estimate_signal_from_bars(score_bars):
    mapping = {5: -45, 4: -55, 3: -65, 2: -75, 1: -85, 0: -90}
    return mapping.get(score_bars, -90)

def get_signal_quality(score_bars):
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
    global data_cache
    try:
        all_devices = eero_api.get_all_devices()
        if not all_devices:
            logging.warning("No devices returned from API")
            return
        
        wireless_devices = [
            device for device in all_devices 
            if device.get('connected') and (
                safe_lower(device.get('connection_type')) == 'wireless' or 
                device.get('wireless')
            )
        ]
        
        current_time = datetime.now()
        
        data_cache['connected_users'].append({
            'timestamp': current_time.isoformat(),
            'count': len(wireless_devices)
        })
        
        two_hours_ago = current_time - timedelta(hours=2)
        data_cache['connected_users'] = [
            entry for entry in data_cache['connected_users']
            if datetime.fromisoformat(entry['timestamp']) > two_hours_ago
        ]
        
        device_os = {'iOS': 0, 'Android': 0, 'Windows': 0, 'Other': 0}
        freq_distribution = {'2.4GHz': 0, '5GHz': 0, '6GHz': 0, 'Unknown': 0}
        signal_strengths = []
        device_list = []
        
        for device in wireless_devices:
            os_type = categorize_device_os(device)
            device_os[os_type] += 1
            
            connectivity = device.get('connectivity', {}) or {}
            interface = device.get('interface', {}) or {}
            freq_display, freq_band = parse_frequency(interface)
            
            if freq_band in freq_distribution:
                freq_distribution[freq_band] += 1
            
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
        
        data_cache['device_os'] = device_os
        data_cache['frequency_distribution'] = freq_distribution
        data_cache['devices'] = sorted(device_list, key=lambda x: x['name'].lower())
        
        if signal_strengths:
            avg_signal = sum(signal_strengths) / len(signal_strengths)
            data_cache['signal_strength_avg'].append({
                'timestamp': current_time.isoformat(),
                'avg_dbm': round(avg_signal, 2)
            })
            
            data_cache['signal_strength_avg'] = [
                entry for entry in data_cache['signal_strength_avg']
                if datetime.fromisoformat(entry['timestamp']) > two_hours_ago
            ]
        
        data_cache['last_update'] = current_time.isoformat()
        logging.info(f"Cache updated: {len(wireless_devices)} wireless devices")
        
    except Exception as e:
        logging.error(f"Cache update error: {e}")

def run_speedtest():
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
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/api/dashboard')
def get_dashboard_data():
    update_cache()
    return jsonify(data_cache)

@app.route('/api/devices')
def get_devices():
    return jsonify({
        'devices': data_cache.get('devices', []),
        'count': len(data_cache.get('devices', []))
    })

@app.route('/api/speedtest/start', methods=['POST'])
def start_speedtest():
    if data_cache['speedtest_running']:
        return jsonify({'status': 'running'}), 409
    
    threading.Thread(target=run_speedtest, daemon=True).start()
    return jsonify({'status': 'started'})

@app.route('/api/speedtest/status')
def get_speedtest_status():
    return jsonify({
        'running': data_cache['speedtest_running'],
        'result': data_cache['speedtest_result']
    })

@app.route('/api/health')
def health_check():
    return jsonify({
        'status': 'ok',
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/version')
def get_version():
    config = load_config()
    environment = config.get('environment', 'production')
    
    return jsonify({
        'version': CURRENT_VERSION,
        'name': 'Eero Dashboard (Lightsail)',
        'network_id': config.get('network_id', eero_api.network_id),
        'environment': environment,
        'api_url': config.get('api_url', 'api-user.e2ro.com')
    })

@app.route('/api/admin/network-id', methods=['POST'])
def change_network_id():
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
                with open(API_TOKEN_FILE, 'w') as f:
                    f.write(token)
                os.chmod(API_TOKEN_FILE, 0o600)
                subprocess.run(['chown', 'eero:eero', API_TOKEN_FILE], check=False)
                
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
    
    logging.info("Performing initial cache update...")
    
    try:
        if 'eero_api' in globals() and eero_api.network_id:
            update_cache()
            logging.info("Initial cache update complete")
        else:
            logging.warning("Eero API not configured - please configure through web interface")
    except Exception as e:
        logging.error(f"Initial cache update failed: {e}")
    
    logging.info("Starting Flask server on 0.0.0.0:5000")
    logging.info("=" * 60)
    
    try:
        app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
    except Exception as e:
        logging.error(f"Failed to start server: {e}")
        sys.exit(1)
EOF

# Create frontend HTML (using your existing frontend)
cat > /home/eero/dashboard/frontend/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Eero Dashboard v5.2.4 (Lightsail)</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            background: linear-gradient(135deg, #001a33 0%, #003366 100%); 
            font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif; 
            color: #fff; 
            overflow: hidden; 
            height: 100vh; 
        }
        .header { 
            background: rgba(0,20,40,.9); 
            padding: 8px 20px; 
            display: flex; 
            justify-content: space-between; 
            align-items: center; 
            border-bottom: 2px solid rgba(77,166,255,.3); 
        }
        .header-title { 
            font-size: 18px; 
            font-weight: 600; 
            color: #4da6ff; 
        }
        .header-actions { 
            display: flex; 
            gap: 10px; 
            align-items: center; 
        }
        .header-btn { 
            padding: 6px 12px; 
            background: rgba(77,166,255,.2); 
            border: 2px solid #4da6ff; 
            border-radius: 6px; 
            color: #fff; 
            cursor: pointer; 
            display: flex; 
            align-items: center; 
            gap: 6px; 
            font-size: 12px; 
            transition: all .3s; 
        }
        .header-btn:hover { 
            background: rgba(77,166,255,.4); 
            transform: translateY(-2px); 
        }
        .status-indicator { 
            display: flex; 
            align-items: center; 
            gap: 6px; 
            padding: 6px 12px; 
            background: rgba(0,0,0,.3); 
            border-radius: 15px; 
            font-size: 11px; 
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
            50% { opacity: .5; } 
        }
        .pi-icon { 
            position: fixed; 
            bottom: 20px; 
            right: 20px; 
            width: 30px; 
            height: 30px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
            border-radius: 50%; 
            display: flex; 
            align-items: center; 
            justify-content: center; 
            cursor: pointer; 
            box-shadow: 0 4px 20px rgba(102,126,234,.4); 
            transition: all .3s; 
            z-index: 999; 
            font-size: 16px; 
            font-weight: 700; 
            color: #fff; 
            border: 2px solid rgba(255,255,255,.3); 
        }
        .pi-icon:hover { 
            transform: scale(1.1) rotate(180deg); 
        }
        .dashboard-container { 
            display: grid; 
            grid-template-columns: 1fr 1fr 1fr 1fr; 
            gap: 10px; 
            padding: 10px; 
            height: calc(100vh - 60px); 
        }
        .chart-card { 
            background: rgba(0,40,80,.7); 
            border-radius: 10px; 
            padding: 10px; 
            box-shadow: 0 8px 32px rgba(0,0,0,.3); 
            border: 1px solid rgba(255,255,255,.1); 
            display: flex; 
            flex-direction: column; 
        }
        .chart-title { 
            font-size: 14px; 
            font-weight: 600; 
            margin-bottom: 8px; 
            text-align: center; 
            color: #4da6ff; 
            text-transform: uppercase; 
        }
        .chart-subtitle { 
            font-size: 11px; 
            text-align: center; 
            color: rgba(255,255,255,.6); 
            margin-bottom: 8px; 
        }
        .chart-container { 
            flex: 1; 
            position: relative; 
            min-height: 0; 
            display: flex; 
            align-items: center; 
            justify-content: center; 
            max-height: calc(100% - 50px); 
        }
        canvas { 
            max-width: 100% !important; 
            max-height: 100% !important; 
            width: auto !important; 
            height: auto !important; 
        }
        
        .modal { 
            display: none; 
            position: fixed; 
            z-index: 1000; 
            left: 0; 
            top: 0; 
            width: 100%; 
            height: 100%; 
            background: rgba(0,0,0,.8); 
            overflow: auto; 
        }
        .modal.active { 
            display: flex; 
            align-items: center; 
            justify-content: center; 
        }
        .modal-content { 
            background: linear-gradient(135deg, #001a33 0%, #003366 100%); 
            border-radius: 15px; 
            padding: 30px; 
            max-width: 800px; 
            width: 90%; 
            max-height: 80vh; 
            overflow-y: auto; 
            box-shadow: 0 10px 50px rgba(0,0,0,.5); 
            border: 2px solid rgba(77,166,255,.3); 
            position: relative; 
        }
        .modal-header { 
            display: flex; 
            justify-content: space-between; 
            align-items: center; 
            margin-bottom: 20px; 
            padding-bottom: 15px; 
            border-bottom: 2px solid rgba(77,166,255,.3); 
        }
        .modal-title { 
            font-size: 24px; 
            font-weight: 700; 
            color: #4da6ff; 
        }
        .modal-close { 
            font-size: 28px; 
            cursor: pointer; 
            color: #fff; 
            background: none; 
            border: none; 
            transition: all .3s; 
        }
        .modal-close:hover { 
            color: #ff6b6b; 
            transform: rotate(90deg); 
        }
        
        .device-grid { 
            display: grid; 
            gap: 15px; 
            margin-top: 20px; 
        }
        .device-item { 
            background: rgba(0,40,80,.5); 
            padding: 15px; 
            border-radius: 10px; 
            border: 1px solid rgba(77,166,255,.2); 
            transition: all .3s; 
        }
        .device-item:hover { 
            border-color: #4da6ff; 
            transform: translateX(5px); 
        }
        .device-name { 
            font-size: 16px; 
            font-weight: 600; 
            color: #4da6ff; 
            margin-bottom: 8px; 
        }
        .device-info { 
            display: grid; 
            grid-template-columns: 1fr 1fr; 
            gap: 8px; 
            font-size: 12px; 
        }
        .device-info-item { 
            display: flex; 
            justify-content: space-between; 
            padding: 4px 0; 
        }
        .device-label { 
            color: rgba(255,255,255,.6); 
        }
        .device-value { 
            color: #fff; 
            font-weight: 500; 
        }
        .signal-bar { 
            width: 100%; 
            height: 8px; 
            background: rgba(255,255,255,.1); 
            border-radius: 4px; 
            overflow: hidden; 
            margin-top: 8px; 
        }
        .signal-fill { 
            height: 100%; 
            background: linear-gradient(90deg, #51cf66 0%, #4da6ff 100%); 
            transition: width .3s; 
        }
        
        .speedtest-content { 
            text-align: center; 
        }
        .speedtest-btn { 
            padding: 15px 30px; 
            background: linear-gradient(135deg, #4da6ff 0%, #667eea 100%); 
            border: none; 
            border-radius: 10px; 
            color: #fff; 
            font-size: 16px; 
            font-weight: 600; 
            cursor: pointer; 
            margin: 20px 0; 
            transition: all .3s; 
        }
        .speedtest-btn:hover { 
            transform: translateY(-2px); 
            box-shadow: 0 5px 20px rgba(77,166,255,.4); 
        }
        .speedtest-btn:disabled { 
            opacity: .5; 
            cursor: not-allowed; 
        }
        .speedtest-results { 
            display: grid; 
            grid-template-columns: repeat(3, 1fr); 
            gap: 20px; 
            margin-top: 30px; 
        }
        .speedtest-metric { 
            background: rgba(0,40,80,.5); 
            padding: 20px; 
            border-radius: 10px; 
            border: 1px solid rgba(77,166,255,.2); 
        }
        .speedtest-label { 
            font-size: 12px; 
            color: rgba(255,255,255,.6); 
            margin-bottom: 8px; 
            text-transform: uppercase; 
        }
        .speedtest-value { 
            font-size: 32px; 
            font-weight: 700; 
            color: #4da6ff; 
        }
        .speedtest-unit { 
            font-size: 14px; 
            color: rgba(255,255,255,.7); 
            margin-left: 5px; 
        }
        .spinner { 
            border: 4px solid rgba(255,255,255,.1); 
            border-top: 4px solid #4da6ff; 
            border-radius: 50%; 
            width: 40px; 
            height: 40px; 
            animation: spin 1s linear infinite; 
            margin: 20px auto; 
        }
        @keyframes spin { 
            0% { transform: rotate(0deg); } 
            100% { transform: rotate(360deg); } 
        }
        
        .admin-menu { 
            display: grid; 
            gap: 15px; 
        }
        .admin-btn { 
            padding: 15px; 
            background: rgba(77,166,255,.2); 
            border: 2px solid #4da6ff; 
            border-radius: 10px; 
            color: #fff; 
            font-size: 14px; 
            cursor: pointer; 
            transition: all .3s; 
            display: flex; 
            align-items: center; 
            gap: 10px; 
        }
        .admin-btn:hover { 
            background: rgba(77,166,255,.4); 
            transform: translateX(5px); 
        }
        .admin-btn i { 
            font-size: 20px; 
        }
        .admin-info { 
            background: rgba(0,40,80,.5); 
            padding: 15px; 
            border-radius: 10px; 
            margin-bottom: 20px; 
        }
        .admin-info-item { 
            display: flex; 
            justify-content: space-between; 
            padding: 8px 0; 
            border-bottom: 1px solid rgba(255,255,255,.1); 
        }
        .admin-info-item:last-child { 
            border-bottom: none; 
        }
        
        .form-group { 
            margin: 20px 0; 
        }
        .form-label { 
            display: block; 
            margin-bottom: 8px; 
            color: #4da6ff; 
            font-weight: 600; 
        }
        .form-input { 
            width: 100%; 
            padding: 12px; 
            background: rgba(0,40,80,.5); 
            border: 2px solid rgba(77,166,255,.3); 
            border-radius: 8px; 
            color: #fff; 
            font-size: 14px; 
        }
        .form-input:focus { 
            outline: none; 
            border-color: #4da6ff; 
        }
        .form-btn { 
            padding: 12px 24px; 
            background: linear-gradient(135deg, #4da6ff 0%, #667eea 100%); 
            border: none; 
            border-radius: 8px; 
            color: #fff; 
            font-size: 14px; 
            font-weight: 600; 
            cursor: pointer; 
            transition: all .3s; 
        }
        .form-btn:hover { 
            transform: translateY(-2px); 
        }
        .form-btn:disabled { 
            opacity: .5; 
            cursor: not-allowed; 
        }
        
        .alert { 
            padding: 12px 20px; 
            border-radius: 8px; 
            margin: 15px 0; 
            font-size: 14px; 
        }
        .alert-success { 
            background: rgba(81,207,102,.2); 
            border: 1px solid #51cf66; 
            color: #51cf66; 
        }
        .alert-error { 
            background: rgba(255,107,107,.2); 
            border: 1px solid #ff6b6b; 
            color: #ff6b6b; 
        }
        .alert-info { 
            background: rgba(77,166,255,.2); 
            border: 1px solid #4da6ff; 
            color: #4da6ff; 
        }

        .setup-notice {
            background: rgba(255,193,7,.2);
            border: 2px solid #ffc107;
            color: #ffc107;
            padding: 20px;
            border-radius: 10px;
            margin: 20px;
            text-align: center;
        }
        .setup-notice h3 {
            margin-bottom: 10px;
            font-size: 18px;
        }
        .setup-notice p {
            margin-bottom: 15px;
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="header-title">Network Dashboard v5.2.4 (Lightsail)</div>
        <div class="header-actions">
            <div class="status-indicator">
                <div class="status-dot"></div>
                <span id="lastUpdate">Loading...</span>
            </div>
            <button class="header-btn" onclick="showDevices()">
                <i class="fas fa-list"></i><span>Devices</span>
            </button>
            <button class="header-btn" onclick="openModal('speedtestModal')">
                <i class="fas fa-gauge-high"></i><span>Speed Test</span>
            </button>
        </div>
    </div>
    
    <div class="dashboard-container">
        <div class="chart-card">
            <div class="chart-title">Connected Users</div>
            <div class="chart-subtitle">Wireless devices over time</div>
            <div class="chart-container"><canvas id="usersChart"></canvas></div>
        </div>
        <div class="chart-card">
            <div class="chart-title">Device OS</div>
            <div class="chart-subtitle" id="deviceOsSubtitle">Loading...</div>
            <div class="chart-container"><canvas id="deviceOSChart"></canvas></div>
        </div>
        <div class="chart-card">
            <div class="chart-title">Frequency Distribution</div>
            <div class="chart-subtitle" id="frequencySubtitle">Loading...</div>
            <div class="chart-container"><canvas id="frequencyChart"></canvas></div>
        </div>
        <div class="chart-card">
            <div class="chart-title">Average Signal Strength</div>
            <div class="chart-subtitle">Network-wide average (dBm)</div>
            <div class="chart-container"><canvas id="signalStrengthChart"></canvas></div>
        </div>
    </div>
    
    <div class="pi-icon" onclick="showAdmin()">π</div>
    
    <!-- Setup Notice (shown when not configured) -->
    <div id="setupNotice" class="setup-notice" style="display: none;">
        <h3><i class="fas fa-exclamation-triangle"></i> Configuration Required</h3>
        <p>Please configure your API authentication to start monitoring.</p>
        <button class="form-btn" onclick="showAdmin()">Open Admin Panel</button>
    </div>
    
    <!-- Devices Modal -->
    <div id="devicesModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <h2 class="modal-title">Connected Devices</h2>
                <button class="modal-close" onclick="closeModal('devicesModal')">&times;</button>
            </div>
            <div id="devicesList" class="device-grid"></div>
        </div>
    </div>
    
    <!-- Speed Test Modal -->
    <div id="speedtestModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <h2 class="modal-title">Speed Test</h2>
                <button class="modal-close" onclick="closeModal('speedtestModal')">&times;</button>
            </div>
            <div class="speedtest-content">
                <button id="startSpeedtest" class="speedtest-btn" onclick="runSpeedTest()">
                    Start Speed Test
                </button>
                <div id="speedtestStatus"></div>
                <div id="speedtestResults"></div>
            </div>
        </div>
    </div>
    
    <!-- Admin Modal -->
    <div id="adminModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <h2 class="modal-title">Admin Panel</h2>
                <button class="modal-close" onclick="closeModal('adminModal')">&times;</button>
            </div>
            <div class="admin-info" id="adminInfo"></div>
            <div class="admin-menu">
                <button class="admin-btn" onclick="showNetworkIdForm()">
                    <i class="fas fa-network-wired"></i><span>Change Network ID</span>
                </button>
                <button class="admin-btn" onclick="showReauthorizeForm()">
                    <i class="fas fa-key"></i><span>Reauthorize API</span>
                </button>
            </div>
            <div id="adminFormContainer"></div>
            <div id="adminAlerts"></div>
        </div>
    </div>
    
    <script>
        let charts = {};
        let speedtestInterval = null;
        let isConfigured = false;
        
        function initCharts() {
            const commonOptions = {
                maintainAspectRatio: false,
                responsive: true,
                plugins: {
                    legend: {
                        labels: {
                            color: "#fff"
                        }
                    }
                }
            };
            
            charts.users = new Chart(document.getElementById("usersChart").getContext("2d"), {
                type: "line",
                data: {
                    labels: [],
                    datasets: [{
                        label: "Connected",
                        data: [],
                        borderColor: "#4da6ff",
                        backgroundColor: "rgba(77,166,255,0.1)",
                        tension: 0.4,
                        fill: true
                    }]
                },
                options: {
                    ...commonOptions,
                    scales: {
                        y: { ticks: { color: "#fff" } },
                        x: { ticks: { color: "#fff" } }
                    }
                }
            });
            
            charts.deviceOS = new Chart(document.getElementById("deviceOSChart").getContext("2d"), {
                type: "doughnut",
                data: {
                    labels: ["iOS", "Android", "Windows", "Other"],
                    datasets: [{
                        data: [0, 0, 0, 0],
                        backgroundColor: ["#4da6ff", "#51cf66", "#74c0fc", "#ffd43b"]
                    }]
                },
                options: commonOptions
            });
            
            charts.frequency = new Chart(document.getElementById("frequencyChart").getContext("2d"), {
                type: "doughnut",
                data: {
                    labels: ["2.4 GHz", "5 GHz", "6 GHz"],
                    datasets: [{
                        data: [0, 0, 0],
                        backgroundColor: ["#ff922b", "#4da6ff", "#b197fc"]
                    }]
                },
                options: commonOptions
            });
            
            charts.signalStrength = new Chart(document.getElementById("signalStrengthChart").getContext("2d"), {
                type: "line",
                data: {
                    labels: [],
                    datasets: [{
                        label: "Avg Signal",
                        data: [],
                        borderColor: "#51cf66",
                        backgroundColor: "rgba(81,207,102,0.1)",
                        tension: 0.4,
                        fill: true
                    }]
                },
                options: {
                    ...commonOptions,
                    scales: {
                        y: { ticks: { color: "#fff" } },
                        x: { ticks: { color: "#fff" } }
                    }
                }
            });
        }
        
        async function updateDashboard() {
            try {
                const response = await fetch("/api/dashboard");
                const data = await response.json();
                
                if (data.connected_users && data.connected_users.length > 0) {
                    isConfigured = true;
                    document.getElementById("setupNotice").style.display = "none";
                } else if (!isConfigured) {
                    document.getElementById("setupNotice").style.display = "block";
                }
                
                charts.users.data.labels = data.connected_users.map(entry => 
                    new Date(entry.timestamp).toLocaleTimeString()
                );
                charts.users.data.datasets[0].data = data.connected_users.map(entry => entry.count);
                charts.users.update();
                
                const deviceOS = data.device_os || {};
                charts.deviceOS.data.datasets[0].data = [
                    deviceOS.iOS || 0,
                    deviceOS.Android || 0,
                    deviceOS.Windows || 0,
                    deviceOS.Other || 0
                ];
                charts.deviceOS.update();
                document.getElementById("deviceOsSubtitle").textContent = 
                    `${Object.values(deviceOS).reduce((a, b) => a + b, 0)} devices`;
                
                const freqDist = data.frequency_distribution || {};
                charts.frequency.data.datasets[0].data = [
                    freqDist["2.4GHz"] || 0,
                    freqDist["5GHz"] || 0,
                    freqDist["6GHz"] || 0
                ];
                charts.frequency.update();
                document.getElementById("frequencySubtitle").textContent = 
                    `${(freqDist["2.4GHz"] || 0) + (freqDist["5GHz"] || 0) + (freqDist["6GHz"] || 0)} devices`;
                
                charts.signalStrength.data.labels = data.signal_strength_avg.map(entry => 
                    new Date(entry.timestamp).toLocaleTimeString()
                );
                charts.signalStrength.data.datasets[0].data = data.signal_strength_avg.map(entry => entry.avg_dbm);
                charts.signalStrength.update();
                
                document.getElementById("lastUpdate").textContent = 
                    `Updated: ${new Date(data.last_update).toLocaleTimeString()}`;
                    
            } catch (error) {
                console.error("Dashboard update error:", error);
                document.getElementById("lastUpdate").textContent = "Update failed";
            }
        }
        
        function openModal(modalId) {
            document.getElementById(modalId).classList.add("active");
        }
        
        function closeModal(modalId) {
            document.getElementById(modalId).classList.remove("active");
        }
        
        window.onclick = function(event) {
            if (event.target.classList.contains("modal")) {
                event.target.classList.remove("active");
            }
        }
        
        async function showDevices() {
            try {
                const response = await fetch("/api/devices");
                const data = await response.json();
                const container = document.getElementById("devicesList");
                
                if (!data.devices || data.devices.length === 0) {
                    container.innerHTML = '<p style="text-align:center;color:rgba(255,255,255,.6);">No devices found</p>';
                } else {
                    container.innerHTML = data.devices.map(device => `
                        <div class="device-item">
                            <div class="device-name">${device.name}</div>
                            <div class="device-info">
                                <div class="device-info-item">
                                    <span class="device-label">IP:</span>
                                    <span class="device-value">${device.ip}</span>
                                </div>
                                <div class="device-info-item">
                                    <span class="device-label">MAC:</span>
                                    <span class="device-value">${device.mac}</span>
                                </div>
                                <div class="device-info-item">
                                    <span class="device-label">Manufacturer:</span>
                                    <span class="device-value">${device.manufacturer}</span>
                                </div>
                                <div class="device-info-item">
                                    <span class="device-label">OS:</span>
                                    <span class="device-value">${device.device_os}</span>
                                </div>
                                <div class="device-info-item">
                                    <span class="device-label">Frequency:</span>
                                    <span class="device-value">${device.frequency}</span>
                                </div>
                                <div class="device-info-item">
                                    <span class="device-label">Signal:</span>
                                    <span class="device-value">${device.signal_quality} (${device.signal_avg_dbm})</span>
                                </div>
                            </div>
                            <div class="signal-bar">
                                <div class="signal-fill" style="width: ${device.signal_avg}%"></div>
                            </div>
                        </div>
                    `).join("");
                }
                
                openModal("devicesModal");
            } catch (error) {
                console.error("Error loading devices:", error);
            }
        }
        
        async function runSpeedTest() {
            const button = document.getElementById("startSpeedtest");
            const status = document.getElementById("speedtestStatus");
            const results = document.getElementById("speedtestResults");
            
            button.disabled = true;
            status.innerHTML = '<div class="spinner"></div><p>Running speed test...</p>';
            results.innerHTML = "";
            
            try {
                await fetch("/api/speedtest/start", { method: "POST" });
                
                speedtestInterval = setInterval(async () => {
                    const response = await fetch("/api/speedtest/status");
                    const data = await response.json();
                    
                    if (!data.running && data.result) {
                        clearInterval(speedtestInterval);
                        button.disabled = false;
                        status.innerHTML = "";
                        
                        if (data.result.error) {
                            results.innerHTML = `<div class="alert alert-error">Error: ${data.result.error}</div>`;
                        } else {
                            results.innerHTML = `
                                <div class="speedtest-results">
                                    <div class="speedtest-metric">
                                        <div class="speedtest-label">Download</div>
                                        <div class="speedtest-value">${data.result.download}<span class="speedtest-unit">Mbps</span></div>
                                    </div>
                                    <div class="speedtest-metric">
                                        <div class="speedtest-label">Upload</div>
                                        <div class="speedtest-value">${data.result.upload}<span class="speedtest-unit">Mbps</span></div>
                                    </div>
                                    <div class="speedtest-metric">
                                        <div class="speedtest-label">Ping</div>
                                        <div class="speedtest-value">${data.result.ping}<span class="speedtest-unit">ms</span></div>
                                    </div>
                                </div>
                            `;
                        }
                    }
                }, 2000);
                
            } catch (error) {
                button.disabled = false;
                status.innerHTML = "";
                results.innerHTML = '<div class="alert alert-error">Failed to start speed test</div>';
            }
        }
        
        async function showAdmin() {
            await loadAdminInfo();
            openModal("adminModal");
        }
        
        async function loadAdminInfo() {
            try {
                const response = await fetch("/api/version");
                const data = await response.json();
                
                document.getElementById("adminInfo").innerHTML = `
                    <div class="admin-info-item">
                        <span>Version:</span>
                        <span>${data.version}</span>
                    </div>
                    <div class="admin-info-item">
                        <span>Network ID:</span>
                        <span>${data.network_id || 'Not configured'}</span>
                    </div>
                    <div class="admin-info-item">
                        <span>Environment:</span>
                        <span>${data.environment}</span>
                    </div>
                    <div class="admin-info-item">
                        <span>API URL:</span>
                        <span>${data.api_url}</span>
                    </div>
                `;
            } catch (error) {
                console.error("Error loading admin info:", error);
            }
        }
        
        function showAlert(message, type = "info") {
            const alertsContainer = document.getElementById("adminAlerts");
            alertsContainer.innerHTML = `<div class="alert alert-${type}">${message}</div>`;
            setTimeout(() => {
                alertsContainer.innerHTML = "";
            }, 5000);
        }
        
        function showNetworkIdForm() {
            document.getElementById("adminFormContainer").innerHTML = `
                <div class="form-group">
                    <label class="form-label">New Network ID:</label>
                    <input type="text" id="newNetworkId" class="form-input" placeholder="Enter network ID" value="20478317">
                    <button class="form-btn" style="margin-top:10px" onclick="changeNetworkId()">
                        Update Network ID
                    </button>
                </div>
            `;
        }
        
        async function changeNetworkId() {
            const newId = document.getElementById("newNetworkId").value.trim();
            
            if (!newId || !newId.match(/^\d+$/)) {
                showAlert("Invalid network ID", "error");
                return;
            }
            
            try {
                const response = await fetch("/api/admin/network-id", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ network_id: newId })
                });
                
                const data = await response.json();
                showAlert(data.message, data.success ? "success" : "error");
                
                if (data.success) {
                    document.getElementById("adminFormContainer").innerHTML = "";
                    setTimeout(() => location.reload(), 2000);
                }
            } catch (error) {
                showAlert("Failed to update network ID", "error");
            }
        }
        
        function showReauthorizeForm() {
            document.getElementById("adminFormContainer").innerHTML = `
                <div class="form-group">
                    <label class="form-label">Email:</label>
                    <input type="email" id="authEmail" class="form-input" placeholder="Enter email">
                    <button class="form-btn" style="margin-top:10px" onclick="sendAuthCode()">
                        Send Code
                    </button>
                </div>
                <div id="codeFormContainer"></div>
            `;
        }
        
        async function sendAuthCode() {
            const email = document.getElementById("authEmail").value.trim();
            
            if (!email || !email.includes("@")) {
                showAlert("Invalid email", "error");
                return;
            }
            
            try {
                const response = await fetch("/api/admin/reauthorize", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ step: "send", email })
                });
                
                const data = await response.json();
                showAlert(data.message, data.success ? "success" : "error");
                
                if (data.success) {
                    document.getElementById("codeFormContainer").innerHTML = `
                        <div class="form-group">
                            <label class="form-label">Verification Code:</label>
                            <input type="text" id="authCode" class="form-input" placeholder="Enter code from email">
                            <button class="form-btn" style="margin-top:10px" onclick="verifyAuthCode()">
                                Verify
                            </button>
                        </div>
                    `;
                }
            } catch (error) {
                showAlert("Failed to send code", "error");
            }
        }
        
        async function verifyAuthCode() {
            const code = document.getElementById("authCode").value.trim();
            
            if (!code) {
                showAlert("Code required", "error");
                return;
            }
            
            try {
                const response = await fetch("/api/admin/reauthorize", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ step: "verify", code })
                });
                
                const data = await response.json();
                showAlert(data.message, data.success ? "success" : "error");
                
                if (data.success) {
                    document.getElementById("adminFormContainer").innerHTML = "";
                    document.getElementById("codeFormContainer").innerHTML = "";
                }
            } catch (error) {
                showAlert("Failed to verify code", "error");
            }
        }
        
        window.addEventListener("load", () => {
            initCharts();
            updateDashboard();
            setInterval(updateDashboard, 60000);
        });
    </script>
</body>
</html>
EOF

# Create initial configuration with your network ID
cat > /home/eero/dashboard/.config.json << 'EOF'
{
  "network_id": "20478317",
  "environment": "production",
  "api_url": "api-user.e2ro.com",
  "last_updated": "2024-01-01T00:00:00"
}
EOF

# Set permissions
chown -R eero:eero /home/eero/dashboard
chmod 600 /home/eero/dashboard/.config.json

# Create systemd service
cat > /etc/systemd/system/eero-dashboard.service << 'EOF'
[Unit]
Description=Eero Dashboard v5.2.4 (Lightsail)
After=network.target

[Service]
Type=simple
User=eero
WorkingDirectory=/home/eero/dashboard/backend
Environment="PATH=/home/eero/dashboard/venv/bin"
ExecStart=/home/eero/dashboard/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 --timeout 120 app:app
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx
cat > /etc/nginx/sites-available/eero-dashboard << 'EOF'
server {
    listen 80;
    server_name _;
    
    client_max_body_size 10M;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/eero-dashboard /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Start services
systemctl daemon-reload
systemctl enable eero-dashboard
systemctl start eero-dashboard
systemctl enable nginx
systemctl restart nginx

# Configure firewall
ufw allow 80
ufw allow 22
ufw --force enable

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "============================================================"
echo "MiniRack Dashboard Deployment Complete!"
echo "============================================================"
echo "Dashboard URL: http://$PUBLIC_IP"
echo "Network ID: 20478317 (pre-configured)"
echo ""
echo "Next Steps:"
echo "1. Visit the dashboard URL above"
echo "2. Click the π icon (admin panel)"
echo "3. Click 'Reauthorize API'"
echo "4. Enter your email and verification code"
echo ""
echo "The dashboard will then show your real-time network data!"
echo "============================================================"