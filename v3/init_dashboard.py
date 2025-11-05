#!/usr/bin/env python3
import os,sys,subprocess,urllib.request,re,shutil,threading,time,json,requests
from pathlib import Path

SCRIPT_VERSION="3.0.4"
GITHUB_REPO="eero-drew/minirackdash"
GITHUB_RAW=f"https://raw.githubusercontent.com/{GITHUB_REPO}/main"
SCRIPT_URL_V3=f"{GITHUB_RAW}/v3/init_dashboard.py"
INSTALL_DIR="/home/eero/dashboard"
CONFIG_FILE=f"{INSTALL_DIR}/.config.json"
TOKEN_FILE=f"{INSTALL_DIR}/.eero_token"
USER="eero"

class C:
    R='\033[0;31m';G='\033[0;32m';Y='\033[1;33m';B='\033[0;34m';C='\033[0;36m';M='\033[0;35m';N='\033[0m'

def pc(c,m):print(f"{c}{m}{C.N}")
def ps(m):pc(C.G,f"✓ {m}")
def pe(m):pc(C.R,f"✗ {m}")
def pw(m):pc(C.Y,f"⚠ {m}")
def pi(m):pc(C.C,f"ℹ {m}")
def ph(m):print("\n"+"="*60);pc(C.B,m.center(60));print("="*60+"\n")

def extract_version(s):
    m=re.search(r'SCRIPT_VERSION\s*=\s*["\']([^"\']+)["\']',s)
    return m.group(1)if m else None

def compare_versions(v1,v2):
    p1=[int(x)for x in v1.split('.')];p2=[int(x)for x in v2.split('.')]
    for i in range(max(len(p1),len(p2))):
        a=p1[i]if i<len(p1)else 0;b=p2[i]if i<len(p2)else 0
        if a>b:return 1
        elif a<b:return-1
    return 0

def load_config():
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE,'r')as f:return json.load(f)
    except:pass
    return{}

def save_config(cfg):
    try:
        os.makedirs(os.path.dirname(CONFIG_FILE),exist_ok=True)
        with open(CONFIG_FILE,'w')as f:json.dump(cfg,f,indent=2)
        os.chmod(CONFIG_FILE,0o600)
        if os.geteuid()==0:
            import pwd
            u=pwd.getpwnam(USER)
            os.chown(CONFIG_FILE,u.pw_uid,u.pw_gid)
        ps("Config saved");return True
    except Exception as e:pe(f"Save failed: {e}");return False

def prompt_network_id():
    ph("Network Configuration")
    cfg=load_config();sid=cfg.get('network_id')
    if sid:
        pi(f"Saved: {sid}");pc(C.M,"Press Enter to use saved, or enter new:");pc(C.C,"Network ID: ")
        nid=input().strip()
        if not nid:pw("Using saved");return sid
    else:
        pi("Enter Eero Network ID:");pc(C.C,"Network ID: ")
        nid=input().strip()
        while not nid:pe("Required!");pc(C.C,"Network ID: ");nid=input().strip()
    if not nid.isdigit():pe("Must be numeric!");sys.exit(1)
    cfg['network_id']=nid;cfg['last_updated']=time.strftime('%Y-%m-%dT%H:%M:%S')
    save_config(cfg);ps(f"Network ID: {nid}");return nid

def authenticate_eero(nid):
    ph("Eero API Authentication")
    if os.path.exists(TOKEN_FILE):
        pi("Existing token found");r=input("Re-authenticate? (yes/no): ").strip()
        if r.lower()not in['yes','y']:
            pi("Using existing token");cfg=load_config();cfg['last_auth']=time.time();save_config(cfg);return True
    pi("Authenticating...");pc(C.C,"Email: ");email=input().strip()
    if not email or'@'not in email:pe("Invalid email");return False
    pi(f"Sending code to: {email}")
    try:
        r=requests.post("https://api-user.e2ro.com/2.2/pro/login",json={"login":email},timeout=10)
        r.raise_for_status();rd=r.json()
        if'data'not in rd or'user_token'not in rd['data']:pe("Token gen failed");return False
        token=rd['data']['user_token'];ps("Code sent!")
        pc(C.C,"Verification code: ");code=input().strip()
        if not code:pe("Code required");return False
        pi("Verifying...")
        vr=requests.post("https://api-user.e2ro.com/2.2/login/verify",headers={"X-User-Token":token},data={"code":code},timeout=10)
        vr.raise_for_status();vd=vr.json()
        if vd.get('data',{}).get('email',{}).get('verified'):
            ps("Success!")
            os.makedirs(os.path.dirname(TOKEN_FILE),exist_ok=True)
            with open(TOKEN_FILE,'w')as f:f.write(token)
            os.chmod(TOKEN_FILE,0o600)
            if os.geteuid()==0:
                import pwd;u=pwd.getpwnam(USER);os.chown(TOKEN_FILE,u.pw_uid,u.pw_gid)
            cfg=load_config();cfg['last_auth']=time.time();save_config(cfg);ps("Token saved");return True
        else:pe("Verification failed");return False
    except Exception as e:pe(f"Error: {e}");return False

def check_updates():
    ph("Version Check");pi(f"Current: v{SCRIPT_VERSION}")
    try:
        with urllib.request.urlopen(SCRIPT_URL_V3,timeout=10)as r:latest=r.read().decode('utf-8')
        lv=extract_version(latest)
        if lv and compare_versions(lv,SCRIPT_VERSION)>0:
            pw(f"New version: v{lv}");curr=os.path.abspath(__file__)
            shutil.copy2(curr,f"{curr}.backup")
            with open(curr,'w')as f:f.write(latest)
            os.chmod(curr,0o755);ps("Updated!");time.sleep(1)
            os.execv(sys.executable,[sys.executable,curr]+sys.argv[1:])
        else:ps("Latest version")
    except:pass
    return False

def check_root():
    if os.geteuid()!=0:pe("Run as root (sudo)");sys.exit(1)

def run_cmd(cmd,timeout=300,show=False):
    try:
        if show:return subprocess.run(cmd,shell=True,timeout=timeout).returncode==0
        return subprocess.run(cmd,shell=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=timeout).returncode==0
    except:return False

def create_user():
    pi("Setting up user...")
    if subprocess.run(['id',USER],capture_output=True).returncode!=0:run_cmd(f'useradd -m -s /bin/bash {USER}')
    ps(f"User ready: {USER}")

def update_system():
    ph("Updating System")
    run_cmd('apt-get update',120,True)
    run_cmd('DEBIAN_FRONTEND=noninteractive apt-get upgrade -y',600,True)

def install_deps():
    ph("Installing Dependencies")
    run_cmd("DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip python3-venv nginx git curl speedtest-cli chromium-browser unclutter x11-xserver-utils xdotool",600,True)
    ps("Dependencies installed")

def create_dirs():
    for d in[f"{INSTALL_DIR}/backend",f"{INSTALL_DIR}/frontend",f"{INSTALL_DIR}/frontend/assets",f"{INSTALL_DIR}/logs"]:
        Path(d).mkdir(parents=True,exist_ok=True)
    run_cmd(f'chown -R {USER}:{USER} /home/eero')

