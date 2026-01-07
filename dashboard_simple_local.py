#!/usr/bin/env python3
"""
MiniRack Dashboard - Simple macOS Local Version
Standalone local version with proper macOS paths
"""
import os
import sys
import json
import requests
import threading
import time
from datetime import datetime, timedelta
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from pathlib import Path
import logging
import pytz

# Configuration for local development
VERSION = "6.7.8-mobile-local"
LOCAL_DIR = Path.home() / ".minirack"
CONFIG_FILE = LOCAL_DIR / "config.json"
TOKEN_FILE = LOCAL_DIR / ".eero_token"
TEMPLATE_FILE = Path(__file__).parent / "deploy" / "index.html"
DATA_CACHE_FILE = LOCAL_DIR / "data_cache.json"

# Ensure local directory exists
LOCAL_DIR.mkdir(exist_ok=True)

# Setup logging for local development
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOCAL_DIR / 'dashboard.log'),
        logging.StreamHandler()
    ]
)

# Flask app
app = Flask(__name__)
CORS(app)

def load_config():
    """Load configuration"""
    try:
        if CONFIG_FILE.exists():
            with open(CONFIG_FILE, 'r') as f:
                config = json.load(f)
                # Migrate old single network config to new multi-network format
                if 'network_id' in config and 'networks' not in config:
                    config['networks'] = [{
                        'id': config.get('network_id', '20478317'),
                        'name': 'Primary Network',
                        'email': '',
                        'token': '',
                        'active': True
                    }]
                return config
    except Exception as e:
        logging.error("Config load error: " + str(e))
    
    return {
        "networks": [{
            "id": "20478317",
            "name": "Primary Network", 
            "email": "",
            "token": "",
            "active": True
        }],
        "environment": "development",
        "api_url": "api-user.e2ro.com",
        "timezone": "America/New_York"
    }

def save_config(config):
    """Save configuration"""
    try:
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)
        return True
    except Exception as e:
        logging.error("Config save error: " + str(e))
        return False

def get_timezone_aware_now():
    """Get current time in configured timezone"""
    try:
        config = load_config()
        tz_name = config.get('timezone', 'America/New_York')
        tz = pytz.timezone(tz_name)
        return datetime.now(tz)
    except Exception as e:
        logging.warning("Timezone error, using UTC: " + str(e))
        return datetime.now(pytz.UTC)

# Initialize data cache
data_cache = {
    'networks': {},
    'combined': {
        'connected_users': [],
        'device_os': {},
        'frequency_distribution': {},
        'signal_strength_avg': [],
        'devices': [],
        'last_update': None
    }
}

class EeroAPI:
    def __init__(self):
        self.session = requests.Session()
        self.config = load_config()
        self.api_url = self.config.get('api_url', 'api-user.e2ro.com')
        self.api_base = "https://" + self.api_url + "/2.2"
        self.network_tokens = {}
        self.load_all_tokens()
    
    def load_all_tokens(self):
        """Load API tokens for all configured networks"""
        try:
            networks = self.config.get('networks', [])
            for network in networks:
                network_id = network.get('id')
                if network_id:
                    token_file = LOCAL_DIR / f".eero_token_{network_id}"
                    if token_file.exists():
                        with open(token_file, 'r') as f:
                            self.network_tokens[network_id] = f.read().strip()
        except Exception as e:
            logging.error("Token loading error: " + str(e))
    
    def get_headers(self, network_id):
        """Get request headers for specific network"""
        headers = {
            'Content-Type': 'application/json',
            'User-Agent': 'MiniRack-Dashboard/' + VERSION
        }
        token = self.network_tokens.get(network_id)
        if token:
            headers['X-User-Token'] = token
        return headers
    
    def get_all_devices(self, network_id):
        """Get all devices for specific network"""
        try:
            url = self.api_base + "/networks/" + network_id + "/devices"
            response = self.session.get(url, headers=self.get_headers(network_id), timeout=15)
            response.raise_for_status()
            data = response.json()
            
            if 'data' in data:
                devices = data['data'] if isinstance(data['data'], list) else data['data'].get('devices', [])
                logging.info(f"Retrieved {len(devices)} devices from network {network_id}")
                return devices
            return []
        except Exception as e:
            logging.error(f"Device fetch error for network {network_id}: {str(e)}")
            return []

