#!/bin/bash

# AWS EC2 Deployment Script for Request Marketplace Backend
# Run this script on your EC2 instance
# NOTE: RDS database is already configured and running

echo "🚀 Starting Request Marketplace Backend Deployment..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2 for process management
sudo npm install -g pm2

# Install Nginx for reverse proxy
sudo apt install -y nginx

# Create application directory
sudo mkdir -p /var/www/request-backend
sudo chown -R $USER:$USER /var/www/request-backend

# Navigate to app directory
cd /var/www/request-backend

# Clone or upload your backend code here
# git clone your-repo-url .
# OR upload files manually

echo "📁 Please upload your backend files to /var/www/request-backend/"
echo "   You can use: scp -r backend/ ubuntu@your-ec2-ip:/var/www/request-backend/"
echo "   Press Enter when files are uploaded..."
read -p ""

# Install dependencies
npm install --production

# Copy production environment (uses existing RDS)
cp deploy/production.env .env

echo "✅ Using existing RDS database: requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com"

# Create PM2 ecosystem file
cat > ecosystem.config.js << 'EOL'
module.exports = {
  apps: [{
    name: 'request-backend',
    script: 'server.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3001
    },
    error_file: '/var/log/pm2/request-backend-error.log',
    out_file: '/var/log/pm2/request-backend-out.log',
    log_file: '/var/log/pm2/request-backend.log',
    time: true,
    max_memory_restart: '1G',
    watch: false
  }]
};
EOL

# Create Nginx configuration
sudo tee /etc/nginx/sites-available/request-backend << 'EOL'
server {
    listen 80;
    server_name api.alphabet.lk;  # Replace with your domain

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.alphabet.lk;  # Replace with your domain

    # SSL Configuration (you'll need to set up certificates)
    ssl_certificate /etc/letsencrypt/live/api.alphabet.lk/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.alphabet.lk/privkey.pem;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Proxy to Node.js application
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # File upload size
        client_max_body_size 50M;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:3001/health;
        access_log off;
    }
}
EOL

# Enable the site
sudo ln -s /etc/nginx/sites-available/request-backend /etc/nginx/sites-enabled/
sudo nginx -t

# Install Certbot for SSL (Let's Encrypt)
sudo apt install -y certbot python3-certbot-nginx

# Create PM2 log directory
sudo mkdir -p /var/log/pm2
sudo chown -R $USER:$USER /var/log/pm2

# Start the application with PM2
pm2 start ecosystem.config.js
pm2 save
pm2 startup

echo "✅ Backend deployment completed!"
echo "📋 Next steps:"
echo "1. Set up SSL certificate: sudo certbot --nginx -d api.alphabet.lk"
echo "2. Update DNS to point to this server"
echo "3. Update mobile app API URL to https://api.alphabet.lk"
echo "4. Test the deployment: curl https://api.alphabet.lk/health"