def setup_python():
    run_cmd(f'sudo -u {USER} python3 -m venv {INSTALL_DIR}/venv',120)
    run_cmd(f'sudo -u {USER} {INSTALL_DIR}/venv/bin/pip install --quiet flask flask-cors requests gunicorn speedtest-cli',300)
    ps("Python ready")

def create_backend(nid):
    pi("Creating backend...")
    code=f'''#!/usr/bin/env python3
import os,sys,json,requests,speedtest,threading,subprocess,urllib.request,re,time
from datetime import datetime,timedelta
from flask import Flask,jsonify,request
from flask_cors import CORS
import logging
app=Flask(__name__)
CORS(app)
logging.basicConfig(filename='/home/eero/dashboard/logs/backend.log',level=logging.INFO,format='%(asctime)s-%(levelname)s-%(message)s')
NETWORK_ID="{nid}"
EERO_API_BASE="https://api-user.e2ro.com/2.2"
API_TOKEN_FILE="/home/eero/dashboard/.eero_token"
CONFIG_FILE="/home/eero/dashboard/.config.json"
GITHUB_RAW="https://raw.githubusercontent.com/{GITHUB_REPO}/main"
SCRIPT_URL_V3=f"{{GITHUB_RAW}}/v3/init_dashboard.py"
def load_config():
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE,'r')as f:return json.load(f)
    except:pass
    return{{}}
def save_config(c):
    try:
        with open(CONFIG_FILE,'w')as f:json.dump(c,f,indent=2)
        os.chmod(CONFIG_FILE,0o600);return True
    except:return False
class EeroAPI:
    def __init__(self):
        self.session=requests.Session();self.api_token=self.load_token();self.network_id=self.load_network_id()
    def load_token(self):
        try:
            if os.path.exists(API_TOKEN_FILE):
                with open(API_TOKEN_FILE,'r')as f:return f.read().strip()
        except:pass
        return None
    def load_network_id(self):
        c=load_config();return c.get('network_id',NETWORK_ID)
    def reload_network_id(self):self.network_id=self.load_network_id()
    def reload_token(self):self.api_token=self.load_token()
    def get_headers(self):
        h={{'Content-Type':'application/json','User-Agent':'Eero-Dashboard/3.0'}}
        if self.api_token:h['X-User-Token']=self.api_token
        return h
    def get_all_devices(self):
        try:
            url=f"{{EERO_API_BASE}}/networks/{{self.network_id}}/devices"
            r=self.session.get(url,headers=self.get_headers(),timeout=10);r.raise_for_status();d=r.json()
            if'data'in d:
                if isinstance(d['data'],list):return d['data']
                elif isinstance(d['data'],dict)and'devices'in d['data']:return d['data']['devices']
            return[]
        except Exception as e:logging.error(f"Device fetch error:{{e}}");return[]
def safe_str(v,d=''):return d if v is None else str(v)
def safe_lower(v,d=''):return d if v is None else str(v).lower()
def categorize_os(dev):
    txt=f"{{safe_lower(dev.get('manufacturer'))}} {{safe_lower(dev.get('device_type'))}} {{safe_lower(dev.get('hostname'))}} {{safe_lower(dev.get('model_name'))}} {{safe_lower(dev.get('display_name'))}}"
    for k in['apple','iphone','ipad','mac','macbook','ios']:
        if k in txt:return'iOS'
    for k in['android','samsung','google','pixel','xiaomi','lg','motorola','sony','oneplus']:
        if k in txt:return'Android'
    for k in['windows','microsoft','dell','hp','lenovo','asus','surface','pc','laptop']:
        if k in txt:return'Windows'
    return'Other'
def estimate_signal(s):return{{5:-45,4:-55,3:-65,2:-75,1:-85,0:-90}}.get(s,-90)
def get_quality(s):
    if s is None:return'Unknown'
    try:
        b=int(s)
        if b>=5:return'Excellent'
        elif b==4:return'Very Good'
        elif b==3:return'Good'
        elif b==2:return'Fair'
        elif b==1:return'Poor'
    except:pass
    return'Unknown'
def dbm_to_pct(s):
    try:
        if not s or s=='N/A':return 0
        dbm=float(str(s).replace(' dBm','').strip())
        if dbm>=-50:return 100
        elif dbm<=-100:return 0
        else:return int(2*(dbm+100))
    except:return 0
def parse_freq(i):
    try:
        if i is None:return'N/A','Unknown'
        freq=i.get('frequency')
        if freq is None or freq=='N/A'or freq=='':return'N/A','Unknown'
        fv=float(freq)
        if 2.4<=fv<2.5:band='2.4GHz'
        elif 5.0<=fv<6.0:band='5GHz'
        elif 6.0<=fv<7.0:band='6GHz'
        else:band='Unknown'
        return f"{{freq}} GHz",band
    except:return'N/A','Unknown'
def extract_ver(s):
    m=re.search(r'SCRIPT_VERSION\\s*=\\s*["\']([^"\']+)["\']',s)
    return m.group(1)if m else None
def compare_ver(v1,v2):
    p1=[int(x)for x in v1.split('.')];p2=[int(x)for x in v2.split('.')]
    for i in range(max(len(p1),len(p2))):
        a=p1[i]if i<len(p1)else 0;b=p2[i]if i<len(p2)else 0
        if a>b:return 1
        elif a<b:return-1
    return 0
eero_api=EeroAPI()
data_cache={{'connected_users':[],'device_os':{{}},'frequency_distribution':{{}},'signal_strength_avg':[],'devices':[],'last_update':None,'speedtest_running':False,'speedtest_result':None}}
cache_lock=threading.Lock()
def update_cache():
    global data_cache
    try:
        all_devs=eero_api.get_all_devices()
        if not all_devs:logging.warning("No devices returned");return
        wireless=[d for d in all_devs if d.get('connected')and(safe_lower(d.get('connection_type'))=='wireless'or d.get('wireless'))]
        ct=datetime.now()
        with cache_lock:
            data_cache['connected_users'].append({{'timestamp':ct.isoformat(),'count':len(wireless)}})
            two_hrs=ct-timedelta(hours=2)
            data_cache['connected_users']=[e for e in data_cache['connected_users']if datetime.fromisoformat(e['timestamp'])>two_hrs]
            dos={{'iOS':0,'Android':0,'Windows':0,'Other':0}}
            fd={{'2.4GHz':0,'5GHz':0,'6GHz':0,'Unknown':0}}
            sigs=[];devs=[]
            for dev in wireless:
                ost=categorize_os(dev);dos[ost]+=1
                conn=dev.get('connectivity',{{}})or{{}};iface=dev.get('interface',{{}})or{{}}
                freq_disp,freq_band=parse_freq(iface)
                if freq_band in fd:fd[freq_band]+=1
                sig_dbm=conn.get('signal_avg');score_bars=conn.get('score_bars',0)
                if sig_dbm is None and score_bars:sig_dbm=estimate_signal(score_bars)
                sig_pct=dbm_to_pct(sig_dbm)
                if sig_dbm is not None:
                    try:sigs.append(float(sig_dbm)if isinstance(sig_dbm,(int,float))else float(str(sig_dbm).replace(' dBm','').strip()))
                    except:pass
                devs.append({{'name':safe_str(dev.get('nickname')or dev.get('hostname')or dev.get('display_name')or'Unknown'),'ip':', '.join(dev.get('ips',[]))if dev.get('ips')else'N/A','mac':safe_str(dev.get('mac'),'N/A'),'manufacturer':safe_str(dev.get('manufacturer'),'Unknown'),'signal_avg':sig_pct,'signal_avg_dbm':f"{{sig_dbm}} dBm"if sig_dbm else'N/A','score_bars':score_bars,'signal_quality':get_quality(score_bars),'device_os':ost,'frequency':freq_disp,'frequency_band':freq_band}})
            data_cache['device_os']=dos;data_cache['frequency_distribution']=fd
            data_cache['devices']=sorted(devs,key=lambda x:x['name'].lower())
            if sigs:
                avg=sum(sigs)/len(sigs)
                data_cache['signal_strength_avg'].append({{'timestamp':ct.isoformat(),'avg_dbm':round(avg,2)}})
                data_cache['signal_strength_avg']=[e for e in data_cache['signal_strength_avg']if datetime.fromisoformat(e['timestamp'])>two_hrs]
            data_cache['last_update']=ct.isoformat()
            logging.info(f"Cache updated: {{len(wireless)}} devices")
    except Exception as e:logging.error(f"Cache update error:{{e}}")
def background_updater():
    while True:
        try:update_cache();time.sleep(30)
        except Exception as e:logging.error(f"Background updater error:{{e}}");time.sleep(30)
def run_speedtest():
    global data_cache
    try:
        with cache_lock:data_cache['speedtest_running']=True
        st=speedtest.Speedtest();st.get_best_server()
        with cache_lock:
            data_cache['speedtest_result']={{'download':round(st.download()/1_000_000,2),'upload':round(st.upload()/1_000_000,2),'ping':round(st.results.ping,2),'timestamp':datetime.now().isoformat()}}
    except Exception as e:
        with cache_lock:data_cache['speedtest_result']={{'error':str(e)}}
    finally:
        with cache_lock:data_cache['speedtest_running']=False
@app.route('/api/dashboard')
def get_dashboard():
    with cache_lock:return jsonify(data_cache)
@app.route('/api/devices')
def get_devices():
    with cache_lock:return jsonify({{'devices':data_cache.get('devices',[]),'count':len(data_cache.get('devices',[]))}})
@app.route('/api/speedtest/start',methods=['POST'])
def start_speedtest():
    with cache_lock:
        if data_cache['speedtest_running']:return jsonify({{'status':'running'}}),409
    threading.Thread(target=run_speedtest,daemon=True).start()
    return jsonify({{'status':'started'}})
@app.route('/api/speedtest/status')
def speedtest_status():
    with cache_lock:return jsonify({{'running':data_cache['speedtest_running'],'result':data_cache['speedtest_result']}})
@app.route('/api/health')
def health():return jsonify({{'status':'ok','timestamp':datetime.now().isoformat()}})
@app.route('/api/version')
def version():
    c=load_config();la=c.get('last_auth',0);hrs=(time.time()-la)/3600 if la else 999
    return jsonify({{'version':'3.0.4','name':'Eero Dashboard','network_id':c.get('network_id',eero_api.network_id),'hours_since_auth':round(hrs,1),'needs_reauth':hrs>=24}})
@app.route('/api/admin/check-update')
def check_update():
    try:
        with urllib.request.urlopen(SCRIPT_URL_V3,timeout=10)as r:ls=r.read().decode('utf-8')
        lv=extract_ver(ls)
        return jsonify({{'current_version':'3.0.4','latest_version':lv or'3.0.4','update_available':compare_ver(lv or'3.0.4','3.0.4')>0}})
    except:return jsonify({{'current_version':'3.0.4','latest_version':'3.0.4','update_available':False}})
@app.route('/api/admin/update',methods=['POST'])
def update_sys():
    try:
        with urllib.request.urlopen(SCRIPT_URL_V3,timeout=10)as r:ls=r.read().decode('utf-8')
        lv=extract_ver(ls)
        if not lv or compare_ver(lv,'3.0.4')<=0:return jsonify({{'success':False,'message':'Already latest'}})
        sp='/root/init_dashboard.py'
        if not os.path.exists(sp):sp=os.path.abspath(sys.argv[0])
        with open(f"{{sp}}.backup",'w')as f:
            with open(sp,'r')as o:f.write(o.read())
        with open(sp,'w')as f:f.write(ls)
        os.chmod(sp,0o755)
        subprocess.Popen(['/usr/bin/sudo','/usr/bin/python3',sp,'--no-update'])
        return jsonify({{'success':True,'message':f'Updated to v{{lv}}'}})
    except Exception as e:return jsonify({{'success':False,'message':str(e)}}),500
@app.route('/api/admin/restart',methods=['POST'])
def restart():
    try:
        r=subprocess.run(['sudo','systemctl','restart','eero-dashboard'],capture_output=True,timeout=10)
        return jsonify({{'success':r.returncode==0,'message':'Restarted'if r.returncode==0 else'Failed'}})
    except Exception as e:return jsonify({{'success':False,'message':str(e)}}),500
@app.route('/api/admin/reboot',methods=['POST'])
def reboot():subprocess.Popen(['sudo','reboot']);return jsonify({{'success':True,'message':'Rebooting'}})
@app.route('/api/admin/network-id',methods=['POST'])
def change_network():
    try:
        d=request.get_json();nid=d.get('network_id','').strip()
        if not nid or not nid.isdigit():return jsonify({{'success':False,'message':'Invalid ID'}}),400
        c=load_config();c['network_id']=nid;c['last_updated']=datetime.now().strftime('%Y-%m-%dT%H:%M:%S')
        if save_config(c):
            eero_api.reload_network_id();subprocess.Popen(['sudo','systemctl','restart','eero-dashboard'])
            return jsonify({{'success':True,'message':f'Updated to {{nid}}'}})
        return jsonify({{'success':False,'message':'Save failed'}}),500
    except Exception as e:return jsonify({{'success':False,'message':str(e)}}),500
@app.route('/api/admin/reauthorize',methods=['POST'])
def reauth():
    try:
        d=request.get_json();email=d.get('email','').strip();code=d.get('code','').strip();step=d.get('step','send')
        if step=='send':
            if not email or'@'not in email:return jsonify({{'success':False,'message':'Invalid email'}}),400
            r=requests.post("https://api-user.e2ro.com/2.2/pro/login",json={{"login":email}},timeout=10);r.raise_for_status();rd=r.json()
            if'data'not in rd or'user_token'not in rd['data']:return jsonify({{'success':False,'message':'Token gen failed'}}),500
            with open(API_TOKEN_FILE+'.temp','w')as f:f.write(rd['data']['user_token'])
            return jsonify({{'success':True,'message':'Code sent','step':'verify'}})
        elif step=='verify':
            if not code:return jsonify({{'success':False,'message':'Code required'}}),400
            if not os.path.exists(API_TOKEN_FILE+'.temp'):return jsonify({{'success':False,'message':'Restart process'}}),400
            with open(API_TOKEN_FILE+'.temp','r')as f:token=f.read().strip()
            vr=requests.post("https://api-user.e2ro.com/2.2/login/verify",headers={{"X-User-Token":token}},data={{"code":code}},timeout=10);vr.raise_for_status();vd=vr.json()
            if vd.get('data',{{}}).get('email',{{}}).get('verified'):
                with open(API_TOKEN_FILE,'w')as f:f.write(token)
                os.chmod(API_TOKEN_FILE,0o600)
                if os.path.exists(API_TOKEN_FILE+'.temp'):os.remove(API_TOKEN_FILE+'.temp')
                c=load_config();c['last_auth']=time.time();save_config(c);eero_api.reload_token()
                return jsonify({{'success':True,'message':'Reauthorized!'}})
            return jsonify({{'success':False,'message':'Verification failed'}}),400
    except Exception as e:return jsonify({{'success':False,'message':str(e)}}),500
if __name__=='__main__':
    logging.info("Starting Eero Dashboard Backend v3.0.4")
    update_cache()
    threading.Thread(target=background_updater,daemon=True).start()
    app.run(host='127.0.0.1',port=5000,debug=False)
'''
    with open(f"{INSTALL_DIR}/backend/eero_api.py",'w')as f:f.write(code)
    os.chmod(f"{INSTALL_DIR}/backend/eero_api.py",0o755)
    run_cmd(f'chown {USER}:{USER} {INSTALL_DIR}/backend/eero_api.py')
    ps("Backend created")

