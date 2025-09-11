# Local Docker Build Test Script (PowerShell)
# Tests the Docker build process before CI/CD deployment

Write-Host "🔨 Testing Docker build for Request Backend..." -ForegroundColor Green

# Change to backend directory
Set-Location backend

try {
    # Build the Docker image
    Write-Host "📦 Building Docker image..." -ForegroundColor Yellow
    docker build -t request-backend:test .
    
    if ($LASTEXITCODE -ne 0) {
        throw "Docker build failed"
    }
    
    Write-Host "✅ Docker build successful!" -ForegroundColor Green
    
    # Test the container
    Write-Host "🧪 Starting test container..." -ForegroundColor Yellow
    docker run -d --name request-backend-test -p 3002:3001 request-backend:test
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to start container"
    }
    
    # Wait for container to start
    Write-Host "⏳ Waiting for container to start..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    # Test health endpoint
    Write-Host "🏥 Testing health endpoint..." -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3002/health" -TimeoutSec 10 -ErrorAction Stop
        Write-Host "✅ Health check passed!" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Health check failed!" -ForegroundColor Red
        Write-Host "Container logs:" -ForegroundColor Yellow
        docker logs request-backend-test
    }
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    # Cleanup
    Write-Host "🧹 Cleaning up test container..." -ForegroundColor Yellow
    docker stop request-backend-test 2>$null
    docker rm request-backend-test 2>$null
}

Write-Host "🎉 Local Docker test completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Cyan
Write-Host "1. If tests passed, your Docker setup is ready for CI/CD" -ForegroundColor White
Write-Host "2. Configure GitHub secrets (see CI_CD_SETUP_GUIDE.md)" -ForegroundColor White
Write-Host "3. Push to master branch to trigger automatic deployment" -ForegroundColor White
