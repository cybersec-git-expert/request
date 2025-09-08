# 🚀 Request Marketplace - AWS Production Deployment Guide

## Overview
This guide will help you deploy your Request Marketplace backend to AWS EC2 using your existing RDS database.

## Prerequisites ✅
- ✅ **AWS RDS Database**: `requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com` (already configured)
- ✅ **Domain Name**: `api.alphabet.lk` (for API access)
- ✅ **Play Store Ready App**: AAB build completed (47.4MB)
- ⚠️ **AWS EC2 Instance**: Needs to be created
- ⚠️ **Domain DNS**: Needs to point to EC2

## Step 1: Create AWS EC2 Instance

### 1.1 Launch EC2 Instance
```bash
# Go to AWS Console → EC2 → Launch Instance
Instance Type: t3.medium (2 vCPU, 4GB RAM)
AMI: Ubuntu Server 22.04 LTS
Storage: 20GB GP3
Security Group: HTTP (80), HTTPS (443), SSH (22)
Key Pair: Create or use existing
```

### 1.2 Configure Security Group
```bash
Inbound Rules:
- SSH (22) - Your IP only
- HTTP (80) - Anywhere (0.0.0.0/0)
- HTTPS (443) - Anywhere (0.0.0.0/0)
- Custom TCP (3001) - Anywhere (for testing)
```

## Step 2: Connect to EC2 Instance

```bash
# Connect via SSH
ssh -i your-key.pem ubuntu@your-ec2-public-ip

# Or use AWS Systems Manager Session Manager
```

## Step 3: Upload Backend Code

### Option A: Using SCP
```bash
# From your local machine
scp -i your-key.pem -r backend/ ubuntu@your-ec2-ip:/tmp/
```

### Option B: Using Git (if you have a repository)
```bash
# On EC2 instance
git clone https://github.com/your-username/request-backend.git
```

## Step 4: Run Deployment Script

```bash
# On EC2 instance
cd /tmp/backend  # or your uploaded directory
chmod +x deploy/ec2-deploy.sh
./deploy/ec2-deploy.sh
```

The script will:
- ✅ Install Node.js 20
- ✅ Install PM2 process manager
- ✅ Install Nginx reverse proxy
- ✅ Configure your app to use existing RDS database
- ✅ Start the backend with PM2
- ✅ Configure Nginx with SSL ready setup

## Step 5: Set Up SSL Certificate

```bash
# After domain DNS is configured
sudo certbot --nginx -d api.alphabet.lk
```

## Step 6: Configure Domain DNS

### 6.1 Point Domain to EC2
```bash
# In your domain provider (GoDaddy, Namecheap, etc.)
A Record: api.alphabet.lk → YOUR-EC2-PUBLIC-IP
```

### 6.2 Test Domain Resolution
```bash
# Test from any computer
nslookup api.alphabet.lk
ping api.alphabet.lk
```

## Step 7: Test Deployment

### 7.1 Health Check
```bash
# Test API endpoint
curl https://api.alphabet.lk/health
curl https://api.alphabet.lk/api/test
```

### 7.2 Check Services
```bash
# On EC2 instance
pm2 status
sudo systemctl status nginx
```

## Step 8: Deploy Admin Panel to S3

```bash
# Run the admin panel deployment script
cd admin-react/deploy
./admin-s3-deploy.sh
```

## Step 9: Update Mobile App

Your mobile app is already configured to use `https://api.alphabet.lk` so it should work immediately once the backend is deployed.

## Monitoring & Maintenance

### View Application Logs
```bash
# PM2 logs
pm2 logs request-backend

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Restart Services
```bash
# Restart backend
pm2 restart request-backend

# Restart Nginx
sudo systemctl restart nginx
```

### Update Code
```bash
# Upload new code
scp -i your-key.pem -r backend/ ubuntu@your-ec2-ip:/var/www/request-backend/

# Restart application
pm2 restart request-backend
```

## Environment Configuration

Your production environment is configured in `deploy/production.env`:

```env
NODE_ENV=production
PORT=3001
DB_HOST=requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com
DB_PORT=5432
DB_NAME=requestdb
DB_USER=postgres
DB_PASSWORD=[your-password]
API_URL=https://api.alphabet.lk
ADMIN_URL=https://admin.alphabet.lk
```

## Security Checklist

- ✅ **SSL Certificate**: Let's Encrypt configured
- ✅ **Firewall**: UFW enabled with specific ports
- ✅ **Database**: RDS with security groups
- ✅ **API Keys**: Environment variables only
- ✅ **Nginx**: Security headers configured
- ✅ **Process Manager**: PM2 with auto-restart

## Cost Estimation

### Monthly AWS Costs:
- **EC2 t3.medium**: ~$30/month
- **RDS (existing)**: Already running
- **Data Transfer**: ~$5-10/month
- **Route 53** (if used): ~$0.50/month
- **Total**: ~$35-40/month

## Support & Troubleshooting

### Common Issues:

1. **502 Bad Gateway**
   ```bash
   # Check if PM2 is running
   pm2 status
   # Check Nginx config
   sudo nginx -t
   ```

2. **Database Connection Error**
   ```bash
   # Check RDS security group allows EC2
   # Verify credentials in .env file
   ```

3. **SSL Certificate Issues**
   ```bash
   # Renew certificate
   sudo certbot renew
   ```

### Get Help
- Check logs: `pm2 logs` and `sudo tail -f /var/log/nginx/error.log`
- PM2 status: `pm2 status`
- Nginx status: `sudo systemctl status nginx`

---

**Your Request Marketplace will be live at:**
- 🌐 **API**: https://api.alphabet.lk
- 📱 **Mobile App**: Ready for Play Store with 47.4MB AAB
- 👨‍💼 **Admin Panel**: Will be at https://admin.alphabet.lk (after S3 deployment)

**Ready for 24/7 operation with PM2 process management and Nginx load balancing!** 🚀
