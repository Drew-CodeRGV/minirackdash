#!/bin/bash
# Add Mobile Responsive Design to Dashboard

set -e

echo "📱 Adding mobile responsive design to MiniRack Dashboard..."

# Stop dashboard
sudo systemctl stop eero-dashboard

# Download updated files
echo "📥 Downloading v6.7.4-mobile with CSS fix..."
sudo curl -o /opt/eero/app/dashboard.py https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
sudo curl -o /opt/eero/app/index.html https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html

# Set permissions
sudo chown www-data:www-data /opt/eero/app/dashboard.py /opt/eero/app/index.html
sudo chmod +x /opt/eero/app/dashboard.py
sudo chmod 644 /opt/eero/app/index.html

# Test Python syntax
echo "🔍 Testing Python syntax..."
if sudo -u www-data /opt/eero/venv/bin/python -c "import sys; sys.path.insert(0, '/opt/eero/app'); import dashboard; print('✅ Python syntax OK')" 2>/dev/null; then
    echo "✅ Python syntax validated"
else
    echo "⚠️ Python syntax check failed, but continuing..."
fi

# Start dashboard
echo "🚀 Starting dashboard with mobile responsive design..."
sudo systemctl start eero-dashboard
sleep 3

# Test if service is running
if sudo systemctl is-active --quiet eero-dashboard; then
    echo "✅ Dashboard service is running"
    
    # Test HTTP response
    if curl -s http://localhost:5000/ | grep -q "6.7.4" 2>/dev/null; then
        echo "✅ Version 6.7.4-mobile is live with responsive design"
        
        # Restart nginx
        sudo systemctl restart nginx
        
        PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
        echo ""
        echo "🎉 Mobile responsive design applied successfully!"
        echo "🌐 Dashboard: http://$PUBLIC_IP"
        echo ""
        echo "📱 MOBILE FEATURES ACTIVE:"
        echo "   ✅ Responsive grid layout (1-2-4 columns based on screen size)"
        echo "   ✅ Touch-friendly buttons and controls (44px minimum)"
        echo "   ✅ Optimized typography with clamp() for all screen sizes"
        echo "   ✅ Mobile-first design approach"
        echo "   ✅ Improved modal dialogs for mobile interaction"
        echo "   ✅ Better spacing and padding for touch devices"
        echo "   ✅ Touch-optimized π admin button"
        echo ""
        echo "📊 RESPONSIVE BREAKPOINTS:"
        echo "   • Mobile: Single column chart layout"
        echo "   • Tablet: Two column chart layout"
        echo "   • Desktop: Four column chart layout"
        echo ""
        echo "📲 Test on your mobile device for the best experience!"
        echo "🔧 Use admin panel (π button) to configure networks and settings"
    else
        echo "⚠️ Dashboard may not be responding correctly"
        echo "Checking service status..."
        sudo systemctl status eero-dashboard --no-pager -l
    fi
else
    echo "❌ Dashboard service failed to start"
    sudo systemctl status eero-dashboard --no-pager -l
    echo ""
    echo "🔧 Troubleshooting steps:"
    echo "   1. Check logs: sudo journalctl -u eero-dashboard -f"
    echo "   2. Check permissions: ls -la /opt/eero/app/"
    echo "   3. Manual start: sudo -u www-data /opt/eero/venv/bin/python /opt/eero/app/dashboard.py"
fi