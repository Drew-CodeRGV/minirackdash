#!/usr/bin/env python3
"""
AWS Lightsail Deployment Script for MiniRack Dashboard
Cost: ~$3.50/month for the smallest instance
"""
import os
import json

def create_lightsail_startup_script():
    """Create startup script for Lightsail instance"""
    
    startup_script = '''#!/bin/bash
# MiniRack Dashboard - AWS Lightsail Startup Script

# Update system
apt-get update -y
apt-get upgrade -y

# Install Python and dependencies
apt-get install -y python3 python3-pip python3-venv git nginx

# Create user
useradd -m -s /bin/bash eero
mkdir -p /home/eero/dashboard
chown -R eero:eero /home/eero

# Setup Python environment
sudo -u eero python3 -m venv /home/eero/dashboard/venv
sudo -u eero /home/eero/dashboard/venv/bin/pip install flask flask-cors requests speedtest-cli gunicorn

# Create dashboard files
cat > /home/eero/dashboard/app.py << 'EOF'
# Your dashboard code will be inserted here
EOF

# Create frontend directory and files
mkdir -p /home/eero/dashboard/frontend
cat > /home/eero/dashboard/frontend/index.html << 'EOF'
# Your frontend HTML will be inserted here
EOF

# Create systemd service
cat > /etc/systemd/system/eero-dashboard.service << 'EOF'
[Unit]
Description=Eero Dashboard
After=network.target

[Service]
Type=simple
User=eero
WorkingDirectory=/home/eero/dashboard
Environment="PATH=/home/eero/dashboard/venv/bin"
ExecStart=/home/eero/dashboard/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx
cat > /etc/nginx/sites-available/eero-dashboard << 'EOF'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/eero-dashboard /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Start services
systemctl daemon-reload
systemctl enable eero-dashboard
systemctl start eero-dashboard
systemctl enable nginx
systemctl restart nginx

# Open firewall
ufw allow 80
ufw allow 22
ufw --force enable

echo "Dashboard deployment complete!"
echo "Access at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
'''
    
    return startup_script

def create_lightsail_instructions():
    """Create deployment instructions"""
    
    instructions = """
# AWS Lightsail Deployment Instructions

## Cost: ~$3.50/month (smallest instance)

### Step 1: Create Lightsail Instance

1. Go to AWS Lightsail console: https://lightsail.aws.amazon.com/
2. Click "Create instance"
3. Choose:
   - Platform: Linux/Unix
   - Blueprint: Ubuntu 20.04 LTS
   - Instance plan: $3.50/month (512 MB RAM, 1 vCPU, 20 GB SSD)
4. Name your instance: "eero-dashboard"
5. Click "Create instance"

### Step 2: Configure Instance

1. Wait for instance to be "Running"
2. Click on the instance name
3. Go to "Networking" tab
4. Create static IP (free while attached)
5. Attach the static IP to your instance

### Step 3: Deploy Dashboard

1. Click "Connect using SSH" 
2. Run the deployment commands (see deploy_commands.sh)

### Step 4: Configure Dashboard

1. Access your dashboard at: http://YOUR_STATIC_IP
2. Click the π icon for admin panel
3. Enter your Network ID and authenticate

## Alternative: Use the startup script

When creating the instance, paste the startup script in the "Launch script" section.
This will automatically install everything on first boot.

## Security Notes

- The instance will be accessible from the internet
- Consider adding HTTPS with Let's Encrypt
- Use strong authentication
- Monitor access logs

## Scaling

If you need more resources:
- $5/month: 1 GB RAM, 1 vCPU, 40 GB SSD
- $10/month: 2 GB RAM, 1 vCPU, 60 GB SSD

## Monitoring

Lightsail includes basic monitoring:
- CPU utilization
- Network traffic
- Instance health

## Backup

Enable automatic snapshots:
- Daily snapshots: $0.05/GB/month
- Manual snapshots available
"""
    
    return instructions

if __name__ == "__main__":
    # Create deployment files
    os.makedirs("aws_deployment", exist_ok=True)
    
    with open("aws_deployment/startup_script.sh", "w") as f:
        f.write(create_lightsail_startup_script())
    
    with open("aws_deployment/LIGHTSAIL_INSTRUCTIONS.md", "w") as f:
        f.write(create_lightsail_instructions())
    
    print("✓ Lightsail deployment files created!")
    print("✓ Check aws_deployment/ directory")