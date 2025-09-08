#!/bin/bash

# Enhanced S3 Admin Panel Deployment Script
# Run this script to update the admin panel on AWS S3

set -e

echo "🚀 Updating Request Admin Panel on S3..."

# Configuration
BUCKET_NAME="request-admin-panel"
CLOUDFRONT_DISTRIBUTION_ID=""  # Add your CloudFront ID if you have one
BUILD_DIR="../build"
BACKUP_DIR="../backups"

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup current S3 content (optional)
echo "📦 Creating backup..."
aws s3 sync s3://$BUCKET_NAME $BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S)/ || echo "Backup failed (bucket might not exist yet)"

# Build the admin panel
echo "🔨 Building admin panel..."
cd ..
npm install
npm run build

# Check if build was successful
if [ ! -d "$BUILD_DIR" ]; then
    echo "❌ Build failed - $BUILD_DIR directory not found"
    exit 1
fi

cd deploy

# Upload to S3
echo "📤 Uploading to S3..."
aws s3 sync $BUILD_DIR s3://$BUCKET_NAME --delete --cache-control "public, max-age=31536000" --exclude "*.html" --exclude "service-worker.js"

# Upload HTML files with no cache (for updates)
aws s3 sync $BUILD_DIR s3://$BUCKET_NAME --delete --cache-control "no-cache" --include "*.html" --include "service-worker.js"

# Set proper content types
aws s3 cp s3://$BUCKET_NAME s3://$BUCKET_NAME --recursive --metadata-directive REPLACE --content-type "text/html" --include "*.html"
aws s3 cp s3://$BUCKET_NAME s3://$BUCKET_NAME --recursive --metadata-directive REPLACE --content-type "application/javascript" --include "*.js"
aws s3 cp s3://$BUCKET_NAME s3://$BUCKET_NAME --recursive --metadata-directive REPLACE --content-type "text/css" --include "*.css"

# Configure S3 bucket for website hosting
echo "🔧 Configuring S3 bucket for website hosting..."
aws s3 website s3://$BUCKET_NAME --index-document index.html --error-document index.html

# Invalidate CloudFront (if configured)
if [ ! -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
    echo "🔄 Invalidating CloudFront cache..."
    aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_DISTRIBUTION_ID --paths "/*"
fi

echo "✅ Admin panel update completed!"
echo "🌐 Your admin panel should be available at: http://$BUCKET_NAME.s3-website-us-east-1.amazonaws.com"

# Display bucket policy for reference
echo "📋 If this is the first deployment, apply this bucket policy for public access:"
echo '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::'$BUCKET_NAME'/*"
        }
    ]
}'
