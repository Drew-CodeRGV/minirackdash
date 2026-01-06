#!/usr/bin/env python3
"""
MiniRack Dashboard - macOS Setup Script
This script helps set up the dashboard on macOS
"""
import os
import sys
import json
import subprocess
import urllib.request
from pathlib import Path

def print_color(color_code, message):
    """Print colored message"""
    print(f"\033[{color_code}m{message}\033[0m")

def print_success(message):
    print_color("0;32", f"✓ {message}")

def print_error(message):
    print_color("0;31", f"✗ {message}")

def print_warning(message):
    print_color("1;33", f"⚠ {message}")

def print_info(message):
    print_color("0;36", f"ℹ {message}")

def print_header(message):
    print("\n" + "=" * 60)
    print_color("0;34", message.center(60))
    print("=" * 60 + "\n")

def check_python_version():
    """Check if Python version is compatible"""
    if sys.version_info < (3, 7):
        print_error("Python 3.7 or higher is required")
        print_info(f"Current version: {sys.version}")
        return False
    print_success(f"Python version: {sys.version.split()[0]}")
    return True

def check_dependencies():
    """Check and install required Python packages"""
    print_info("Checking Python dependencies...")
    
    required_packages = [
        'flask',
        'flask-cors', 
        'requests',
        'speedtest-cli'
    ]
    
    missing_packages = []
    
    for package in required_packages:
        try:
            __import__(package.replace('-', '_'))
            print_success(f"{package} is installed")
        except ImportError:
            missing_packages.append(package)
            print_warning(f"{package} is missing")
    
    if missing_packages:
        print_info("Installing missing packages...")
        try:
            subprocess.check_call([
                sys.executable, '-m', 'pip', 'install'
            ] + missing_packages)
            print_success("All dependencies installed")
        except subprocess.CalledProcessError:
            print_error("Failed to install dependencies")
            print_info("Try running: pip install " + " ".join(missing_packages))
            return False
    
    return True

def setup_directories():
    """Create necessary directories"""
    print_info("Setting up directories...")
    
    home_dir = os.path.expanduser("~")
    install_dir = os.path.join(home_dir, "eero_dashboard")
    
    directories = [
        install_dir,
        os.path.join(install_dir, "logs"),
        os.path.join(install_dir, "frontend")
    ]
    
    for directory in directories:
        os.makedirs(directory, exist_ok=True)
        print_success(f"Created: {directory}")
    
    return install_dir

def create_config_file(install_dir):
    """Create initial configuration file"""
    print_info("Creating configuration file...")
    
    config_file = os.path.join(install_dir, ".config.json")
    
    # Get network ID from user
    print_color("1;33", "\nPlease enter your Eero Network ID:")
    print_info("You can find this in your Eero app or by contacting Eero support")
    
    while True:
        network_id = input("Network ID: ").strip()
        if network_id and network_id.isdigit():
            break
        print_error("Please enter a valid numeric network ID")
    
    # Get environment preference
    print_color("1;33", "\nSelect environment:")
    print("1. Production (api-user.e2ro.com)")
    print("2. Staging (api-user.stage.e2ro.com)")
    
    while True:
        choice = input("Choice (1 or 2): ").strip()
        if choice == "1":
            environment = "production"
            api_url = "api-user.e2ro.com"
            break
        elif choice == "2":
            environment = "staging"
            api_url = "api-user.stage.e2ro.com"
            break
        print_error("Please enter 1 or 2")
    
    config = {
        "network_id": network_id,
        "environment": environment,
        "api_url": api_url,
        "last_updated": "2024-01-01T00:00:00"
    }
    
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)
    
    os.chmod(config_file, 0o600)
    print_success("Configuration file created")
    
    return config

