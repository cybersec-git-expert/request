#!/bin/bash
# Quick EC2 Setup Script for Request Backend
# Run this on your EC2 instance to prepare for deployment

echo "🚀 Setting up EC2 for Request Backend deployment..."

# Update system
echo "📦 Updating system packages..."
sudo apt update

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    sudo apt install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    echo "✅ Docker installed. You may need to logout and login again."
else
    echo "✅ Docker already installed"
fi

# Install Git if not present
if ! command -v git &> /dev/null; then
    echo "📋 Installing Git..."
    sudo apt install -y git
else
    echo "✅ Git already installed"
fi

# Install curl if not present
if ! command -v curl &> /dev/null; then
    echo "🌐 Installing curl..."
    sudo apt install -y curl
else
    echo "✅ curl already installed"
fi

# Create app directory
echo "📁 Setting up application directory..."
mkdir -p ~/request-app
cd ~/request-app

# Clone repository if not exists
if [ ! -d "request" ]; then
    echo "📥 Cloning repository..."
    git clone https://github.com/cybersec-git-expert/request.git
else
    echo "📝 Updating repository..."
    cd request
    git pull origin master
    cd ..
fi

cd request

# Make scripts executable
chmod +x deploy-ec2.sh
if [ -f "run-database-cleanup.sh" ]; then
    chmod +x run-database-cleanup.sh
fi

# Create production.env from template
if [ ! -f "production.env" ] && [ -f "production.password.env" ]; then
    echo "📄 Creating production.env from template..."
    cp production.password.env production.env
    echo "⚠️  IMPORTANT: Edit production.env with your actual values!"
    echo "   nano production.env"
fi

echo ""
echo "🎉 EC2 setup completed!"
echo ""
echo "📋 Next steps:"
echo "1. Edit your environment file:     nano production.env"
echo "2. Login to GitHub registry:       echo 'YOUR_TOKEN' | docker login ghcr.io -u USERNAME --password-stdin"
echo "3. Deploy the application:         ./deploy-ec2.sh"
echo ""
echo "🔗 Useful commands:"
echo "  Check Docker status:  sudo systemctl status docker"
echo "  View this script:     cat setup-ec2.sh"
echo "  Deploy app:          ./deploy-ec2.sh"
echo ""

# Show current directory contents
echo "📁 Current directory contents:"
ls -la
