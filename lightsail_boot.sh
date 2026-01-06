#!/bin/bash
# MiniRack Dashboard - Lightsail Boot Script - BULLETPROOF VERSION
# Repository: https://github.com/Drew-CodeRGV/minirackdash

set -e
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/minirack-install.log
}

log "🚀 MiniRack Dashboard - Starting BULLETPROOF Installation"

# Update system and install essentials
log "📦 Updating system packages..."
apt-get update -y >> /var/log/minirack-install.log 2>&1

log "📦 Installing system packages..."
apt-get install -y python3-pip nginx git curl python3-venv >> /var/log/minirack-install.log 2>&1

# Create directories first
log "📁 Creating directories..."
mkdir -p /opt/eero/{app,logs,backups}

# Create a working Python dashboard file directly (no downloads)
log "📝 Creating dashboard application..."
cat > /opt/eero/app/dashboard.py << 'PYTHON_EOF'
#!/usr/bin/env python3
import os
import json
import requests
from datetime import datetime
from flask import Flask, jsonify
from flask_cors import CORS
import logging

VERSION = "6.3.0-bulletproof"
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
<html><head><title>MiniRack Dashboard v6.3.0</title></head>
<body style="font-family: Arial, sans-serif; background: #001a33; color: white; padding: 20px;">
<h1>🚀 MiniRack Dashboard v6.3.0</h1>
<p>Dashboard is running! Configure your network settings in the admin panel.</p>
<div style="margin-top: 20px;">
<button onclick="location.reload()" style="padding: 10px 20px; background: #4da6ff; color: white; border: none; border-radius: 5px; cursor: pointer;">Refresh</button>
</div>
<script>
setTimeout(() => {
    fetch('/api/dashboard')
    .then(r => r.json())
    .then(d => {
        document.body.innerHTML += '<h2>Status: Connected ✅</h2><p>Total Devices: ' + d.total_devices + '</p>';
    })
    .catch(e => {
        document.body.innerHTML += '<h2>Status: Not Configured ⚠️</h2><p>Please configure your API settings.</p>';
    });
}, 1000);
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
PYTHON_EOF

# Create config file
log "📝 Creating config file..."
cat > /opt/eero/app/config.json << 'JSON_EOF'
{
  "network_id": "20478317",
  "environment": "production",
  "api_url": "api-user.e2ro.com"
}
JSON_EOF

# Create requirements file
log "📝 Creating requirements file..."
cat > /opt/eero/app/requirements.txt << 'REQ_EOF'
flask==2.3.3
flask-cors==4.0.0
requests==2.31.0
gunicorn==21.2.0
REQ_EOF

# Create Python virtual environment
log "🐍 Creating Python virtual environment..."
cd /opt/eero
python3 -m venv venv >> /var/log/minirack-install.log 2>&1
source venv/bin/activate

# Install Python dependencies in virtual environment
log "📦 Installing Python dependencies..."
pip install --upgrade pip >> /var/log/minirack-install.log 2>&1
pip install -r app/requirements.txt >> /var/log/minirack-install.log 2>&1

# Set permissions
log "🔐 Setting permissions..."
chown -R www-data:www-data /opt/eero
chmod +x /opt/eero/app/dashboard.py

# Create systemd service
log "⚙️ Creating systemd service..."
cat > /etc/systemd/system/eero-dashboard.service << 'SERVICE_EOF'
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
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always
RestartSec=10
KillMode=mixed
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Configure Nginx for port 80
log "🌐 Configuring Nginx..."

