
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
