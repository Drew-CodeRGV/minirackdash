#!/bin/bash
# MiniRack Dashboard - macOS Local Runner

echo "🍎 MiniRack Dashboard - Local macOS"
echo "=================================="
echo "🚀 Starting dashboard..."
echo "📱 Mobile responsive design enabled"
echo "🌐 Dashboard: http://localhost:3000"
echo "🔧 Press Ctrl+C to stop"
echo ""

# Check if we're in the right directory
if [ ! -f "deploy/dashboard_minimal.py" ]; then
    echo "❌ Please run this script from the minirackdash directory"
    exit 1
fi

# Check if Python dependencies are installed
python3 -c "import flask, flask_cors, requests, pytz" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ Missing dependencies. Installing..."
    pip3 install flask==2.3.3 flask-cors==4.0.0 requests==2.31.0 pytz==2023.3
fi

# Run the dashboard
python3 dashboard_local.py