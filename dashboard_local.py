#!/usr/bin/env python3
"""
MiniRack Dashboard - macOS Local Version
Runs the full dashboard locally on macOS with local configuration
"""
import os
import sys
import json
from pathlib import Path
import logging

# Configuration for local development
VERSION = "6.7.8-mobile-local"
LOCAL_DIR = Path.home() / ".minirack"
CONFIG_FILE = LOCAL_DIR / "config.json"
TEMPLATE_FILE = Path(__file__).parent / "deploy" / "index.html"
DATA_CACHE_FILE = LOCAL_DIR / "data_cache.json"

# Ensure local directory exists
LOCAL_DIR.mkdir(exist_ok=True)

# Setup logging for local development BEFORE importing the main module
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOCAL_DIR / 'dashboard.log'),
        logging.StreamHandler()
    ]
)

# Override the production logging configuration by patching the logging module
# This prevents the main dashboard from trying to create /opt/eero/logs/dashboard.log
original_basicConfig = logging.basicConfig
def patched_basicConfig(*args, **kwargs):
    # Ignore any basicConfig calls from the main dashboard module
    pass
logging.basicConfig = patched_basicConfig

# Now import and patch the dashboard module
sys.path.insert(0, str(Path(__file__).parent / "deploy"))
import dashboard_minimal

# Restore original basicConfig after import
logging.basicConfig = original_basicConfig

# Patch the configuration file paths for local development
dashboard_minimal.VERSION = VERSION
dashboard_minimal.CONFIG_FILE = str(CONFIG_FILE)
dashboard_minimal.TOKEN_FILE = str(LOCAL_DIR / ".eero_token")
dashboard_minimal.TEMPLATE_FILE = str(TEMPLATE_FILE)
dashboard_minimal.DATA_CACHE_FILE = str(DATA_CACHE_FILE)

# Import the Flask app and functions
from dashboard_minimal import app, update_cache

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
    print(f"🚀 Starting MiniRack Dashboard {VERSION} (Local macOS)")
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