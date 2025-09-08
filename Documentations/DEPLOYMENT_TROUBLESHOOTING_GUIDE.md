# Request App - Deployment & Troubleshooting Guide

## 📋 Overview

This document explains the complete CI/CD pipeline setup, the troubleshooting process we went through when the mobile app stopped working, and guidelines for future maintenance.

---

## 🏗️ CI/CD Pipeline Architecture

### Current Setup

Your application uses a **Docker-based CI/CD pipeline** with **GitHub Actions** for automated building and deployment.

#### Components:
1. **GitHub Repository**: `GitGuruSL/request`
2. **Container Registry**: GitHub Container Registry (GHCR)
3. **Deployment Target**: AWS EC2 instance (`ec2-54-144-9-226.compute-1.amazonaws.com`)
4. **Database**: AWS RDS PostgreSQL
5. **File Storage**: AWS S3

### Workflow Files

#### `.github/workflows/backend-ci.yml`
- **Purpose**: Continuous Integration - Tests and builds Docker images
- **Triggers**: On push to main branch
- **Actions**:
  - Runs tests and linting
  - Builds Docker image
  - Pushes to GitHub Container Registry (GHCR)

#### `.github/workflows/backend-deploy.yml`
- **Purpose**: Production Deployment
- **Triggers**: After successful CI build
- **Actions**:
  - Pulls latest Docker image from GHCR
  - Deploys to production EC2 server
  - Performs health checks
  - Automatic rollback if health checks fail

#### `.github/workflows/backend-deploy-staging.yml`
- **Purpose**: Staging environment deployment
- **Similar to production but for testing**

---

## 🐳 Docker Container System

### How It Works

1. **Image Building**: GitHub Actions builds Docker images with format:
   ```
   ghcr.io/gitgurusl/request-backend:<git-commit-sha>
   ```

2. **Container Deployment**: 
   ```bash
   docker run -d --name request-backend \
     --env-file production.env \
     -p 127.0.0.1:3001:3001 \
     ghcr.io/gitgurusl/request-backend:<image-tag>
   ```

3. **Environment Configuration**: Uses `production.env` file for all settings

### Current Container Status
- **Container Name**: `request-backend`
- **Image**: `ghcr.io/gitgurusl/request-backend:66f9c903c7e51c3e33fd50e8b90d4b0b5a2cf4b9`
- **Port**: `127.0.0.1:3001:3001` (internal port 3001)
- **Status**: Healthy and running

---

## 🔧 Troubleshooting Process - What Went Wrong

### Initial Problem
**Issue**: Mobile app stopped working - "server stop working"

### Root Cause Analysis

We discovered **multiple cascading issues**:

#### 1. Server Syntax Errors
- **Problem**: `server.js` had malformed comments from CI/CD testing
- **Symptom**: Server wouldn't start due to JavaScript syntax errors
- **Solution**: Fixed syntax by removing corrupted comments

#### 2. Database Authentication Failure
- **Problem**: PostgreSQL password mismatch
- **Details**: 
  - App expected: `RequestMarketplace2024!`
  - AWS RDS had different password
  - Username `requestadmindb` didn't exist initially
- **Solution**: Updated RDS master password to match app configuration

#### 3. AWS S3 Credentials Issue
- **Problem**: Placeholder AWS credentials in container
- **Details**:
  - Container had: `AWS_ACCESS_KEY_ID=your-access-key`
  - Should be: `AWS_ACCESS_KEY_ID=AKIA***************` (your actual key)
- **Symptom**: Product images showing "No image"
- **Solution**: Updated `production.env` with correct AWS credentials

#### 4. Banner Image Serving Issue
- **Problem**: Banner images not loading
- **Details**:
  - Images stored in `/app/deploy-package/uploads/`
  - Server expected them at `/app/uploads/`
  - URLs returned as `http://localhost:3001` instead of external server address
- **Solution**: 
  - Created symlink: `/app/uploads` → `/app/deploy-package/uploads/`
  - Added `SERVER_URL` environment variable
  - Modified banner route to use external URL

