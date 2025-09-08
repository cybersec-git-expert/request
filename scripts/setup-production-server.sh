#!/bin/bash
set -euo pipefail

# Production Server Setup Script for Request Backend
# This script prepares the production server for Docker-based deployments

echo "🚀 Request Backend Production Server Setup"
echo "==========================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Docker if not present
install_docker() {
    if command_exists docker; then
        echo "✅ Docker is already installed"
        docker --version
        return
    fi
    
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "✅ Docker installed successfully"
}

# Function to install required tools
install_tools() {
    echo "🔧 Installing required tools..."
    
    # Update package list
    sudo apt-get update -y
    
    # Install essential tools
    sudo apt-get install -y \
        curl \
        wget \
        unzip \
        jq \
        htop \
        nginx
    
    echo "✅ Tools installed successfully"
}

# Function to setup application directories
setup_directories() {
    echo "📁 Setting up application directories..."
    
    # Create main application directory
    sudo mkdir -p /opt/request-backend/{data,logs,config}
    
    # Set proper permissions
    sudo chown -R $USER:$USER /opt/request-backend
    chmod 755 /opt/request-backend
    
    echo "✅ Directories created successfully"
}

# Function to create production environment file template
create_env_template() {
    echo "📝 Creating production environment template..."
    
    cat > /opt/request-backend/production.env.template << 'EOF'
# Request Backend Production Environment Configuration
# Copy this file to production.env and fill in the actual values

# Database Configuration
DATABASE_URL=postgresql://username:password@localhost:5432/request_db
DB_HOST=localhost
DB_PORT=5432
DB_NAME=request_db
DB_USER=your_username
DB_PASSWORD=your_password

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-here
JWT_EXPIRES_IN=7d

# AWS Configuration (prefer IAM Role in production; leave keys unset)
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=
AWS_REGION=us-east-1
AWS_S3_BUCKET=your-s3-bucket-name

# Email Configuration (SES)
SES_FROM_EMAIL=noreply@yourdomain.com
SES_FROM_NAME=Request App

# SMS Configuration
SMS_PROVIDER=your-sms-provider
SMS_API_KEY=your-sms-api-key

# Application Configuration
NODE_ENV=production
PORT=3001
FRONTEND_URL=https://yourdomain.com
API_URL=https://api.yourdomain.com

# Security
BCRYPT_ROUNDS=12
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# File Upload
MAX_FILE_SIZE=10485760
UPLOAD_PATH=/app/uploads

# Logging
LOG_LEVEL=info
LOG_FILE=/opt/request-backend/logs/app.log
EOF

    echo "✅ Environment template created at /opt/request-backend/production.env.template"
    echo "⚠️  Please copy this to production.env and fill in your actual values!"
}

# Function to setup Nginx configuration
setup_nginx() {
    echo "🌐 Setting up Nginx reverse proxy..."
    
    cat > /tmp/request-backend-nginx.conf << 'EOF'
server {
    listen 80;
    server_name api.yourdomain.com;  # Replace with your domain
    
    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.yourdomain.com;  # Replace with your domain
    
    # SSL Configuration (you need to obtain certificates)
    # ssl_certificate /path/to/your/certificate.crt;
    # ssl_certificate_key /path/to/your/private.key;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    # Gzip compression
    gzip on;
    gzip_types text/plain application/json application/javascript text/css;
    
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint (direct access)
    location /health {
        proxy_pass http://127.0.0.1:3001/health;
        access_log off;
    }
    
    # Liveness endpoint (no DB)
    location /live {
        proxy_pass http://127.0.0.1:3001/live;
        access_log off;
    }
    
    # Readiness endpoint (DB connectivity)
    location /ready {
        proxy_pass http://127.0.0.1:3001/ready;
        access_log off;
    }
}
EOF

    sudo mv /tmp/request-backend-nginx.conf /etc/nginx/sites-available/request-backend
    
    # Enable the site (but don't restart nginx yet)
    sudo ln -sf /etc/nginx/sites-available/request-backend /etc/nginx/sites-enabled/
    
    echo "✅ Nginx configuration created"
    echo "⚠️  Please update the server_name and SSL certificates before enabling!"
}

