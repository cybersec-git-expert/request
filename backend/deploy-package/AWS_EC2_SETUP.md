# 🚀 AWS EC2 Setup Guide

## Step 1: Launch EC2 Instance

### 1.1 Go to AWS Console
- Visit: https://aws.amazon.com/console/
- Sign in to your AWS account
- Navigate to **EC2 Dashboard**

### 1.2 Launch Instance
1. Click **"Launch Instance"**
2. **Name**: `request-backend-server`
3. **AMI**: Ubuntu Server 22.04 LTS (Free tier eligible)
4. **Instance Type**: `t3.medium` (2 vCPU, 4GB RAM) - Recommended for production
   - Or `t2.micro` for testing (1 vCPU, 1GB RAM) - Free tier
5. **Key Pair**: 
   - Create new key pair: `request-backend-key`
   - Download the `.pem` file and save it securely
6. **Network Settings**:
   - Create security group: `request-backend-sg`
   - Allow SSH (22) from your IP
   - Allow HTTP (80) from anywhere
   - Allow HTTPS (443) from anywhere
   - Allow Custom TCP (3001) from anywhere (for testing)
7. **Storage**: 20GB GP3 (sufficient for backend)
8. Click **"Launch Instance"**

### 1.3 Note Down Details
- **Instance ID**: `i-xxxxxxxxxxxxx`
- **Public IP**: `xx.xx.xx.xx` (will be shown after launch)
- **Public DNS**: `ec2-xx-xx-xx-xx.compute-1.amazonaws.com`

## Step 2: Connect to Your Instance

### Windows (PowerShell):
```powershell
# Navigate to where you saved the key file
cd C:\path\to\your\key
# Connect via SSH
ssh -i "request-backend-key.pem" ubuntu@YOUR-EC2-PUBLIC-IP
```

### Example:
```powershell
ssh -i "request-backend-key.pem" ubuntu@54.123.456.789
```

## Next Steps:
Once connected, we'll run the deployment script to set up Node.js, PM2, Nginx, and deploy your backend code.

---
**Save your EC2 details:**
- Public IP: ________________
- Key file location: ________________
- Instance ID: ________________