# COMPLETELY remove nginx defaults
systemctl stop nginx || true
rm -rf /etc/nginx/sites-enabled/*
rm -rf /etc/nginx/sites-available/default
rm -f /var/www/html/index.nginx-debian.html
rm -f /var/www/html/index.html

# Create nginx config that ONLY serves our dashboard
cat > /etc/nginx/nginx.conf << 'NGINX_EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

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
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }
    }
}
NGINX_EOF

# Enable our site and disable default
log "🔗 Enabling Nginx site..."
ln -sf /etc/nginx/sites-available/eero-dashboard /etc/nginx/sites-enabled/

# Ensure no other sites are enabled
find /etc/nginx/sites-enabled/ -type l ! -name "eero-dashboard" -delete

# Test nginx config
log "✅ Testing Nginx configuration..."
if ! nginx -t >> /var/log/minirack-install.log 2>&1; then
    log "❌ Nginx configuration test failed"
    cat /var/log/nginx/error.log >> /var/log/minirack-install.log 2>&1 || true
    exit 1
fi

# Configure firewall
log "🔥 Configuring firewall..."
ufw allow 80/tcp >> /var/log/minirack-install.log 2>&1
ufw allow 22/tcp >> /var/log/minirack-install.log 2>&1
ufw --force enable >> /var/log/minirack-install.log 2>&1

# Start services
log "🚀 Starting services..."
systemctl daemon-reload

# Enable and start eero-dashboard
systemctl enable eero-dashboard
if ! systemctl start eero-dashboard; then
    log "❌ Failed to start eero-dashboard service"
    journalctl -u eero-dashboard --no-pager -n 20 >> /var/log/minirack-install.log 2>&1
    systemctl status eero-dashboard >> /var/log/minirack-install.log 2>&1 || true
    exit 1
fi

# Wait for service to be ready
log "⏳ Waiting for dashboard service to start..."
sleep 5

# Check if service is actually running
if ! systemctl is-active --quiet eero-dashboard; then
    log "❌ Dashboard service is not active"
    systemctl status eero-dashboard >> /var/log/minirack-install.log 2>&1 || true
    journalctl -u eero-dashboard --no-pager -n 20 >> /var/log/minirack-install.log 2>&1
    exit 1
fi

# Test if dashboard is responding on port 5000
log "🔍 Testing dashboard on port 5000..."
for i in {1..10}; do
    if curl -f http://localhost:5000/health > /dev/null 2>&1; then
        log "✅ Dashboard responding on port 5000"
        break
    fi
    if [ $i -eq 10 ]; then
        log "❌ Dashboard not responding on port 5000 after 10 attempts"
        systemctl status eero-dashboard >> /var/log/minirack-install.log 2>&1 || true
        journalctl -u eero-dashboard --no-pager -n 20 >> /var/log/minirack-install.log 2>&1
        exit 1
    fi
    log "⏳ Attempt $i: Dashboard not ready, waiting..."
    sleep 2
done

# Enable and restart nginx
systemctl enable nginx
if ! systemctl restart nginx; then
    log "❌ Failed to restart nginx service"
    journalctl -u nginx --no-pager -n 10 >> /var/log/minirack-install.log 2>&1
    nginx -t >> /var/log/minirack-install.log 2>&1 || true
    exit 1
fi

# Wait for nginx to be ready
log "⏳ Waiting for nginx to be ready..."
sleep 3

# Verify nginx is running and configured correctly
if ! systemctl is-active --quiet nginx; then
    log "❌ Nginx service is not active"
    systemctl status nginx >> /var/log/minirack-install.log 2>&1 || true
    exit 1
fi

# Test local connection multiple times
log "🔍 Testing local HTTP connection..."
for i in {1..5}; do
    if curl -f -s http://localhost/ | grep -q "MiniRack Dashboard" 2>/dev/null; then
        log "✅ Local HTTP test successful - Dashboard content detected"
        break
    fi
    if [ $i -eq 5 ]; then
        log "❌ Local HTTP test failed - Dashboard not loading properly"
        log "🔍 Debugging information:"
        curl -v http://localhost/ >> /var/log/minirack-install.log 2>&1 || true
        systemctl status eero-dashboard nginx >> /var/log/minirack-install.log 2>&1 || true
        journalctl -u eero-dashboard --no-pager -n 10 >> /var/log/minirack-install.log 2>&1
        journalctl -u nginx --no-pager -n 10 >> /var/log/minirack-install.log 2>&1
        exit 1
    fi
    log "⏳ Attempt $i: Testing connection..."
    sleep 3
done

# Final verification
log "🔍 Verifying installation..."
if systemctl is-active --quiet eero-dashboard && systemctl is-active --quiet nginx; then
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "unknown")
    log "✅ Services are running"
    log "🌐 Dashboard: http://$PUBLIC_IP"
    echo "✅ Installation complete!"
    echo "🌐 Dashboard: http://$PUBLIC_IP"
    echo "📋 Version: 6.3.0-bulletproof"
    echo "🔧 Configure your Network ID and API authentication via the web interface"
else
    log "❌ Services failed to start properly"
    systemctl status eero-dashboard >> /var/log/minirack-install.log 2>&1 || true
    systemctl status nginx >> /var/log/minirack-install.log 2>&1 || true
    exit 1
fi