# Function to create deployment script
create_deployment_script() {
    echo "📜 Creating local deployment script..."
    
    cat > /opt/request-backend/deploy.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Local deployment script for Request Backend
# Usage: ./deploy.sh [image-tag]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_TAG="${1:-latest}"
CONTAINER_NAME="request-backend-container"
NETWORK_NAME="request-net"
PORT="3001"
IMAGE="ghcr.io/gitgurusl/request-backend:${IMAGE_TAG}"

echo "🚀 Deploying Request Backend"
echo "Image: $IMAGE"
echo "Container: $CONTAINER_NAME"

# Check if production.env exists
if [ ! -f "$SCRIPT_DIR/production.env" ]; then
    echo "❌ Error: production.env file not found!"
    echo "Please copy production.env.template to production.env and configure it."
    exit 1
fi

# Create network if needed
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
    echo "📡 Creating Docker network: $NETWORK_NAME"
    docker network create "$NETWORK_NAME"
fi

# Stop existing container
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "🛑 Stopping existing container..."
    docker stop "$CONTAINER_NAME" || true
    docker rm "$CONTAINER_NAME" || true
fi

# Pull latest image
echo "📥 Pulling image: $IMAGE"
docker pull "$IMAGE"

# Start new container
echo "🚀 Starting new container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --restart always \
    --network "$NETWORK_NAME" \
    -p 127.0.0.1:3001:3001 \
    --env-file "$SCRIPT_DIR/production.env" \
    -v "$SCRIPT_DIR/data:/app/uploads" \
    -v "$SCRIPT_DIR/logs:/app/logs" \
    "$IMAGE"

# Wait for readiness (fallback to health)
echo "🔍 Waiting for service readiness..."
for i in {1..30}; do
    if curl -fsS http://localhost:3001/ready >/dev/null 2>&1 || \
       curl -fsS http://localhost:3001/health >/dev/null 2>&1; then
        echo "✅ Service is ready!"
        break
    fi
    echo "⏳ Waiting... ($i/30)"
    sleep 2
done

if ! curl -fsS http://localhost:3001/ready >/dev/null 2>&1 && \
   ! curl -fsS http://localhost:3001/health >/dev/null 2>&1; then
    echo "❌ Service health check failed!"
    echo "Container logs:"
    docker logs --tail=50 "$CONTAINER_NAME"
    exit 1
fi

echo "🎉 Deployment completed successfully!"
docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
EOF

    chmod +x /opt/request-backend/deploy.sh
    echo "✅ Deployment script created at /opt/request-backend/deploy.sh"
}

# Function to create systemd service for container monitoring
create_systemd_service() {
    echo "🔧 Creating systemd service for container monitoring..."
    
    cat > /tmp/request-backend.service << 'EOF'
[Unit]
Description=Request Backend Container
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/opt/request-backend/deploy.sh latest
ExecStop=/usr/bin/docker stop request-backend-container
User=ubuntu
Group=ubuntu

[Install]
WantedBy=multi-user.target
EOF

    sudo mv /tmp/request-backend.service /etc/systemd/system/
    sudo systemctl daemon-reload
    
    echo "✅ Systemd service created"
    echo "Enable with: sudo systemctl enable request-backend"
}

# Main execution
main() {
    echo "Starting production server setup..."
    
    install_docker
    install_tools
    setup_directories
    create_env_template
    setup_nginx
    create_deployment_script
    create_systemd_service
    
    echo ""
    echo "🎉 Production server setup completed!"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Copy production.env.template to production.env and configure it"
    echo "2. Update Nginx configuration with your domain and SSL certificates"
    echo "3. Test deployment: /opt/request-backend/deploy.sh"
    echo "4. Enable systemd service: sudo systemctl enable request-backend"
    echo "5. Configure firewall to allow ports 80, 443, and 22"
    echo ""
    echo "🔧 Manual Configuration Required:"
    echo "- Database setup and connection"
    echo "- SSL certificates for HTTPS"
    echo "- DNS records pointing to this server"
    echo "- GitHub Container Registry access (for private images)"
    echo ""
}

# Run main function
main "$@"
