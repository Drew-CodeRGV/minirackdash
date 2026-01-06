
# AWS EC2 Free Tier Deployment

## Cost: FREE for 12 months
- t2.micro instance (1 vCPU, 1 GB RAM)
- 30 GB EBS storage
- 750 hours/month free

## Step 1: Launch EC2 Instance

1. Go to EC2 console: https://console.aws.amazon.com/ec2/
2. Click "Launch Instance"
3. Choose Amazon Linux 2 AMI (Free tier eligible)
4. Select t2.micro instance type
5. Configure instance:
   - Add user data script (see user_data.sh)
   - Add security group rule: HTTP (port 80) from anywhere
6. Create or select key pair
7. Launch instance

## Step 2: Configure Security Group

1. Go to Security Groups
2. Select your instance's security group
3. Add inbound rules:
   - HTTP (80) from 0.0.0.0/0
   - SSH (22) from your IP

## Step 3: Access Dashboard

1. Wait for instance to be "running"
2. Get public IP from EC2 console
3. Visit: http://YOUR_PUBLIC_IP
4. Configure your Network ID and API token

## Step 4: Configure Dashboard

1. SSH into your instance (optional)
2. Edit config: `/home/eero/dashboard/.config.json`
3. Add your API token: `/home/eero/dashboard/.eero_token`

## Pros:
- Completely free for 12 months
- Full Linux environment
- SSH access for debugging
- Can install additional software

## Cons:
- Limited to 750 hours/month
- t2.micro has limited resources
- Charges apply after free tier expires
- Need to manage OS updates

## Monitoring:
- CloudWatch metrics included
- Set up billing alerts
- Monitor free tier usage

## Security:
- Keep OS updated
- Use strong SSH keys
- Restrict security group access
- Consider using Elastic IP

## Scaling:
After free tier, upgrade to:
- t3.micro: ~$8.50/month
- t3.small: ~$17/month
