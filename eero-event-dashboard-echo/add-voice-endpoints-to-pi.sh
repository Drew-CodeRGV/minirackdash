#!/bin/bash

# Add Voice API Endpoints to Raspberry Pi Dashboard
# This script adds the voice-optimized API endpoints needed for Echo integration

set -e

echo "🎤 Adding Voice API Endpoints to Raspberry Pi Dashboard"
echo "=================================================="

# Check if we're running on the Pi or need to copy to Pi
if [ "$1" = "--remote" ] && [ -n "$2" ]; then
    PI_HOST="$2"
    echo "📡 Remote mode: Will update Pi at $PI_HOST"
    REMOTE_MODE=true
else
    echo "🏠 Local mode: Updating local dashboard"
    REMOTE_MODE=false
fi

# Define the dashboard path
if [ "$REMOTE_MODE" = true ]; then
    DASHBOARD_PATH="/home/wifi/eero-dashboard"
else
    DASHBOARD_PATH="./eero-dashboard-pi"
fi

echo "📁 Dashboard path: $DASHBOARD_PATH"

# Function to add voice endpoints to dashboard.py
add_voice_endpoints() {
    local dashboard_file="$1"
    
    echo "🔧 Adding voice API endpoints to $dashboard_file"
    
    # Check if voice endpoints already exist
    if grep -q "/api/voice/status" "$dashboard_file"; then
        echo "✅ Voice endpoints already exist in dashboard"
        return 0
    fi
    
    # Create a temporary file with the voice endpoints
    cat > /tmp/voice_endpoints.py << 'EOF'

# Voice API endpoints for Echo integration
@app.route('/api/voice/status')
def get_voice_status():
    """Get network status optimized for voice responses"""
    try:
        update_cache()
        combined_data = data_cache['combined']
        
        total_devices = combined_data.get('total_devices', 0)
        wireless_devices = combined_data.get('wireless_devices', 0)
        wired_devices = combined_data.get('wired_devices', 0)
        
        # Calculate AP statistics
        total_aps = 0
        online_aps = 0
        busiest_ap = None
        max_devices = 0
        
        for network_id, network_data in data_cache.get('networks', {}).items():
            ap_data = network_data.get('ap_data', {})
            for ap_id, ap_info in ap_data.items():
                total_aps += 1
                online_aps += 1  # All APs in data are considered online
                
                if ap_info.get('total_devices', 0) > max_devices:
                    max_devices = ap_info.get('total_devices', 0)
                    busiest_ap = {
                        'name': ap_info.get('name', 'Unknown AP'),
                        'device_count': max_devices
                    }
        
        return jsonify({
            'total_devices': total_devices,
            'wireless_devices': wireless_devices,
            'wired_devices': wired_devices,
            'total_aps': total_aps,
            'online_aps': online_aps,
            'busiest_ap': busiest_ap,
            'internet_status': 'connected',  # Assume connected if we have data
            'last_update': combined_data.get('last_update')
        })
        
    except Exception as e:
        logging.error(f"Voice status error: {str(e)}")
        return jsonify({
            'total_devices': 0,
            'wireless_devices': 0,
            'wired_devices': 0,
            'total_aps': 0,
            'online_aps': 0,
            'busiest_ap': None,
            'internet_status': 'unknown',
            'last_update': None
        }), 500

@app.route('/api/voice/devices')
def get_voice_devices():
    """Get device information optimized for voice responses"""
    try:
        update_cache()
        combined_data = data_cache['combined']
        
        total_devices = combined_data.get('total_devices', 0)
        wireless_devices = combined_data.get('wireless_devices', 0)
        wired_devices = combined_data.get('wired_devices', 0)
        device_os = combined_data.get('device_os', {})
        
        # Find busiest AP
        busiest_ap = None
        max_devices = 0
        
        for network_id, network_data in data_cache.get('networks', {}).items():
            ap_data = network_data.get('ap_data', {})
            for ap_id, ap_info in ap_data.items():
                if ap_info.get('total_devices', 0) > max_devices:
                    max_devices = ap_info.get('total_devices', 0)
                    busiest_ap = {
                        'name': ap_info.get('name', 'Unknown AP'),
                        'device_count': max_devices
                    }
        
        return jsonify({
            'total_devices': total_devices,
            'wireless_devices': wireless_devices,
            'wired_devices': wired_devices,
            'device_types': device_os,
            'busiest_ap': busiest_ap,
            'last_update': combined_data.get('last_update')
        })
        
    except Exception as e:
        logging.error(f"Voice devices error: {str(e)}")
        return jsonify({
            'total_devices': 0,
            'wireless_devices': 0,
            'wired_devices': 0,
            'device_types': {},
            'busiest_ap': None,
            'last_update': None
        }), 500

@app.route('/api/voice/aps')
def get_voice_aps():
    """Get access point information optimized for voice responses"""
    try:
        update_cache()
        
        total_aps = 0
        busiest_ap = None
        max_devices = 0
        
        for network_id, network_data in data_cache.get('networks', {}).items():
            ap_data = network_data.get('ap_data', {})
            for ap_id, ap_info in ap_data.items():
                total_aps += 1
                
                if ap_info.get('total_devices', 0) > max_devices:
                    max_devices = ap_info.get('total_devices', 0)
                    busiest_ap = {
                        'name': ap_info.get('name', 'Unknown AP'),
                        'device_count': max_devices,
                        'model': ap_info.get('model', 'Unknown')
                    }
        
        return jsonify({
            'total_aps': total_aps,
            'online_aps': total_aps,  # All APs in data are considered online
            'busiest_ap': busiest_ap,
            'last_update': data_cache['combined'].get('last_update')
        })
        
    except Exception as e:
        logging.error(f"Voice APs error: {str(e)}")
        return jsonify({
            'total_aps': 0,
            'online_aps': 0,
            'busiest_ap': None,
            'last_update': None
        }), 500

@app.route('/api/voice/events')
def get_voice_events():
    """Get recent network events optimized for voice responses"""
    try:
        # For now, return mock events since we don't have real event tracking
        # This can be enhanced later with actual event monitoring
        current_time = get_timezone_aware_now()
        
        # Generate some sample events based on current device data
        events = []
        combined_data = data_cache['combined']
        devices = combined_data.get('devices', [])
        
        # Create mock recent events for voice responses
        if devices:
            # Take first few devices as "recently connected"
            for i, device in enumerate(devices[:3]):
                event_time = current_time - timedelta(minutes=i*15)
                events.append({
                    'type': 'device_connected',
                    'device_name': device.get('name', 'Unknown Device'),
                    'timestamp': event_time.isoformat(),
                    'description': f"{device.get('name', 'Unknown Device')} connected"
                })
        
        return jsonify({
            'events': events,
            'event_count': len(events),
            'last_update': combined_data.get('last_update')
        })
        
    except Exception as e:
        logging.error(f"Voice events error: {str(e)}")
        return jsonify({
            'events': [],
            'event_count': 0,
            'last_update': None
        }), 500

EOF
    
    # Find the insertion point (before the main execution block)
    if [ "$REMOTE_MODE" = true ]; then
        # For remote mode, create a script to run on the Pi
        cat > /tmp/update_dashboard.sh << 'REMOTE_EOF'
#!/bin/bash
set -e

DASHBOARD_FILE="/home/wifi/eero-dashboard/dashboard.py"
BACKUP_FILE="/home/wifi/eero-dashboard/dashboard.py.backup.$(date +%Y%m%d_%H%M%S)"

echo "📋 Creating backup: $BACKUP_FILE"
cp "$DASHBOARD_FILE" "$BACKUP_FILE"

echo "🔧 Adding voice endpoints to dashboard.py"

# Find the line with "if __name__ == '__main__':" and insert before it
LINE_NUM=$(grep -n "if __name__ == '__main__':" "$DASHBOARD_FILE" | head -1 | cut -d: -f1)

if [ -z "$LINE_NUM" ]; then
    echo "❌ Could not find insertion point in dashboard.py"
    exit 1
fi

# Insert the voice endpoints before the main block
head -n $((LINE_NUM - 1)) "$DASHBOARD_FILE" > /tmp/dashboard_new.py
cat /tmp/voice_endpoints.py >> /tmp/dashboard_new.py
tail -n +$LINE_NUM "$DASHBOARD_FILE" >> /tmp/dashboard_new.py

# Replace the original file
mv /tmp/dashboard_new.py "$DASHBOARD_FILE"

echo "✅ Voice endpoints added successfully"
echo "🔄 Restarting dashboard service..."
sudo systemctl restart eero-dashboard

echo "✅ Dashboard service restarted"
echo "🎤 Voice API endpoints are now available at:"
echo "   - http://$(hostname -I | awk '{print $1}')/api/voice/status"
echo "   - http://$(hostname -I | awk '{print $1}')/api/voice/devices"
echo "   - http://$(hostname -I | awk '{print $1}')/api/voice/aps"
echo "   - http://$(hostname -I | awk '{print $1}')/api/voice/events"
REMOTE_EOF
        
        # Copy files to Pi and execute
        echo "📤 Copying files to Pi..."
        scp /tmp/voice_endpoints.py /tmp/update_dashboard.sh "wifi@$PI_HOST:/tmp/"
        
        echo "🚀 Executing update on Pi..."
        ssh "wifi@$PI_HOST" "chmod +x /tmp/update_dashboard.sh && /tmp/update_dashboard.sh"
        
    else
        # Local mode
        if [ ! -f "$dashboard_file" ]; then
            echo "❌ Dashboard file not found: $dashboard_file"
            return 1
        fi
        
        # Create backup
        backup_file="${dashboard_file}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "📋 Creating backup: $backup_file"
        cp "$dashboard_file" "$backup_file"
        
        # Find the line with "if __name__ == '__main__':" and insert before it
        line_num=$(grep -n "if __name__ == '__main__':" "$dashboard_file" | head -1 | cut -d: -f1)
        
        if [ -z "$line_num" ]; then
            echo "❌ Could not find insertion point in dashboard.py"
            return 1
        fi
        
        # Insert the voice endpoints before the main block
        head -n $((line_num - 1)) "$dashboard_file" > /tmp/dashboard_new.py
        cat /tmp/voice_endpoints.py >> /tmp/dashboard_new.py
        tail -n +$line_num "$dashboard_file" >> /tmp/dashboard_new.py
        
        # Replace the original file
        mv /tmp/dashboard_new.py "$dashboard_file"
        
        echo "✅ Voice endpoints added successfully"
    fi
    
    # Clean up
    rm -f /tmp/voice_endpoints.py /tmp/update_dashboard.sh
}

