#!/bin/bash

# Admin Panel S3 Deployment Script
echo "🎛️ Deploying Admin Panel to S3..."

# Build the React admin panel
cd /path/to/admin-react
npm install
npm run build

# Configure AWS CLI (make sure it's installed and configured)
# aws configure

# Create S3 bucket for static hosting
aws s3 mb s3://request-admin-panel --region us-east-1

# Enable static website hosting
aws s3 website s3://request-admin-panel \
  --index-document index.html \
  --error-document index.html

# Set bucket policy for public read access
cat > bucket-policy.json << 'EOL'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::request-admin-panel/*"
    }
  ]
}
EOL

aws s3api put-bucket-policy \
  --bucket request-admin-panel \
  --policy file://bucket-policy.json

# Upload build files to S3
aws s3 sync dist/ s3://request-admin-panel --delete

# Set up CloudFront distribution (optional, for better performance)
aws cloudfront create-distribution \
  --distribution-config file://cloudfront-config.json

echo "✅ Admin panel deployed!"
echo "🌐 Access URL: http://request-admin-panel.s3-website-us-east-1.amazonaws.com"
echo "📋 For custom domain, set up Route 53 and CloudFront"
