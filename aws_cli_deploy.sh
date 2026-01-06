#!/bin/bash
# AWS CLI commands to deploy MiniRack Dashboard to Lightsail
# Run these commands if you have AWS CLI configured

echo "Creating Lightsail instance with MiniRack Dashboard..."

# Read the startup script
STARTUP_SCRIPT=$(cat lightsail_complete_deploy.sh)

# Create the instance
aws lightsail create-instances \
    --instance-names "eero-dashboard" \
    --availability-zone "us-east-1a" \
    --blueprint-id "ubuntu_20_04" \
    --bundle-id "nano_2_0" \
    --user-data "$STARTUP_SCRIPT"

echo "Instance created! Waiting for it to be running..."

# Wait for instance to be running
aws lightsail wait instance-running --instance-name "eero-dashboard"

echo "Instance is running! Creating static IP..."

# Create static IP
aws lightsail allocate-static-ip --static-ip-name "eero-dashboard-ip"

# Attach static IP to instance
aws lightsail attach-static-ip \
    --static-ip-name "eero-dashboard-ip" \
    --instance-name "eero-dashboard"

# Get the static IP
STATIC_IP=$(aws lightsail get-static-ip --static-ip-name "eero-dashboard-ip" --query 'staticIp.ipAddress' --output text)

echo "============================================================"
echo "Deployment Complete!"
echo "============================================================"
echo "Dashboard URL: http://$STATIC_IP"
echo "Network ID: 20478317 (pre-configured)"
echo ""
echo "Next Steps:"
echo "1. Wait 5 minutes for full deployment"
echo "2. Visit: http://$STATIC_IP"
echo "3. Click π icon → 'Reauthorize API'"
echo "4. Enter your email and verification code"
echo "============================================================"