# Main execution
if [ "$REMOTE_MODE" = true ]; then
    echo "🔗 Connecting to Pi at $PI_HOST..."
    
    # Test connection
    if ! ssh -o ConnectTimeout=5 "wifi@$PI_HOST" "echo 'Connection successful'"; then
        echo "❌ Cannot connect to Pi at $PI_HOST"
        echo "💡 Make sure:"
        echo "   - Pi is powered on and connected to network"
        echo "   - SSH is enabled on the Pi"
        echo "   - You can SSH to wifi@$PI_HOST"
        exit 1
    fi
    
    add_voice_endpoints
    
    echo ""
    echo "🎉 Voice endpoints successfully added to Pi dashboard!"
    echo "🔧 Configure your Echo skill with Pi IP: $PI_HOST"
    
else
    # Local mode
    if [ ! -d "$DASHBOARD_PATH" ]; then
        echo "❌ Dashboard directory not found: $DASHBOARD_PATH"
        echo "💡 Make sure you're running this from the correct directory"
        exit 1
    fi
    
    add_voice_endpoints "$DASHBOARD_PATH/dashboard.py"
    
    echo ""
    echo "🎉 Voice endpoints successfully added to local dashboard!"
    echo "🔧 You can now test the endpoints locally"
fi

echo ""
echo "📋 Next steps:"
echo "1. 🏠 Get your Pi's IP address: hostname -I"
echo "2. 🎤 Configure your Echo skill with the Pi IP"
echo "3. 🧪 Test voice endpoints:"
echo "   curl http://YOUR_PI_IP/api/voice/status"
echo "4. 📱 Deploy your Echo skill to AWS Lambda"
echo ""
echo "✅ Setup complete!"