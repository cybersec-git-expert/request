# GitHub Secrets Setup Script for Request Backend CI/CD (PowerShell)
# This script helps you set up the necessary GitHub secrets for the CI/CD pipeline

Write-Host "🚀 Request Backend CI/CD Setup Assistant" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Repository information
$REPO_OWNER = "cybersec-git-expert"
$REPO_NAME = "request"
$REPO_URL = "https://github.com/$REPO_OWNER/$REPO_NAME"

Write-Host "Repository: $REPO_URL" -ForegroundColor Blue
Write-Host ""

# Check if GitHub CLI is installed
$ghInstalled = Get-Command gh -ErrorAction SilentlyContinue

if (-not $ghInstalled) {
    Write-Host "Warning: GitHub CLI (gh) is not installed." -ForegroundColor Yellow
    Write-Host "You'll need to add secrets manually through the GitHub web interface."
    Write-Host ""
    Write-Host "Manual setup steps:"
    Write-Host "1. Go to: $REPO_URL/settings/secrets/actions"
    Write-Host "2. Click 'New repository secret'"
    Write-Host "3. Add the secrets listed below"
    Write-Host ""
} else {
    Write-Host "✅ GitHub CLI detected" -ForegroundColor Green
    Write-Host ""
}

# Function to display secret setup instructions
function Show-SecretSetup {
    param(
        [string]$SecretName,
        [string]$Description,
        [string]$Instructions
    )
    
    Write-Host "Secret: $SecretName" -ForegroundColor Yellow
    Write-Host "Description: $Description" -ForegroundColor Blue
    Write-Host "Instructions: $Instructions"
    Write-Host ""
}

Write-Host "Required GitHub Secrets:" -ForegroundColor Green
Write-Host "========================"
Write-Host ""

# EC2 SSH Key setup
Show-SecretSetup -SecretName "EC2_SSH_KEY" `
    -Description "Private key for SSH access to EC2 instance" `
    -Instructions "Copy the entire content of your AWS-EC2.pem file (including BEGIN/END lines)"

Write-Host "Example EC2_SSH_KEY content:" -ForegroundColor Blue
Write-Host "-----BEGIN RSA PRIVATE KEY-----"
Write-Host "MIIEpAIBAAKCAQEA7Gj2..."
Write-Host "[Your private key content]"
Write-Host "...3yX4wJ8="
Write-Host "-----END RSA PRIVATE KEY-----"
Write-Host ""

# Check if user wants to add secrets using GitHub CLI
if ($ghInstalled) {
    Write-Host "GitHub CLI Setup Options:" -ForegroundColor Green
    Write-Host "========================="
    Write-Host ""
    
    $response = Read-Host "Do you want to add the EC2_SSH_KEY secret using GitHub CLI? (y/n)"
    
    if ($response -eq "y" -or $response -eq "Y") {
        Write-Host ""
        Write-Host "Please provide the path to your AWS EC2 private key file:" -ForegroundColor Yellow
        $keyPath = Read-Host "Private key file path (e.g., C:\Users\cyber\Downloads\AWS-EC2.pem)"
        
        if (Test-Path $keyPath) {
            Write-Host ""
            Write-Host "Adding EC2_SSH_KEY secret..." -ForegroundColor Blue
            
            try {
                $keyContent = Get-Content $keyPath -Raw
                $keyContent | gh secret set EC2_SSH_KEY --repo "$REPO_OWNER/$REPO_NAME"
                Write-Host "✅ EC2_SSH_KEY secret added successfully!" -ForegroundColor Green
            } catch {
                Write-Host "❌ Failed to add EC2_SSH_KEY secret" -ForegroundColor Red
                Write-Host "Please add it manually through the GitHub web interface."
                Write-Host "Error: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ File not found: $keyPath" -ForegroundColor Red
            Write-Host "Please add the secret manually."
        }
    }
}

Write-Host ""
Write-Host "Setup Verification:" -ForegroundColor Green
Write-Host "==================="
Write-Host ""
Write-Host "After adding the secrets, verify your setup:"
Write-Host ""
Write-Host "1. Check secrets are added:"
Write-Host "   $REPO_URL/settings/secrets/actions"
Write-Host ""
Write-Host "2. Test the CI/CD pipeline:"
Write-Host "   - Make a change to backend code"
Write-Host "   - Push to master branch"
Write-Host "   - Check Actions tab: $REPO_URL/actions"
Write-Host ""
Write-Host "3. Verify deployment:"
Write-Host "   - Production: http://54.144.9.226:3001/health"
Write-Host "   - Staging: http://54.144.9.226:3002/health"
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Green
Write-Host "==========="
Write-Host ""
Write-Host "1. Set up EC2 environment files:"
Write-Host "   - SSH to EC2: ssh -i 'C:\Users\cyber\Downloads\AWS-EC2.pem' ubuntu@54.144.9.226"
Write-Host "   - Copy production.env.template to /home/ubuntu/production.env"
Write-Host "   - Copy staging.env.template to /home/ubuntu/staging.env"
Write-Host "   - Update with your actual values"
Write-Host ""
Write-Host "2. Test the deployment:"
Write-Host "   - Push changes to master branch"
Write-Host "   - Monitor GitHub Actions"
Write-Host "   - Verify application health"
Write-Host ""

Write-Host "For detailed setup instructions, see: CICD_SETUP_GUIDE.md" -ForegroundColor Blue
Write-Host ""
Write-Host "🎉 Setup assistant completed!" -ForegroundColor Green

# Pause to keep window open
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