def create_frontend():
    pi("Creating frontend...")
    html="""<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Eero v3</title><script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script><link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css"><style>*{margin:0;padding:0;box-sizing:border-box}body{background:linear-gradient(135deg,#001a33 0%,#003366 100%);font-family:'Segoe UI',sans-serif;color:#fff;overflow:hidden;height:100vh}.header{background:rgba(0,20,40,.9);padding:8px 20px;display:flex;justify-content:space-between;align-items:center;border-bottom:2px solid rgba(77,166,255,.3)}.logo{height:30px}.header-title{font-size:18px;font-weight:600;color:#4da6ff}.header-actions{display:flex;gap:10px;align-items:center}.header-btn{padding:6px 12px;background:rgba(77,166,255,.2);border:2px solid #4da6ff;border-radius:6px;color:#fff;cursor:pointer;display:flex;align-items:center;gap:6px;font-size:12px;transition:all .3s}.header-btn:hover{background:rgba(77,166,255,.4);transform:translateY(-2px)}.header-btn:disabled{opacity:.5;cursor:not-allowed}.status-indicator{display:flex;align-items:center;gap:6px;padding:6px 12px;background:rgba(0,0,0,.3);border-radius:15px;font-size:11px}.status-dot{width:8px;height:8px;border-radius:50%;background:#4CAF50;animation:pulse 2s infinite}@keyframes pulse{0%,100%{opacity:1}50%{opacity:.5}}.pi-icon{position:fixed;bottom:20px;right:20px;width:30px;height:30px;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);border-radius:50%;display:flex;align-items:center;justify-content:center;cursor:pointer;box-shadow:0 4px 20px rgba(102,126,234,.4);transition:all .3s;z-index:999;font-size:16px;font-weight:700;color:#fff;border:2px solid rgba(255,255,255,.3)}.pi-icon:hover{transform:scale(1.1) rotate(180deg)}.dashboard-container{display:grid;grid-template-columns:1fr 1fr 1fr 1fr;gap:10px;padding:10px;height:calc(100vh - 60px)}.chart-card{background:rgba(0,40,80,.7);border-radius:10px;padding:10px;box-shadow:0 8px 32px rgba(0,0,0,.3);border:1px solid rgba(255,255,255,.1);display:flex;flex-direction:column}.chart-title{font-size:14px;font-weight:600;margin-bottom:8px;text-align:center;color:#4da6ff;text-transform:uppercase}.chart-subtitle{font-size:11px;text-align:center;color:rgba(255,255,255,.6);margin-bottom:8px}.chart-container{flex:1;position:relative;min-height:0}canvas{max-width:100%;max-height:100%}.modal{display:none;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,.8);z-index:1000;justify-content:center;align-items:center}.modal.active{display:flex}.modal-content{background:linear-gradient(135deg,#001a33 0%,#003366 100%);border-radius:15px;padding:30px;max-width:900px;width:90%;max-height:80vh;overflow-y:auto;border:2px solid rgba(77,166,255,.3)}.gibson-modal .modal-content{max-width:600px;background:linear-gradient(135deg,#0a0e27 0%,#1a1a2e 100%);border:2px solid #667eea}.gibson-title{font-size:32px;color:#667eea;text-align:center;margin-bottom:10px;font-weight:700;text-shadow:0 0 20px rgba(102,126,234,.5);letter-spacing:2px}.gibson-subtitle{text-align:center;color:rgba(255,255,255,.6);font-size:12px;margin-bottom:30px;font-style:italic}.version-info{background:rgba(0,0,0,.3);padding:20px;border-radius:10px;margin-bottom:20px;border:1px solid rgba(102,126,234,.3)}.version-row{display:flex;justify-content:space-between;margin-bottom:10px;font-size:14px}.version-label{color:#667eea;font-weight:600}.version-value{color:#fff;font-family:'Courier New',monospace}.version-status{text-align:center;padding:10px;border-radius:8px;margin-top:15px;font-weight:600}.version-status.up-to-date{background:rgba(76,175,80,.2);color:#4CAF50;border:1px solid #4CAF50}.version-status.update-available{background:rgba(255,193,7,.2);color:#ffc107;border:1px solid #ffc107}.admin-actions{display:grid;gap:15px;margin-top:20px}.admin-btn{padding:15px 20px;border:none;border-radius:10px;font-size:16px;font-weight:600;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:10px;transition:all .3s}.admin-btn:hover{transform:translateY(-2px)}.admin-btn:disabled{opacity:.5;cursor:not-allowed;transform:none}.admin-btn.update{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:#fff}.admin-btn.restart{background:linear-gradient(135deg,#f093fb 0%,#f5576c 100%);color:#fff}.admin-btn.reboot{background:linear-gradient(135deg,#fa709a 0%,#fee140 100%);color:#1a1a2e}.admin-btn.network{background:linear-gradient(135deg,#4facfe 0%,#00f2fe 100%);color:#fff}.admin-btn.auth{background:linear-gradient(135deg,#ffc837 0%,#ff8008 100%);color:#fff}.modal-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;padding-bottom:15px;border-bottom:2px solid rgba(77,166,255,.3)}.modal-title{font-size:24px;color:#4da6ff}.close-btn{background:0 0;border:none;color:#fff;font-size:28px;cursor:pointer}.close-btn:hover{color:#ff6b6b}.device-table{width:100%;border-collapse:collapse;margin-top:15px}.device-table th{background:rgba(77,166,255,.2);padding:12px;text-align:left;font-weight:600;color:#4da6ff;border-bottom:2px solid rgba(77,166,255,.3)}.device-table td{padding:12px;border-bottom:1px solid rgba(255,255,255,.1)}.device-table tr:hover{background:rgba(77,166,255,.1)}.signal-bar{width:100px;height:8px;background:rgba(255,255,255,.1);border-radius:4px;overflow:hidden}.signal-fill{height:100%;border-radius:4px}.signal-excellent{background:#4CAF50}.signal-good{background:#8BC34A}.signal-fair{background:#FFC107}.signal-poor{background:#FF9800}.signal-weak{background:#F44336}.speedtest-container{text-align:center;padding:20px}.speedtest-results{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;margin-top:30px}.speedtest-metric{background:rgba(0,40,80,.5);padding:25px;border-radius:10px}.speedtest-metric-label{font-size:14px;color:#4da6ff;margin-bottom:10px}.speedtest-metric-value{font-size:36px;font-weight:600;color:#fff}.speedtest-metric-unit{font-size:14px;color:rgba(255,255,255,.7)}.spinner{border:4px solid rgba(77,166,255,.3);border-top:4px solid #4da6ff;border-radius:50%;width:50px;height:50px;animation:spin 1s linear infinite;margin:20px auto}@keyframes spin{0%{transform:rotate(0)}100%{transform:rotate(360deg)}}.device-count{font-size:16px;color:rgba(255,255,255,.8);margin-bottom:15px}.action-message{padding:15px;border-radius:8px;margin-top:15px;text-align:center;font-weight:600}.action-message.success{background:rgba(76,175,80,.2);color:#4CAF50;border:1px solid #4CAF50}.action-message.error{background:rgba(244,67,54,.2);color:#f44336;border:1px solid #f44336}.action-message.info{background:rgba(77,166,255,.2);color:#4da6ff;border:1px solid #4da6ff}.input-group{margin:20px 0}.input-group label{display:block;color:#667eea;font-weight:600;margin-bottom:10px;font-size:14px}.input-group input{width:100%;padding:12px;background:rgba(0,0,0,.3);border:2px solid rgba(102,126,234,.3);border-radius:8px;color:#fff;font-size:16px;font-family:'Courier New',monospace}.input-group input:focus{outline:none;border-color:#667eea}.reauth-warning{background:rgba(255,193,7,.2);border:2px solid #ffc107;color:#ffc107;padding:15px;border-radius:10px;margin-bottom:20px;text-align:center;font-weight:600}</style></head><body><div class="header"><div style="display:flex;align-items:center;gap:10px"><img src="/assets/eero-logo.png" class="logo" onerror="this.style.display='none'"><div class="header-title">Network Dashboard v3.0.4</div></div><div class="header-actions"><div class="status-indicator"><div class="status-dot"></div><span id="lastUpdate">Loading...</span></div><button class="header-btn" id="deviceDetailsBtn"><i class="fas fa-list"></i><span>Devices</span></button><button class="header-btn" id="speedTestBtn"><i class="fas fa-gauge-high"></i><span>Speed Test</span></button></div></div><div class="dashboard-container"><div class="chart-card"><div class="chart-title">Connected Users</div><div class="chart-subtitle">Wireless devices over time</div><div class="chart-container"><canvas id="usersChart"></canvas></div></div><div class="chart-card"><div class="chart-title">Device OS</div><div class="chart-subtitle" id="deviceOsSubtitle">Loading...</div><div class="chart-container"><canvas id="deviceOSChart"></canvas></div></div><div class="chart-card"><div class="chart-title">Frequency Distribution</div><div class="chart-subtitle" id="frequencySubtitle">Loading...</div><div class="chart-container"><canvas id="frequencyChart"></canvas></div></div><div class="chart-card"><div class="chart-title">Average Signal Strength</div><div class="chart-subtitle">Network-wide average (dBm)</div><div class="chart-container"><canvas id="signalStrengthChart"></canvas></div></div></div><div class="pi-icon" id="piIcon">π</div><div class="modal" id="reauthReminderModal"><div class="modal-content" style="max-width:500px"><div class="modal-header"><h2 class="modal-title">⏰ Reauthorization Required</h2><button class="close-btn" onclick="document.getElementById('reauthReminderModal').classList.remove('active')">&times;</button></div><div class="reauth-warning"><i class="fas fa-exclamation-triangle"></i> Your API token is over 24 hours old!</div><p style="text-align:center;margin-bottom:20px;color:rgba(255,255,255,0.8)">For security, please reauthorize your connection.</p><button class="admin-btn auth" onclick="document.getElementById('reauthReminderModal').classList.remove('active');openReauthorize()" style="width:100%"><i class="fas fa-key"></i><span>Reauthorize Now</span></button><button class="header-btn" onclick="localStorage.setItem('reauth_reminder_dismissed','true');document.getElementById('reauthReminderModal').classList.remove('active')" style="width:100%;margin-top:10px;justify-content:center"><i class="fas fa-clock"></i><span>Remind Me Later</span></button></div></div><div class="modal gibson-modal" id="gibsonModal"><div class="modal-content"><div class="modal-header"><h2 class="gibson-title">THE GIBSON</h2><button class="close-btn" id="closeGibsonModal">&times;</button></div><div class="gibson-subtitle">"Hack the Planet!"</div><div class="version-info"><div class="version-row"><span class="version-label">Current:</span><span class="version-value" id="currentVersion">Loading...</span></div><div class="version-row"><span class="version-label">Latest:</span><span class="version-value" id="latestVersion">Checking...</span></div><div class="version-row"><span class="version-label">Network ID:</span><span class="version-value" id="networkId">Loading...</span></div><div class="version-row"><span class="version-label">Last Auth:</span><span class="version-value" id="lastAuth">Loading...</span></div><div class="version-status" id="versionStatus"><i class="fas fa-spinner fa-spin"></i> Checking...</div></div><div class="admin-actions"><button class="admin-btn update" id="updateBtn" disabled><i class="fas fa-download"></i><span>Update</span></button><button class="admin-btn auth" id="reauthorizeBtn"><i class="fas fa-key"></i><span>Reauthorize</span></button><button class="admin-btn network" id="changeNetworkBtn"><i class="fas fa-network-wired"></i><span>Change Network ID</span></button><button class="admin-btn restart" id="restartBtn"><i class="fas fa-rotate-right"></i><span>Restart Service</span></button><button class="admin-btn reboot" id="rebootBtn"><i class="fas fa-power-off"></i><span>Reboot System</span></button></div><div id="actionMessage"></div></div></div><div class="modal" id="reauthorizeModal"><div class="modal-content" style="max-width:500px"><div class="modal-header"><h2 class="modal-title">Reauthorize</h2><button class="close-btn" id="closeReauthorizeModal">&times;</button></div><div id="reauthStep1"><div class="input-group"><label for="reauthEmail">Eero API Email:</label><input type="email" id="reauthEmail" placeholder="email@example.com"/></div><button class="admin-btn auth" id="sendReauthCodeBtn" style="width:100%"><i class="fas fa-paper-plane"></i><span>Send Code</span></button></div><div id="reauthStep2" style="display:none"><p style="text-align:center;margin-bottom:20px">✓ Code sent! Check your email.</p><div class="input-group"><label for="reauthCode">Verification Code:</label><input type="text" id="reauthCode" placeholder="123456"/></div><button class="admin-btn auth" id="verifyReauthCodeBtn" style="width:100%"><i class="fas fa-check"></i><span>Verify</span></button></div><div id="reauthMessage"></div></div></div><div class="modal" id="networkIdModal"><div class="modal-content" style="max-width:500px"><div class="modal-header"><h2 class="modal-title">Change Network ID</h2><button class="close-btn" id="closeNetworkIdModal">&times;</button></div><div class="input-group"><label for="newNetworkId">New Network ID:</label><input type="text" id="newNetworkId" placeholder="18073602"/></div><button class="admin-btn network" id="saveNetworkBtn" style="width:100%;margin-top:20px"><i class="fas fa-save"></i><span>Save & Restart</span></button><div id="networkMessage"></div></div></div><div class="modal" id="deviceModal"><div class="modal-content"><div class="modal-header"><h2 class="modal-title">Connected Devices</h2><button class="close-btn" id="closeDeviceModal">&times;</button></div><div class="device-count" id="deviceCount">Loading...</div><table class="device-table"><thead><tr><th>Device</th><th>OS</th><th>Freq</th><th>IP</th><th>Manufacturer</th><th>Signal</th></tr></thead><tbody id="deviceTableBody"><tr><td colspan="6" style="text-align:center">Loading...</td></tr></tbody></table></div></div><div class="modal" id="speedTestModal"><div class="modal-content"><div class="modal-header"><h2 class="modal-title">Speed Test</h2><button class="close-btn" id="closeSpeedTestModal">&times;</button></div><div class="speedtest-container" id="speedTestContainer"><button class="header-btn" id="runSpeedTest" style="margin:20px auto"><i class="fas fa-play"></i><span>Run Test</span></button></div></div></div><script>let charts={};const cc={primary:'#4da6ff',success:'#51cf66',warning:'#ffd43b',info:'#74c0fc',purple:'#b197fc',orange:'#ff922b'};const opts={responsive:true,maintainAspectRatio:false,plugins:{legend:{labels:{color:'#fff',font:{size:10}}}},scales:{y:{ticks:{color:'#fff',font:{size:9}},grid:{color:'rgba(255,255,255,0.1)'}},x:{ticks:{color:'#fff',font:{size:9}},grid:{color:'rgba(255,255,255,0.1)'}}}};function initCharts(){charts.users=new Chart(document.getElementById('usersChart').getContext('2d'),{type:'line',data:{labels:[],datasets:[{label:'Connected',data:[],borderColor:cc.primary,backgroundColor:'rgba(77,166,255,0.1)',tension:0.4,fill:true,borderWidth:2}]},options:opts});charts.deviceOS=new Chart(document.getElementById('deviceOSChart').getContext('2d'),{type:'doughnut',data:{labels:['iOS','Android','Windows','Other'],datasets:[{data:[0,0,0,0],backgroundColor:[cc.primary,cc.success,cc.info,cc.warning],borderWidth:2,borderColor:'#001a33'}]},options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{position:'bottom',labels:{color:'#fff',font:{size:10},padding:8}}}}});charts.frequency=new Chart(document.getElementById('frequencyChart').getContext('2d'),{type:'doughnut',data:{labels:['2.4 GHz','5 GHz','6 GHz'],datasets:[{data:[0,0,0],backgroundColor:[cc.orange,cc.primary,cc.purple],borderWidth:2,borderColor:'#001a33'}]},options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{position:'bottom',labels:{color:'#fff',font:{size:10},padding:8}}}}});charts.signalStrength=new Chart(document.getElementById('signalStrengthChart').getContext('2d'),{type:'line',data:{labels:[],datasets:[{label:'Avg Signal',data:[],borderColor:cc.success,backgroundColor:'rgba(81,207,102,0.1)',tension:0.4,fill:true,borderWidth:2}]},options:opts});}async function updateDashboard(){try{const r=await fetch('/api/dashboard');const d=await r.json();charts.users.data.labels=d.connected_users.map(e=>new Date(e.timestamp).toLocaleTimeString());charts.users.data.datasets[0].data=d.connected_users.map(e=>e.count);charts.users.update();const os=d.device_os||{};const tot=Object.values(os).reduce((a,b)=>a+b,0);charts.deviceOS.data.datasets[0].data=[os.iOS||0,os.Android||0,os.Windows||0,os.Other||0];charts.deviceOS.update();document.getElementById('deviceOsSubtitle').textContent=`${tot} devices`;const fd=d.frequency_distribution||{};const tf=(fd['2.4GHz']||0)+(fd['5GHz']||0)+(fd['6GHz']||0);charts.frequency.data.datasets[0].data=[fd['2.4GHz']||0,fd['5GHz']||0,fd['6GHz']||0];charts.frequency.update();document.getElementById('frequencySubtitle').textContent=`${tf} devices`;charts.signalStrength.data.labels=d.signal_strength_avg.map(e=>new Date(e.timestamp).toLocaleTimeString());charts.signalStrength.data.datasets[0].data=d.signal_strength_avg.map(e=>e.avg_dbm);charts.signalStrength.update();document.getElementById('lastUpdate').textContent=`Updated: ${new Date(d.last_update).toLocaleTimeString()}`;}catch(e){console.error(e);}}function getSigClass(s){if(s>=80)return'signal-excellent';if(s>=60)return'signal-good';if(s>=40)return'signal-fair';if(s>=20)return'signal-poor';return'signal-weak';}async function loadDevices(){try{const r=await fetch('/api/devices');const d=await r.json();document.getElementById('deviceCount').textContent=`Total: ${d.count} devices`;const tb=document.getElementById('deviceTableBody');if(d.devices.length===0){tb.innerHTML='<tr><td colspan="6" style="text-align:center">No devices</td></tr>';return;}tb.innerHTML=d.devices.map(dev=>`<tr><td><strong>${dev.name}</strong></td><td>${dev.device_os}</td><td>${dev.frequency}</td><td>${dev.ip}</td><td>${dev.manufacturer}</td><td><div style="display:flex;align-items:center;gap:10px"><div class="signal-bar"><div class="signal-fill ${getSigClass(dev.signal_avg)}" style="width:${dev.signal_avg}%"></div></div><small style="color:rgba(255,255,255,0.6)">${dev.signal_quality}</small></div></td></tr>`).join('');}catch(e){console.error(e);}}async function runSpeedTest(){const btn=document.getElementById('runSpeedTest');const cont=document.getElementById('speedTestContainer');btn.innerHTML='<i class="fas fa-spinner fa-spin"></i><span>Running...</span>';btn.disabled=true;cont.innerHTML='<div class="spinner"></div><p>Testing speed...</p>';try{await fetch('/api/speedtest/start',{method:'POST'});const check=setInterval(async()=>{const r=await fetch('/api/speedtest/status');const d=await r.json();if(!d.running&&d.result){clearInterval(check);if(d.result.error){cont.innerHTML=`<p style="color:#ff6b6b">Error: ${d.result.error}</p>`;}else{cont.innerHTML=`<div class="speedtest-results"><div class="speedtest-metric"><div class="speedtest-metric-label">Download</div><div class="speedtest-metric-value">${d.result.download}</div><div class="speedtest-metric-unit">Mbps</div></div><div class="speedtest-metric"><div class="speedtest-metric-label">Upload</div><div class="speedtest-metric-value">${d.result.upload}</div><div class="speedtest-metric-unit">Mbps</div></div><div class="speedtest-metric"><div class="speedtest-metric-label">Ping</div><div class="speedtest-metric-value">${d.result.ping}</div><div class="speedtest-metric-unit">ms</div></div></div><button class="header-btn" onclick="runSpeedTest()" style="margin:20px auto"><i class="fas fa-redo"></i><span>Again</span></button>`;}btn.innerHTML='<i class="fas fa-play"></i><span>Run Test</span>';btn.disabled=false;}},2000);}catch(e){cont.innerHTML=`<p style="color:#ff6b6b">Error</p>`;btn.innerHTML='<i class="fas fa-play"></i><span>Run Test</span>';btn.disabled=false;}}async function checkVersion(){try{const r=await fetch('/api/version');const d=await r.json();document.getElementById('currentVersion').textContent=`v${d.version}`;document.getElementById('networkId').textContent=d.network_id||'N/A';document.getElementById('lastAuth').textContent=`${d.hours_since_auth}h ago`;if(d.needs_reauth){document.getElementById('lastAuth').style.color='#ffc107';}const lr=await fetch('/api/admin/check-update');const ld=await lr.json();document.getElementById('latestVersion').textContent=`v${ld.latest_version}`;const st=document.getElementById('versionStatus');const ub=document.getElementById('updateBtn');if(ld.update_available){st.className='version-status update-available';st.innerHTML='<i class="fas fa-exclamation-circle"></i> Update Available!';ub.disabled=false;}else{st.className='version-status up-to-date';st.innerHTML='<i class="fas fa-check-circle"></i> Up to Date';ub.disabled=true;}}catch(e){console.error(e);}}async function checkAuthStatus(){try{const r=await fetch('/api/version');const d=await r.json();if(d.needs_reauth&&!localStorage.getItem('reauth_reminder_dismissed')){document.getElementById('reauthReminderModal').classList.add('active');}}catch(e){}}async function updateSystem(){const btn=document.getElementById('updateBtn');const msg=document.getElementById('actionMessage');btn.disabled=true;btn.innerHTML='<i class="fas fa-spinner fa-spin"></i>Updating...';msg.className='action-message info';msg.innerHTML='Updating...';try{const r=await fetch('/api/admin/update',{method:'POST'});const d=await r.json();if(d.success){msg.className='action-message success';msg.innerHTML='✓ '+d.message;setTimeout(()=>location.reload(),5000);}else{msg.className='action-message error';msg.innerHTML='✗ '+d.message;btn.disabled=false;btn.innerHTML='<i class="fas fa-download"></i>Update';}}catch(e){msg.className='action-message error';msg.innerHTML='✗ Failed';btn.disabled=false;btn.innerHTML='<i class="fas fa-download"></i>Update';}}async function restartService(){if(!confirm('Restart service?'))return;const btn=document.getElementById('restartBtn');const msg=document.getElementById('actionMessage');btn.disabled=true;btn.innerHTML='<i class="fas fa-spinner fa-spin"></i>Restarting...';msg.className='action-message info';msg.innerHTML='Restarting...';try{const r=await fetch('/api/admin/restart',{method:'POST'});const d=await r.json();if(d.success){msg.className='action-message success';msg.innerHTML='✓ Restarted';setTimeout(()=>location.reload(),3000);}else{msg.className='action-message error';msg.innerHTML='✗ Failed';btn.disabled=false;btn.innerHTML='<i class="fas fa-rotate-right"></i>Restart';}}catch(e){msg.className='action-message error';msg.innerHTML='✗ Failed';btn.disabled=false;btn.innerHTML='<i class="fas fa-rotate-right"></i>Restart';}}async function rebootSystem(){if(!confirm('REBOOT SYSTEM?'))return;if(!confirm('ABSOLUTELY SURE?'))return;const btn=document.getElementById('rebootBtn');const msg=document.getElementById('actionMessage');btn.disabled=true;btn.innerHTML='<i class="fas fa-spinner fa-spin"></i>Rebooting...';msg.className='action-message info';msg.innerHTML='System rebooting...';try{await fetch('/api/admin/reboot',{method:'POST'});msg.className='action-message success';msg.innerHTML='✓ Rebooting. Reconnect in 60s.';}catch{msg.className='action-message success';msg.innerHTML='✓ Rebooting. Reconnect in 60s.';}}function changeNetworkId(){document.getElementById('networkIdModal').classList.add('active');}async function saveNetworkId(){const nid=document.getElementById('newNetworkId').value.trim();const btn=document.getElementById('saveNetworkBtn');const msg=document.getElementById('networkMessage');if(!nid||!nid.match(/^\d+$/)){msg.className='action-message error';msg.innerHTML='✗ Invalid ID';return;}btn.disabled=true;btn.innerHTML='<i class="fas fa-spinner fa-spin"></i>Saving...';msg.className='action-message info';msg.innerHTML='Updating...';try{const r=await fetch('/api/admin/network-id',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({network_id:nid})});const d=await r.json();if(d.success){msg.className='action-message success';msg.innerHTML='✓ '+d.message;setTimeout(()=>{document.getElementById('networkIdModal').classList.remove('active');location.reload();},3000);}else{msg.className='action-message error';msg.innerHTML='✗ '+d.message;btn.disabled=false;btn.innerHTML='<i class="fas fa-save"></i>Save';}}catch(e){msg.className='action-message error';msg.innerHTML='✗ Failed';btn.disabled=false;btn.innerHTML='<i class="fas fa-save"></i>Save';}}function openReauthorize(){document.getElementById('reauthorizeModal').classList.add('active');document.getElementById('reauthStep1').style.display='block';document.getElementById('reauthStep2').style.display='none';document.getElementById('reauthEmail').value='';document.getElementById('reauthCode').value='';document.getElementById('reauthMessage').innerHTML='';}async function sendReauthCode(){const email=document.getElementById('reauthEmail').value.trim();const btn=document.getElementById('sendReauthCodeBtn');const msg=document.getElementById('reauthMessage');if(!email||!email.includes('@')){msg.className='action-message error';msg.innerHTML='✗ Invalid email';return;}btn.disabled=true;btn.innerHTML='<i class="fas fa-spinner fa-spin"></i>Sending...';msg.className='action-message info';msg.innerHTML='Sending...';try{const r=await fetch('/api/admin/reauthorize',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:email,step:'send'})});const d=await r.json();if(d.success){msg.className='action-message success';msg.innerHTML='✓ '+d.message;setTimeout(()=>{document.getElementById('reauthStep1').style.display='none';document.getElementById('reauthStep2').style.display='block';msg.innerHTML='';btn.disabled=false;btn.innerHTML='<i class="fas fa-paper-plane"></i>Send Code';},1500);}else{msg.className='action-message error';msg.innerHTML='✗ '+d.message;btn.disabled=false;btn.innerHTML='<i class="fas fa-paper-plane"></i>Send Code';}}catch(e){msg.className='action-message error';msg.innerHTML='✗ Failed';btn.disabled=false;btn.innerHTML='<i class="fas fa-paper-plane"></i>Send Code';}}async function verifyReauthCode(){const code=document.getElementById('reauthCode').value.trim();const btn=document.getElementById('verifyReauthCodeBtn');const msg=document.getElementById('reauthMessage');if(!code){msg.className='action-message error';msg.innerHTML='✗ Code required';return;}btn.disabled=true;btn.innerHTML='<i class="fas fa-spinner fa-spin"></i>Verifying...';msg.className='action-message info';msg.innerHTML='Verifying...';try{const r=await fetch('/api/admin/reauthorize',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({code:code,step:'verify'})});const d=await r.json();if(d.success){msg.className='action-message success';msg.innerHTML='✓ '+d.message;localStorage.removeItem('reauth_reminder_dismissed');setTimeout(()=>{document.getElementById('reauthorizeModal').classList.remove('active');location.reload();},2000);}else{msg.className='action-message error';msg.innerHTML='✗ '+d.message;btn.disabled=false;btn.innerHTML='<i class="fas fa-check"></i>Verify';}}catch(e){msg.className='action-message error';msg.innerHTML='✗ Failed';btn.disabled=false;btn.innerHTML='<i class="fas fa-check"></i>Verify';}}document.getElementById('piIcon').addEventListener('click',()=>{document.getElementById('gibsonModal').classList.add('active');checkVersion();});document.getElementById('closeGibsonModal').addEventListener('click',()=>document.getElementById('gibsonModal').classList.remove('active'));document.getElementById('updateBtn').addEventListener('click',updateSystem);document.getElementById('changeNetworkBtn').addEventListener('click',changeNetworkId);document.getElementById('reauthorizeBtn').addEventListener('click',openReauthorize);document.getElementById('restartBtn').addEventListener('click',restartService);document.getElementById('rebootBtn').addEventListener('click',rebootSystem);document.getElementById('saveNetworkBtn').addEventListener('click',saveNetworkId);document.getElementById('sendReauthCodeBtn').addEventListener('click',sendReauthCode);document.getElementById('verifyReauthCodeBtn').addEventListener('click',verifyReauthCode);document.getElementById('closeReauthorizeModal').addEventListener('click',()=>document.getElementById('reauthorizeModal').classList.remove('active'));document.getElementById('closeNetworkIdModal').addEventListener('click',()=>document.getElementById('networkIdModal').classList.remove('active'));document.getElementById('deviceDetailsBtn').addEventListener('click',()=>{document.getElementById('deviceModal').classList.add('active');loadDevices();});document.getElementById('closeDeviceModal').addEventListener('click',()=>document.getElementById('deviceModal').classList.remove('active'));document.getElementById('speedTestBtn').addEventListener('click',()=>document.getElementById('speedTestModal').classList.add('active'));document.getElementById('closeSpeedTestModal').addEventListener('click',()=>document.getElementById('speedTestModal').classList.remove('active'));document.getElementById('runSpeedTest').addEventListener('click',runSpeedTest);document.querySelectorAll('.modal').forEach(m=>{m.addEventListener('click',e=>{if(e.target===m)m.classList.remove('active');});});window.addEventListener('load',()=>{initCharts();updateDashboard();setInterval(updateDashboard,60000);setTimeout(checkAuthStatus,2000);setInterval(checkAuthStatus,3600000);});</script></body></html>"""
    with open(f"{INSTALL_DIR}/frontend/index.html",'w')as f:f.write(html)
    run_cmd(f'chown {USER}:{USER} {INSTALL_DIR}/frontend/index.html')
    ps("Frontend created")