def setup_authentication(install_dir, api_url):
    """Set up Eero API authentication"""
    print_header("Eero API Authentication")
    print_info("This will authenticate your access to the Eero API")
    print_info(f"Using API: {api_url}")
    
    email = input("Enter your Eero account email: ").strip()
    if not email or '@' not in email:
        print_error("Invalid email address")
        return False
    
    print_info(f"Sending verification code to: {email}")
    
    try:
        import requests
        
        # Send login request
        login_payload = {"login": email}
        response = requests.post(f"https://{api_url}/2.2/pro/login", json=login_payload, timeout=10)
        response.raise_for_status()
        response_data = response.json()
        
        if 'data' not in response_data or 'user_token' not in response_data['data']:
            print_error("Failed to generate access token")
            return False
        
        unverified_token = response_data['data']['user_token']
        print_success("Verification code sent to your email!")
        
        # Get verification code
        code = input("Enter the verification code from your email: ").strip()
        if not code:
            print_error("Verification code is required")
            return False
        
        print_info("Verifying access token...")
        
        # Verify token
        verify_url = f"https://{api_url}/2.2/login/verify"
        verify_payload = {"code": code}
        verify_headers = {"X-User-Token": unverified_token}
        verify_response = requests.post(verify_url, headers=verify_headers, data=verify_payload, timeout=10)
        verify_response.raise_for_status()
        verify_data = verify_response.json()
        
        if verify_data.get('data', {}).get('email', {}).get('verified'):
            print_success("Authentication successful!")
            
            # Save token
            token_file = os.path.join(install_dir, ".eero_token")
            with open(token_file, 'w') as f:
                f.write(unverified_token)
            os.chmod(token_file, 0o600)
            
            print_success("Token saved")
            return True
        else:
            print_error("Account verification failed")
            return False
            
    except Exception as e:
        print_error(f"Authentication error: {e}")
        return False

def create_launch_script(install_dir):
    """Create a launch script for easy startup"""
    print_info("Creating launch script...")
    
    script_content = f"""#!/bin/bash
# MiniRack Dashboard Launch Script for macOS

cd "{install_dir}"
echo "Starting MiniRack Dashboard..."
echo "Dashboard will be available at: http://localhost:5000"
echo "Press Ctrl+C to stop"
echo ""

python3 macos_dashboard.py
"""
    
    launch_script = os.path.join(install_dir, "start_dashboard.sh")
    with open(launch_script, 'w') as f:
        f.write(script_content)
    
    os.chmod(launch_script, 0o755)
    print_success("Launch script created")
    
    return launch_script

def main():
    """Main setup function"""
    print_header("MiniRack Dashboard - macOS Setup")
    
    # Check Python version
    if not check_python_version():
        sys.exit(1)
    
    # Check and install dependencies
    if not check_dependencies():
        sys.exit(1)
    
    # Setup directories
    install_dir = setup_directories()
    
    # Copy dashboard files
    print_info("Copying dashboard files...")
    
    # Copy main dashboard script
    current_dir = os.path.dirname(os.path.abspath(__file__))
    dashboard_source = os.path.join(current_dir, "macos_dashboard.py")
    dashboard_dest = os.path.join(install_dir, "macos_dashboard.py")
    
    if os.path.exists(dashboard_source):
        import shutil
        shutil.copy2(dashboard_source, dashboard_dest)
        print_success("Dashboard script copied")
    else:
        print_error("Dashboard script not found")
        print_info("Please ensure macos_dashboard.py is in the same directory as this setup script")
        sys.exit(1)
    
    # Copy frontend files
    frontend_source = os.path.join(current_dir, "frontend")
    frontend_dest = os.path.join(install_dir, "frontend")
    
    if os.path.exists(frontend_source):
        import shutil
        if os.path.exists(frontend_dest):
            shutil.rmtree(frontend_dest)
        shutil.copytree(frontend_source, frontend_dest)
        print_success("Frontend files copied")
    else:
        print_error("Frontend directory not found")
        sys.exit(1)
    
    # Create configuration
    config = create_config_file(install_dir)
    
    # Setup authentication
    if not setup_authentication(install_dir, config['api_url']):
        print_warning("Authentication failed - you can set this up later through the web interface")
    
    # Create launch script
    launch_script = create_launch_script(install_dir)
    
    # Final instructions
    print_header("Setup Complete!")
    print_success("MiniRack Dashboard has been set up successfully!")
    print()
    print_info("To start the dashboard:")
    print(f"  cd {install_dir}")
    print("  ./start_dashboard.sh")
    print()
    print_info("Or run directly:")
    print(f"  cd {install_dir}")
    print("  python3 macos_dashboard.py")
    print()
    print_info("Dashboard will be available at: http://localhost:5000")
    print_info("Admin panel: Click the π icon in the bottom right")
    print()
    print_warning("Note: The dashboard runs on port 5000 (no sudo required)")
    print_warning("If you need to change the network ID, use the admin panel")

if __name__ == "__main__":
    main()