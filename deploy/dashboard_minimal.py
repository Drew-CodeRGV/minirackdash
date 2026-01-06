#!/usr/bin/env python3
import os
import json
import requests
from datetime import datetime
from flask import Flask, jsonify
from flask_cors import CORS
import logging

VERSION = "6.2.1-fixed"
CONFIG_FILE = "/opt/eero/app/config.json"
TOKEN_FILE = "/opt/eero/app/.eero_token"
TEMPLATE_FILE = "/opt/eero/app/index.html"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/eero/logs/dashboard.log'),
        logging.StreamHandler()
    ]
)

app = Flask(__name__)
CORS(app)

def load_config():
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, 'r') as f:
                return json.load(f)
    except Exception as e:
        logging.error("Config load error: " + str(e))
    
    return {
        "network_id": "20478317",
        "environment": "production",
        "api_url": "api-user.e2ro.com"
    }

class EeroAPI:
    def __init__(self):
        self.session = requests.Session()
        self.config = load_config()
        self.api_token = self.load_token()
        self.network_id = self.config.get('network_id', '20478317')
        self.api_url = self.config.get('api_url', 'api-user.e2ro.com')
        self.api_base = "https://" + self.api_url + "/2.2"
    
    def load_token(self):
        try:
            if os.path.exists(TOKEN_FILE):
                with open(TOKEN_FILE, 'r') as f:
                    return f.read().strip()
        except Exception as e:
            logging.error("Token load error: " + str(e))
        return None
    
    def get_headers(self):
        headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'MiniRack-Dashboard/' + VERSION
        }
        if self.api_token:
            headers['X-User-Token'] = self.api_token
        return headers
    
    def get_network_info(self):
        try:
            url = self.api_base + "/networks/" + self.network_id
            response = self.session.get(url, headers=self.get_headers(), timeout=10)
            response.raise_for_status()
            data = response.json()
            
            if 'data' in data:
                return data['data']
            return {}
        except Exception as e:
            logging.error("Network info fetch error: " + str(e))
            return {}
    
    def get_all_devices(self):
        try:
            url = self.api_base + "/networks/" + self.network_id + "/devices"
            response = self.session.get(url, headers=self.get_headers(), timeout=15)
            response.raise_for_status()
            data = response.json()
            
            if 'data' in data:
                devices = data['data'] if isinstance(data['data'], list) else data['data'].get('devices', [])
                logging.info("Retrieved " + str(len(devices)) + " devices")
                return devices
            return []
        except Exception as e:
            logging.error("Device fetch error: " + str(e))
            return []

eero_api = EeroAPI()

data_cache = {
    'connected_users': [],
    'device_os': {},
    'frequency_distribution': {},
    'signal_strength_avg': [],
    'devices': [],
    'last_update': None
}

def detect_device_os(device):
    manufacturer = str(device.get('manufacturer', '')).lower()
    hostname = str(device.get('hostname', '')).lower()
    text = manufacturer + " " + hostname
    
    if 'amazon' in text or 'echo' in text:
        return 'Amazon'
    elif 'apple' in text or 'iphone' in text or 'ipad' in text:
        return 'iOS'
    elif 'android' in text or 'samsung' in text or 'google' in text:
        return 'Android'
    elif 'windows' in text or 'microsoft' in text or 'dell' in text:
        return 'Windows'
    else:
        return 'Other'

def update_cache():
    global data_cache
    try:
        all_devices = eero_api.get_all_devices()
        connected_devices = [d for d in all_devices if d.get('connected')]
        
        device_list = []
        os_counts = {'iOS': 0, 'Android': 0, 'Windows': 0, 'Amazon': 0, 'Other': 0}
        
        for device in connected_devices:
            device_os = detect_device_os(device)
            os_counts[device_os] += 1
            
            device_list.append({
                'name': device.get('nickname') or device.get('hostname') or 'Unknown Device',
                'ip': ', '.join(device.get('ips', [])) if device.get('ips') else 'N/A',
                'mac': device.get('mac', 'N/A'),
                'manufacturer': device.get('manufacturer', 'Unknown'),
                'device_os': device_os,
                'connection_type': 'Wireless' if device.get('wireless') else 'Wired'
            })
        
        current_time = datetime.now()
        data_cache.update({
            'connected_users': [{'timestamp': current_time.isoformat(), 'count': len(connected_devices)}],
            'device_os': os_counts,
            'frequency_distribution': {'2.4GHz': 0, '5GHz': 0, '6GHz': 0},
            'signal_strength_avg': [],
            'devices': device_list,
            'total_devices': len(connected_devices),
            'wireless_devices': len([d for d in connected_devices if d.get('wireless')]),
            'wired_devices': len([d for d in connected_devices if not d.get('wireless')]),
            'last_update': current_time.isoformat()
        })
        
        logging.info("Cache updated: " + str(len(connected_devices)) + " devices")
        
    except Exception as e:
        logging.error("Cache update error: " + str(e))

@app.route('/')
def index():
    try:
        if os.path.exists(TEMPLATE_FILE):
            with open(TEMPLATE_FILE, 'r') as f:
                return f.read()
    except Exception as e:
        logging.error("Template load error: " + str(e))
    
    return '''<!DOCTYPE html>
<html><head><title>MiniRack Dashboard</title></head>
<body><h1>Dashboard Loading...</h1>
<p>Please wait while the dashboard initializes.</p>
<script>setTimeout(() => location.reload(), 5000);</script>
</body></html>'''

@app.route('/api/dashboard')
def get_dashboard_data():
    update_cache()
    return jsonify(data_cache)

@app.route('/api/network')
def get_network_info():
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

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'version': VERSION})

if __name__ == '__main__':
    logging.info("Starting MiniRack Dashboard " + VERSION)
    
    try:
        update_cache()
        logging.info("Initial cache update complete")
    except Exception as e:
        logging.warning("Initial cache update failed: " + str(e))
    
    app.run(host='0.0.0.0', port=5000, debug=False)
