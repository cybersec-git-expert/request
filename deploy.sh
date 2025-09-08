#!/bin/bash
set -euo pipefail

# Simple, robust deployment script for Request backend
# Usage: ./deploy.sh [image-tag]

IMAGE_TAG=${1:-latest}
IMAGE="ghcr.io/gitgurusl/request-backend:$IMAGE_TAG"
NAME="request-backend-container"
PORT=3001

echo "🚀 Deploying $IMAGE"

# Stop and remove old containers
echo "🧹 Cleaning up old containers..."
docker stop $(docker ps -aq --filter "ancestor=ghcr.io/gitgurusl/request-backend" 2>/dev/null) 2>/dev/null || true
docker rm -f $(docker ps -aq --filter "ancestor=ghcr.io/gitgurusl/request-backend" 2>/dev/null) 2>/dev/null || true
docker rm -f "$NAME" request-backend 2>/dev/null || true

# Clean old images (keep latest 3)
OLD_IMAGES=$(docker images ghcr.io/gitgurusl/request-backend --format "{{.ID}}" | tail -n +4)
if [ -n "$OLD_IMAGES" ]; then
  echo "🗑️  Removing old images..."
  docker rmi -f $OLD_IMAGES 2>/dev/null || true
fi

# Ensure production.env exists
if [ ! -f /opt/request-backend/production.env ]; then
  echo "❌ /opt/request-backend/production.env not found!"
  echo "Create it with your database credentials and JWT_SECRET"
  exit 1
fi

# Fix permissions
sudo chmod 644 /opt/request-backend/production.env
sudo chown root:docker /opt/request-backend/production.env 2>/dev/null || sudo chown root:root /opt/request-backend/production.env

# Pull and run
echo "📥 Pulling $IMAGE..."
docker pull "$IMAGE"

echo "🚀 Starting container..."
docker run -d --name "$NAME" \
  --restart unless-stopped \
  --env-file /opt/request-backend/production.env \
  --label "com.gitgurusl.app=request-backend" \
  -p "127.0.0.1:$PORT:3001" \
  "$IMAGE"

# Health check
echo "⏱️  Health check..."
for i in $(seq 1 30); do
  if curl -fsS "http://localhost:$PORT/health" >/dev/null 2>&1; then
    echo "✅ Deployment successful!"
    echo "🔗 API: http://localhost:$PORT"
    echo "🏥 Health: http://localhost:$PORT/health"
    exit 0
  fi
  sleep 2
done

echo "❌ Health check failed!"
docker logs --tail=50 "$NAME"
exit 1
