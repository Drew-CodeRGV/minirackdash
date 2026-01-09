# Eero Echo Dashboard Setup Guide

Complete setup guide for connecting your Amazon Echo to your Raspberry Pi Eero Dashboard.

## Overview

This setup connects your Echo device to your existing Raspberry Pi Eero Dashboard, allowing you to ask Alexa about your network status using voice commands. All data stays local on your Pi.

## Prerequisites Checklist

- ✅ Raspberry Pi with Eero Dashboard running on port 80
- ✅ Pi dashboard authenticated with Eero API
- ✅ Amazon Echo device on same network as Pi
- ✅ AWS account for hosting Alexa skill
- ✅ Amazon Developer account for creating skill

## Step 1: Add Voice Endpoints to Your Pi

### Option A: Remote Update (Recommended)
If you're working from a different machine and want to update your Pi remotely:

```bash
# From your development machine
cd eero-event-dashboard-echo
./add-voice-endpoints-to-pi.sh --remote YOUR_PI_IP_ADDRESS

# Example:
./add-voice-endpoints-to-pi.sh --remote 192.168.1.100
```

### Option B: Local Update
If you're working directly on the Pi or have the Pi files locally:

```bash
# From the directory containing your Pi dashboard files
./add-voice-endpoints-to-pi.sh
```

### Verify Voice Endpoints
Test that the voice endpoints were added successfully:

```bash
# Replace YOUR_PI_IP with your Pi's actual IP address
curl http://YOUR_PI_IP/api/voice/status
curl http://YOUR_PI_IP/api/voice/devices
curl http://YOUR_PI_IP/api/voice/aps
curl http://YOUR_PI_IP/api/voice/events
```

You should see JSON responses with your network data.

## Step 2: Get Your Pi's IP Address

On your Raspberry Pi, run:
```bash
hostname -I
```

Note the first IP address (usually something like 192.168.1.100). You'll need this for the Lambda configuration.

## Step 3: Deploy the Alexa Skill to AWS

### Install Dependencies
```bash
cd eero-event-dashboard-echo
npm install
```

### Configure Your Pi IP
Edit the CloudFormation template to include your Pi's IP:

```bash
# Edit infrastructure/template.yaml
# Find the line with PI_DASHBOARD_IP and update it:
PI_DASHBOARD_IP: '192.168.1.100'  # Replace with your Pi's IP
```

### Deploy to AWS
```bash
# Deploy the CloudFormation stack
aws cloudformation deploy \
  --template-file infrastructure/template.yaml \
  --stack-name eero-echo-dashboard \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides Environment=dev
```

### Get the Lambda Function ARN
```bash
# Get the Lambda function ARN (you'll need this for the Alexa skill)
aws cloudformation describe-stacks \
  --stack-name eero-echo-dashboard \
  --query 'Stacks[0].Outputs[?OutputKey==`SkillFunctionArn`].OutputValue' \
  --output text
```

Save this ARN - you'll need it in the next step.

## Step 4: Create the Alexa Skill

### 1. Go to Alexa Developer Console
Visit: https://developer.amazon.com/alexa/console/ask

### 2. Create New Skill
- Click "Create Skill"
- **Skill name**: "Eero Dashboard"
- **Default language**: English (US)
- **Choose a model**: Custom
- **Choose a method**: Provision your own
- Click "Create skill"

### 3. Configure the Interaction Model
- In the left sidebar, click "JSON Editor"
- Copy the entire contents of `skill-package/interactionModels/custom/en-US.json`
- Paste it into the JSON Editor
- Click "Save Model"
- Click "Build Model" (this may take a few minutes)

### 4. Configure the Endpoint
- In the left sidebar, click "Endpoint"
- Select "AWS Lambda ARN"
- Paste your Lambda function ARN from Step 3
- Leave "Account Linking" set to "No"
- Click "Save Endpoints"

### 5. Test the Skill
- Click "Test" in the top navigation
- Enable testing for "Development"
- Try saying: "ask eero dashboard how many devices are connected"
- You should get a response with your actual network data

## Step 5: Enable on Your Echo Device

### Option A: Through Alexa App
1. Open the Alexa app on your phone
2. Go to "Skills & Games"
3. Search for "Eero Dashboard"
4. Enable the skill

