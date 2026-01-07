#!/bin/bash
# Universal MiniRack Dashboard Installer
# Detects OS and uses appropriate installation method

set -e

VERSION="6.7.8-universal"
EMAIL_TO="drew@drewlentz.com"

echo "🌐 MiniRack Dashboard - Universal Installer"
echo "📧 Email notifications to: $EMAIL_TO"

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt >/dev/null 2>&1; then
            OS="debian"
            echo "🐧 Detected: Debian/Ubuntu/Raspberry Pi OS"
        elif command -v yum >/dev/null 2>&1; then
            OS="redhat"
            echo "🐧 Detected: RedHat/CentOS/Fedora"
        elif command -v pacman >/dev/null 2>&1; then
            OS="arch"
            echo "🐧 Detected: Arch Linux"
        else
            OS="linux-unknown"
            echo "🐧 Detected: Unknown Linux distribution"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        echo "🍎 Detected: macOS"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
        echo "🪟 Detected: Windows"
    else
        OS="unknown"
        echo "❓ Unknown operating system: $OSTYPE"
    fi
}

# Install for Raspberry Pi / Debian / Ubuntu
install_debian() {
    echo "📦 Installing for Debian/Ubuntu/Raspberry Pi..."
    
    # Update system
    sudo apt update && sudo apt upgrade -y
    
    # Install dependencies
    sudo apt install -y python3 python3-pip python3-venv nginx curl
    
    # Create dashboard user and directories
    sudo useradd -r -s /bin/false -d /opt/eero dashboard 2>/dev/null || true
    sudo mkdir -p /opt/eero/{app,logs}
    sudo chown -R dashboard:dashboard /opt/eero
    
    # Setup Python environment
    sudo -u dashboard python3 -m venv /opt/eero/venv
    sudo -u dashboard /opt/eero/venv/bin/pip install flask flask-cors requests gunicorn pytz
    
    # Download dashboard files
    sudo -u dashboard curl -fsSL -o /opt/eero/app/dashboard.py \
        https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
    sudo -u dashboard curl -fsSL -o /opt/eero/app/index.html \
        https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html
    
    sudo chmod +x /opt/eero/app/dashboard.py
    
    # Create configuration
    sudo -u dashboard tee /opt/eero/app/config.json > /dev/null << 'EOF'
{
    "networks": [{
        "id": "20478317",
        "name": "Primary Network",
        "email": "",
        "token": "",
        "active": true
    }],
    "environment": "linux",
    "api_url": "api-user.e2ro.com",
    "timezone": "UTC"
}
EOF

    # Configure Nginx
    sudo tee /etc/nginx/sites-available/dashboard > /dev/null << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

    sudo rm -f /etc/nginx/sites-enabled/default
    sudo ln -sf /etc/nginx/sites-available/dashboard /etc/nginx/sites-enabled/
    
    # Create systemd service
    sudo tee /etc/systemd/system/eero-dashboard.service > /dev/null << 'EOF'
[Unit]
Description=MiniRack Dashboard
After=network.target

[Service]
Type=exec
User=dashboard
Group=dashboard
WorkingDirectory=/opt/eero/app
Environment=PATH=/opt/eero/venv/bin
ExecStart=/opt/eero/venv/bin/python dashboard.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start services
    sudo systemctl daemon-reload
    sudo systemctl enable nginx eero-dashboard
    sudo systemctl start nginx eero-dashboard
    
    # Get IP and display
    LOCAL_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || echo "localhost")
    echo "✅ Dashboard installed successfully!"
    echo "🌐 Access at: http://$LOCAL_IP"
}

# Install for macOS
install_macos() {
    echo "🍎 Installing for macOS..."
    
    # Check for Homebrew
    if ! command -v brew >/dev/null 2>&1; then
        echo "📦 Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Install dependencies
    brew install python3 nginx
    
    # Create directories
    mkdir -p ~/eero-dashboard/{app,logs}
    cd ~/eero-dashboard
    
    # Setup Python environment
    python3 -m venv venv
    ./venv/bin/pip install flask flask-cors requests gunicorn pytz
    
    # Download dashboard files
    curl -fsSL -o app/dashboard.py \
        https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
    curl -fsSL -o app/index.html \
        https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html
    
    chmod +x app/dashboard.py
    
    # Create configuration
    tee app/config.json > /dev/null << 'EOF'
{
    "networks": [{
        "id": "20478317",
        "name": "Primary Network",
        "email": "",
        "token": "",
        "active": true
    }],
    "environment": "macos",
    "api_url": "api-user.e2ro.com",
    "timezone": "UTC"
}
EOF

    # Configure Nginx
    sudo tee /usr/local/etc/nginx/servers/dashboard.conf > /dev/null << 'EOF'
server {
    listen 8080;
    server_name localhost;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

    # Start services
    brew services start nginx
    
    # Create launch script
    tee start-dashboard.sh > /dev/null << 'EOF'
#!/bin/bash
cd ~/eero-dashboard
./venv/bin/python app/dashboard.py &
echo "Dashboard started at http://localhost:8080"
echo "Use 'pkill -f dashboard.py' to stop"
EOF
    
    chmod +x start-dashboard.sh
    
    echo "✅ Dashboard installed successfully!"
    echo "🚀 Start with: ~/eero-dashboard/start-dashboard.sh"
    echo "🌐 Access at: http://localhost:8080"
}

# Install for Windows (WSL/Cygwin)
install_windows() {
    echo "🪟 Windows installation requires WSL (Windows Subsystem for Linux)"
    echo "Please install WSL with Ubuntu and run this script inside WSL"
    echo "Guide: https://docs.microsoft.com/en-us/windows/wsl/install"
    exit 1
}

# Main installation logic
main() {
    detect_os
    
    case $OS in
        "debian")
            install_debian
            ;;
        "macos")
            install_macos
            ;;
        "windows")
            install_windows
            ;;
        *)
            echo "❌ Unsupported operating system: $OS"
            echo "💡 This installer supports:"
            echo "   • Raspberry Pi OS"
            echo "   • Ubuntu/Debian"
            echo "   • macOS"
            echo "   • Windows (via WSL)"
            echo ""
            echo "📋 Manual installation:"
            echo "1. Install Python 3.8+"
            echo "2. Install pip packages: flask flask-cors requests gunicorn pytz"
            echo "3. Download dashboard files from GitHub"
            echo "4. Run: python dashboard.py"
            exit 1
            ;;
    esac
    
    echo ""
    echo "🎉 Installation complete!"
    echo "📋 Next steps:"
    echo "1. Access the dashboard URL shown above"
    echo "2. Click the π (pi) button for admin panel"
    echo "3. Add your Eero networks using Network ID and email"
    echo "4. Monitor your networks in real-time"
}

# Run main function
main "$@"