# 🚨 API Domain Troubleshooting Guide

## Current Issue: api.alphabet.lk Not Working

### Problem Identified
- **EC2 Instance**: Not responding to ping (54.144.9.22)
- **Domain**: Cannot resolve or connect
- **Services**: Backend appears to be down

## Step-by-Step Fix

### 1. Check EC2 Instance Status
Login to AWS Console and check:

```
AWS Console → EC2 → Instances → Check Status
```

**Possible States:**
- ✅ **Running**: Instance is on
- ❌ **Stopped**: Instance is off - START IT
- ❌ **Terminated**: Instance is deleted - NEED NEW INSTANCE

### 2. If Instance is Stopped
**Start the instance:**
1. Select your instance
2. Click "Instance State" → "Start Instance"
3. Wait 2-3 minutes for startup
4. Note the NEW PUBLIC IP (it might change!)

### 3. Check Security Groups
Ensure these ports are open:

```
Port 22  (SSH)     - Source: Your IP
Port 80  (HTTP)    - Source: 0.0.0.0/0
Port 443 (HTTPS)   - Source: 0.0.0.0/0
Port 3000 (Node)   - Source: 0.0.0.0/0 (for testing)
```

**To fix:**
1. Go to EC2 → Security Groups
2. Find your instance's security group
3. Edit Inbound Rules
4. Add missing ports

### 4. SSH Into Instance (If Running)
```bash
ssh -i "your-key.pem" ubuntu@54.144.9.22
```

**If IP changed, update DNS:**
- Update your DNS A record to new IP
- Wait 5-10 minutes for propagation

### 5. Check Services on EC2
Once SSH connected, check:

```bash
# Check if PM2 is running
pm2 status

# Check if Nginx is running
sudo systemctl status nginx

# Check if Node.js app is running
sudo netstat -tlnp | grep :3000

# Check server logs
pm2 logs

# Restart services if needed
pm2 restart all
sudo systemctl restart nginx
```

### 6. Test Services
```bash
# Test Node.js directly
curl localhost:3000/health

# Test through Nginx
curl localhost/health

# Test external access
curl http://54.144.9.22/health
```

### 7. Common Fixes

#### If PM2 not running:
```bash
cd /home/ubuntu/request-backend
pm2 start server.js --name "request-api"
pm2 startup
pm2 save
```

#### If Nginx not configured:
```bash
sudo nano /etc/nginx/sites-available/default
```

Add this configuration:
```nginx
server {
    listen 80;
    server_name api.alphabet.lk 54.144.9.22;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Restart Nginx:
```bash
sudo systemctl restart nginx
```

### 8. Quick Recovery Commands

If you can SSH in, run these commands:

```bash
# Navigate to your app directory
cd /home/ubuntu/request-backend

# Update and restart everything
git pull origin main
npm install
pm2 restart all

# Restart Nginx
sudo systemctl restart nginx

# Check status
pm2 status
sudo systemctl status nginx
```

### 9. DNS Issues Fix

If EC2 is running but domain not working:

1. **Check your DNS settings** in your domain registrar
2. **Update A record** if IP changed:
   ```
   Type: A
   Name: api
   Value: [NEW_EC2_IP]
   TTL: 300
   ```

3. **Test DNS propagation:**
   ```bash
   nslookup api.alphabet.lk
   ```

### 10. Emergency Backup Plan

If EC2 is terminated or unfixable:

1. **Create new EC2 instance**
2. **Deploy backend again:**
   ```bash
   # Install Node.js, PM2, Nginx
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
   nvm install --lts
   npm install -g pm2
   sudo apt update && sudo apt install nginx -y
   
   # Clone and start your backend
   git clone [your-repo]
   cd request-backend
   npm install
   pm2 start server.js --name "request-api"
   ```

3. **Update DNS** to new IP

## Quick Test Commands

```bash
# Test from your computer
ping 54.144.9.22
curl http://54.144.9.22/health
curl http://api.alphabet.lk/health

# Test from EC2 (via SSH)
curl localhost:3000/health
curl localhost/health
pm2 status
sudo systemctl status nginx
```

## What to Check First

1. ✅ **AWS Console** - Is instance running?
2. ✅ **Security Groups** - Are ports 80, 443, 3000 open?
3. ✅ **SSH Access** - Can you connect to EC2?
4. ✅ **PM2 Status** - Is your Node.js app running?
5. ✅ **Nginx Status** - Is reverse proxy working?
6. ✅ **DNS Settings** - Is A record pointing to correct IP?

## Contact Info

If you need help:
1. Share your AWS Console screenshots
2. Share SSH connection errors
3. Share PM2 and Nginx status output

The most likely issue is that your EC2 instance was stopped and needs to be restarted from AWS Console.
