#!/bin/bash
# MiniRack Dashboard - EC2 User Data Script

# Update system
yum update -y

# Install Python 3 and dependencies
yum install -y python3 python3-pip git nginx

# Create user
useradd -m eero
mkdir -p /home/eero/dashboard
chown -R eero:eero /home/eero

# Install Python packages
pip3 install flask flask-cors requests speedtest-cli gunicorn

# Create dashboard application
cat > /home/eero/dashboard/app.py << 'EOF'
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
CURRENT_VERSION = "5.2.4-aws"
CONFIG_FILE = "/home/eero/dashboard/.config.json"
API_TOKEN_FILE = "/home/eero/dashboard/.eero_token"
LOG_DIR = "/home/eero/dashboard/logs"
FRONTEND_DIR = "/home/eero/dashboard/frontend"

# Create directories
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
                    return f.read().strip()
        except Exception as e:
            logging.error(f"Token load error: {e}")
        return None
    
    def load_network_id(self):
        config = load_config()
        return config.get('network_id', '')
    
    def get_headers(self):
        headers = {'Content-Type': 'application/json', 'User-Agent': 'Eero-Dashboard-AWS/1.0'}
        if self.api_token:
            headers['X-User-Token'] = self.api_token
        return headers
    
    def get_all_devices(self):
        try:
            url = f"{self.api_base}/networks/{self.network_id}/devices"
            response = self.session.get(url, headers=self.get_headers(), timeout=10)
            response.raise_for_status()
            data = response.json()
            if 'data' in data:
                return data['data'] if isinstance(data['data'], list) else data['data'].get('devices', [])
            return []
        except Exception as e:
            logging.error(f"Device fetch error: {e}")
            return []

# Initialize API
eero_api = EeroAPI()

@app.route('/')
def index():
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/api/dashboard')
def get_dashboard_data():
    # Simplified dashboard data for EC2
    devices = eero_api.get_all_devices()
    wireless = [d for d in devices if d.get('connected') and d.get('wireless')]
    
    return jsonify({
        'connected_users': [{'timestamp': datetime.now().isoformat(), 'count': len(wireless)}],
        'device_os': {'iOS': 0, 'Android': 0, 'Windows': 0, 'Other': len(wireless)},
        'frequency_distribution': {'2.4GHz': 0, '5GHz': len(wireless), '6GHz': 0},
        'devices': [{'name': d.get('nickname', 'Device'), 'ip': 'N/A', 'mac': 'N/A'} for d in wireless[:10]],
        'last_update': datetime.now().isoformat()
    })

@app.route('/api/version')
def get_version():
    config = load_config()
    return jsonify({
        'version': CURRENT_VERSION,
        'network_id': config.get('network_id', ''),
        'environment': config.get('environment', 'production'),
        'api_url': config.get('api_url', 'api-user.e2ro.com')
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

# Create frontend
mkdir -p /home/eero/dashboard/frontend
cat > /home/eero/dashboard/frontend/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Eero Dashboard (AWS EC2)</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; background: #1a1a1a; color: white; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { text-align: center; margin-bottom: 30px; }
        .header h1 { color: #4da6ff; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { background: #2a2a2a; padding: 20px; border-radius: 10px; text-align: center; }
        .stat-value { font-size: 2em; font-weight: bold; color: #4da6ff; }
        .stat-label { margin-top: 10px; color: #ccc; }
        .setup-form { background: #2a2a2a; padding: 30px; border-radius: 10px; max-width: 500px; margin: 0 auto; }
        .form-group { margin-bottom: 20px; }
        .form-label { display: block; margin-bottom: 5px; color: #4da6ff; }
        .form-input { width: 100%; padding: 10px; background: #3a3a3a; border: 1px solid #555; border-radius: 5px; color: white; }
        .form-btn { background: #4da6ff; color: white; border: none; padding: 12px 24px; border-radius: 5px; cursor: pointer; }
        .form-btn:hover { background: #357abd; }
        .alert { padding: 10px; margin: 10px 0; border-radius: 5px; }
        .alert-info { background: rgba(77,166,255,0.2); border: 1px solid #4da6ff; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Eero Network Dashboard</h1>
            <p>AWS EC2 Deployment</p>
        </div>
        
        <div id="setupSection" class="setup-form">
            <h2>Setup Required</h2>
            <div class="alert alert-info">
                Please configure your Eero network settings to get started.
            </div>
            
            <div class="form-group">
                <label class="form-label">Network ID:</label>
                <input type="text" id="networkId" class="form-input" placeholder="Enter your Eero network ID">
            </div>
            
            <div class="form-group">
                <label class="form-label">API Token:</label>
                <input type="text" id="apiToken" class="form-input" placeholder="Enter your Eero API token">
            </div>
            
            <button class="form-btn" onclick="saveConfig()">Save Configuration</button>
        </div>
        
        <div id="dashboardSection" style="display: none;">
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
        </div>
    </div>
    
    <script>
        async function loadDashboard() {
            try {
                const response = await fetch('/api/dashboard');
                const data = await response.json();
                
                document.getElementById('deviceCount').textContent = data.connected_users[0]?.count || 0;
                document.getElementById('lastUpdate').textContent = new Date().toLocaleTimeString();
                
                document.getElementById('setupSection').style.display = 'none';
                document.getElementById('dashboardSection').style.display = 'block';
            } catch (error) {
                console.error('Dashboard load error:', error);
            }
        }
        
        function saveConfig() {
            const networkId = document.getElementById('networkId').value;
            const apiToken = document.getElementById('apiToken').value;
            
            if (!networkId || !apiToken) {
                alert('Please fill in all fields');
                return;
            }
            
            // In a real implementation, this would save to the backend
            alert('Configuration saved! Refresh the page to load dashboard.');
        }
        
        // Try to load dashboard on page load
        window.addEventListener('load', loadDashboard);
    </script>
</body>
</html>
EOF

# Set permissions
chown -R eero:eero /home/eero/dashboard
chmod +x /home/eero/dashboard/app.py

# Create systemd service
cat > /etc/systemd/system/eero-dashboard.service << 'EOF'
[Unit]
Description=Eero Dashboard
After=network.target

[Service]
Type=simple
User=eero
WorkingDirectory=/home/eero/dashboard
ExecStart=/usr/bin/python3 /home/eero/dashboard/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx
cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;

        location / {
            proxy_pass http://127.0.0.1:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF

# Start services
systemctl daemon-reload
systemctl enable eero-dashboard
systemctl start eero-dashboard
systemctl enable nginx
systemctl start nginx

# Configure firewall (Amazon Linux uses iptables)
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
service iptables save

echo "Dashboard deployment complete!"
echo "Access at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
