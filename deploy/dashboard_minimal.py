#!/usr/bin/env python3
"""
MiniRack Dashboard - Production Ready (Minimal)
Serves the full macOS replica dashboard from external template
"""
import os
import sys
import json
import requests
import threading
import time
import subprocess
from datetime import datetime, timedelta
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import logging

# Configuration
VERSION = "6.1.3-production"
CONFIG_FILE = "/opt/eero/app/config.json"
TOKEN_FILE = "/opt/eero/app/.eero_token"
TEMPLATE_FILE = "/opt/eero/app/index.html"
HISTORY_FILE = "/opt/eero/app/device_history.json"

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

def save_config(conig):
    """Save configuration"""
    try:
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)
        os.chmod(CONFIG_FILE, 0o600)
        return True
    except Exception as e:
        logging.error(f"Co)
        return False

def load_his
    """Load historical data fr""
    try:
     
 as f:
                history = json.load(f)
                logging.info(f"Loaded history: {len(
        history
    except Exception as e:
        logging.err")
    
    return {
        '[],
        
    }

def save_history(history_data):
    """Save historical data to persistent storage"""
    try:
        to_save = {
            'connected_users': history_data.get('
            'signal_)

        
        with open(HISTORY_FIas f:
        
        os.chmod(HISTORY_FILE, 0o600)
        return True
    except Exception as e:
        logging.err: {e}")
        return False

class EeroAPI:
    def __init__(self):
        self.session = requests.Session()
        self.config)
        self.api_token = sen()
        self.network_id = self.config.get('networ78317')
        self.api_url')
        self.api_base = f"ht
    
    def load_token(self):
        """Load API token"""
        try:
            if os.pE):
                with open( as f:
                    return f.read().strip()
        except Excep:

        return None
    
    def get_headers(self):
        """Get request headers"""
        headers = {
            'Content-Type': 'application/json',
            'User-Agent': f'MiniRack-Dashboard/{VERSION}'
        }
    
            headers['X-Us
        return headers
    
    def get_network_info(self):
        """Get network information including nam
        try:
            url = f"{self.api_
            response = self.session.get(url, header
            responss()
    )
            
            if 'data' in data:
                net
                logging.info(f"Retrieved networn')}")
                return network_data
         {}
        except Exception ae:
            logging.error(f"Network info fetch error)
            return {}
    
    def get_all_devices(self):
        """Get all devices with retry logic"""
        max_tries = 3
        for attempt in range(max_retries):
            try:
                url = f"{self.api_base}devices"
                response = self.se=15)
            ()
                data = responsson()
                
                if 'data' in data:
                    devices = data[', [])
                    l
                    return devices
                
                loggi
    []
                
            except requests.exceptions.Timeout
                logging")
                if attempt < max_retries - 1:
                )
                    continue
            except requests.exceptions.RequestException as e:
                logging.warning(f"API reque)
                if attempt < max_retri 1:
                )
                    continue
            except Exception as e:
                logging.error(f"Device fetch error on attempt {attempt + 1}: {e}")
                if attempt < max_r
                mpt)
                    continue
        
        logging.ailed")
        return []

# Initialize API
eero_api = EeroAPI()

# Load historical data on startup
historical_data = load_history()

# Data cache - initialize with loaded history
data_cache = {
    'connected_users': historical_, []),
    'device_os': {},
    'frequency_distribution': {},
    'signal_strength_avg': historical_data.get('signal_strength_avg,
    'devices': [],
    'lasone
}

:
    """Detect de"""
    manufacturer = s()
