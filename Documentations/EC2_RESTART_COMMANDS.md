# 🔧 EC2 Service Restart Commands

## Run these commands in your SSH terminal (ubuntu@ip-172-31-47-231):

### 1. Check Current Status
```bash
# Check PM2 status
pm2 status

# Check Nginx status
sudo systemctl status nginx

# Check what's running on port 3000
sudo netstat -tlnp | grep :3000

# Check if Node.js is installed
node --version
npm --version
```

### 2. Navigate to Your App Directory
```bash
# Find your app directory
ls -la
cd /home/ubuntu
ls -la

# Look for your backend folder
ls -la | grep -i request
ls -la | grep -i backend
```

### 3. Start/Restart Services

#### If PM2 is installed:
```bash
# Go to your app directory (adjust path as needed)
cd /home/ubuntu/request-backend

# Start with PM2
pm2 start server.js --name "request-api"

# Or restart if already running
pm2 restart all

# Save PM2 configuration
pm2 save
pm2 startup
```

#### If PM2 is not installed:
```bash
# Install PM2
npm install -g pm2

# Or start with node directly (for testing)
node server.js
```

### 4. Start/Restart Nginx
```bash
# Check Nginx status
sudo systemctl status nginx

# Start Nginx if stopped
sudo systemctl start nginx

# Restart Nginx
sudo systemctl restart nginx

# Enable Nginx to start on boot
sudo systemctl enable nginx
```

### 5. Test Services
```bash
# Test Node.js app directly
curl localhost:3000/health

# Test through Nginx
curl localhost/health

# Test external access
curl http://54.144.9.226/health
```

### 6. Check Logs if Issues
```bash
# PM2 logs
pm2 logs

# Nginx logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log

# System logs
sudo journalctl -u nginx -f
```

### 7. Quick All-in-One Restart
```bash
# Navigate to app directory
cd /home/ubuntu/request-backend

# Install dependencies (if needed)
npm install

# Start with PM2
pm2 restart all || pm2 start server.js --name "request-api"

# Restart Nginx
sudo systemctl restart nginx

# Test everything
curl localhost:3000/health
curl localhost/health
```

## Expected Outputs:

### PM2 Status (when working):
```
┌─────┬──────────┬──────┬───────┬────────┬─────────┬────────┬─────┬───────────┬────────┬──────────┐
│ id  │ name     │ mode │ ↺    │ status │ cpu     │ memory │ pid │ user      │ uptime │ ...      │
├─────┼──────────┼──────┼───────┼────────┼─────────┼────────┼─────┼───────────┼────────┼──────────┤
│ 0   │ request-api│ fork│ 0     │ online │ 0%      │ 50MB   │ 1234│ ubuntu    │ 5m     │ disabled │
└─────┴──────────┴──────┴───────┴────────┴─────────┴────────┴─────┴───────────┴────────┴──────────┘
```

### Health Check (when working):
```
{"status":"OK"}
```

Run these commands in your SSH terminal and let me know what output you get!
