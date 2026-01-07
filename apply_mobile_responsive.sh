#!/bin/bash
# Apply Mobile Responsive Design to Dashboard

set -e

echo "📱 Applying mobile responsive design to MiniRack Dashboard..."

# Stop dashboard
sudo systemctl stop eero-dashboard

# Download updated files directly
echo "📥 Downloading v6.7.3-mobile files..."
sudo curl -o /opt/eero/app/dashboard.py https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
sudo curl -o /opt/eero/app/index.html https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html

# Set permissions
sudo chown www-data:www-data /opt/eero/app/dashboard.py /opt/eero/app/index.html
sudo chmod +x /opt/eero/app/dashboard.py
sudo chmod 644 /opt/eero/app/index.html

# Test Python syntax
echo "🔍 Testing Python syntax..."
sudo -u www-data /opt/eero/venv/bin/python -c "import sys; sys.path.insert(0, '/opt/eero/app'); import dashboard; print('✅ Python syntax OK')"

# Start dashboard
echo "🚀 Starting dashboard with mobile responsive design..."
sudo systemctl start eero-dashboard
sleep 3

# Test
if curl -s http://localhost:5000/ | grep -q "6.7.3"; then
    echo "✅ Version 6.7.3-mobile is live with responsive design"
    
    # Restart nginx
    sudo systemctl restart nginx
    
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    echo ""
    echo "🎉 Mobile responsive design applied successfully!"
    echo "🌐 Dashboard: http://$PUBLIC_IP"
    echo ""
    echo "📱 MOBILE ENHANCEMENTS:"
    echo "   • Responsive grid layout (1-2-4 columns based on screen size)"
    echo "   • Touch-friendly buttons and controls (44px minimum)"
    echo "   • Optimized typography with clamp() for all screen sizes"
    echo "   • Mobile-first design approach"
    echo "   • Improved modal dialogs for mobile interaction"
    echo "   • Better spacing and padding for touch devices"
    echo ""
    echo "📊 RESPONSIVE FEATURES:"
    echo "   • Mobile: Single column chart layout"
    echo "   • Tablet: Two column chart layout"
    echo "   • Desktop: Four column chart layout"
    echo "   • Scalable fonts and UI elements"
    echo "   • Touch-optimized π admin button"
    echo ""
    echo "📲 Test on your mobile device for the best experience!"
else
    echo "❌ Update may have failed"
    sudo systemctl status eero-dashboard
fi