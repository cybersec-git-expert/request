# OTP Testing Guide (Phone + Email)

This guide helps you validate OTP send/verify flows in local and production environments.

## Phone OTP (Preferred endpoints)

- Send: POST /api/sms/send-otp
- Verify: POST /api/sms/verify-otp

Example (PowerShell):

```powershell
# Send
$body = @{ phoneNumber = "+94771234567"; countryCode = "+94" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:3001/api/sms/send-otp" -Method Post -ContentType 'application/json' -Body $body

# Verify (use otpId returned as otpToken)
$verifyBody = @{ phoneNumber = "+94771234567"; otp = "123456"; otpId = "<paste-otpId>" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:3001/api/sms/verify-otp" -Method Post -ContentType 'application/json' -Body $verifyBody
```

## Legacy/Compatibility

- Send: POST /api/auth/send-otp (body: { emailOrPhone, isEmail, countryCode })
- Verify phone: POST /api/auth/verify-phone-otp

The mobile app maps `otpId` => `otpToken` for compatibility.

## Email OTP

- Send: POST /api/email-verification/send-otp
- Verify: POST /api/email-verification/verify-otp

Example:

```powershell
$body = @{ email = "user@example.com"; purpose = "verification" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:3001/api/email-verification/send-otp" -Method Post -ContentType 'application/json' -Body $body
```

## Common issues

- Phone format must be E.164 (+94xxxxxxxxx). The app now normalizes when possible.
- Missing sms_provider_configs for your country causes send to fail. Configure via Admin or insert a row.
- Verify requires the correct otpId/otpToken that was returned on send.
