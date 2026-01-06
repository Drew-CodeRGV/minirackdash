# AWS Deployment Options for MiniRack Dashboard

Choose the best deployment option based on your needs and budget:

## 🏆 **Recommended: AWS Lightsail** 
**Cost: ~$3.50/month**

✅ **Best for most users**
- Simple setup with one-click deployment
- Predictable monthly cost
- Includes static IP, monitoring, and snapshots
- Perfect for 24/7 dashboard hosting

**Setup:** Follow `LIGHTSAIL_INSTRUCTIONS.md`

---

## 💰 **Most Cost-Effective: AWS Lambda**
**Cost: Nearly FREE (AWS Free Tier)**

✅ **Best for occasional use**
- Pay only for requests (usually <$1/month)
- Serverless - no server management
- Auto-scaling and high availability
- Cold start delays (1-2 seconds)

**Setup:** Follow `LAMBDA_GUIDE.md`

---

## 🆓 **Free Option: AWS EC2 Free Tier**
**Cost: FREE for 12 months**

✅ **Best for learning/testing**
- Completely free for first year
- Full Linux environment with SSH access
- Limited to 750 hours/month
- Becomes ~$8.50/month after free tier

**Setup:** Follow `EC2_INSTRUCTIONS.md`

---

## Quick Comparison

| Option | Monthly Cost | Setup Complexity | Reliability | Performance |
|--------|-------------|------------------|-------------|-------------|
| **Lightsail** | $3.50 | ⭐⭐⭐⭐⭐ Easy | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐⭐⭐ Fast |
| **Lambda** | <$1 | ⭐⭐⭐ Medium | ⭐⭐⭐⭐ Good | ⭐⭐⭐ Good* |
| **EC2 Free** | Free/Year 1 | ⭐⭐⭐⭐ Easy | ⭐⭐⭐⭐ Good | ⭐⭐⭐ Limited |

*Lambda has cold start delays but excellent performance once warmed up.

---

## 🚀 **Quick Start: Lightsail (Recommended)**

1. **Create deployment files:**
   ```bash
   python3 aws_deployment/lightsail_deploy.py
   ```

2. **Go to Lightsail console:**
   https://lightsail.aws.amazon.com/

3. **Create instance:**
   - Platform: Linux/Unix
   - Blueprint: Ubuntu 20.04 LTS  
   - Plan: $3.50/month
   - Paste startup script from `startup_script.sh`

4. **Configure:**
   - Create static IP (free)
   - Access dashboard at your static IP
   - Use admin panel (π icon) to set Network ID

---

## 🔧 **Configuration After Deployment**

Regardless of which option you choose:

1. **Access your dashboard** at the provided URL
2. **Click the π icon** (admin panel)
3. **Enter your Network ID** 
4. **Authenticate with Eero API:**
   - Enter your email
   - Check email for verification code
   - Enter code to complete setup

---

## 🛡️ **Security Considerations**

### For Internet-Accessible Deployments:
- **Use HTTPS** (Let's Encrypt is free)
- **Strong authentication** (consider adding login)
- **Monitor access logs** regularly
- **Keep systems updated**

### Network ID Security:
- Your Network ID is not sensitive (it's just an identifier)
- API tokens are stored securely with restricted permissions
- Consider IP whitelisting for admin functions

---

## 📊 **Feature Comparison**

| Feature | Lightsail | Lambda | EC2 Free |
|---------|-----------|--------|----------|
| Real-time updates | ✅ | ⚠️ Limited | ✅ |
| Speed test | ✅ | ❌ | ✅ |
| Admin panel | ✅ | ⚠️ Limited | ✅ |
| Custom domain | ✅ | ✅ | ✅ |
| HTTPS/SSL | ✅ | ✅ | ✅ |
| Backup/Snapshots | ✅ | N/A | Manual |

---

## 🆘 **Support & Troubleshooting**

### Common Issues:
1. **Port conflicts:** Use different ports (3000, 8080, etc.)
2. **API authentication:** Check Network ID and token
3. **No devices showing:** Verify network connectivity
4. **Performance:** Consider upgrading instance size

### Getting Help:
- Check deployment logs in AWS console
- Use SSH to debug (Lightsail/EC2)
- Monitor CloudWatch metrics
- Test API endpoints directly

---

## 🔄 **Migration Between Options**

You can easily migrate between deployment options:
1. Export your configuration (Network ID, API token)
2. Deploy to new platform
3. Import configuration
4. Update DNS if using custom domain

---

## 📈 **Scaling Recommendations**

### Light Usage (Personal):
- **Lightsail $3.50/month** - Perfect balance

### Medium Usage (Small Office):
- **Lightsail $5-10/month** - More resources
- **EC2 t3.micro** - More control

### Heavy Usage (Enterprise):
- **EC2 with Load Balancer** - High availability
- **Lambda + CloudFront** - Global distribution

---

Choose your deployment option and follow the corresponding guide to get your dashboard running in the cloud!