#!/bin/bash
# Comprehensive CSS Issue Diagnosis and Fix

set -e

echo "🔍 Diagnosing CSS display issue..."

# Check current dashboard status
echo "📊 Current dashboard status:"
if sudo systemctl is-active --quiet eero-dashboard 2>/dev/null; then
    echo "✅ Dashboard service is running"
    
    # Check current version
    CURRENT_VERSION=$(curl -s http://localhost:5000/api/version 2>/dev/null | grep -o '"version":"[^"]*' | cut -d'"' -f4 || echo "unknown")
    echo "📋 Current version: $CURRENT_VERSION"
    
    # Check if CSS is being displayed as text
    echo "🔍 Checking for CSS display issue..."
    if curl -s http://localhost:5000/ 2>/dev/null | grep -q "margin: 0; padding: 0"; then
        echo "❌ CSS IS BEING DISPLAYED AS TEXT - Issue confirmed"
        CSS_ISSUE=true
    else
        echo "✅ CSS appears to be rendering correctly"
        CSS_ISSUE=false
    fi
    
    # Check HTML structure
    echo "🔍 Checking HTML structure..."
    HTML_CONTENT=$(curl -s http://localhost:5000/ 2>/dev/null)
    STYLE_OPEN_COUNT=$(echo "$HTML_CONTENT" | grep -o "<style>" | wc -l)
    STYLE_CLOSE_COUNT=$(echo "$HTML_CONTENT" | grep -o "</style>" | wc -l)
    
    echo "📋 Style tags: $STYLE_OPEN_COUNT opening, $STYLE_CLOSE_COUNT closing"
    
    if [ "$STYLE_OPEN_COUNT" -ne "$STYLE_CLOSE_COUNT" ]; then
        echo "❌ MISMATCHED STYLE TAGS - This is the problem!"
        CSS_ISSUE=true
    fi
    
else
    echo "❌ Dashboard service is not running"
    CSS_ISSUE=true
fi

if [ "$CSS_ISSUE" = true ]; then
    echo ""
    echo "🔧 APPLYING CSS FIX..."
    
    # Stop dashboard
    sudo systemctl stop eero-dashboard
    
    # Backup current files
    echo "💾 Creating backup..."
    sudo cp /opt/eero/app/index.html /opt/eero/app/index.html.backup.$(date +%s) 2>/dev/null || true
    sudo cp /opt/eero/app/dashboard.py /opt/eero/app/dashboard.py.backup.$(date +%s) 2>/dev/null || true
    
    # Download fixed files with force
    echo "📥 Downloading v6.7.6-mobile with animation fixes..."
    sudo curl -f -o /opt/eero/app/dashboard.py https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/dashboard_minimal.py
    sudo curl -f -o /opt/eero/app/index.html https://raw.githubusercontent.com/Drew-CodeRGV/minirackdash/eeroNetworkDash/deploy/index.html
    
    # Set proper permissions
    sudo chown www-data:www-data /opt/eero/app/dashboard.py /opt/eero/app/index.html
    sudo chmod +x /opt/eero/app/dashboard.py
    sudo chmod 644 /opt/eero/app/index.html
    
    # Verify files were downloaded correctly
    echo "🔍 Verifying downloaded files..."
    if grep -q "6.7.6" /opt/eero/app/index.html && grep -q "6.7.6" /opt/eero/app/dashboard.py; then
        echo "✅ Files downloaded successfully"
    else
        echo "❌ File download may have failed"
        exit 1
    fi
    
    # Clear any potential caches
    echo "🧹 Clearing caches..."
    sudo systemctl daemon-reload
    
    # Start dashboard
    echo "🚀 Starting dashboard..."
    sudo systemctl start eero-dashboard
    sleep 5
    
    # Test the fix
    echo "🧪 Testing CSS fix..."
    for i in {1..10}; do
        if curl -s http://localhost:5000/ 2>/dev/null | grep -q "6.7.6"; then
            echo "✅ Dashboard is responding with v6.7.6"
            break
        else
            echo "⏳ Waiting for dashboard to start... ($i/10)"
            sleep 2
        fi
    done
    
    # Final verification
    echo "🔍 Final CSS verification..."
    if curl -s http://localhost:5000/ 2>/dev/null | grep -q "margin: 0; padding: 0"; then
        echo "❌ CSS is still being displayed as text - manual intervention needed"
        echo ""
        echo "🔧 Manual steps to try:"
        echo "1. Check logs: sudo journalctl -u eero-dashboard -f"
        echo "2. Restart nginx: sudo systemctl restart nginx"
        echo "3. Check file contents: head -50 /opt/eero/app/index.html"
    else
        echo "✅ CSS ISSUE FIXED! CSS is now rendering properly"
        
        # Restart nginx for good measure
        sudo systemctl restart nginx
        
        PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
        echo ""
        echo "🎉 SUCCESS! CSS display issue resolved"
        echo "🌐 Dashboard: http://$PUBLIC_IP"
        echo "📱 Mobile responsive design is now active"
        echo "✅ CSS should render properly (no text display)"
    fi
    
else
    echo ""
    echo "✅ No CSS issues detected - dashboard appears to be working correctly"
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    echo "🌐 Dashboard: http://$PUBLIC_IP"
fi