### Option B: Voice Command
Say to your Echo: "Alexa, enable Eero Dashboard skill"

## Step 6: Test Voice Commands

Try these commands with your Echo:

- "Alexa, ask Eero Dashboard how many devices are connected"
- "Alexa, ask Eero Dashboard what's my network status"
- "Alexa, ask Eero Dashboard about device types"
- "Alexa, ask Eero Dashboard how are my access points performing"

## Troubleshooting

### Skill Says "Unable to connect to your dashboard"

1. **Check Pi Dashboard Status**:
   ```bash
   sudo systemctl status eero-dashboard
   ```

2. **Test Pi API Endpoints**:
   ```bash
   curl http://YOUR_PI_IP/api/voice/status
   ```

3. **Check Lambda Environment Variables**:
   - Go to AWS Lambda console
   - Find your function (eero-dashboard-skill-dev)
   - Check that PI_DASHBOARD_IP is set correctly

4. **Check Network Connectivity**:
   - Ensure Pi is accessible from the internet (for Lambda to reach it)
   - Consider port forwarding if needed

### Skill Responds Slowly

1. **Check Pi Performance**:
   ```bash
   htop  # Check CPU and memory usage
   ```

2. **Test Response Time**:
   ```bash
   curl -w "%{time_total}" http://YOUR_PI_IP/api/voice/status
   ```

3. **Restart Pi Dashboard**:
   ```bash
   sudo systemctl restart eero-dashboard
   ```

### Voice Endpoints Not Working

1. **Check if endpoints were added**:
   ```bash
   grep -n "api/voice" /home/wifi/eero-dashboard/dashboard.py
   ```

2. **Re-run the integration script**:
   ```bash
   ./add-voice-endpoints-to-pi.sh --remote YOUR_PI_IP
   ```

3. **Check Pi dashboard logs**:
   ```bash
   sudo journalctl -u eero-dashboard -f
   ```

## Network Configuration

### For Local Network Only
If your Pi is only accessible on your local network, you'll need to ensure your Lambda function can reach it. This might require:

1. **Port Forwarding**: Forward port 80 from your router to your Pi
2. **Dynamic DNS**: Use a service like DuckDNS to get a stable hostname
3. **VPN**: Set up a VPN connection for Lambda to access your local network

### For Internet-Accessible Pi
If your Pi is accessible from the internet:

1. **Security**: Ensure your Pi dashboard has proper security measures
2. **Firewall**: Configure firewall rules to allow only necessary access
3. **HTTPS**: Consider adding SSL/TLS encryption

## Advanced Configuration

### Custom Response Caching
Edit your Pi dashboard to adjust voice response caching:

```python
# In dashboard.py, modify the cache duration
VOICE_CACHE_DURATION = 30  # seconds
```

### Multiple Networks
If you have multiple Eero networks configured on your Pi, the voice responses will include data from all active networks.

### Custom Voice Responses
You can modify the voice response format by editing the voice endpoint functions in your Pi dashboard.

## Support

- **Pi Dashboard Issues**: Use your existing Pi dashboard support channels
- **Alexa Skill Issues**: [GitHub Issues](https://github.com/Drew-CodeRGV/eero-event-dashboard-echo/issues)
- **Setup Help**: [GitHub Discussions](https://github.com/Drew-CodeRGV/eero-event-dashboard-echo/discussions)

---

## Quick Reference

### Useful Commands
```bash
# Check Pi dashboard status
sudo systemctl status eero-dashboard

# Restart Pi dashboard
sudo systemctl restart eero-dashboard

# Test voice endpoints
curl http://YOUR_PI_IP/api/voice/status

# View Pi dashboard logs
sudo journalctl -u eero-dashboard -f

# Check Lambda logs
aws logs tail /aws/lambda/eero-dashboard-skill-dev --follow
```

### Voice Command Examples
- "Alexa, ask Eero Dashboard how many devices are connected"
- "Alexa, ask Eero Dashboard what's my network status"
- "Alexa, ask Eero Dashboard about device types"
- "Alexa, ask Eero Dashboard about access point performance"
- "Alexa, ask Eero Dashboard about recent network activity"

---

🎉 **Setup Complete!** You can now ask Alexa about your network using voice commands while keeping all your data local on your Raspberry Pi.