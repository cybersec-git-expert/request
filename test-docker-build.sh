#!/bin/bash
# Local Docker Build Test Script
# Tests the Docker build process before CI/CD deployment

set -e

echo "🔨 Testing Docker build for Request Backend..."

# Change to backend directory
cd backend

# Build the Docker image
echo "📦 Building Docker image..."
docker build -t request-backend:test .

echo "✅ Docker build successful!"

# Test the container
echo "🧪 Starting test container..."
docker run -d --name request-backend-test -p 3002:3001 request-backend:test

# Wait for container to start
echo "⏳ Waiting for container to start..."
sleep 5

# Test health endpoint
echo "🏥 Testing health endpoint..."
if curl -s -f "http://localhost:3002/health" >/dev/null 2>&1; then
    echo "✅ Health check passed!"
else
    echo "❌ Health check failed!"
    echo "Container logs:"
    docker logs request-backend-test
fi

# Cleanup
echo "🧹 Cleaning up test container..."
docker stop request-backend-test
docker rm request-backend-test

echo "🎉 Local Docker test completed!"
echo ""
echo "📋 Next steps:"
echo "1. If tests passed, your Docker setup is ready for CI/CD"
echo "2. Configure GitHub secrets (see CI_CD_SETUP_GUIDE.md)"
echo "3. Push to master branch to trigger automatic deployment"
