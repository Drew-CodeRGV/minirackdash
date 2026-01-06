#!/bin/bash
# MiniRack Dashboard - Lightsail Launch Script
# Paste this directly into the "Launch script" field when creating your Lightsail instance

set -e
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Update system
apt-get update -y
apt-get install -y python3-pip nginx git curl python3-venv

# Create directories
mkdir -p /opt/eero/{app,logs}

# Create dashboard application
cat > /opt/eero/app/dashboard.py << 'EOF'
#!/usr/bin/env python3
import os
import json
import requests
from datetime import datetime
from flask import Flask, jsonify
from flask_cors import CORS
import logging

VERSION = "6.3.0-launch"
CONFIG_FILE = "/opt/eero/app/config.json"
TOKEN_FILE = "/opt/eero/app/.eero_token"

logging.basicConfig(level=logging.INFO, handlers=[logging.FileHandler('/opt/eero/logs/dashboard.log'), logging.StreamHandler()])
app = Flask(__name__)
CORS(app)

def load_config():
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, 'r') as f:
                return json.load(f)
    except:
        pass
    return {"network_id": "20478317", "environment": "production", "api_url": "api-user.e2ro.com"}

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
        except:
            pass
        return None
    
    def get_headers(self):
        headers = {'Content-Type': 'application/json', 'User-Agent': 'MiniRack-Dashboard/' + VERSION}
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
        except:
            return {}
    
    def get_all_devices(self):
        try:
            url = self.api_base + "/networks/" + self.network_id + "/devices"
            response = self.session.get(url, headers=self.get_headers(), timeout=15)
            response.raise_for_status()
            data = response.json()
            if 'data' in data:
                devices = data['data'] if isinstance(data['data'], list) else data['data'].get('devices', [])
                return devices
            return []
        except:
            return []

eero_api = EeroAPI()
data_cache = {'connected_users': [], 'device_os': {}, 'frequency_distribution': {}, 'signal_strength_avg': [], 'devices': [], 'last_update': None}

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
    except Exception as e:
        logging.error("Cache update error: " + str(e))

@app.route('/')
def index():
    return '''<!DOCTYPE html>
<html><head><title>MiniRack Dashboard v6.3.0</title>
<style>
body { font-family: Arial, sans-serif; background: linear-gradient(135deg, #001a33 0%, #003366 100%); color: white; padding: 20px; margin: 0; }
.header { background: rgba(0,20,40,.9); padding: 15px; border-radius: 10px; margin-bottom: 20px; text-align: center; }
.stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
.stat-card { background: rgba(0,40,80,.7); padding: 20px; border-radius: 10px; text-align: center; }
.stat-number { font-size: 2em; font-weight: bold; color: #4da6ff; }
.stat-label { font-size: 0.9em; color: rgba(255,255,255,0.8); }
.btn { padding: 10px 20px; background: #4da6ff; color: white; border: none; border-radius: 5px; cursor: pointer; margin: 5px; }
.btn:hover { background: #357abd; }
.status { padding: 10px; border-radius: 5px; margin: 10px 0; }
.status.success { background: rgba(81,207,102,.2); border: 1px solid #51cf66; }
.status.warning { background: rgba(255,193,7,.2); border: 1px solid #ffc107; }
</style></head>
<body>
<div class="header">
<h1>🚀 MiniRack Dashboard</h1>
<p>Version 6.3.0-launch • Network Monitoring Dashboard</p>
</div>

<div id="status" class="status warning">
<strong>⚠️ Initializing...</strong> Loading network data...
</div>

<div class="stats">
<div class="stat-card">
<div class="stat-number" id="totalDevices">-</div>
<div class="stat-label">Total Devices</div>
</div>
<div class="stat-card">
<div class="stat-number" id="wirelessDevices">-</div>
<div class="stat-label">Wireless</div>
</div>
<div class="stat-card">
<div class="stat-number" id="wiredDevices">-</div>
<div class="stat-label">Wired</div>
</div>
<div class="stat-card">
<div class="stat-number" id="networkName">-</div>
<div class="stat-label">Network</div>
</div>
</div>

<div style="text-align: center; margin: 30px 0;">
<button class="btn" onclick="refreshData()">🔄 Refresh Data</button>
<button class="btn" onclick="showDevices()">📱 View Devices</button>
<button class="btn" onclick="showConfig()">⚙️ Configure</button>
</div>

<div id="deviceList" style="display: none; background: rgba(0,40,80,.5); padding: 20px; border-radius: 10px; margin: 20px 0;"></div>
<div id="configPanel" style="display: none; background: rgba(0,40,80,.5); padding: 20px; border-radius: 10px; margin: 20px 0;"></div>

<script>
let isConfigured = false;

function refreshData() {
    fetch('/api/dashboard')
    .then(r => r.json())
    .then(data => {
        document.getElementById('totalDevices').textContent = data.total_devices || 0;
        document.getElementById('wirelessDevices').textContent = data.wireless_devices || 0;
        document.getElementById('wiredDevices').textContent = data.wired_devices || 0;
        
        if (data.total_devices > 0) {
            document.getElementById('status').className = 'status success';
            document.getElementById('status').innerHTML = '<strong>✅ Connected</strong> Dashboard is working and monitoring your network.';
            isConfigured = true;
        } else if (isConfigured) {
            document.getElementById('status').className = 'status warning';
            document.getElementById('status').innerHTML = '<strong>⚠️ No Devices</strong> No connected devices found. Check your network or API configuration.';
        }
    })
    .catch(e => {
        document.getElementById('status').className = 'status warning';
        document.getElementById('status').innerHTML = '<strong>⚠️ Not Configured</strong> Please configure your Network ID and API authentication.';
    });
    
    fetch('/api/network')
    .then(r => r.json())
    .then(data => {
        document.getElementById('networkName').textContent = data.name !== 'Unknown Network' ? data.name : 'Not Set';
    })
    .catch(e => {
        document.getElementById('networkName').textContent = 'Not Set';
    });
}

function showDevices() {
    fetch('/api/devices')
    .then(r => r.json())
    .then(data => {
        const list = document.getElementById('deviceList');
        if (data.devices && data.devices.length > 0) {
            list.innerHTML = '<h3>📱 Connected Devices (' + data.count + ')</h3>' +
                data.devices.map(d => 
                    '<div style="background: rgba(0,20,40,.5); padding: 15px; margin: 10px 0; border-radius: 8px;">' +
                    '<strong>' + d.name + '</strong> <span style="color: #4da6ff;">(' + d.connection_type + ')</span><br>' +
                    '<small>IP: ' + d.ip + ' | MAC: ' + d.mac + ' | Type: ' + d.device_os + '</small>' +
                    '</div>'
                ).join('');
        } else {
            list.innerHTML = '<h3>📱 No Devices Found</h3><p>Configure your API settings to see connected devices.</p>';
        }
        list.style.display = list.style.display === 'none' ? 'block' : 'none';
    });
}

function showConfig() {
    const panel = document.getElementById('configPanel');
    panel.innerHTML = '<h3>⚙️ Configuration</h3>' +
        '<p><strong>Network ID:</strong> 20478317 (default)</p>' +
        '<p><strong>Status:</strong> Ready for API authentication</p>' +
        '<p><strong>Next Steps:</strong></p>' +
        '<ol>' +
        '<li>This dashboard is running and ready</li>' +
        '<li>Configure your Eero API authentication</li>' +
        '<li>Update Network ID if different from default</li>' +
        '</ol>' +
        '<p><em>Full admin panel coming in next update...</em></p>';
    panel.style.display = panel.style.display === 'none' ? 'block' : 'none';
}

// Auto-refresh every 30 seconds
setInterval(refreshData, 30000);

// Initial load
refreshData();
</script>
</body></html>'''

