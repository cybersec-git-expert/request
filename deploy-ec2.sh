#!/bin/bash
# Linux Deployment Script for Request Backend on AWS EC2
# Usage: ./deploy-ec2.sh [image-tag]

set -euo pipefail

IMAGE_TAG=${1:-latest}
IMAGE="ghcr.io/cybersec-git-expert/request-backend:$IMAGE_TAG"
NAME="request-backend-container"
PORT=3001

echo "🚀 Deploying $IMAGE on EC2"

# Check if Docker is running
if ! docker version >/dev/null 2>&1; then
    echo "❌ Docker is not running or not installed!"
    echo "Install Docker with: sudo apt update && sudo apt install -y docker.io"
    exit 1
fi

# Check if user is in docker group or has sudo
if ! docker ps >/dev/null 2>&1; then
    echo "❌ Permission denied. Run with sudo or add user to docker group:"
    echo "sudo usermod -aG docker \$USER && newgrp docker"
    exit 1
fi

# Stop and remove old containers
echo "🧹 Cleaning up old containers..."
docker stop $(docker ps -aq --filter "ancestor=ghcr.io/cybersec-git-expert/request-backend" 2>/dev/null) 2>/dev/null || true
docker rm -f $(docker ps -aq --filter "ancestor=ghcr.io/cybersec-git-expert/request-backend" 2>/dev/null) 2>/dev/null || true
docker rm -f "$NAME" request-backend 2>/dev/null || true

# Clean old images (keep latest 3)
OLD_IMAGES=$(docker images ghcr.io/cybersec-git-expert/request-backend --format "{{.ID}}" | tail -n +4 2>/dev/null || true)
if [ -n "$OLD_IMAGES" ]; then
  echo "🗑️  Removing old images..."
  docker rmi -f $OLD_IMAGES 2>/dev/null || true
fi

# Check if production.env exists (Linux version)
if [ ! -f "./production.env" ] && [ ! -f "./production.password.env" ]; then
  echo "❌ production.env or production.password.env not found!"
  echo "Create production.env with your database credentials and secrets"
  exit 1
fi

# Use the correct env file
ENV_FILE="./production.env"
if [ -f "./production.password.env" ]; then
    ENV_FILE="./production.password.env"
fi

echo "📄 Using environment file: $ENV_FILE"

# Login to GitHub Container Registry
echo "🔐 Logging into GitHub Container Registry..."
if [ -n "${GITHUB_TOKEN:-}" ]; then
    echo "$GITHUB_TOKEN" | docker login ghcr.io -u USERNAME --password-stdin
else
    echo "⚠️  GITHUB_TOKEN not set. You may need to login manually:"
    echo "docker login ghcr.io"
fi

# Pull and run
echo "📥 Pulling $IMAGE..."
docker pull "$IMAGE"

echo "🚀 Starting container..."
docker run -d --name "$NAME" \
  --restart unless-stopped \
  --env-file "$ENV_FILE" \
  --label "com.gitgurusl.app=request-backend" \
  -p "0.0.0.0:$PORT:3001" \
  "$IMAGE"

# Health check
echo "🏥 Checking container health..."
sleep 5

if docker ps --filter "name=$NAME" --filter "status=running" | grep -q "$NAME"; then
    echo "✅ Container is running successfully!"
    echo "📡 Backend available at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):$PORT"
    
    # Test health endpoint
    for i in {1..10}; do
        if curl -s -f "http://localhost:$PORT/health" >/dev/null 2>&1; then
            echo "✅ Health check passed!"
            break
        elif [ $i -eq 10 ]; then
            echo "⚠️  Health check endpoint not responding, but container is running"
        else
            echo "⏳ Waiting for service to start... ($i/10)"
            sleep 2
        fi
    done
else
    echo "❌ Container failed to start!"
    echo "Checking logs..."
    docker logs "$NAME" 2>/dev/null || true
    exit 1
fi

echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Useful commands:"
echo "  Check logs:    docker logs $NAME"
echo "  Stop service:  docker stop $NAME"
echo "  Restart:       docker restart $NAME"
echo "  Shell access:  docker exec -it $NAME /bin/sh"
