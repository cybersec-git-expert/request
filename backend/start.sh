#!/bin/bash

echo "🚀 Starting Request Marketplace Backend API"
echo "==========================================="

# Check if .env.rds exists in parent directory
if [ ! -f "../.env.rds" ]; then
    echo "❌ Error: .env.rds file not found in parent directory"
    echo "Please create .env.rds with your database configuration"
    echo "Use .env.rds.template as a reference"
    exit 1
fi

# Copy database config to backend
cp ../.env.rds ./.env.rds
echo "✅ Copied database configuration"

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "⚠️  .env file not found, copying from template"
    cp .env.template .env
    echo "📝 Please edit .env file with your configuration"
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

echo ""
echo "🔗 Starting server..."
echo "Health check will be available at: http://localhost:3001/health"
echo ""

# Start the server
npm run dev
