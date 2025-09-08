# CI/CD Deployment Fix Guide ✅

**Status: PRODUCTION SERVER CONFIGURED & READY** 

This guide will help you fix the CI/CD deployment issues you're experiencing where every push to Git requires manual redeployment.

## 🔍 **Current Issues Identified**

1. **GHCR Authentication Failure**: The production server cannot authenticate with GitHub Container Registry
2. **Missing Environment Variables**: Production environment file is not properly configured
3. **Health Check Timeouts**: Container may not be starting properly due to missing configuration

## 🛠️ **Step-by-Step Fix**

### 1. Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions → Environment secrets (production environment):

#### Required Secrets:
```
DEPLOY_HOST=your-production-server-ip-or-domain
DEPLOY_USER=ubuntu (or your SSH username)
DEPLOY_SSH_KEY=your-private-ssh-key-content
GHCR_USER=GitGuruSL (your GitHub username)
GHCR_TOKEN=your-github-personal-access-token
```

#### To create GHCR_TOKEN:
1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Select scopes: `read:packages`, `write:packages`, `delete:packages`
4. Copy the token and add it as `GHCR_TOKEN` secret

### 2. Setup Production Server

Run this command on your production server:

```bash
curl -fsSL https://raw.githubusercontent.com/GitGuruSL/request/main/scripts/setup-production-server.sh -o setup.sh
chmod +x setup.sh
./setup.sh
```

### 3. Configure Environment Variables

Copy the environment template and configure it:

```bash
cd /opt/request-backend
cp production.env.template production.env
nano production.env  # Edit with your actual values
```

### 4. Test Manual Deployment

Test the deployment manually first:

```bash
/opt/request-backend/deploy.sh latest
```

### 5. Make Container Images Public (Alternative Fix)

If authentication issues persist, make your container registry public:

1. Go to GitHub → GitGuruSL/request → Packages
2. Find "request-backend" package
3. Click on it → Package settings
4. Change visibility to Public

## 🔧 **Enhanced Workflow Changes Made**

The updated workflow now includes:

- ✅ Better GHCR authentication with error handling
- ✅ Extended health check timeout (60 seconds instead of 30)
- ✅ Detailed error logging and debugging
- ✅ Production environment file support
- ✅ Better container status reporting
- ✅ Automatic migration execution

## 🚀 **Testing the Fix**

1. Make a small change to your backend code
2. Commit and push to main branch
3. Watch GitHub Actions workflow
4. Verify deployment succeeds without manual intervention

## 🔍 **Troubleshooting Commands**

If deployment still fails, use the troubleshooting script:

```bash
# Download and run troubleshooting script
curl -fsSL https://raw.githubusercontent.com/GitGuruSL/request/main/scripts/troubleshoot-deployment.sh -o troubleshoot.sh
chmod +x troubleshoot.sh
./troubleshoot.sh --full
```

## 📋 **Quick Debugging Checklist**

- [ ] GitHub secrets are properly configured
- [ ] Production server has Docker installed
- [ ] `/opt/request-backend/production.env` exists and is configured
- [ ] GHCR authentication works: `docker login ghcr.io`
- [ ] Health endpoint responds: `curl http://localhost:3001/health`
- [ ] Container is running: `docker ps | grep request-backend`

## 🔄 **Manual Deployment Commands**

If automatic deployment fails, you can manually deploy:

```bash
# Pull latest image
docker pull ghcr.io/gitgurusl/request-backend:latest

# Stop existing container
docker stop request-backend-container || true
docker rm request-backend-container || true

# Start new container
docker run -d \
  --name request-backend-container \
  --restart always \
  --network request-net \
  -p 3001:3001 \
  --env-file /opt/request-backend/production.env \
  -v /opt/request-backend/data:/app/uploads \
  ghcr.io/gitgurusl/request-backend:latest
```

## 📞 **Support**

If you continue to experience issues:

1. Run the troubleshooting script: `./troubleshoot-deployment.sh --full`
2. Check GitHub Actions logs for specific error messages
3. Verify all secrets are properly configured
4. Ensure production server has all required dependencies

The workflow should now automatically deploy on every push to the main branch without requiring manual intervention.
