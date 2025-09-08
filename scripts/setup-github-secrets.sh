#!/bin/bash

# GitHub Secrets Setup Script for Request Backend CI/CD
# This script helps you set up the necessary GitHub secrets for the CI/CD pipeline

echo "🚀 Request Backend CI/CD Setup Assistant"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Repository information
REPO_OWNER="cybersec-git-expert"
REPO_NAME="request"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"

echo -e "${BLUE}Repository: ${REPO_URL}${NC}"
echo ""

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}Warning: GitHub CLI (gh) is not installed.${NC}"
    echo "You'll need to add secrets manually through the GitHub web interface."
    echo ""
    echo "Manual setup steps:"
    echo "1. Go to: ${REPO_URL}/settings/secrets/actions"
    echo "2. Click 'New repository secret'"
    echo "3. Add the secrets listed below"
    echo ""
else
    echo -e "${GREEN}✅ GitHub CLI detected${NC}"
    echo ""
fi

# Function to display secret setup instructions
display_secret_setup() {
    local secret_name=$1
    local description=$2
    local instructions=$3
    
    echo -e "${YELLOW}Secret: ${secret_name}${NC}"
    echo -e "${BLUE}Description: ${description}${NC}"
    echo -e "Instructions: ${instructions}"
    echo ""
}

echo -e "${GREEN}Required GitHub Secrets:${NC}"
echo "========================"
echo ""

# EC2 SSH Key setup
display_secret_setup "EC2_SSH_KEY" \
    "Private key for SSH access to EC2 instance" \
    "Copy the entire content of your AWS-EC2.pem file (including BEGIN/END lines)"

echo -e "${BLUE}Example EC2_SSH_KEY content:${NC}"
echo "-----BEGIN RSA PRIVATE KEY-----"
echo "MIIEpAIBAAKCAQEA7Gj2..."
echo "[Your private key content]"
echo "...3yX4wJ8="
echo "-----END RSA PRIVATE KEY-----"
echo ""

# Check if user wants to add secrets using GitHub CLI
if command -v gh &> /dev/null; then
    echo -e "${GREEN}GitHub CLI Setup Options:${NC}"
    echo "========================="
    echo ""
    
    read -p "Do you want to add the EC2_SSH_KEY secret using GitHub CLI? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${YELLOW}Please provide the path to your AWS EC2 private key file:${NC}"
        read -p "Private key file path (e.g., /path/to/AWS-EC2.pem): " KEY_PATH
        
        if [[ -f "$KEY_PATH" ]]; then
            echo ""
            echo -e "${BLUE}Adding EC2_SSH_KEY secret...${NC}"
            
            if gh secret set EC2_SSH_KEY --repo "${REPO_OWNER}/${REPO_NAME}" < "$KEY_PATH"; then
                echo -e "${GREEN}✅ EC2_SSH_KEY secret added successfully!${NC}"
            else
                echo -e "${RED}❌ Failed to add EC2_SSH_KEY secret${NC}"
                echo "Please add it manually through the GitHub web interface."
            fi
        else
            echo -e "${RED}❌ File not found: ${KEY_PATH}${NC}"
            echo "Please add the secret manually."
        fi
    fi
fi

echo ""
echo -e "${GREEN}Setup Verification:${NC}"
echo "==================="
echo ""
echo "After adding the secrets, verify your setup:"
echo ""
echo "1. Check secrets are added:"
echo "   ${REPO_URL}/settings/secrets/actions"
echo ""
echo "2. Test the CI/CD pipeline:"
echo "   - Make a change to backend code"
echo "   - Push to master branch"
echo "   - Check Actions tab: ${REPO_URL}/actions"
echo ""
echo "3. Verify deployment:"
echo "   - Production: http://54.144.9.226:3001/health"
echo "   - Staging: http://54.144.9.226:3002/health"
echo ""

echo -e "${GREEN}Next Steps:${NC}"
echo "==========="
echo ""
echo "1. Set up EC2 environment files:"
echo "   - SSH to EC2: ssh -i 'AWS-EC2.pem' ubuntu@54.144.9.226"
echo "   - Copy production.env.template to /home/ubuntu/production.env"
echo "   - Copy staging.env.template to /home/ubuntu/staging.env"
echo "   - Update with your actual values"
echo ""
echo "2. Test the deployment:"
echo "   - Push changes to master branch"
echo "   - Monitor GitHub Actions"
echo "   - Verify application health"
echo ""

echo -e "${BLUE}For detailed setup instructions, see: CICD_SETUP_GUIDE.md${NC}"
echo ""
echo -e "${GREEN}🎉 Setup assistant completed!${NC}"
