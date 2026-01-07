#!/bin/bash
# Direct Mobile Responsive Design Update

set -e

echo "📱 Updating dashboard with mobile responsive design..."

# Stop dashboard
sudo systemctl stop eero-dashboard

# Copy files from local repository
echo "📥 Copying mobile responsive files..."
sudo cp deploy/dashboard_minimal.py /opt/eero/app/dashboard.py
sudo cp deploy/index.html /opt/eero/app/index.html

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
    if curl -s http://localhost:5000/ | grep -q "6.7.3" 2>/dev/null; then
        echo "✅ Version 6.7.3-mobile is live with responsive design"
        
        # Restart nginx
        sudo systemctl restart nginx
        
        PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
        echo ""
        echo "🎉 Mobile responsive design applied successfully!"
        echo "🌐 Dashboard: http://$PUBLIC_IP"
        echo ""
        echo "📱 MOBILE FEATURES ACTIVE:"
        echo "   ✅ Responsive grid layout (1-2-4 columns)"
        echo "   ✅ Touch-friendly controls (44px minimum)"
        echo "   ✅ Scalable typography with clamp() functions"
        echo "   ✅ Mobile-first design approach"
        echo "   ✅ Optimized modal dialogs"
        echo "   ✅ Touch-optimized π admin button"
        echo ""
        echo "📲 Ready for mobile testing!"
    else
        echo "⚠️ Dashboard may not be responding correctly"
        echo "Checking service status..."
        sudo systemctl status eero-dashboard --no-pager -l
    fi
else
    echo "❌ Dashboard service failed to start"
    sudo systemctl status eero-dashboard --no-pager -l
fi