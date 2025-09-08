# CI/CD Setup Guide for Request Backend

## Overview
This guide will help you set up the complete CI/CD pipeline for the Request backend using GitHub Actions and AWS EC2.

## Prerequisites
- AWS EC2 instance running at 54.144.9.226
- Docker installed on EC2 instance
- GitHub repository: cybersec-git-expert/request
- AWS EC2 private key file

## Step 1: Configure GitHub Repository Secrets

### 1.1 Add EC2 SSH Key
1. Go to your GitHub repository: https://github.com/cybersec-git-expert/request
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `EC2_SSH_KEY`
5. Value: Copy the entire content of your `AWS-EC2.pem` file
   ```
   -----BEGIN RSA PRIVATE KEY-----
   [Your private key content here]
   -----END RSA PRIVATE KEY-----
   ```

### 1.2 Verify GITHUB_TOKEN (Auto-generated)
- The `GITHUB_TOKEN` is automatically provided by GitHub Actions
- No manual setup required

## Step 2: Set Up EC2 Environment Files

### 2.1 Create Production Environment File
SSH into your EC2 instance and create the production environment file:

```bash
ssh -i "C:\Users\cyber\Downloads\AWS-EC2.pem" ubuntu@54.144.9.226

# Create production environment file
sudo nano /home/ubuntu/production.env
```

Add your production environment variables:
```env
# Database Configuration
DB_HOST=your-rds-endpoint.amazonaws.com
DB_PORT=5432
DB_NAME=request_prod
DB_USER=your_db_user
DB_PASSWORD=your_db_password

# AWS Configuration
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1
AWS_S3_BUCKET=your-s3-bucket

# Application Configuration
NODE_ENV=production
PORT=3001
JWT_SECRET=your_jwt_secret
API_BASE_URL=http://54.144.9.226:3001

# SMS Configuration (Hutch Mobile)
HUTCH_API_URL=your_hutch_api_url
HUTCH_API_KEY=your_hutch_api_key

# Other configurations as needed
```

### 2.2 Create Staging Environment File (Optional)
```bash
sudo nano /home/ubuntu/staging.env
```

Add staging-specific configurations (similar to production but with staging values).

### 2.3 Set Proper Permissions
```bash
sudo chmod 600 /home/ubuntu/production.env
sudo chmod 600 /home/ubuntu/staging.env
sudo chown ubuntu:ubuntu /home/ubuntu/*.env
```

## Step 3: Prepare EC2 for Docker Deployment

### 3.1 Install Docker (if not already installed)
```bash
# Update system
sudo apt update

# Install Docker
sudo apt install -y docker.io

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Logout and login again for group changes to take effect
exit
```

### 3.2 Create Application Directory Structure
```bash
ssh -i "C:\Users\cyber\Downloads\AWS-EC2.pem" ubuntu@54.144.9.226

# Create application directories
mkdir -p /home/ubuntu/request-backend/uploads
mkdir -p /home/ubuntu/request-backend/logs

# Set proper permissions
sudo chmod 755 /home/ubuntu/request-backend
sudo chmod 777 /home/ubuntu/request-backend/uploads
```

## Step 4: CI/CD Pipeline Workflows

### 4.1 Continuous Integration (backend-ci.yml)
- **Triggers**: Push to any branch with backend changes
- **Actions**: 
  - Run tests
  - Lint code
  - Build Docker image
  - Push to GitHub Container Registry

### 4.2 Production Deployment (backend-deploy.yml)
- **Triggers**: Push to `master` branch with backend changes
- **Actions**:
  - Build production Docker image
  - Deploy to EC2 production environment
  - Health checks with rollback capability
  - Port: 3001

### 4.3 Staging Deployment (backend-deploy-staging.yml)
- **Triggers**: Push to `develop` or `staging` branches with backend changes
- **Actions**:
  - Build staging Docker image
  - Deploy to EC2 staging environment
  - Port: 3002

## Step 5: Testing the CI/CD Pipeline

### 5.1 Test CI Pipeline
1. Make a change to any file in the `backend/` directory
2. Commit and push to any branch:
   ```bash
   git add .
   git commit -m "Test CI pipeline"
   git push origin master
   ```
3. Check the **Actions** tab in your GitHub repository
4. Verify the CI workflow runs successfully

### 5.2 Test Production Deployment
1. Make a change to the backend code
2. Push to `master` branch:
   ```bash
   git add .
   git commit -m "Deploy to production"
   git push origin master
   ```
3. Monitor the deployment in GitHub Actions
4. Verify the application is running:
   - Health check: http://54.144.9.226:3001/health
   - Application: http://54.144.9.226:3001

### 5.3 Test Staging Deployment
1. Create and switch to develop branch:
   ```bash
   git checkout -b develop
   git push origin develop
   ```
2. Make changes and push to develop
3. Verify staging deployment at: http://54.144.9.226:3002

## Step 6: Monitoring and Maintenance

### 6.1 Check Application Status
```bash
# SSH into EC2
ssh -i "C:\Users\cyber\Downloads\AWS-EC2.pem" ubuntu@54.144.9.226

# Check running containers
docker ps

# Check container logs
docker logs request-backend
docker logs request-backend-staging

# Check application health
curl http://localhost:3001/health
curl http://localhost:3002/health
```

### 6.2 Manual Deployment Commands
```bash
# Manual production deployment
docker pull ghcr.io/cybersec-git-expert/request-backend:latest
docker stop request-backend || true
docker rm request-backend || true
docker run -d --name request-backend --restart unless-stopped --env-file /home/ubuntu/production.env -p 127.0.0.1:3001:3001 ghcr.io/cybersec-git-expert/request-backend:latest

# Manual staging deployment
docker pull ghcr.io/cybersec-git-expert/request-backend:staging
docker stop request-backend-staging || true
docker rm request-backend-staging || true
docker run -d --name request-backend-staging --restart unless-stopped --env-file /home/ubuntu/staging.env -p 127.0.0.1:3002:3001 ghcr.io/cybersec-git-expert/request-backend:staging
```

## Step 7: Troubleshooting

### 7.1 Common Issues
- **SSH Connection Failed**: Verify EC2_SSH_KEY secret contains the complete private key
- **Docker Login Failed**: Check GITHUB_TOKEN permissions
- **Health Check Failed**: Verify environment variables and database connectivity
- **Port Conflicts**: Ensure ports 3001 and 3002 are available

### 7.2 Debug Commands
```bash
# Check GitHub Container Registry login
echo "$GITHUB_TOKEN" | docker login ghcr.io -u cybersec-git-expert --password-stdin

# Check environment file
cat /home/ubuntu/production.env

# Check Docker networks
docker network ls

# Check system resources
df -h
free -h
```

## Security Notes
- Environment files contain sensitive information - keep them secure
- EC2 SSH key should only be stored in GitHub Secrets
- Regularly update Docker images for security patches
- Monitor application logs for security events

## Next Steps
1. Configure SSL/TLS with nginx reverse proxy
2. Set up log aggregation and monitoring
3. Implement database backup automation
4. Add notification webhooks for deployment status
