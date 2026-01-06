#!/usr/bin/env python3
"""
AWS Lambda + API Gateway Deployment for MiniRack Dashboard
Cost: Nearly free (AWS Free Tier covers most usage)
"""
import json
import base64
import os

def create_lambda_function():
    """Create Lambda-compatible version of the dashboard"""
    
    lambda_code = '''
import json
import os
import requests
import time
from datetime import datetime, timedelta
import base64

# Environment variables (set in Lambda)
NETWORK_ID = os.environ.get('NETWORK_ID', '')
API_TOKEN = os.environ.get('API_TOKEN', '')
API_URL = os.environ.get('API_URL', 'api-user.e2ro.com')

class EeroAPI:
    def __init__(self):
        self.api_token = API_TOKEN
        self.network_id = NETWORK_ID
        self.api_base = f"https://{API_URL}/2.2"
    
    def get_headers(self):
        return {
            'Content-Type': 'application/json',
            'User-Agent': 'Eero-Dashboard-Lambda/1.0',
            'X-User-Token': self.api_token
        }
    
    def get_all_devices(self):
        try:
            url = f"{self.api_base}/networks/{self.network_id}/devices"
            response = requests.get(url, headers=self.get_headers(), timeout=10)
            response.raise_for_status()
            data = response.json()
            
            if 'data' in data:
                return data['data'] if isinstance(data['data'], list) else data['data'].get('devices', [])
            return []
        except Exception as e:
            print(f"Error fetching devices: {e}")
            return []

def categorize_device_os(device):
    """Categorize device OS"""
    def safe_lower(val):
        return str(val).lower() if val else ""
    
    text = f"{safe_lower(device.get('manufacturer'))} {safe_lower(device.get('device_type'))} {safe_lower(device.get('hostname'))}"
    
    if any(k in text for k in ['apple', 'iphone', 'ipad', 'mac']):
        return 'iOS'
    elif any(k in text for k in ['android', 'samsung', 'google', 'pixel']):
        return 'Android'
    elif any(k in text for k in ['windows', 'microsoft', 'dell', 'hp']):
        return 'Windows'
    return 'Other'

def process_devices(devices):
    """Process device data for dashboard"""
    wireless_devices = [d for d in devices if d.get('connected') and d.get('wireless')]
    
    # Count by OS
    os_counts = {'iOS': 0, 'Android': 0, 'Windows': 0, 'Other': 0}
    freq_counts = {'2.4GHz': 0, '5GHz': 0, '6GHz': 0}
    
    device_list = []
    signal_strengths = []
    
    for device in wireless_devices:
        os_type = categorize_device_os(device)
        os_counts[os_type] += 1
        
        # Process frequency
        interface = device.get('interface', {}) or {}
        freq = interface.get('frequency', 0)
        if 2.4 <= freq < 2.5:
            freq_counts['2.4GHz'] += 1
        elif 5.0 <= freq < 6.0:
            freq_counts['5GHz'] += 1
        elif 6.0 <= freq < 7.0:
            freq_counts['6GHz'] += 1
        
        # Signal strength
        connectivity = device.get('connectivity', {}) or {}
        signal_dbm = connectivity.get('signal_avg')
        if signal_dbm:
            signal_strengths.append(signal_dbm)
        
        device_list.append({
            'name': device.get('nickname') or device.get('hostname') or 'Unknown',
            'ip': ', '.join(device.get('ips', [])),
            'mac': device.get('mac', 'N/A'),
            'manufacturer': device.get('manufacturer', 'Unknown'),
            'device_os': os_type,
            'signal_avg_dbm': f"{signal_dbm} dBm" if signal_dbm else 'N/A'
        })
    
    return {
        'device_os': os_counts,
        'frequency_distribution': freq_counts,
        'devices': device_list,
        'connected_count': len(wireless_devices),
        'avg_signal': sum(signal_strengths) / len(signal_strengths) if signal_strengths else 0,
        'last_update': datetime.now().isoformat()
    }

def get_frontend_html():
    """Return the frontend HTML"""
    return """<!DOCTYPE html>
<html>
<head>
    <title>Eero Dashboard (AWS Lambda)</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #1a1a1a; color: white; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 30px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { background: #2a2a2a; padding: 20px; border-radius: 10px; text-align: center; }
        .stat-value { font-size: 2em; font-weight: bold; color: #4da6ff; }
        .stat-label { margin-top: 10px; color: #ccc; }
        .charts { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 30px; }
        .chart-container { background: #2a2a2a; padding: 20px; border-radius: 10px; }
        .devices { background: #2a2a2a; padding: 20px; border-radius: 10px; }
        .device-item { background: #3a3a3a; margin: 10px 0; padding: 15px; border-radius: 5px; }
        .refresh-btn { background: #4da6ff; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; margin: 10px; }
        .refresh-btn:hover { background: #357abd; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Eero Network Dashboard</h1>
            <button class="refresh-btn" onclick="loadData()">Refresh Data</button>
            <div id="lastUpdate"></div>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-value" id="connectedCount">-</div>
                <div class="stat-label">Connected Devices</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="avgSignal">-</div>
                <div class="stat-label">Avg Signal (dBm)</div>
            </div>
        </div>
        
        <div class="charts">
            <div class="chart-container">
                <h3>Device OS Distribution</h3>
                <canvas id="osChart"></canvas>
            </div>
            <div class="chart-container">
                <h3>Frequency Distribution</h3>
                <canvas id="freqChart"></canvas>
            </div>
        </div>
        
        <div class="devices">
            <h3>Connected Devices</h3>
            <div id="deviceList"></div>
        </div>
    </div>
    
    <script>
        let osChart, freqChart;
        
        function initCharts() {
            const osCtx = document.getElementById('osChart').getContext('2d');
            osChart = new Chart(osCtx, {
                type: 'doughnut',
                data: {
                    labels: ['iOS', 'Android', 'Windows', 'Other'],
                    datasets: [{
                        data: [0, 0, 0, 0],
                        backgroundColor: ['#4da6ff', '#51cf66', '#74c0fc', '#ffd43b']
                    }]
                }
            });
            
            const freqCtx = document.getElementById('freqChart').getContext('2d');
            freqChart = new Chart(freqCtx, {
                type: 'doughnut',
                data: {
                    labels: ['2.4 GHz', '5 GHz', '6 GHz'],
                    datasets: [{
                        data: [0, 0, 0],
                        backgroundColor: ['#ff922b', '#4da6ff', '#b197fc']
                    }]
                }
            });
        }
        
        async function loadData() {
            try {
                const response = await fetch('/api/dashboard');
                const data = await response.json();
                
                // Update stats
                document.getElementById('connectedCount').textContent = data.connected_count;
                document.getElementById('avgSignal').textContent = data.avg_signal.toFixed(1);
                document.getElementById('lastUpdate').textContent = `Last updated: ${new Date(data.last_update).toLocaleString()}`;
                
                // Update charts
                osChart.data.datasets[0].data = [
                    data.device_os.iOS,
                    data.device_os.Android,
                    data.device_os.Windows,
                    data.device_os.Other
                ];
                osChart.update();
                
                freqChart.data.datasets[0].data = [
                    data.frequency_distribution['2.4GHz'],
                    data.frequency_distribution['5GHz'],
                    data.frequency_distribution['6GHz']
                ];
                freqChart.update();
                
                // Update device list
                const deviceList = document.getElementById('deviceList');
                deviceList.innerHTML = data.devices.map(device => `
                    <div class="device-item">
                        <strong>${device.name}</strong><br>
                        IP: ${device.ip} | MAC: ${device.mac}<br>
                        ${device.manufacturer} | ${device.device_os} | Signal: ${device.signal_avg_dbm}
                    </div>
                `).join('');
                
            } catch (error) {
                console.error('Error loading data:', error);
            }
        }
        
        // Initialize
        window.addEventListener('load', () => {
            initCharts();
            loadData();
            setInterval(loadData, 60000); // Refresh every minute
        });
    </script>
</body>
</html>"""

def lambda_handler(event, context):
    """Main Lambda handler"""
    
    # Handle different HTTP methods and paths
    http_method = event.get('httpMethod', 'GET')
    path = event.get('path', '/')
    
    if path == '/' and http_method == 'GET':
        # Serve frontend
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'text/html'},
            'body': get_frontend_html()
        }
    
    elif path == '/api/dashboard' and http_method == 'GET':
        # Serve API data
        try:
            eero_api = EeroAPI()
            devices = eero_api.get_all_devices()
            dashboard_data = process_devices(devices)
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps(dashboard_data)
            }
        except Exception as e:
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': str(e)})
            }
    
    else:
        return {
            'statusCode': 404,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Not found'})
        }
'''
    
    return lambda_code

