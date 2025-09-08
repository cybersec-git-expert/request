#!/bin/bash

# Package backend for AWS deployment
echo "📦 Packaging Request Backend for AWS deployment..."

# Create deployment directory
mkdir -p deploy-package

# Copy essential files
echo "📁 Copying backend files..."
cp -r *.js deploy-package/
cp package.json deploy-package/
cp -r routes/ deploy-package/ 2>/dev/null || echo "No routes directory"
cp -r controllers/ deploy-package/ 2>/dev/null || echo "No controllers directory"
cp -r middleware/ deploy-package/ 2>/dev/null || echo "No middleware directory"
cp -r models/ deploy-package/ 2>/dev/null || echo "No models directory"
cp -r config/ deploy-package/ 2>/dev/null || echo "No config directory"
cp -r utils/ deploy-package/ 2>/dev/null || echo "No utils directory"
cp -r uploads/ deploy-package/ 2>/dev/null || echo "No uploads directory"

# Copy deployment files
cp deploy/*.env deploy-package/
cp deploy/*.sh deploy-package/
cp deploy/*.md deploy-package/

# Create archive
echo "🗜️ Creating deployment archive..."
cd deploy-package
tar -czf ../request-backend-deploy.tar.gz .
cd ..

echo "✅ Deployment package created: request-backend-deploy.tar.gz"
echo "📤 Upload this file to your EC2 instance using:"
echo "   scp -i your-key.pem request-backend-deploy.tar.gz ubuntu@YOUR-EC2-IP:~/"

# Clean up
rm -rf deploy-package

echo "🚀 Ready for AWS deployment!"