def configure_nginx():
    pi("Configuring NGINX...")
    cfg="""server {
    listen 80 default_server;
    root /home/eero/dashboard/frontend;
    index index.html;
    location / { try_files $uri $uri/ =404; }
    location /assets/ { alias /home/eero/dashboard/frontend/assets/; }
    location /api/ { proxy_pass http://127.0.0.1:5000; proxy_read_timeout 120s; }
}"""
    with open('/etc/nginx/sites-available/eero-dashboard','w')as f:f.write(cfg)
    for f in['/etc/nginx/sites-enabled/default','/etc/nginx/sites-enabled/eero-dashboard']:
        if os.path.exists(f):os.remove(f)
    os.symlink('/etc/nginx/sites-available/eero-dashboard','/etc/nginx/sites-enabled/eero-dashboard')
    run_cmd('nginx -t');run_cmd('systemctl restart nginx');run_cmd('systemctl enable nginx')
    ps("NGINX ready")

def create_service():
    pi("Creating service...")
    svc=f"""[Unit]
Description=Eero Dashboard v3
After=network.target
[Service]
Type=simple
User={USER}
WorkingDirectory={INSTALL_DIR}/backend
Environment="PATH={INSTALL_DIR}/venv/bin"
ExecStart={INSTALL_DIR}/venv/bin/gunicorn -w 2 -b 127.0.0.1:5000 --timeout 120 eero_api:app
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
"""
    with open('/etc/systemd/system/eero-dashboard.service','w')as f:f.write(svc)
    run_cmd('systemctl daemon-reload');run_cmd('systemctl enable eero-dashboard.service');run_cmd('systemctl start eero-dashboard.service')
    time.sleep(2);ps("Service started")

