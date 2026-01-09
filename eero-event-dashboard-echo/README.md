# Eero Event Dashboard for Amazon Echo (Local Pi Integration)

A voice-enabled Eero network monitoring system that connects your Amazon Echo directly to your Raspberry Pi dashboard. All data stays local on your Pi while providing voice access through Alexa.

## 🎤 Voice Commands

### **Network Status**
- *"Alexa, ask Eero Dashboard how many devices are connected"*
- *"Alexa, ask Eero Dashboard what's my network status"*
- *"Alexa, ask Eero Dashboard about my internet connection"*

### **Device Information**
- *"Alexa, ask Eero Dashboard which devices are online"*
- *"Alexa, ask Eero Dashboard about device types"*
- *"Alexa, ask Eero Dashboard how many phones are connected"*

### **Access Point Information**
- *"Alexa, ask Eero Dashboard which AP has the most devices"*
- *"Alexa, ask Eero Dashboard about AP performance"*
- *"Alexa, ask Eero Dashboard about network coverage"*

### **Network Events**
- *"Alexa, ask Eero Dashboard about recent activity"*
- *"Alexa, ask Eero Dashboard if anyone joined the network"*
- *"Alexa, ask Eero Dashboard about network changes"*

## 🏗️ Architecture

### **Local Data Flow**
1. **Raspberry Pi**: Runs Eero Dashboard with real network data
2. **Echo Device**: Connects to Pi via local network API calls
3. **Alexa Skill**: Hosted on AWS but fetches data from your Pi
4. **Voice Response**: Natural language responses about your network

### **Components**
- **Pi Dashboard**: Your existing Eero dashboard (data source)
- **Pi API Endpoints**: New voice-optimized API routes
- **Alexa Skill**: AWS Lambda function that calls your Pi
- **Local Network**: All data stays on your local network

## 📋 Requirements

### **Hardware**
- Raspberry Pi with Eero Dashboard installed
- Amazon Echo device on same network
- Local network connectivity between devices

### **Software**
- Eero Dashboard Pi (your existing installation)
- Amazon Developer Account (for Alexa skill)
- AWS Account (for Lambda hosting only)

## 🔧 Installation

### **1. Update Your Pi Dashboard**
```bash
# Add voice API endpoints to your existing Pi dashboard
curl -sSL https://raw.githubusercontent.com/Drew-CodeRGV/eero-event-dashboard-echo/main/pi-voice-api.sh | bash
```

### **2. Configure Pi IP Address**
```bash
# Set your Pi's local IP address for the skill
echo "PI_DASHBOARD_IP=192.168.1.100" >> ~/.eero-dashboard/voice-config
```

### **3. Deploy Alexa Skill**
```bash
# Clone and deploy the skill
git clone https://github.com/Drew-CodeRGV/eero-event-dashboard-echo.git
cd eero-event-dashboard-echo
npm install
ask deploy
```

### **4. Configure Skill Settings**
- Set your Pi's IP address in the Alexa Developer Console
- Enable the skill on your Echo device
- Test voice commands

## 🌐 Pi Dashboard Integration

### **New API Endpoints Added**
Your Pi dashboard will get these new voice-optimized endpoints:

- `GET /api/voice/status` - Network status summary
- `GET /api/voice/devices` - Device count and types
- `GET /api/voice/aps` - Access point performance
- `GET /api/voice/events` - Recent network events
- `GET /api/voice/summary` - Complete network summary

### **Data Privacy**
- ✅ All network data stays on your Pi
- ✅ Only voice responses sent to AWS
- ✅ No sensitive data leaves your local network
- ✅ Pi IP address configured locally only

## 🎯 Quick Start

### **1. Verify Pi Dashboard**
Make sure your Pi dashboard is running:
```bash
curl http://localhost/health
```

### **2. Test Voice API**
```bash
curl http://localhost/api/voice/status
```

### **3. Enable Alexa Skill**
- Find "Eero Dashboard" in Alexa Skills
- Enable and configure with your Pi IP
- Say: *"Alexa, open Eero Dashboard"*

## 🔊 Sample Interactions

### **Device Count Query**
**User**: *"Alexa, ask Eero Dashboard how many devices are online"*  
**Alexa**: *"You have 23 devices connected to your network. 18 are wireless and 5 are wired. Your living room access point is handling the most devices with 8 connections."*

### **Network Status**
**User**: *"Alexa, ask Eero Dashboard about my network status"*  
**Alexa**: *"Your network is running smoothly. All 3 access points are online with good coverage. Internet connectivity is excellent."*

### **Recent Activity**
**User**: *"Alexa, ask Eero Dashboard about recent activity"*  
**Alexa**: *"In the last hour, Sarah's iPhone and a new smart TV connected to your network. No devices have disconnected."*

## 🛠️ Configuration

### **Pi Dashboard Settings**
```bash
# Voice API configuration file
~/.eero-dashboard/voice-config

# Example settings:
PI_DASHBOARD_IP=192.168.1.100
VOICE_API_ENABLED=true
RESPONSE_CACHE_TIME=30
MAX_DEVICES_SPOKEN=10
```

### **Alexa Skill Settings**
- **Pi IP Address**: Your Raspberry Pi's local IP
- **Port**: 80 (or 5000 if not using port 80)
- **Timeout**: 10 seconds for Pi responses
- **Fallback**: Graceful handling if Pi is unreachable

## 🔐 Security & Privacy

### **Local Network Only**
- Pi dashboard accessible only on local network
- No external internet access required for data
- Voice skill connects to Pi via local IP only
- All sensitive data remains on your Pi

### **Skill Security**
- Pi IP address stored securely in skill settings
- No network credentials transmitted
- Voice responses contain no sensitive information
- Optional Pi API authentication support

## 📊 Voice-Optimized Responses

### **Smart Summarization**
- Device counts rounded for voice clarity
- Complex data simplified for audio
- Natural language device descriptions
- Time-based event summaries

### **Response Caching**
- Pi responses cached for 30 seconds
- Reduces load on Pi dashboard
- Faster voice response times
- Configurable cache duration

## 🚀 Advanced Features

### **Multi-Network Support**
- Voice access to all configured networks
- Network switching via voice commands
- Aggregate statistics across networks
- Per-network status queries

### **Proactive Notifications**
- Optional push notifications for events
- Daily network summary announcements
- Alert thresholds for device counts
- Custom notification schedules

## 🔧 Troubleshooting

### **Common Issues**

**Skill can't reach Pi:**
```bash
# Check Pi dashboard is running
sudo systemctl status eero-dashboard

# Test local API
curl http://localhost/api/voice/status

# Check firewall
sudo ufw status
```

**Voice responses are slow:**
- Reduce response cache time
- Check Pi performance with `htop`
- Verify network connectivity
- Consider Pi 4 for better performance

**Skill authentication fails:**
- Verify Pi IP address in skill settings
- Check Echo and Pi are on same network
- Test Pi accessibility from Echo's network segment

## 📞 Support

- **Pi Dashboard**: Use existing Pi dashboard support
- **Alexa Skill**: [GitHub Issues](https://github.com/Drew-CodeRGV/eero-event-dashboard-echo/issues)
- **Integration**: [Discussions](https://github.com/Drew-CodeRGV/eero-event-dashboard-echo/discussions)

---

**🎤 "Alexa, ask Eero Dashboard about my network!" 🥧**

*All data stays local on your Raspberry Pi while enjoying voice control through Alexa.*