# CI/CD Setup Guide

This document explains how to set up automated deployments for the Request Backend and Admin React app using GitHub Actions.

## 🚀 Overview

The CI/CD pipeline automatically:
- Builds Docker images for the backend
- Pushes images to GitHub Container Registry (GHCR)
- Deploys to your EC2 server
- Performs health checks
- Rolls back on failure

## 📋 Prerequisites

1. **GitHub Repository**: Your code must be in a GitHub repository
2. **EC2 Server**: Running with Docker installed
3. **SSH Access**: SSH key for EC2 access
4. **Docker**: Docker installed on EC2 server

## 🔧 GitHub Secrets Setup

You need to configure the following secrets in your GitHub repository:

### Go to: Repository → Settings → Secrets and variables → Actions

Add these secrets:

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `EC2_HOST` | Your EC2 server IP address | `3.92.216.149` |
| `EC2_USER` | SSH username for EC2 | `ec2-user` |
| `EC2_SSH_KEY` | Private SSH key content | (entire content of your .pem file) |
| `VITE_API_BASE_URL` | API URL for admin app | `http://3.92.216.149:3001` |

### Setting up EC2_SSH_KEY

1. Open your SSH key file: `d:\Development\request\my-new-ssh-key.pem`
2. Copy the **entire content** including the header and footer:
   ```
   -----BEGIN RSA PRIVATE KEY-----
   (all the content)
   -----END RSA PRIVATE KEY-----
   ```
3. Paste this as the value for `EC2_SSH_KEY` secret

## 📁 File Structure

The CI/CD pipeline expects this structure:

```
request/
├── .github/
│   └── workflows/
│       ├── deploy-backend.yml     # Backend deployment
│       └── deploy-admin.yml       # Admin React deployment
├── backend/
│   ├── Dockerfile                 # Docker configuration
│   ├── .dockerignore             # Docker ignore file
│   ├── package.json              # Node.js dependencies
│   └── (your backend code)
├── admin-react/
│   ├── package.json              # React dependencies
│   └── (your React code)
└── production.env.template       # Environment template
```

## 🔄 Workflow Triggers

### Backend Deployment (`deploy-backend.yml`)
- **Automatic**: Triggers on push to `master`/`main` when backend files change
- **Manual**: Can be triggered manually from GitHub Actions tab
- **Builds**: Docker image and pushes to GHCR
- **Deploys**: To EC2 using your existing production.env

### Admin Deployment (`deploy-admin.yml`)
- **Automatic**: Triggers on push to `master`/`main` when admin-react files change
- **Manual**: Can be triggered manually from GitHub Actions tab
- **Builds**: React app with Vite
- **Deploys**: Static files to `/var/www/admin/current`

## 🐳 Docker Configuration

### Backend Dockerfile Features:
- ✅ Node.js 18 Alpine (lightweight)
- ✅ Non-root user for security
- ✅ Health check endpoint
- ✅ Production optimizations
- ✅ Proper port exposure (3001)

### .dockerignore Benefits:
- ✅ Excludes node_modules (rebuilt in container)
- ✅ Ignores development files
- ✅ Reduces image size
- ✅ Faster builds

## 🔧 EC2 Server Requirements

### Docker Setup
Your EC2 server needs:
```bash
# Install Docker (if not already installed)
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Verify Docker is working
docker --version
docker ps
```

### File Requirements
- `production.env` file must exist in `/home/ec2-user/`
- EC2 user must have Docker permissions
- Port 3001 must be open in security groups

## 🚀 Deployment Process

### Automatic Deployment
1. **Push code** to master/main branch
2. **GitHub Actions** detects changes
3. **Builds** Docker image (backend) or React app (admin)
4. **Pushes** image to GitHub Container Registry
5. **SSH** into EC2 server
6. **Pulls** latest image
7. **Stops** old container
8. **Starts** new container
9. **Health check** verifies deployment
10. **Cleanup** removes old images

### Manual Deployment
1. Go to **GitHub repository**
2. Click **Actions** tab
3. Select **Deploy Backend** or **Deploy Admin React App**
4. Click **Run workflow**
5. Select branch and click **Run workflow**

## 📊 Monitoring & Debugging

### Check Deployment Status
1. **GitHub Actions**: Repository → Actions tab
2. **Live logs**: Click on running workflow
3. **Status badges**: Shows success/failure

### Troubleshooting
```bash
# SSH into EC2
ssh -i "my-new-ssh-key.pem" ec2-user@3.92.216.149

# Check container status
docker ps -a

# View container logs
docker logs request-backend-container

# Check health endpoint
curl http://localhost:3001/health

# View deployment logs
docker logs --tail 50 request-backend-container
```

## 🔒 Security Features

- ✅ **Non-root Docker user**
- ✅ **Minimal Alpine images**
- ✅ **SSH key authentication**
- ✅ **GitHub Container Registry**
- ✅ **Automatic secrets handling**
- ✅ **Environment file isolation**

## 🎯 Benefits

1. **Automated**: No manual deployment steps
2. **Consistent**: Same process every time
3. **Fast**: Optimized Docker builds with caching
4. **Safe**: Health checks and rollback on failure
5. **Traceable**: Full deployment history in GitHub
6. **Scalable**: Easy to add more environments

## ⚡ Quick Start

1. **Set up secrets** (EC2_HOST, EC2_USER, EC2_SSH_KEY)
2. **Commit and push** to master branch
3. **Watch GitHub Actions** deploy automatically
4. **Verify** at http://your-ec2-ip:3001/health

## 🔄 Migration from Manual

Your current manual deployment will work alongside CI/CD:
- ✅ Same Docker image structure
- ✅ Same environment file (production.env)
- ✅ Same port configuration (3001)
- ✅ Same health check endpoint

The CI/CD pipeline replicates your working manual process!

## 📞 Support

If deployment fails:
1. Check GitHub Actions logs
2. Verify EC2 secrets are correct
3. Ensure production.env exists on server
4. Test SSH connection manually
5. Check Docker is running on EC2

---

**Ready to deploy?** Just push your code to master! 🚀