def create_kiosk():
    kiosk="""#!/bin/bash
xset s off 2>/dev/null;xset -dpms 2>/dev/null;xset s noblank 2>/dev/null;unclutter -idle 0.1 2>/dev/null &
BROWSER="chromium-browser";command -v chromium &>/dev/null && BROWSER="chromium"
$BROWSER --kiosk --noerrdialogs --no-first-run http://localhost
"""
    with open(f"{INSTALL_DIR}/start_kiosk.sh",'w')as f:f.write(kiosk)
    os.chmod(f"{INSTALL_DIR}/start_kiosk.sh",0o755)
    Path(f'/home/{USER}/.config/autostart').mkdir(parents=True,exist_ok=True)
    desktop=f"""[Desktop Entry]
Type=Application
Name=Eero Dashboard v3
Exec={INSTALL_DIR}/start_kiosk.sh
X-GNOME-Autostart-enabled=true
"""
    with open(f'/home/{USER}/.config/autostart/dashboard.desktop','w')as f:f.write(desktop)
    run_cmd(f'chown -R {USER}:{USER} /home/{USER}/.config');ps("Kiosk ready")

def setup_logs():
    for l in[f"{INSTALL_DIR}/logs/backend.log",f"{INSTALL_DIR}/logs/nginx_access.log",f"{INSTALL_DIR}/logs/nginx_error.log"]:
        Path(l).touch()
    run_cmd(f'chown -R {USER}:{USER} {INSTALL_DIR}/logs')

def main():
    os.system('clear')
    ph(f"Eero Dashboard v3 Installer - v{SCRIPT_VERSION}")
    if '--no-update' not in sys.argv:check_updates()
    check_root()
    ph("Starting Installation")
    try:
        create_user();update_system();install_deps();create_dirs()
        nid=prompt_network_id();setup_python()
        if not authenticate_eero(nid):pe("Auth failed");sys.exit(1)
        create_backend(nid);create_frontend();configure_nginx();create_service();create_kiosk();setup_logs()
        ph("Complete!");ps(f"Dashboard v{SCRIPT_VERSION} installed!")
        pi("Dashboard: http://localhost");pi("Click π icon (bottom-right) for admin")
    except KeyboardInterrupt:pe("\nCancelled");sys.exit(1)
    except Exception as e:pe(f"Failed: {e}");sys.exit(1)

if __name__=='__main__':main()
