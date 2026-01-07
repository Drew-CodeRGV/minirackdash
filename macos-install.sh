#!/bin/bash
# MiniRack Dashboard - macOS Installation Script

set -e

echo "🍎 MiniRack Dashboard - macOS Installation"

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This script is for macOS only"
    echo "💡 Use raspberry-pi-install.sh for Raspberry Pi"
    echo "💡 Use universal-install.sh for auto-detection"
    exit 1
fi

# Check for Homebrew
if ! command -v brew >/dev/null 2>&1; then
    echo "📦 Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for this session
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# Install Python if needed
if ! command -v python3 >/dev/null 2>&1; then
    echo "🐍 Installing Python..."
    brew install python3
fi

# Create dashboard directory
DASHBOARD_DIR="$HOME/eero-dashboard"
echo "📁 Creating dashboard directory: $DASHBOARD_DIR"
mkdir -p "$DASHBOARD_DIR"/{app,logs}
cd "$DASHBOARD_DIR"

# Setup Python virtual environment
echo "🐍 Setting up Python environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "📦 Installing Python packages..."
pip install --upgrade pip
pip install flask==2.3.3 flask-cors==4.0.0 requests==2.31.0 gunicorn==21.2.0 pytz==2023.3

# Download dashboard files
echo "📥 Downloading dashboard files..."
curl -fsSL -o app/dashboard.py \
    https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py

curl -fsSL -o app/index.html \
    https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html

# Make dashboard executable
chmod +x app/dashboard.py

# Create configuration
echo "⚙️ Creating configuration..."
tee app/config.json > /dev/null << 'EOF'
{
    "networks": [{
        "id": "20478317",
        "name": "Primary Network",
        "email": "",
        "token": "",
        "active": true
    }],
    "environment": "macos-development",
    "api_url": "api-user.e2ro.com",
    "timezone": "America/New_York"
}
EOF

# Create startup script
echo "🚀 Creating startup script..."
tee start-dashboard.sh > /dev/null << 'EOF'
#!/bin/bash
# MiniRack Dashboard Startup Script for macOS

cd "$(dirname "$0")"

echo "🍎 Starting MiniRack Dashboard on macOS..."

# Activate virtual environment
source venv/bin/activate

# Start dashboard
echo "🚀 Starting dashboard on http://localhost:3000"
echo "🔧 Use Ctrl+C to stop"
echo "📊 Access admin panel with π (pi) button"
echo ""

# Set port to 3000 to avoid conflicts with other services
export PORT=3000
python app/dashboard.py
EOF

chmod +x start-dashboard.sh

# Create stop script
tee stop-dashboard.sh > /dev/null << 'EOF'
#!/bin/bash
# Stop MiniRack Dashboard

echo "🛑 Stopping MiniRack Dashboard..."
pkill -f "python.*dashboard.py" || echo "Dashboard not running"
echo "✅ Dashboard stopped"
EOF

chmod +x stop-dashboard.sh

# Update dashboard.py to use PORT environment variable
echo "⚙️ Configuring dashboard for macOS..."
sed -i '' 's/app.run(host=.*$/port = int(os.environ.get("PORT", 5000))\
    app.run(host="0.0.0.0", port=port, debug=False)/' app/dashboard.py

# Test installation
echo "🧪 Testing installation..."
source venv/bin/activate
if python -c "import flask, requests, pytz; print('✅ All dependencies installed')"; then
    echo "✅ Installation successful!"
else
    echo "❌ Installation may have issues"
    exit 1
fi

# Get local IP
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

echo ""
echo "🎉 MiniRack Dashboard installed successfully!"
echo ""
echo "📁 Installation directory: $DASHBOARD_DIR"
echo "🚀 Start dashboard: ./start-dashboard.sh"
echo "🛑 Stop dashboard: ./stop-dashboard.sh"
echo ""
echo "🌐 Dashboard URLs:"
echo "   Local: http://localhost:3000"
if [ ! -z "$LOCAL_IP" ]; then
    echo "   Network: http://$LOCAL_IP:3000"
fi
echo ""
echo "📋 Next steps:"
echo "1. Run: cd $DASHBOARD_DIR && ./start-dashboard.sh"
echo "2. Open browser to http://localhost:3000"
echo "3. Click π (pi) button for admin panel"
echo "4. Add Eero networks using Network ID and email"
echo ""
echo "🔧 Useful commands:"
echo "   Start: cd $DASHBOARD_DIR && ./start-dashboard.sh"
echo "   Stop: cd $DASHBOARD_DIR && ./stop-dashboard.sh"
echo "   Logs: Check terminal output when running"