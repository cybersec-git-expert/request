# Database Connection Fix Script
# This script helps diagnose and fix database connection issues after CI/CD deployment

Write-Host "🔍 Diagnosing Database Connection Issues..." -ForegroundColor Yellow
Write-Host ""

# Step 1: Check if backend is responding
Write-Host "1. Testing backend connectivity..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "http://3.92.216.149:3001/health" -TimeoutSec 10 -ErrorAction Stop
    Write-Host "✅ Backend is responding!" -ForegroundColor Green
    Write-Host "Response: $($response.Content)" -ForegroundColor White
} catch {
    Write-Host "❌ Backend is NOT responding" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Step 2: Provide manual connection commands
Write-Host "2. Manual diagnosis commands:" -ForegroundColor Cyan
Write-Host ""
Write-Host "To connect to EC2 and check container status:" -ForegroundColor Yellow
Write-Host "ssh -i my-new-ssh-key.pem ec2-user@3.92.216.149" -ForegroundColor White
Write-Host ""
Write-Host "Once connected, run these commands:" -ForegroundColor Yellow
Write-Host "docker ps -a" -ForegroundColor White
Write-Host "docker logs request-backend-container" -ForegroundColor White
Write-Host "ls -la /home/ec2-user/production.env" -ForegroundColor White
Write-Host ""

# Step 3: Show expected production.env content
Write-Host "3. Required production.env content:" -ForegroundColor Cyan
Write-Host @"
# Database Configuration
DB_HOST=your-rds-endpoint.rds.amazonaws.com
DB_PORT=5432
DB_NAME=request_db
DB_USERNAME=request_user
DB_PASSWORD=your-db-password
DB_SSL=true

# AWS Configuration  
AWS_REGION=us-east-1

# Other required vars
NODE_ENV=production
PORT=3001
"@ -ForegroundColor White

Write-Host ""
Write-Host "4. Quick fix commands (run on EC2):" -ForegroundColor Cyan
Write-Host @"
# Stop current container
docker stop request-backend-container
docker rm request-backend-container

# Create/update production.env file
sudo nano /home/ec2-user/production.env

# Restart container with correct env file
docker run -d --name request-backend-container \
  --restart unless-stopped \
  --env-file /home/ec2-user/production.env \
  -p 3001:3001 \
  request-backend:latest
"@ -ForegroundColor White

Write-Host ""
Write-Host "5. Test after fix:" -ForegroundColor Cyan
Write-Host "curl http://localhost:3001/health" -ForegroundColor White
