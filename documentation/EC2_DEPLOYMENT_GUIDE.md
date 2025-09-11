# 🚀 AWS EC2 Deployment Guide

## 📋 Prerequisites on EC2 Server

### 1. **Connect to your EC2 instance:**
```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### 2. **Install Docker (if not already installed):**
```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### 3. **Install Git (if not already installed):**
```bash
sudo apt install -y git
```

## 🚢 Deployment Steps

### 1. **Clone or Update Your Repository:**
```bash
# If first time
git clone https://github.com/cybersec-git-expert/request.git
cd request

# If updating
cd request
git pull origin master
```

### 2. **Create Production Environment File:**
```bash
# Copy the template and edit it
cp production.password.env production.env
nano production.env
```

**Important**: Update these critical values:
```bash
# CHANGE THESE SECURITY KEYS!
JWT_SECRET=your-super-secure-jwt-secret-change-this-in-production
SESSION_SECRET=your-super-secure-session-secret-change-this
DEFAULT_ADMIN_PASSWORD=ChangeThisSecurePassword123!

# ADD YOUR EC2 PUBLIC IP OR DOMAIN
ALLOWED_ORIGINS=http://YOUR-EC2-IP:3001,https://yourdomain.com
```

### 3. **Login to GitHub Container Registry:**
```bash
# Create a GitHub Personal Access Token with packages:read permission
# Then login:
echo "YOUR_GITHUB_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

### 4. **Make Deployment Script Executable:**
```bash
chmod +x deploy-ec2.sh
```

### 5. **Run the Deployment:**
```bash
./deploy-ec2.sh
```

### 6. **Verify Deployment:**
```bash
# Check if container is running
docker ps

# Check logs
docker logs request-backend-container

# Test the endpoint
curl http://localhost:3001/health
```

## 🔧 Troubleshooting

### If deployment fails:

1. **Check Docker is running:**
   ```bash
   sudo systemctl status docker
   ```

2. **Check if you're logged into registry:**
   ```bash
   docker login ghcr.io
   ```

3. **Check container logs:**
   ```bash
   docker logs request-backend-container
   ```

4. **Check environment file:**
   ```bash
   cat production.env
   ```

### Common Issues:

1. **Permission denied**: Add user to docker group
2. **Image pull failed**: Check GitHub token and login
3. **Container won't start**: Check environment variables
4. **Port conflicts**: Make sure port 3001 is available

## 🔒 Security Setup

### 1. **Configure EC2 Security Group:**
- Allow inbound HTTP on port 3001 from your IP
- Allow inbound HTTPS on port 443 (if using SSL)
- Allow inbound SSH on port 22 from your IP only

### 2. **Set up a reverse proxy (optional but recommended):**
```bash
sudo apt install -y nginx

# Configure nginx to proxy to your app
sudo nano /etc/nginx/sites-available/request-backend
```

Add this configuration:
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/request-backend /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## 🎉 After Successful Deployment

Your backend will be available at:
- `http://YOUR-EC2-IP:3001` (direct access)
- `http://your-domain.com` (if using nginx proxy)

### Next Steps:
1. Test all API endpoints
2. Run database cleanup: `./run-database-cleanup.ps1`
3. Deploy your Flutter app
4. Set up monitoring and backups
