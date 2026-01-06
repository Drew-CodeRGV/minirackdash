#!/usr/bin/env python3
"""
MiniRack Dashboard - Production Ready (Full macOS Replica)
Exact replica of the macOS version for Lightsail deployment
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
        
        # Update connected users history (keep last 20 points)
        current_time = datetime.now()
        connected_users = data_cache.get('connected_users', [])
        connected_users.append({
            'timestamp': current_time.isoformat(),
            'count': len(wireless_devices)
        })
        if len(connected_users) > 20:
            connected_users = connected_users[-20:]
        
        # Update signal strength history (keep last 20 points)
        signal_strength_avg = data_cache.get('signal_strength_avg', [])
        if signal_values:
            avg_signal = sum(signal_values) / len(signal_values)
            signal_strength_avg.append({
                'timestamp': current_time.isoformat(),
                'avg_dbm': round(avg_signal, 1)
            })
        if len(signal_strength_avg) > 20:
            signal_strength_avg = signal_strength_avg[-20:]
        
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
    # Return the complete HTML from frontend/index.html
    return '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Network Dashboard v5.2.4 (Production)</title>
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
        <div class="header-title">Network Dashboard v5.2.4 (Production)</div>
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
        <p>Please configure your Network ID and API authentication to start monitoring.</p>
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
                <button class="admin-btn" onclick="updateDashboard()">
                    <i class="fas fa-sync"></i><span>Update Dashboard</span>
                </button>
                <button class="admin-btn" onclick="checkForUpdates()">
                    <i class="fas fa-download"></i><span>Check for Updates</span>
                </button>
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
            
            // Connected Users Chart
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
            
            // Device OS Chart
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
            
            // Frequency Chart
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
            
            // Signal Strength Chart
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
        
        async function updateDashboardData() {
            try {
                const response = await fetch("/api/dashboard");
                const data = await response.json();
                
                // Check if we have data (indicates configuration is working)
                if (data.connected_users && data.connected_users.length > 0) {
                    isConfigured = true;
                    document.getElementById("setupNotice").style.display = "none";
                } else if (!isConfigured) {
                    document.getElementById("setupNotice").style.display = "block";
                }
                
                // Update Connected Users Chart
                charts.users.data.labels = data.connected_users.map(entry => 
                    new Date(entry.timestamp).toLocaleTimeString()
                );
                charts.users.data.datasets[0].data = data.connected_users.map(entry => entry.count);
                charts.users.update();
                
                // Update Device OS Chart
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
                
                // Update Frequency Chart
                const freqDist = data.frequency_distribution || {};
                charts.frequency.data.datasets[0].data = [
                    freqDist["2.4GHz"] || 0,
                    freqDist["5GHz"] || 0,
                    freqDist["6GHz"] || 0
                ];
                charts.frequency.update();
                document.getElementById("frequencySubtitle").textContent = 
                    `${(freqDist["2.4GHz"] || 0) + (freqDist["5GHz"] || 0) + (freqDist["6GHz"] || 0)} devices`;
                
                // Update Signal Strength Chart
                charts.signalStrength.data.labels = data.signal_strength_avg.map(entry => 
                    new Date(entry.timestamp).toLocaleTimeString()
                );
                charts.signalStrength.data.datasets[0].data = data.signal_strength_avg.map(entry => entry.avg_dbm);
                charts.signalStrength.update();
                
                // Update last update time
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
        
        // Close modal when clicking outside
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
        
        async function updateDashboard() {
            try {
                const response = await fetch("/api/admin/update", { method: "POST" });
                const data = await response.json();
                showAlert(data.message, data.success ? "success" : "error");
                
                if (data.success) {
                    setTimeout(() => location.reload(), 3000);
                }
            } catch (error) {
                showAlert("Failed to update dashboard", "error");
            }
        }
        
        async function checkForUpdates() {
            try {
                const response = await fetch("/api/admin/check-update");
                const data = await response.json();
                
                if (data.update_available) {
                    showAlert(`Update available: v${data.latest_version} (Current: v${data.current_version})`, "info");
                } else {
                    showAlert("You are running the latest version", "success");
                }
            } catch (error) {
                showAlert("Failed to check for updates", "error");
            }
        }
        
        function showNetworkIdForm() {
            document.getElementById("adminFormContainer").innerHTML = `
                <div class="form-group">
                    <label class="form-label">New Network ID:</label>
                    <input type="text" id="newNetworkId" class="form-input" placeholder="Enter network ID">
                    <button class="form-btn" style="margin-top:10px" onclick="changeNetworkId()">
                        Update Network ID
                    </button>
                </div>
            `;
        }
        
        async function changeNetworkId() {
            const newId = document.getElementById("newNetworkId").value.trim();
            
            if (!newId || !newId.match(/^\\d+$/)) {
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
        
        // Initialize everything when page loads
        window.addEventListener("load", () => {
            initCharts();
            updateDashboardData();
            setInterval(updateDashboardData, 60000); // Update every minute
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
        return jsonify({'status': 'already running'}), 409
    
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
        'version': VERSION,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/version')
def get_version():
    """Get version information"""
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
    """Update dashboard from GitHub"""
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
            
    except subprocess.TimeoutExpired:
        return jsonify({
            'success': False, 
            'message': 'Update timed out'
        }), 500
    except Exception as e:
        return jsonify({
            'success': False, 
            'message': f'Update error: {str(e)}'
        }), 500

@app.route('/api/admin/check-update')
def check_update():
    """Check for updates"""
    try:
        # This is a placeholder - in a real implementation you'd check GitHub releases
        return jsonify({
            'update_available': False,
            'current_version': VERSION,
            'latest_version': VERSION,
            'message': 'You are running the latest version'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': str(e)
        }), 500

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
        
        if save_config(config):
            eero_api.network_id = new_id
            return jsonify({'success': True, 'message': f'Network ID updated to {new_id}'})
        
        return jsonify({'success': False, 'message': 'Failed to save configuration'}), 500
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/admin/reauthorize', methods=['POST'])
def reauthorize():
    """Reauthorize API access"""
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