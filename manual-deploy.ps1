# PowerShell Deployment Script for Request Backend
# Usage: .\manual-deploy.ps1 [image-tag]

param(
    [string]$ImageTag = "latest"
)

$IMAGE = "ghcr.io/gitgurusl/request-backend:$ImageTag"
$NAME = "request-backend-container"
$PORT = 3001

Write-Host "🚀 Deploying $IMAGE" -ForegroundColor Green

# Check if Docker is running
try {
    docker version | Out-Null
} catch {
    Write-Host "❌ Docker is not running or not installed!" -ForegroundColor Red
    exit 1
}

# Stop and remove old containers
Write-Host "🧹 Cleaning up old containers..." -ForegroundColor Yellow
try {
    $oldContainers = docker ps -aq --filter "ancestor=ghcr.io/gitgurusl/request-backend" 2>$null
    if ($oldContainers) {
        docker stop $oldContainers 2>$null
        docker rm -f $oldContainers 2>$null
    }
    docker rm -f $NAME 2>$null
    docker rm -f "request-backend" 2>$null
} catch {
    Write-Host "⚠️  Some cleanup operations failed, continuing..." -ForegroundColor Yellow
}

# Check if production.password.env exists
if (-not (Test-Path ".\production.password.env")) {
    Write-Host "❌ production.password.env not found in current directory!" -ForegroundColor Red
    Write-Host "Make sure you're running this from the project root directory" -ForegroundColor Yellow
    exit 1
}

# Pull the latest image
Write-Host "📥 Pulling $IMAGE..." -ForegroundColor Blue
try {
    docker pull $IMAGE
} catch {
    Write-Host "❌ Failed to pull image: $IMAGE" -ForegroundColor Red
    Write-Host "Make sure you're logged in to the registry: docker login ghcr.io" -ForegroundColor Yellow
    exit 1
}

# Run the container
Write-Host "🚀 Starting container..." -ForegroundColor Green
try {
    docker run -d --name $NAME `
        --restart unless-stopped `
        --env-file ".\production.password.env" `
        --label "com.gitgurusl.app=request-backend" `
        -p "127.0.0.1:$PORT`:3001" `
        $IMAGE
} catch {
    Write-Host "❌ Failed to start container!" -ForegroundColor Red
    exit 1
}

# Health check
Write-Host "🏥 Checking container health..." -ForegroundColor Blue
Start-Sleep -Seconds 5

$containerStatus = docker inspect --format='{{.State.Status}}' $NAME 2>$null
if ($containerStatus -eq "running") {
    Write-Host "✅ Container is running successfully!" -ForegroundColor Green
    Write-Host "📡 Backend available at: http://localhost:$PORT" -ForegroundColor Cyan
    
    # Test endpoint
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$PORT/health" -TimeoutSec 10 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ Health check passed!" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠️  Health check endpoint not responding yet, but container is running" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Container failed to start!" -ForegroundColor Red
    Write-Host "Container status: $containerStatus" -ForegroundColor Yellow
    Write-Host "Checking logs..." -ForegroundColor Yellow
    docker logs $NAME
    exit 1
}

Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green