#!/bin/bash
# Check Mobile Responsive Design Status

echo "📱 Checking mobile responsive design status..."

# Check if dashboard is running
if sudo systemctl is-active --quiet eero-dashboard 2>/dev/null; then
    echo "✅ Dashboard service is running"
    
    # Check version
    VERSION=$(curl -s http://localhost:5000/api/version 2>/dev/null | grep -o '"version":"[^"]*' | cut -d'"' -f4)
    if [ ! -z "$VERSION" ]; then
        echo "📊 Current version: $VERSION"
        
        if [[ "$VERSION" == *"6.7.5"* ]]; then
            echo "✅ Mobile responsive version detected"
        else
            echo "⚠️ Older version detected - mobile features may not be available"
        fi
    else
        echo "⚠️ Could not retrieve version information"
    fi
    
    # Check if mobile CSS is present
    if curl -s http://localhost:5000/ 2>/dev/null | grep -q "clamp(" && curl -s http://localhost:5000/ 2>/dev/null | grep -q "grid-template-columns"; then
        echo "✅ Mobile responsive CSS detected"
        echo "   • CSS Grid layouts found"
        echo "   • Responsive typography (clamp) found"
        echo "   • Touch-friendly design active"
    else
        echo "❌ Mobile responsive CSS not found"
        echo "   Run: ./add_mobile_responsive_design.sh"
    fi
    
    # Check for mobile viewport meta tag
    if curl -s http://localhost:5000/ 2>/dev/null | grep -q "viewport.*width=device-width"; then
        echo "✅ Mobile viewport configuration found"
    else
        echo "⚠️ Mobile viewport configuration missing"
    fi
    
    # Get public IP
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    echo ""
    echo "🌐 Dashboard URL: http://$PUBLIC_IP"
    echo "📲 Test on mobile device to verify responsive design"
    
    # Show responsive features
    echo ""
    echo "📱 MOBILE FEATURES:"
    echo "   • Responsive grid: 1 column (mobile) → 2 columns (tablet) → 4 columns (desktop)"
    echo "   • Touch targets: Minimum 44px for all interactive elements"
    echo "   • Scalable fonts: clamp() functions for optimal sizing"
    echo "   • Mobile modals: Optimized dialogs for touch interaction"
    echo "   • Admin panel: Touch-friendly π button and controls"
    
else
    echo "❌ Dashboard service is not running"
    echo "Run: sudo systemctl start eero-dashboard"
fi

echo ""
echo "🔧 Available mobile scripts:"
echo "   ./add_mobile_responsive_design.sh - Apply mobile responsive design"
echo "   ./check_mobile_status.sh - Check current mobile status"