@app.route('/api/dashboard')
def get_dashboard_data():
    update_cache()
    return jsonify(data_cache)

@app.route('/api/network')
def get_network_info():
    try:
        network_info = eero_api.get_network_info()
        return jsonify({'name': network_info.get('name', 'Unknown Network'), 'network_id': eero_api.network_id, 'success': True})
    except:
        return jsonify({'name': 'Unknown Network', 'network_id': eero_api.network_id, 'success': False})

@app.route('/api/devices')
def get_devices():
    return jsonify({'devices': data_cache.get('devices', []), 'count': len(data_cache.get('devices', []))})

@app.route('/api/version')
def get_version():
    config = load_config()
    return jsonify({'version': VERSION, 'network_id': config.get('network_id'), 'authenticated': eero_api.api_token is not None})

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'version': VERSION})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

# Create config
cat > /opt/eero/app/config.json << 'EOF'
{"network_id": "20478317", "environment": "production", "api_url": "api-user.e2ro.com"}
EOF

# Create requirements
cat > /opt/eero/app/requirements.txt << 'EOF'
flask==2.3.3
flask-cors==4.0.0
requests==2.31.0
gunicorn==21.2.0
EOF

# Setup Python environment
cd /opt/eero
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r app/requirements.txt

# Set permissions
chown -R www-data:www-data /opt/eero
chmod +x /opt/eero/app/dashboard.py

# Create systemd service
cat > /etc/systemd/system/eero-dashboard.service << 'EOF'
[Unit]
Description=MiniRack Dashboard
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/eero/app
Environment=PATH=/opt/eero/venv/bin
ExecStart=/opt/eero/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 dashboard:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx - PROPERLY this time
# Remove ALL default nginx configurations
rm -f /etc/nginx/sites-enabled/*
rm -f /etc/nginx/sites-available/default
rm -f /var/www/html/index.nginx-debian.html

# Create our dashboard configuration with HIGHEST priority
cat > /etc/nginx/sites-available/eero-dashboard << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    # Remove any default root
    root /nonexistent;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}
EOF

# Enable ONLY our site
ln -sf /etc/nginx/sites-available/eero-dashboard /etc/nginx/sites-enabled/eero-dashboard

# Test nginx config and fix if needed
nginx -t || (
    echo "Nginx config failed, creating minimal config"
    cat > /etc/nginx/nginx.conf << 'NGINXEOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

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
NGINXEOF
)

# Start services - WITH PROPER VERIFICATION
systemctl daemon-reload
systemctl enable eero-dashboard
systemctl start eero-dashboard

# Wait for Flask app to be ready
echo "Waiting for Flask app to start..."
for i in {1..30}; do
    if curl -f http://localhost:5000/health > /dev/null 2>&1; then
        echo "Flask app is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Flask app failed to start!"
        systemctl status eero-dashboard
        exit 1
    fi
    sleep 2
done

# Now start nginx
systemctl enable nginx
systemctl restart nginx

# Verify nginx is proxying correctly
echo "Testing nginx proxy..."
for i in {1..10}; do
    if curl -f http://localhost/ | grep -q "MiniRack Dashboard" 2>/dev/null; then
        echo "Nginx proxy working!"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "Nginx proxy failed!"
        systemctl status nginx
        curl -v http://localhost/
        exit 1
    fi
    sleep 2
done

# Configure firewall
ufw allow 80/tcp
ufw allow 22/tcp
ufw --force enable

echo "✅ MiniRack Dashboard installation complete!"
echo "🌐 Access your dashboard at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"