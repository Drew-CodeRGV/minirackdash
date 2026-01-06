#!/bin/bash
# Minimal Eero Dashboard Installer for Lightsail

apt-get update -y
apt-get install -y python3-pip nginx

# Install Flask
pip3 install flask flask-cors requests

# Create minimal app
mkdir -p /opt/eero
cat > /opt/eero/app.py << 'EOF'
from flask import Flask, jsonify, request
import json, os, requests
app = Flask(__name__)

CONFIG = {"network_id": "20478317", "api_url": "api-user.e2ro.com"}
TOKEN_FILE = "/opt/eero/.token"

@app.route('/')
def home():
    return '''<!DOCTYPE html><html><head><title>Eero Dashboard</title></head>
<body style="font-family:Arial;background:#1a1a1a;color:white;padding:20px">
<h1>Eero Network Dashboard</h1>
<div id="status">Loading...</div>
<button onclick="showAuth()">Setup API</button>
<div id="auth" style="display:none">
<input id="email" placeholder="Email"><button onclick="sendCode()">Send Code</button><br>
<input id="code" placeholder="Code"><button onclick="verify()">Verify</button>
</div>
<script>
function showAuth(){document.getElementById('auth').style.display='block'}
async function sendCode(){
const r=await fetch('/auth',{method:'POST',headers:{'Content-Type':'application/json'},
body:JSON.stringify({step:'send',email:document.getElementById('email').value})})
alert((await r.json()).message)}
async function verify(){
const r=await fetch('/auth',{method:'POST',headers:{'Content-Type':'application/json'},
body:JSON.stringify({step:'verify',code:document.getElementById('code').value})})
alert((await r.json()).message)}
</script></body></html>'''

@app.route('/auth', methods=['POST'])
def auth():
    data = request.get_json()
    if data['step'] == 'send':
        try:
            r = requests.post(f"https://{CONFIG['api_url']}/2.2/pro/login", 
                json={"login": data['email']}, timeout=10)
            token = r.json()['data']['user_token']
            with open(TOKEN_FILE + '.temp', 'w') as f: f.write(token)
            return jsonify({'success': True, 'message': 'Code sent to email'})
        except: return jsonify({'success': False, 'message': 'Failed'})
    elif data['step'] == 'verify':
        try:
            with open(TOKEN_FILE + '.temp', 'r') as f: token = f.read()
            r = requests.post(f"https://{CONFIG['api_url']}/2.2/login/verify",
                headers={"X-User-Token": token}, data={"code": data['code']})
            if r.json().get('data', {}).get('email', {}).get('verified'):
                with open(TOKEN_FILE, 'w') as f: f.write(token)
                return jsonify({'success': True, 'message': 'Success!'})
        except: pass
        return jsonify({'success': False, 'message': 'Failed'})

if __name__ == '__main__': app.run(host='0.0.0.0', port=5000)
EOF

# Create service
cat > /etc/systemd/system/eero.service << 'EOF'
[Unit]
Description=Eero Dashboard
[Service]
ExecStart=/usr/bin/python3 /opt/eero/app.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# Configure nginx
cat > /etc/nginx/sites-enabled/default << 'EOF'
server {
    listen 80;
    location / { proxy_pass http://127.0.0.1:5000; }
}
EOF

# Start services
systemctl enable eero
systemctl start eero
systemctl restart nginx

echo "Setup complete!"