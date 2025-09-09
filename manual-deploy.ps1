# Manual deployment script for when SSH authentication fails
# This script provides alternative deployment methods

Write-Host "🔍 Manual Deployment Script" -ForegroundColor Green
Write-Host "Current situation: SSH authentication failing to EC2 instance" -ForegroundColor Yellow

Write-Host "`n📋 Available options:" -ForegroundColor Cyan
Write-Host "1. Check AWS EC2 Console for correct key pair name"
Write-Host "2. Use AWS Systems Manager Session Manager (if enabled)"
Write-Host "3. Create new EC2 instance with our existing key"
Write-Host "4. Test different key pairs"

Write-Host "`n🔑 Available SSH keys in current directory:" -ForegroundColor Cyan
Get-ChildItem "*.pem" | ForEach-Object {
    Write-Host "  - $($_.Name)" -ForegroundColor White
}

Write-Host "`n📝 Steps to resolve:" -ForegroundColor Yellow
Write-Host "1. Go to AWS EC2 Console > Instances > Select instance 44.211.63.136"
Write-Host "2. Check the 'Key pair name' in the instance details"
Write-Host "3. Either:"
Write-Host "   a) Use the matching .pem file if you have it"
Write-Host "   b) Create a new instance with request-backend-key"
Write-Host "   c) Use AWS Systems Manager Session Manager"

Write-Host "`n🚀 Quick test commands:" -ForegroundColor Green
Write-Host "Test SSH with different keys:"
$keys = Get-ChildItem "*.pem"
foreach ($key in $keys) {
    Write-Host "ssh -i `"$($key.Name)`" -o ConnectTimeout=5 ec2-user@44.211.63.136 'echo success'" -ForegroundColor Gray
}

Write-Host "`n💡 Alternative deployment via AWS CLI (if configured):" -ForegroundColor Blue
Write-Host "aws ssm start-session --target INSTANCE-ID"