---

## 🛠️ Technical Fixes Applied

### 1. Database Configuration
```bash
# Current working credentials in production.env:
DB_HOST=requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com
DB_PORT=5432
DB_NAME=request
DB_USERNAME=requestadmindb
DB_PASSWORD=RequestMarketplace2024!
DB_SSL=true
```

### 2. AWS S3 Configuration
```bash
# AWS credentials in production.env:
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=AKIA***************  # Your actual AWS Access Key ID
AWS_SECRET_ACCESS_KEY=***************  # Your actual AWS Secret Access Key
AWS_S3_BUCKET=requestappbucket
```

### 3. Server URL Configuration
```bash
# Added to production.env:
SERVER_URL=http://ec2-54-144-9-226.compute-1.amazonaws.com:3001
```

### 4. File System Fix
```bash
# Created symlink in container:
ln -sf /app/deploy-package/uploads /app/uploads
```

### 5. Code Changes
Modified `backend/routes/banners.js`:
```javascript
function absoluteBase(req) {
  // Use SERVER_URL environment variable if available (for production deployment)
  if (process.env.SERVER_URL) {
    return process.env.SERVER_URL;
  }
  const proto = (req.protocol || 'http').toLowerCase();
  const host = req.get('host');
  const finalProto = process.env.NODE_ENV === 'production' ? 'https' : proto;
  return `${finalProto}://${host}`;
}
```

---

## 📱 Current System Status

### ✅ What's Working Now

1. **Server Health**: `http://127.0.0.1:3001/health` returns healthy status
2. **Database**: PostgreSQL connection working perfectly
3. **Product Images**: Loading from AWS S3 with signed URLs
4. **Banner Images**: Loading from local uploads directory
5. **Mobile App**: Fully functional with all images displaying

### 🔍 Health Check Details
```json
{
  "status": "healthy",
  "timestamp": "2025-08-27T06:33:10.384Z",
  "database": {
    "status": "healthy",
    "timestamp": "2025-08-27T06:33:10.384Z",
    "connectionCount": 1,
    "idleCount": 1,
    "waitingCount": 0
  },
  "version": "1.0.0"
}
```

---

## 🚀 Future Maintenance Guidelines

### Regular Monitoring

#### 1. Health Checks
**Check server health regularly:**
```bash
curl -s http://ec2-54-144-9-226.compute-1.amazonaws.com:3001/health
```

**Expected Response**: `"status": "healthy"`

#### 2. Container Status
**Check Docker container:**
```bash
ssh -i your-key.pem ubuntu@ec2-54-144-9-226.compute-1.amazonaws.com "docker ps"
```

**Expected Status**: `Up X minutes (healthy)`

#### 3. GitHub Actions
- **Monitor**: Repository → Actions tab
- **Check**: All workflows showing green ✅
- **Failed builds**: Check logs and fix issues immediately

### Common Issues & Solutions

#### Issue: Mobile App Not Loading Data
**Diagnosis Steps:**
1. Check server health endpoint
2. Check container status
3. Check GitHub Actions for failed deployments

**Quick Fix:**
```bash
# Restart container if unhealthy
docker restart request-backend
```

#### Issue: Images Not Loading
**Diagnosis:**
1. **Product Images**: Check AWS credentials in container
2. **Banner Images**: Check uploads directory symlink

**Solutions:**
```bash
# Check AWS credentials
docker exec <container-id> printenv | grep AWS

# Should show:
# AWS_ACCESS_KEY_ID=AKIA***************
# AWS_SECRET_ACCESS_KEY=***************

# Recreate uploads symlink
docker exec <container-id> ln -sf /app/deploy-package/uploads /app/uploads
```

#### Issue: Database Connection Errors
**Check:**
1. RDS instance status in AWS console
2. Database credentials in `production.env`
3. Security groups allowing port 5432

### Deployment Process

