# Hutch Mobile SMS Configuration - Quick Setup Script
# This script helps configure Hutch Mobile SMS provider through the admin portal

Write-Host "🚀 Hutch Mobile SMS Configuration Helper" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Yellow

# Configuration Details
$hutchConfig = @{
    "Provider" = "hutch_mobile"
    "DisplayName" = "Hutch Mobile (Sri Lanka)"
    "Country" = "LK"
    "API_URL" = "https://bsms.hutch.lk/api/send"
    "Username" = "rimas@alphabet.lk"
    "Password" = "HT3l0b&LH6819"
    "SenderID" = "ALPHABET"
    "MessageType" = "text"
    "Priority" = 1
    "MaxDailyLimit" = 1000
    "CostPerSMS" = 0.50
    "RetryAttempts" = 3
    "IsActive" = $true
}

Write-Host "📱 Configuration Details:" -ForegroundColor Cyan
foreach ($key in $hutchConfig.Keys) {
    if ($key -eq "Password") {
        Write-Host "   $key`: ********" -ForegroundColor White
    } else {
        Write-Host "   $key`: $($hutchConfig[$key])" -ForegroundColor White
    }
}

Write-Host "`n🌐 Testing API connectivity..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "https://api.alphabet.lk/health" -Method Get
    Write-Host "✅ API Status: $($response.status)" -ForegroundColor Green
} catch {
    Write-Host "❌ API connectivity issue: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n📋 Quick Setup Instructions:" -ForegroundColor Cyan
Write-Host "1. 🌐 Open your browser to: http://localhost:5173/" -ForegroundColor White
Write-Host "2. 🔐 Login with your admin credentials" -ForegroundColor White
Write-Host "3. 🔍 Navigate to 'SMS Configuration' in the sidebar" -ForegroundColor White
Write-Host "4. ➕ Click 'Add New Configuration'" -ForegroundColor White
Write-Host "5. 📋 Fill in the form with these details:" -ForegroundColor White
Write-Host "   • Provider: Hutch Mobile (Sri Lanka)" -ForegroundColor Gray
Write-Host "   • Country: Sri Lanka (LK)" -ForegroundColor Gray
Write-Host "   • API URL: https://bsms.hutch.lk/api/send" -ForegroundColor Gray
Write-Host "   • Username: rimas@alphabet.lk" -ForegroundColor Gray
Write-Host "   • Password: HT3l0b&LH6819" -ForegroundColor Gray
Write-Host "   • Sender ID: ALPHABET" -ForegroundColor Gray
Write-Host "   • Message Type: text" -ForegroundColor Gray
Write-Host "6. 💾 Click 'Save Configuration'" -ForegroundColor White
Write-Host "7. 📤 Test SMS sending with a Sri Lankan number (+94xxxxxxxxx)" -ForegroundColor White

Write-Host "`n🧪 Test Configuration (JSON for API):" -ForegroundColor Yellow
$jsonConfig = @{
    provider = "hutch_mobile"
    country = "LK"
    isActive = $true
    priority = 1
    maxDailyLimit = 1000
    costPerSms = 0.50
    retryAttempts = 3
    hutchMobileConfig = @{
        apiUrl = "https://bsms.hutch.lk/api/send"
        username = "rimas@alphabet.lk"
        password = "HT3l0b&LH6819"
        senderId = "ALPHABET"
        messageType = "text"
    }
} | ConvertTo-Json -Depth 3

Write-Host $jsonConfig -ForegroundColor Gray

Write-Host "`n🔗 Quick Links:" -ForegroundColor Cyan
Write-Host "   • Admin Portal: http://localhost:5173/" -ForegroundColor Blue
Write-Host "   • API Health: https://api.alphabet.lk/health" -ForegroundColor Blue
Write-Host "   • Hutch API: https://bsms.hutch.lk/api/send" -ForegroundColor Blue

Write-Host "`n✅ Setup is ready! Open the admin portal to configure Hutch Mobile SMS." -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Yellow

# Optional: Open admin portal automatically
$openPortal = Read-Host "`n🌐 Open admin portal in browser? (y/n)"
if ($openPortal -eq "y" -or $openPortal -eq "Y") {
    Start-Process "http://localhost:5173/"
    Write-Host "🚀 Admin portal opened in default browser" -ForegroundColor Green
}