# Initialize API
eero_api = EeroAPI()

def update_cache():
    """Update data cache - simplified version"""
    global data_cache
    try:
        logging.info("Updating cache...")
        current_time = get_timezone_aware_now()
        
        # Simple mock data for testing
        data_cache['combined'].update({
            'connected_users': [{'timestamp': current_time.isoformat(), 'count': 15}],
            'device_os': {'iOS': 5, 'Android': 4, 'Windows': 3, 'Amazon': 2, 'Other': 1},
            'frequency_distribution': {'2.4GHz': 6, '5GHz': 8, '6GHz': 1},
            'signal_strength_avg': [{'timestamp': current_time.isoformat(), 'avg_dbm': -45.5}],
            'devices': [],
            'last_update': current_time.isoformat(),
            'last_successful_update': current_time.isoformat()
        })
        
        logging.info("Cache updated successfully")
    except Exception as e:
        logging.error("Cache update error: " + str(e))

# Routes
@app.route('/')
def index():
    """Serve main dashboard page"""
    try:
        if TEMPLATE_FILE.exists():
            with open(TEMPLATE_FILE, 'r', encoding='utf-8') as f:
                content = f.read()
                if 'showAdmin' in content and len(content) > 10000:
                    logging.info("Serving dashboard template")
                    return content
    except Exception as e:
        logging.error("Template load error: " + str(e))
    
    return '''<!DOCTYPE html>
<html><head><title>MiniRack Dashboard</title></head>
<body><h1>Dashboard Loading...</h1>
<p>Please wait while the dashboard initializes.</p>
<script>setTimeout(() => location.reload(), 5000);</script>
</body></html>'''

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'version': VERSION})

@app.route('/api/dashboard')
def get_dashboard_data():
    """Get dashboard data"""
    update_cache()
    return jsonify(data_cache['combined'])

@app.route('/api/version')
def get_version():
    """Get version info"""
    config = load_config()
    current_time = get_timezone_aware_now()
    
    return jsonify({
        'version': VERSION,
        'network_id': '20478317',
        'environment': 'development',
        'api_url': config.get('api_url', 'api-user.e2ro.com'),
        'timezone': config.get('timezone', 'America/New_York'),
        'authenticated': len(eero_api.network_tokens) > 0,
        'timestamp': current_time.isoformat(),
        'local_time': current_time.strftime('%Y-%m-%d %H:%M:%S %Z')
    })

@app.route('/api/network')
def get_network_info():
    """Get network information"""
    return jsonify({
        'name': 'Local Development Network',
        'network_id': '20478317',
        'success': True
    })

@app.route('/api/devices')
def get_devices():
    """Get devices"""
    return jsonify({
        'devices': data_cache['combined'].get('devices', []),
        'count': len(data_cache['combined'].get('devices', []))
    })

def create_default_config():
    """Create default configuration if it doesn't exist"""
    if not CONFIG_FILE.exists():
        config = {
            "networks": [{
                "id": "20478317",
                "name": "Primary Network",
                "email": "",
                "token": "",
                "active": True
            }],
            "environment": "development",
            "api_url": "api-user.e2ro.com",
            "timezone": "America/New_York"
        }
        
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"✅ Created default config: {CONFIG_FILE}")

if __name__ == '__main__':
    print(f"🚀 Starting MiniRack Dashboard {VERSION} (Simple Local macOS)")
    print(f"📁 Config directory: {LOCAL_DIR}")
    print(f"🌐 Dashboard: http://localhost:3000")
    print("📱 Mobile responsive design enabled")
    print("🔧 Press Ctrl+C to stop")
    print("")
    
    # Create default config if needed
    create_default_config()
    
    # Initial cache update
    try:
        update_cache()
        logging.info("Initial cache update complete")
    except Exception as e:
        logging.warning("Initial cache update failed: " + str(e))
    
    # Run the Flask app
    app.run(host='127.0.0.1', port=3000, debug=True)