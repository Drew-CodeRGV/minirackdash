#!/usr/bin/env python3
"""
MiniRack Dashboard - Production Ready (Minimal)
Serves the full macOS replica dashboard from external template
"""
import os
import sys
import json
import requests
import speedtest
import threading
import time
import subprocess
from datetime import datetime, timedelta
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import logging

# Configuration
VERSION = "5.2.4-production"
CONFIG_FILE = "/opt/eero/app/config.json"
TOKEN_FILE = "/opt/eero/app/.eero_token"
TEMPLATE_FILE = "/opt/eero/app/index.html"

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
    
    def get_network_info(self):
        """Get network information including name"""
        try:
            url = f"{self.api_base}/networks/{self.network_id}"
            response = self.session.get(url, headers=self.get_headers(), timeout=10)
            response.raise_for_status()
            data = response.json()
            
            if 'data' in data:
                network_data = data['data']
                logging.info(f"Retrieved network info: {network_data.get('name', 'Unknown')}")
                return network_data
            return {}
        except Exception as e:
            logging.error(f"Network info fetch error: {e}")
            return {}
    
    def get_all_devices(self):
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

# Data cache - matches macOS version structure
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

def detect_device_os(device):
    """Detect device OS from manufacturer and hostname"""
    manufacturer = str(device.get('manufacturer', '')).lower()
    hostname = str(device.get('hostname', '')).lower()
    text = f"{manufacturer} {hostname}"
    
    if any(k in text for k in ['apple', 'iphone', 'ipad', 'mac', 'ios']):
        return 'iOS'
    elif any(k in text for k in ['android', 'samsung', 'google', 'pixel', 'lg', 'htc']):
        return 'Android'
    elif any(k in text for k in ['windows', 'microsoft', 'dell', 'hp', 'lenovo', 'asus']):
        return 'Windows'
    else:
        return 'Other'

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

def get_signal_quality(signal_dbm):
    """Get signal quality description"""
    try:
        if not signal_dbm or signal_dbm == 'N/A':
            return 'Unknown'
        dbm = float(str(signal_dbm).replace(' dBm', '').strip())
        if dbm >= -50:
            return 'Excellent'
        elif dbm >= -60:
            return 'Very Good'
        elif dbm >= -70:
            return 'Good'
        elif dbm >= -80:
            return 'Fair'
        else:
            return 'Poor'
    except:
        return 'Unknown'

def update_cache():
    """Update data cache with latest device information"""
    global data_cache
    try:
        all_devices = eero_api.get_all_devices()
        wireless_devices = [d for d in all_devices if d.get('connected') and d.get('wireless')]
        
        # Process devices for detailed view
        device_list = []
        os_counts = {'iOS': 0, 'Android': 0, 'Windows': 0, 'Other': 0}
        freq_counts = {'2.4GHz': 0, '5GHz': 0, '6GHz': 0}
        signal_values = []
        
        for device in wireless_devices:
            # OS Detection
            device_os = detect_device_os(device)
            os_counts[device_os] += 1
            
            # Frequency Detection
            interface_info = device.get('interface', {})
            freq_display, freq_band = parse_frequency(interface_info)
            if freq_band in freq_counts:
                freq_counts[freq_band] += 1
            
            # Signal Strength
            signal_dbm = interface_info.get('signal_dbm', 'N/A')
            signal_percent = convert_signal_dbm_to_percent(signal_dbm)
            signal_quality = get_signal_quality(signal_dbm)
            
            if signal_dbm != 'N/A':
                try:
                    signal_values.append(float(str(signal_dbm).replace(' dBm', '').strip()))
                except:
                    pass
            
            device_list.append({
                'name': device.get('nickname') or device.get('hostname') or 'Unknown Device',
                'ip': ', '.join(device.get('ips', [])) if device.get('ips') else 'N/A',
                'mac': device.get('mac', 'N/A'),
                'manufacturer': device.get('manufacturer', 'Unknown'),
                'device_os': device_os,
                'frequency': freq_display,
                'frequency_band': freq_band,
                'signal_avg_dbm': f"{signal_dbm} dBm" if signal_dbm != 'N/A' else 'N/A',
                'signal_avg': signal_percent,
                'signal_quality': signal_quality
            })
        
        # Update connected users history (keep last 168 points for 1 week of hourly data)
        current_time = datetime.now()
        connected_users = data_cache.get('connected_users', [])
        connected_users.append({
            'timestamp': current_time.isoformat(),
            'count': len(wireless_devices)
        })
        if len(connected_users) > 168:  # Keep 1 week of hourly data
            connected_users = connected_users[-168:]
        
        # Update signal strength history (keep last 168 points for 1 week of hourly data)
        signal_strength_avg = data_cache.get('signal_strength_avg', [])
        if signal_values:
            avg_signal = sum(signal_values) / len(signal_values)
            signal_strength_avg.append({
                'timestamp': current_time.isoformat(),
                'avg_dbm': round(avg_signal, 1)
            })
        if len(signal_strength_avg) > 168:  # Keep 1 week of hourly data
            signal_strength_avg = signal_strength_avg[-168:]
        
        # Update cache
        data_cache.update({
            'connected_users': connected_users,
            'device_os': os_counts,
            'frequency_distribution': freq_counts,
            'signal_strength_avg': signal_strength_avg,
            'devices': device_list,
            'last_update': current_time.isoformat()
        })
        
        logging.info(f"Cache updated: {len(wireless_devices)} wireless devices")
        
    except Exception as e:
        logging.error(f"Cache update error: {e}")