def create_lambda_deployment_guide():
    """Create Lambda deployment guide"""
    
    guide = """
# AWS Lambda Deployment Guide

## Cost: Nearly FREE (AWS Free Tier)
- 1M requests/month free
- 400,000 GB-seconds compute free
- Typical usage: <$1/month

## Step 1: Create Lambda Function

1. Go to AWS Lambda console
2. Click "Create function"
3. Choose "Author from scratch"
4. Function name: `eero-dashboard`
5. Runtime: Python 3.9
6. Click "Create function"

## Step 2: Deploy Code

1. Copy the code from `lambda_function.py`
2. Paste into the Lambda function editor
3. Click "Deploy"

## Step 3: Set Environment Variables

In Lambda configuration, add:
- `NETWORK_ID`: Your Eero network ID
- `API_TOKEN`: Your Eero API token
- `API_URL`: api-user.e2ro.com (or staging)

## Step 4: Create API Gateway

1. Go to API Gateway console
2. Create "HTTP API"
3. Add integration: Lambda function
4. Configure routes:
   - `GET /` → Lambda function
   - `GET /api/dashboard` → Lambda function
   - `ANY /{proxy+}` → Lambda function

## Step 5: Deploy API

1. Create stage (e.g., "prod")
2. Deploy API
3. Note the invoke URL

## Step 6: Access Dashboard

Visit your API Gateway URL to access the dashboard.

## Pros:
- Nearly free
- Serverless (no server management)
- Auto-scaling
- High availability

## Cons:
- Cold starts (1-2 second delay)
- 15-minute timeout limit
- More complex setup
- Limited real-time features

## Security:
- Add API key authentication
- Use custom domain with HTTPS
- Set up CloudFront for caching
"""
    
    return guide

if __name__ == "__main__":
    os.makedirs("aws_deployment", exist_ok=True)
    
    with open("aws_deployment/lambda_function.py", "w") as f:
        f.write(create_lambda_function())
    
    with open("aws_deployment/LAMBDA_GUIDE.md", "w") as f:
        f.write(create_lambda_deployment_guide())
    
    print("✓ Lambda deployment files created!")