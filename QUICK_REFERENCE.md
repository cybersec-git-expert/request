# Quick Reference - Request App Deployment

## 🚨 Emergency Quick Fixes

### Mobile App Not Working?
```bash
# 1. Check server health
curl -s http://ec2-54-144-9-226.compute-1.amazonaws.com:3001/health

# 2. If unhealthy, restart container
ssh -i "your-key.pem" ubuntu@ec2-54-144-9-226.compute-1.amazonaws.com
docker restart request-backend

# 3. Check if uploads link exists
docker exec request-backend ls -la /app/uploads
# If missing: docker exec request-backend ln -sf /app/deploy-package/uploads /app/uploads
```

## 🔄 Normal Deployment Process

### Making Changes
1. Edit code locally
2. Commit and push to main:
   ```bash
   git add .
   git commit -m "Your changes"
   git push origin main
   ```
3. GitHub Actions automatically deploys
4. Check GitHub Actions tab for success ✅

## 📊 System Status Check

```bash
# Server health
curl -s http://ec2-54-144-9-226.compute-1.amazonaws.com:3001/health

# Container status
ssh -i "your-key.pem" ubuntu@ec2-54-144-9-226.compute-1.amazonaws.com "docker ps"

# Recent logs
ssh -i "your-key.pem" ubuntu@ec2-54-144-9-226.compute-1.amazonaws.com "docker logs request-backend --tail 10"
```

## 🔑 Key Files & Locations

- **Production Environment**: `/home/ubuntu/production.env` (on EC2)
- **Container Name**: `request-backend`
- **Health Endpoint**: `/health`
- **GitHub Actions**: Repository → Actions tab

## ⚙️ Current Configuration

- **Database**: `requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com`
- **User**: `requestadmindb` 
- **Password**: `RequestMarketplace2024!`
- **AWS S3**: `requestappbucket`
- **AWS Access Key**: `AKIA***************` (stored in production.env)
- **Server URL**: `http://ec2-54-144-9-226.compute-1.amazonaws.com:3001`

## 📞 When Something Goes Wrong

1. **Check GitHub Actions** first (Repository → Actions)
2. **Check server health** endpoint
3. **Look at container logs** for errors
4. **Verify environment variables** in container
5. **Restart container** if needed
6. **Check this documentation** for specific issues

---
*Last Updated: August 27, 2025*