def filter_data_by_timerange(data, hours):
    """Filter time-series data by hours"""
    if not data or hours == 0:
        return data
    
    cutoff_time = datetime.now() - timedelta(hours=hours)
    return [
        entry for entry in data 
        if datetime.fromisoformat(entry['timestamp']) >= cutoff_time
    ]

def run_speedtest():
    """Run speed test"""
    global data_cache
    try:
        data_cache['speedtest_running'] = True
        st = speedtest.Speedtest()
        st.get_best_server()
        
        data_cache['speedtest_result'] = {
            'download': round(st.download() / 1_000_000, 2),
            'upload': round(st.upload() / 1_000_000, 2),
            'ping': round(st.results.ping, 2),
            'timestamp': datetime.now().isoformat()
        }
    except Exception as e:
        data_cache['speedtest_result'] = {'error': str(e)}
    finally:
        data_cache['speedtest_running'] = False

# Routes - Exact replica of macOS version
@app.route('/')
def index():
    """Serve main dashboard page"""
    try:
        if os.path.exists(TEMPLATE_FILE):
            with open(TEMPLATE_FILE, 'r') as f:
                return f.read()
    except Exception as e:
        logging.error(f"Template load error: {e}")
    
    # Fallback minimal HTML
    return '''<!DOCTYPE html>
<html><head><title>MiniRack Dashboard</title></head>
<body><h1>Dashboard Loading...</h1>
<p>Please wait while the dashboard initializes.</p>
<script>setTimeout(() => location.reload(), 5000);</script>
</body></html>'''

# API Routes (same as full version)
@app.route('/api/dashboard')
def get_dashboard_data():
    update_cache()
    return jsonify(data_cache)

@app.route('/api/dashboard/<int:hours>')
def get_dashboard_data_filtered(hours):
    """Get dashboard data filtered by time range"""
    update_cache()
    filtered_cache = data_cache.copy()
    
    # Filter time-series data
    filtered_cache['connected_users'] = filter_data_by_timerange(data_cache['connected_users'], hours)
    filtered_cache['signal_strength_avg'] = filter_data_by_timerange(data_cache['signal_strength_avg'], hours)
    
    return jsonify(filtered_cache)

@app.route('/api/network')
def get_network_info():
    """Get network information"""
    try:
        network_info = eero_api.get_network_info()
        return jsonify({
            'name': network_info.get('name', 'Unknown Network'),
            'network_id': eero_api.network_id,
            'success': True
        })
    except Exception as e:
        return jsonify({
            'name': 'Unknown Network',
            'network_id': eero_api.network_id,
            'success': False,
            'error': str(e)
        })

@app.route('/api/devices')
def get_devices():
    return jsonify({
        'devices': data_cache.get('devices', []),
        'count': len(data_cache.get('devices', []))
    })

@app.route('/api/speedtest/start', methods=['POST'])
def start_speedtest():
    if data_cache['speedtest_running']:
        return jsonify({'status': 'already running'}), 409
    threading.Thread(target=run_speedtest, daemon=True).start()
    return jsonify({'status': 'started'})

@app.route('/api/speedtest/status')
def get_speedtest_status():
    return jsonify({
        'running': data_cache['speedtest_running'],
        'result': data_cache['speedtest_result']
    })

@app.route('/api/version')
def get_version():
    config = load_config()
    return jsonify({
        'version': VERSION,
        'network_id': config.get('network_id'),
        'environment': config.get('environment', 'production'),
        'api_url': config.get('api_url', 'api-user.e2ro.com'),
        'authenticated': eero_api.api_token is not None,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/admin/update', methods=['POST'])
def update_dashboard():
    try:
        result = subprocess.run(['/opt/eero/update.sh'], 
                              capture_output=True, text=True, timeout=60)
        
        if result.returncode == 0:
            return jsonify({
                'success': True, 
                'message': 'Dashboard updated successfully! Reloading...'
            })
        else:
            return jsonify({
                'success': False, 
                'message': f'Update failed: {result.stderr}'
            }), 500
    except Exception as e:
        return jsonify({
            'success': False, 
            'message': f'Update error: {str(e)}'
        }), 500

@app.route('/api/admin/network-id', methods=['POST'])
def change_network_id():
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
        
        return jsonify({'success': False, 'message': 'Failed to save configuration'}), 500
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/admin/reauthorize', methods=['POST'])
def reauthorize():
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
                return jsonify({'success': False, 'message': 'Please restart authentication process'}), 400
            
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

if __name__ == '__main__':
    logging.info(f"Starting MiniRack Dashboard {VERSION}")
    
    # Initial cache update
    try:
        update_cache()
        logging.info("Initial cache update complete")
    except Exception as e:
        logging.warning(f"Initial cache update failed: {e}")
    
    app.run(host='0.0.0.0', port=5000, debug=False)