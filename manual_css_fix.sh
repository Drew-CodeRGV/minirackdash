#!/bin/bash
# Manual CSS Fix - Direct File Edit

set -e

echo "🔧 Manual CSS fix - editing file directly..."

# Stop dashboard
sudo systemctl stop eero-dashboard

# Create backup
sudo cp /opt/eero/app/index.html /opt/eero/app/index.html.backup.$(date +%s)

# Fix the CSS issue by removing any premature </style> tags
echo "🔍 Scanning for CSS structure issues..."

# Use sed to fix common CSS issues
sudo sed -i 's/    <\/style> //' /opt/eero/app/index.html
sudo sed -i '/^[[:space:]]*align-items: center;[[:space:]]*$/d' /opt/eero/app/index.html
sudo sed -i '/^[[:space:]]*margin-bottom: 20px;[[:space:]]*$/d' /opt/eero/app/index.html
sudo sed -i '/^[[:space:]]*padding-bottom: 15px;[[:space:]]*$/d' /opt/eero/app/index.html
sudo sed -i '/^[[:space:]]*border-bottom: 2px solid rgba(77,166,255,.3);[[:space:]]*$/d' /opt/eero/app/index.html

# Ensure proper CSS structure
echo "🔧 Ensuring proper CSS structure..."

# Check if we have proper style tags
STYLE_OPEN=$(grep -c "<style>" /opt/eero/app/index.html || echo "0")
STYLE_CLOSE=$(grep -c "</style>" /opt/eero/app/index.html || echo "0")

echo "📋 Style tags found: $STYLE_OPEN opening, $STYLE_CLOSE closing"

if [ "$STYLE_OPEN" -eq 1 ] && [ "$STYLE_CLOSE" -eq 1 ]; then
    echo "✅ CSS structure looks correct"
else
    echo "❌ CSS structure still has issues"
    echo "Manual intervention required"
fi

# Set permissions
sudo chown www-data:www-data /opt/eero/app/index.html
sudo chmod 644 /opt/eero/app/index.html

# Start dashboard
echo "🚀 Starting dashboard..."
sudo systemctl start eero-dashboard
sleep 3

# Test
if curl -s http://localhost:5000/ | grep -q "Network Dashboard" 2>/dev/null; then
    echo "✅ Dashboard is responding"
    
    # Check if CSS is still being displayed as text
    if curl -s http://localhost:5000/ 2>/dev/null | grep -q "margin: 0; padding: 0"; then
        echo "❌ CSS is still being displayed as text"
        echo "🔧 Try downloading fresh files with: sudo ./diagnose_and_fix_css.sh"
    else
        echo "✅ CSS appears to be rendering correctly now"
        sudo systemctl restart nginx
        PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
        echo "🌐 Dashboard: http://$PUBLIC_IP"
    fi
else
    echo "❌ Dashboard not responding"
    sudo systemctl status eero-dashboard --no-pager -l
fi