#### Automatic Deployment (Recommended)
1. **Make code changes**
2. **Commit to main branch**:
   ```bash
   git add .
   git commit -m "Your changes"
   git push origin main
   ```
3. **GitHub Actions will automatically**:
   - Build new Docker image
   - Deploy to production
   - Perform health checks
   - Rollback if issues detected

#### Manual Deployment (Emergency)
```bash
# SSH to server
ssh -i your-key.pem ubuntu@ec2-54-144-9-226.compute-1.amazonaws.com

# Pull latest image
docker pull ghcr.io/gitgurusl/request-backend:latest

# Stop current container
docker stop request-backend && docker rm request-backend

# Start new container
docker run -d --name request-backend \
  --env-file production.env \
  -p 127.0.0.1:3001:3001 \
  ghcr.io/gitgurusl/request-backend:latest

# Recreate uploads symlink
docker exec request-backend ln -sf /app/deploy-package/uploads /app/uploads
```

### Environment File Maintenance

#### Critical Files on Server
1. **`production.env`**: Contains all environment variables
2. **Location**: `/home/ubuntu/production.env`

#### Backup Environment File
```bash
# Create backup before changes
cp production.env production.env.backup.$(date +%Y%m%d)
```

#### Update Environment Variables
```bash
# Edit production.env
nano production.env

# Restart container to apply changes
docker restart request-backend
```

### Security Considerations

#### 1. Keep Credentials Secure
- **Never commit** `production.env` to Git
- **Rotate AWS keys** periodically
- **Use strong database passwords**

#### 2. Monitor Access
- **Check SSH access logs**
- **Monitor Docker container logs**
- **Review GitHub Actions logs**

#### 3. Update Dependencies
- **Regularly update Docker base images**
- **Update Node.js dependencies**
- **Apply security patches**

---

## 📞 Emergency Contacts & Resources

### Quick Commands Cheat Sheet

```bash
# Check server health
curl -s http://ec2-54-144-9-226.compute-1.amazonaws.com:3001/health

# SSH to server
ssh -i "path/to/your/key.pem" ubuntu@ec2-54-144-9-226.compute-1.amazonaws.com

# Check container status
docker ps

# View container logs
docker logs request-backend --tail 20

# Restart container
docker restart request-backend

# Check environment variables
docker exec request-backend printenv | grep -E 'DB_|AWS_|SERVER_'
```

### Important URLs
- **Server Health**: `http://ec2-54-144-9-226.compute-1.amazonaws.com:3001/health`
- **GitHub Repository**: `https://github.com/GitGuruSL/request`
- **GitHub Actions**: `https://github.com/GitGuruSL/request/actions`
- **GHCR Images**: `https://github.com/GitGuruSL/request/pkgs/container/request-backend`

### AWS Resources
- **EC2 Instance**: `ec2-54-144-9-226.compute-1.amazonaws.com`
- **RDS Database**: `requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com`
- **S3 Bucket**: `requestappbucket`

---

## 📝 Lessons Learned

### Key Takeaways
1. **Environment Variables**: Always verify production environment variables match development
2. **Health Checks**: Implement comprehensive health checks for early issue detection
3. **Database Credentials**: Keep RDS and application passwords synchronized
4. **Image Serving**: Ensure static file paths are correctly configured in containers
5. **Monitoring**: Regular monitoring prevents small issues from becoming big problems

### Best Practices Established
1. **Automated Deployment**: CI/CD pipeline with health checks and rollback
2. **Environment Management**: Centralized environment configuration
3. **Container Health**: Docker health checks and monitoring
4. **Documentation**: This guide for future reference and troubleshooting

---

## 🎯 Conclusion

Your Request app now has a **robust, automated deployment system** with proper error handling, health monitoring, and rollback capabilities. The mobile app is fully functional with all images loading correctly.

**The system is production-ready and maintenance-friendly!** 🚀

For any issues, follow the troubleshooting steps in this guide or check the GitHub Actions logs for automated deployment issues.
