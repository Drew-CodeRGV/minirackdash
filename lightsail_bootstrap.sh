#!/bin/bash
# MiniRack Dashboard - Lightsail Bootstrap Script (Under 16KB)
# This downloads and runs the full deployment

# Update system
apt-get update -y

# Install basic dependencies
apt-get install -y python3 python3-pip git curl

# Create deployment directory
mkdir -p /tmp/eero-deploy
cd /tmp/eero-deploy

# Create the full deployment script
cat > deploy.py << 'EOF'
#!/usr/bin/env python3
import os
import subprocess
import json

def run_cmd(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

def install_system_deps():
    print("Installing system dependencies...")
    run_cmd("apt-get update -y")
    run_cmd("apt-get install -y python3-venv nginx")

def create_user():
    print("Creating user...")
    run_cmd("useradd -m -s /bin/bash eero")
    run_cmd("mkdir -p /home/eero/dashboard/{backend,frontend,logs}")
    run_cmd("chown -R eero:eero /home/eero")

def setup_python():
    print("Setting up Python environment...")
    run_cmd("sudo -u eero python3 -m venv /home/eero/dashboard/venv")
    run_cmd("sudo -u eero /home/eero/dashboard/venv/bin/pip install flask flask-cors requests speedtest-cli gunicorn")

def create_backend():
    print("Creating backend...")
    backend_code = '''#!/usr/bin/env python3
import os, json, requests, speedtest, threading, time, socket
from datetime import datetime, timedelta
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import logging

app = Flask(__name__, static_folder='/home/eero/dashboard/frontend', static_url_path='')
CORS(app)

CONFIG_FILE = "/home/eero/dashboard/.config.json"
TOKEN_FILE = "/home/eero/dashboard/.eero_token"

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')

def load_config():
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, 'r') as f:
                return json.load(f)
    except: pass
    return {}

def save_config(config):
    try:
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)
        os.chmod(CONFIG_FILE, 0o600)
        return True
    except: return False

class EeroAPI:
    def __init__(self):
        self.session = requests.Session()
        self.api_token = self.load_token()
        self.network_id = load_config().get('network_id', '20478317')
        self.api_url = load_config().get('api_url', 'api-user.e2ro.com')
        self.api_base = f"https://{self.api_url}/2.2"
    
    def load_token(self):
        try:
            if os.path.exists(TOKEN_FILE):
                with open(TOKEN_FILE, 'r') as f:
                    return f.read().strip()
        except: pass
        return None
    
    def get_headers(self):
        headers = {'Content-Type': 'application/json', 'User-Agent': 'Eero-Dashboard/1.0'}
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

eero_api = EeroAPI()
data_cache = {'devices': [], 'last_update': None, 'speedtest_running': False, 'speedtest_result': None}

def update_cache():
    devices = eero_api.get_all_devices()
    wireless = [d for d in devices if d.get('connected') and d.get('wireless')]
    
    device_list = []
    for device in wireless:
        device_list.append({
            'name': device.get('nickname') or device.get('hostname') or 'Unknown',
            'ip': ', '.join(device.get('ips', [])) if device.get('ips') else 'N/A',
            'mac': device.get('mac', 'N/A'),
            'manufacturer': device.get('manufacturer', 'Unknown')
        })
    
    data_cache.update({
        'connected_users': [{'timestamp': datetime.now().isoformat(), 'count': len(wireless)}],
        'device_os': {'iOS': 0, 'Android': 0, 'Windows': 0, 'Other': len(wireless)},
        'frequency_distribution': {'2.4GHz': 0, '5GHz': len(wireless), '6GHz': 0},
        'signal_strength_avg': [{'timestamp': datetime.now().isoformat(), 'avg_dbm': -50}],
        'devices': device_list,
        'last_update': datetime.now().isoformat()
    })

def run_speedtest():
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

@app.route('/')
def index():
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/api/dashboard')
def get_dashboard_data():
    update_cache()
    return jsonify(data_cache)

@app.route('/api/devices')
def get_devices():
    return jsonify({'devices': data_cache.get('devices', []), 'count': len(data_cache.get('devices', []))})

@app.route('/api/speedtest/start', methods=['POST'])
def start_speedtest():
    if data_cache['speedtest_running']:
        return jsonify({'status': 'running'}), 409
    threading.Thread(target=run_speedtest, daemon=True).start()
    return jsonify({'status': 'started'})

@app.route('/api/speedtest/status')
def get_speedtest_status():
    return jsonify({'running': data_cache['speedtest_running'], 'result': data_cache['speedtest_result']})

@app.route('/api/version')
def get_version():
    config = load_config()
    return jsonify({
        'version': '5.2.4-lightsail',
        'network_id': config.get('network_id', '20478317'),
        'environment': config.get('environment', 'production'),
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
            eero_api.network_id = new_id
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
        api_url = load_config().get('api_url', 'api-user.e2ro.com')
        
        if step == 'send':
            if not email or '@' not in email:
                return jsonify({'success': False, 'message': 'Invalid email address'}), 400
            
            response = requests.post(f"https://{api_url}/2.2/pro/login", json={"login": email}, timeout=10)
            response.raise_for_status()
            response_data = response.json()
            
            if 'data' not in response_data or 'user_token' not in response_data['data']:
                return jsonify({'success': False, 'message': 'Failed to generate token'}), 500
            
            with open(TOKEN_FILE + '.temp', 'w') as f:
                f.write(response_data['data']['user_token'])
            return jsonify({'success': True, 'message': 'Verification code sent', 'step': 'verify'})
            
        elif step == 'verify':
            if not code:
                return jsonify({'success': False, 'message': 'Verification code required'}), 400
            
            temp_file = TOKEN_FILE + '.temp'
            if not os.path.exists(temp_file):
                return jsonify({'success': False, 'message': 'Please restart the process'}), 400
            
            with open(temp_file, 'r') as f:
                token = f.read().strip()
            
            verify_response = requests.post(f"https://{api_url}/2.2/login/verify", 
                headers={"X-User-Token": token}, data={"code": code}, timeout=10)
            verify_response.raise_for_status()
            verify_data = verify_response.json()
            
            if verify_data.get('data', {}).get('email', {}).get('verified'):
                with open(TOKEN_FILE, 'w') as f:
                    f.write(token)
                os.chmod(TOKEN_FILE, 0o600)
                if os.path.exists(temp_file):
                    os.remove(temp_file)
                eero_api.api_token = token
                return jsonify({'success': True, 'message': 'Successfully reauthorized!'})
            return jsonify({'success': False, 'message': 'Verification failed'}), 400
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

if __name__ == '__main__':
    logging.info("Starting Eero Dashboard Backend")
    try:
        update_cache()
        logging.info("Initial cache update complete")
    except Exception as e:
        logging.error(f"Initial cache update failed: {e}")
    
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
'''
    
    with open('/home/eero/dashboard/backend/app.py', 'w') as f:
        f.write(backend_code)
    run_cmd('chmod +x /home/eero/dashboard/backend/app.py')

def create_frontend():
    print("Creating frontend...")
    # Download a minimal frontend
    frontend_url = "https://raw.githubusercontent.com/eero-drew/minirackdash/main/frontend/index.html"
    try:
        import urllib.request
        urllib.request.urlretrieve(frontend_url, '/home/eero/dashboard/frontend/index.html')
    except:
        # Fallback minimal frontend
        minimal_html = '''<!DOCTYPE html>
<html><head><title>Eero Dashboard</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<style>body{font-family:Arial;background:#1a1a1a;color:white;margin:20px}
.container{max-width:1200px;margin:0 auto}.header{text-align:center;margin-bottom:30px}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:20px;margin-bottom:30px}
.stat-card{background:#2a2a2a;padding:20px;border-radius:10px;text-align:center}
.stat-value{font-size:2em;font-weight:bold;color:#4da6ff}
.admin-btn{background:#4da6ff;color:white;border:none;padding:10px 20px;border-radius:5px;cursor:pointer;margin:10px}
.modal{display:none;position:fixed;z-index:1000;left:0;top:0;width:100%;height:100%;background:rgba(0,0,0,.8)}
.modal.active{display:flex;align-items:center;justify-content:center}
.modal-content{background:#2a2a2a;padding:30px;border-radius:10px;max-width:500px;width:90%}
.form-input{width:100%;padding:10px;margin:10px 0;background:#3a3a3a;border:1px solid #555;color:white;border-radius:5px}
</style></head><body>
<div class="container">
<div class="header"><h1>Eero Network Dashboard</h1>
<button class="admin-btn" onclick="showAdmin()">Admin Panel</button></div>
<div class="stats">
<div class="stat-card"><div class="stat-value" id="deviceCount">-</div><div>Connected Devices</div></div>
<div class="stat-card"><div class="stat-value" id="lastUpdate">-</div><div>Last Updated</div></div>
</div></div>
<div id="adminModal" class="modal">
<div class="modal-content"><h2>Admin Panel</h2>
<button onclick="showNetworkForm()">Change Network ID</button>
<button onclick="showAuthForm()">Reauthorize API</button>
<div id="formContainer"></div><div id="alerts"></div>
<button onclick="closeModal()" style="margin-top:20px">Close</button></div></div>
<script>
function showAdmin(){document.getElementById('adminModal').classList.add('active')}
function closeModal(){document.getElementById('adminModal').classList.remove('active')}
function showNetworkForm(){document.getElementById('formContainer').innerHTML='<input id="networkId" class="form-input" placeholder="Network ID" value="20478317"><button onclick="changeNetwork()">Update</button>'}
function showAuthForm(){document.getElementById('formContainer').innerHTML='<input id="email" class="form-input" placeholder="Email"><button onclick="sendCode()">Send Code</button><div id="codeForm"></div>'}
async function changeNetwork(){const id=document.getElementById('networkId').value;
const r=await fetch('/api/admin/network-id',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({network_id:id})});
const d=await r.json();alert(d.message)}
async function sendCode(){const email=document.getElementById('email').value;
const r=await fetch('/api/admin/reauthorize',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({step:'send',email})});
const d=await r.json();if(d.success)document.getElementById('codeForm').innerHTML='<input id="code" class="form-input" placeholder="Verification Code"><button onclick="verifyCode()">Verify</button>';alert(d.message)}
async function verifyCode(){const code=document.getElementById('code').value;
const r=await fetch('/api/admin/reauthorize',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({step:'verify',code})});
const d=await r.json();alert(d.message)}
async function loadData(){try{const r=await fetch('/api/dashboard');const d=await r.json();
document.getElementById('deviceCount').textContent=d.connected_users[0]?.count||0;
document.getElementById('lastUpdate').textContent=new Date().toLocaleTimeString()}catch(e){console.error(e)}}
setInterval(loadData,60000);loadData()
</script></body></html>'''
        with open('/home/eero/dashboard/frontend/index.html', 'w') as f:
            f.write(minimal_html)

def create_config():
    print("Creating configuration...")
    config = {
        "network_id": "20478317",
        "environment": "production", 
        "api_url": "api-user.e2ro.com",
        "last_updated": "2024-01-01T00:00:00"
    }
    with open('/home/eero/dashboard/.config.json', 'w') as f:
        json.dump(config, f, indent=2)
    run_cmd('chmod 600 /home/eero/dashboard/.config.json')
    run_cmd('chown -R eero:eero /home/eero/dashboard')

def create_services():
    print("Creating services...")
    
    # Systemd service
    service = '''[Unit]
Description=Eero Dashboard
After=network.target

[Service]
Type=simple
User=eero
WorkingDirectory=/home/eero/dashboard/backend
Environment="PATH=/home/eero/dashboard/venv/bin"
ExecStart=/home/eero/dashboard/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target'''
    
    with open('/etc/systemd/system/eero-dashboard.service', 'w') as f:
        f.write(service)
    
    # Nginx config
    nginx_config = '''server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}'''
    
    with open('/etc/nginx/sites-available/eero-dashboard', 'w') as f:
        f.write(nginx_config)
    
    run_cmd('ln -sf /etc/nginx/sites-available/eero-dashboard /etc/nginx/sites-enabled/')
    run_cmd('rm -f /etc/nginx/sites-enabled/default')

def start_services():
    print("Starting services...")
    run_cmd('systemctl daemon-reload')
    run_cmd('systemctl enable eero-dashboard')
    run_cmd('systemctl start eero-dashboard')
    run_cmd('systemctl enable nginx')
    run_cmd('systemctl restart nginx')
    run_cmd('ufw allow 80')
    run_cmd('ufw --force enable')

def main():
    print("Starting MiniRack Dashboard deployment...")
    install_system_deps()
    create_user()
    setup_python()
    create_backend()
    create_frontend()
    create_config()
    create_services()
    start_services()
    
    # Get public IP
    try:
        import urllib.request
        with urllib.request.urlopen('http://169.254.169.254/latest/meta-data/public-ipv4', timeout=5) as response:
            public_ip = response.read().decode('utf-8')
        print(f"\n🎉 Deployment Complete!")
        print(f"Dashboard URL: http://{public_ip}")
        print(f"Network ID: 20478317 (pre-configured)")
        print(f"\nNext Steps:")
        print(f"1. Visit: http://{public_ip}")
        print(f"2. Click 'Admin Panel'")
        print(f"3. Click 'Reauthorize API'")
        print(f"4. Enter your email and verification code")
    except:
        print("Deployment complete! Check your Lightsail console for the public IP.")

if __name__ == '__main__':
    main()
EOF

# Run the deployment
python3 deploy.py

echo "Bootstrap complete!"