()
    text = f"{manufacturer} {host
    

    if any(k in manufacturer for k in ['amazo']):
        returnon'
    elif any(k in text for k in ['echo', 'alexa', 'fire tv', 'kind
        return 'Amaz
    
    # Apple/iOS detection
    elif any(k in ):
        return 'iOS'
 
OS'
    
    # Android detection (includes many manufacturers)
    elif any(k in manufacturer for k in ['samsung', 'google', ):
        return 'Android'
    elif any(k in text for k in ['andro:
    d'
    
    # Windows detection
    elif any(k in manuf
        return 'Windows'
    elif any(k in text e']):
    ws'
    
    # Gaming consoles and other specific devices
    elif any(k in ma
        return 'Gaming'
    elif any(k in te
    ming'
    
    # Smart TV and streaming devices
    elif any(k in manufat']):
        return 'Streaming'
    elif any(k in text f']):
    ming'
    
    else:
        return 'Other'

def parse_frequency(inte
    
    try:
        if interface_info is None:
            return 'N/AUnknown'
        
        freq = interfac)
    
            return 'N/A', 'Unknown'
        
        freq_value = float)
        if 2.4 <= freq_value < 2.5:
            band = '2.4GHz'
    ue < 6.0:
         z'
        elif 6.0 <= fr < 7.0:

        else:
            band = 'Unknown'
        
        return f"{freq} GHz", band
    except:
        nown'

def convert_signal_dbm_to_percent(signal_dbm):
    """Convert dBm to percentage"""
    try:
        if not signal_dbm or sig
            return 0
        dbm = float(str(sigstrip())
        if dbm >= -50:
            return 100
        elif dbm <= -100:
            return 0
        else:
            return int(2 * ())
    exce:
        return 0

def get_signal_quality(signal_d
"
    try:
        if not signal_dbm or signal:
        
        dbm = float(str(signal_dbm).replace(' dBm
        if dbm >= -50:
            return 'Excellent'
        elif dbm >= -60:
            return 'Very Good'
        elif dbm >= -70:
            return '
        elif 
            return 'Fair'
        else:
            retu
:
        return 'Unknown'

def updacache():
    """Update data cache with latest device infor
    global data_cache
    try:
        logging.info("")
        all_devices = eero_apis()
        
        # Validate we got actuta
        if not all_devices:
            logging.warnicache")
            if 'last_upd
                data_cacht()
            r
        
        # Ievices
        connected_device
     
        # If we get
        previous_device_count = len(data_cache.get('device))
        if len(connec0:
        
            return
        
        ]
        
        logging.info(f"Proc")
        
        # Process devices for detailed view
        device_list = []
        os_counts = {'iOS': 0, 'Android': 0, 'Windows': 0, 'Amazon': 0
        freq_count
         []
        
        # Process all connected devices for OS detection
        s:
            # OS Detection (for all devices)
            device_os = detect_device_os(device)
            os_counts[device_os] += 1
            
            # Freqevices
        e)
            interface_info = device.get('interface', {}) if is_wireless else {}
        
            if is_wireless:
        
                if freq_band in freq_counts:
                    freq= 1
                
                # Signal Strength (wireless only)
                signal_dbm
        )
                signal_quality = get_signal_quality(signl_dbm)
                
                if signal_dbm != 'N/A':
                    try:
                        signal_values
             except:
                        pass
            else:
                # Wired device
            
                freq_band =ed'
                signal_dbm = 'N/A'
                signal_percent = 100  # Wire"
                signal_quality = 'Wired'
            
            device_list.append({
                'name': device.get('nickname') or device.get('hostnaevice',
                'ip': ', '.join(device.get('ips', [])) if device.get('ips'N/A',
                'mac': device.get('mac', 'N/A'),
                
                'device_os': device_os,
                'connect
                'frequency': freq_display,
                'frequency_,
                'signal_avg_'N/A',
                '
                'signal_qualitl_quality
            })
        
        # Update connected users h)
        current_time = datetime.now()
        connected_users = data_cache.get
        connppend({
            'timestamp': currentt(),
            'count': len(connected_devices)
        })
        if len(connected_users) > 168:
            connected_users = connected_users[-168:]
        
        # Update signal strength history (keep last 168 points for 1 week ata)
        signal_strength_avg = data_cache.g[])
        if signal_values:
            avg_signal = sum(signal_values) / len(signal_values)
            signal_strength_avg.append({
                'timestamp': current_time.isofort(),
              1)
        
        if len(signal_strength_avg) > 168:
            signal_strength_avg = signal_strength_avg[-168:]
        
        # Update cache
        data_cache.update({
            'connected_users': connected_users,
            'device_os': os_counts,
          
            'signal_strength_avg': signal_strength_avg,
            'devices': device_list,
        ),
            'wireless_devices': len(wireless_devices),
            'wired_devices': len(connected_devices) - len(,
            'last_update': current_time.isoformat(),
            'last_successat()
        })
        
        # Save historical data to persistent storage
        save_history(data_cache)
        
        logging.info(f"Cache updated successfully: {len(connected_device
        
    exce:
        logging.error(")
        # Update last_updatged
        if 'last_update' in data_cache:
            data_cache['last_updateormat()

def filter_data_by_timerange(data, hours):
    """Filter time-series data by h""
    if not data or hours == 0:
        return data
    
    cutoff_time = datetime.now() - timedelta(hours=h
    return [
        enta 
        
    ]

# Routes
@app.route('/')
def index():
    """Serve main dashboar""
    try:
        if os.path.exists(TEMPLATE_FILE):
            with open(TEMPLATE_FILE, 'r as f:
                return f.read()
as e:
        logging.error(f"Template load erro: {e}")
    
    # Fallback minimal HTML
    return '''<!DOC html>
<htmhead>
<body><h1>Dashboard Loading...</h1>
<p>Please wa
<script>setTimeout(() => locatioipt>
</body></html>'''


@app.route('/api/dashboard')
def get_dashboa
    update_c
    return jsonify(data_cache)

@app.route('/api/dashboard/<int:hours>')
def get_dashboard_data_filtered(hours):
    """Get dashboard data filtege"""
    update_cache()
    filtered_cache = data_cache.copy()
    
    # Filter time-series da
    filtered_cache['connectedurs)
    filtered_cache['signal_strength_avg'] = filter_durs)
    
    return jsonify(filtered_cache)

@app.route('/api/etwork')
fo():
    """Get network information"""
    try:
        network_info = eek_info()
        return jso({
            'name': network_in'),
,
            'success': True
        })
    except Exception as e:
        return jsoy({
            'name': 'Unknown Network',
    rk_id,
            'success': False,
            'error': str(e)
        })

@app.route('/api/devices')
ices():
    return jsonify({
        'devices': data', []),
        'count': len(data_cache.g
    })

@app.route('/api/version
def get_version():
    config = load_config()
    return jsonify({
        'v
        'network_id': conf
        'environment': c
        'api_url': config.get('api_url),
        'authenticated': eero_api.api_token is
        'timestamp': datetimeat()
    })

)
def update_dashboard():
    """Update dash
    try:
        logging.info("Starting dashboard update f...")
        
      s
te = [
            {
                'u,
                'path': '/py'
            },
            {
                'url': 'https://raw.githubuserc, 
                'path': '/opt/eero/app/index.html'
            }
        ]
        
      h file
e:
            logging.info(f"Downloading {file_info}")
            
            response = requests.get(file_info['url'], timeout=30)
        
            
        up
            backup_path = f"{file_info['path']}.backup"
            if os.path.exis'path']):
             
                    with open(backup_path, 'w', encoding='utf-8') as dst:
                        dst.write(src.read())
            
            #e
            with open(file_info['path'], 'w', encoding='utf-8') as f:
                f.write(response.text)
            
         44)
        /gid
            os.chmod(file_info['path'
            
            logging.info(f"Updated {file_info['path']}")
        
        # Set directory permissions
        os.chown('/opt/eero/app', 33, 3
        os.c0o755)
        
        # Restart service using absolute path with propg
        logging.info("Restarting eero-dashboard sice...")
        
        # Try different approaches for restarting the service
        restart_commands = [
            ],
            ['/bin/sudo', '/rd'],
            ['/usr/bin/systemctl', 'restart', 'eero-dashboard'],
            ['/bin/systemctl', 'restar]
        ]
        
        restart_success = False
        for cmd in restart_commands:
            try:
                restart_result = subprocess.run(
        
                    capture_output=True, 
                    text=True, 
                    timeout=30,
        
                )
                
        
                    restart_success = True
                    logging.")
                    break
                else:
                    logging.warning(f"Command {' '.join(cmd)} fa)
            except Exception as e:
         
        
        
        if not restart_success:
            loggled")
            return jsonify({
                'success'e, 
                'message': 'Files updateddashboard'
            }), 500
        
        logging.info("Dashboard update completed successfully")
        return js({
            'suc, 
            'message': 'Dashboard code updated suc...'
        })
        
    except requests.Reque e:
        logging.error
        return jsonify({
            'success': False, 
            'message': f'Download failed: {str(e)}'
        }), 500
    exceor as e:
        logging.error(f"File op(e)}")
        return jsonify({
            'success': False, 
            'message': f'File oper'
        }), 500
    except Exception as e:
        ")
        return jsonify({
            'success': F 
            'message': f'Upda
        }), 500

@app.rou)
def change_network_id():
    try:
        data = request.gn()
        new_id = data.get('nettrip()
        
        if not t():
            return jsoni00
        
        config = load_config()
        config['network_id'] =w_id
        
        if save:
            eero_api.netwoew_id
            return jsonify({'success': True, 'me'})
        
        return jsonify({'succe
        
    except Exceas e:
500

@app.route('/api/admin/r'])
def reauize():
    try:
        data = request.get_json()
        d')
        
        if step == 'send':
        )
            if not email or '@:
                return jsonify({'succ), 400
         
            logging.info(f"Send
            response = requests.post(
                f"https://{eero_api.api_url}/2.2/pro/login",
        
                timeout=10
          )
            response.raises()
            response_data = response.json()
 
            logging.info(f"Login response: {response_d
            
        
                return jsonify({'500
            
         as f:
                f.write(re
            os.chmod(TOKEN_FILE + '.temp', 0o600)
            
            return jsonify({'success': True, 'message': 'Verification code sent to })
            
        elif step == 'verify':
            code = data.get('code', 'p()
            if not code:
                return jsonify({'succe400
            
            t'
            if not os.path.exists(temp_:
                return jsonify({'success': 0
            
            with open(temp_file, 'r') as f:
            strip()
            
            logging.info(f"Verifying code: {code}")
            
            # Try both form data and JSON for verifica
            verify_methods = [
                # Method 1: Form data (original e
            
                    f"https://{eero_api.api_url}/2.2/login/verify",
            d"},
                    data={"cod},
                    timeout=10
                ),
                # Method 2: JSON data
            (
                    f"https://{eero_api.api_erify",
                    headers={"X-User-Token": ,
                    json={"code": code},
            10
                )
            ]
            
            verify_response = None
            ):
                try:
                    verify_res)
                    verify_response.raise_for_status()
                    verify_data = veri()
                    logging.info(f"Verify method {i+1} response: {va}")
                    
                    # Check for successfn
                    if (verify
                  r
                        verify_respon):
                        
                        # Save the token
                        with open(TOKEN_FILE, 'w') as f:
                            f.write(toke)
                        os.chm
                   
             
            ile):
                            os.rem)
                        
                    
                        eero_api.api_token = ten
                        logging.info("Authentication s")
                        
                        return jsonify({'success': True, 'message': 'Authenticat
                    
                except requests.RequestException as e:
                    logging.warning(f"Verify method {i+1} failed: {str(e)}")
                    continue
                except Exception as e:
                    logg")
                    continue
            
            # If we get here, all methods 
            if verify_response:
                logging.")
                return jsonify({'success': F400
            else:
                return jsonify({'success': False
            
    except requests.RequestException as e:
        logging.error(f"Network error during reaut
        return jsonify({'success': False, 'message': f'Network er}), 500
    except Exception as :
        logging.error(f"Reauthorization error: {str(e)}")
        return jsoni, 500

if __name__ == '__main__':
    logging.info(f"Starting ON}")
    
    # Initial cache update
    try:
        upda
        logging.info("Initial cache update complete")
    except Exception as e:
        logging.warning(f"Initial cache update failed: {e}")
    
    app.run(host=e) debug=Fals000,', port=50.0.0.0'