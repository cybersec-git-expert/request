# 🚀 Hutch Mobile SMS Integration Setup Guide for AWS EC2

## Overview
This guide will help you set up Hutch Mobile SMS API for Sri Lanka on your AWS EC2 production server at `api.alphabet.lk`.

## Prerequisites
- ✅ AWS EC2 server running at `api.alphabet.lk`
- ✅ Admin portal configured to use production API
- ✅ Database migration applied
- ✅ Hutch Mobile SMS API credentials

## Step 1: Apply Database Migration

SSH into your AWS EC2 server and run:

```bash
# Connect to your EC2 server
ssh -i your-key.pem ubuntu@api.alphabet.lk

# Navigate to the backend directory
cd /path/to/your/backend

# Run the Hutch Mobile migration
node run_hutch_migration.js
```

Expected output:
```
🚀 Running Hutch Mobile configuration migration...
✅ Migration completed successfully!
📱 Hutch Mobile SMS provider support added
✅ hutch_mobile_config column confirmed in database
```

## Step 2: Verify API Configuration

Ensure your production server has the correct environment variables:

```bash
# Check if SERVER_URL is set for image serving
echo $SERVER_URL
# Should show: https://api.alphabet.lk

# Verify the backend is running
curl https://api.alphabet.lk/health
# Should return: {"status":"OK","message":"Server is running"}
```

## Step 3: Configure Hutch Mobile in Admin Portal

1. **Access Admin Portal**: Open your admin portal (make sure it's pointing to `api.alphabet.lk`)

2. **Navigate to SMS Configuration**: 
   - Login as Country Admin for Sri Lanka
   - Go to SMS Configuration module

3. **Configure Hutch Mobile Provider**:
   ```javascript
   // Provider: Hutch Mobile (Sri Lanka)
   {
     "apiUrl": "https://bsms.hutch.lk/api/send",
     "username": "your_hutch_username",
     "password": "your_hutch_password", 
     "senderId": "HUTCH",
     "messageType": "text"
   }
   ```

4. **Test Configuration**:
   - Use the built-in test feature
   - Send a test SMS to your Sri Lankan phone number
   - Verify delivery and cost tracking

## Step 4: Frontend Configuration Verification

Your admin portal should already be configured to use the production API. Verify these files have the correct settings:

### Admin Portal (.env):
```bash
VITE_API_BASE_URL=https://api.alphabet.lk
NODE_ENV=production
```

### Vite Config (vite.config.js):
```javascript
proxy: {
  '/api': {
    target: 'https://api.alphabet.lk',
    changeOrigin: true,
    secure: true
  }
}
```

## Step 5: API Endpoints for Hutch Mobile

The following endpoints are available on your production server:

### SMS Configuration Management:
- **GET** `https://api.alphabet.lk/api/admin/sms-configurations`
- **POST** `https://api.alphabet.lk/api/admin/sms-configurations`
- **PUT** `https://api.alphabet.lk/api/admin/sms-configurations/:id`

### SMS Sending:
- Preferred (current):
  - POST `https://api.alphabet.lk/api/sms/send-otp`
  - POST `https://api.alphabet.lk/api/sms/verify-otp`
- Legacy (still available):
  - POST `https://api.alphabet.lk/api/auth/send-otp`
  - POST `https://api.alphabet.lk/api/auth/verify-phone-otp`

## Step 6: Test the Complete Flow

1. **Test SMS Sending**:
```bash
curl -X POST https://api.alphabet.lk/api/sms/send-otp \
  -H "Content-Type: application/json" \
  -d '{
  "phoneNumber": "+94771234567",
  "countryCode": "+94"
  }'
```

2. **Expected Response**:
```json
{
  "success": true,
  "message": "OTP sent successfully",
  "otpId": "otp_12345",
  "expiresIn": 300,
  "provider": "hutch_mobile"
}
```

## Step 7: Monitor and Verify

1. **Check Database**:
```sql
-- Verify Hutch Mobile configuration is saved
SELECT country_code, active_provider, hutch_mobile_config 
FROM sms_configurations 
WHERE country_code = 'LK';

-- Check OTP records
SELECT phone, provider_used, created_at 
FROM phone_otp_verifications 
ORDER BY created_at DESC 
LIMIT 5;
```

2. **Check Logs**:
```bash
# On your EC2 server, check application logs
pm2 logs backend
# or
tail -f /var/log/your-app.log
```

## Troubleshooting

### Issue 1: Admin Portal Not Connecting to Production API
**Solution**: 
- Verify `.env` file has `VITE_API_BASE_URL=https://api.alphabet.lk`
- Clear browser cache and restart dev server
- Check browser network tab for correct API calls

### Issue 2: Hutch Mobile API Connection Failed
**Solution**:
- Verify Hutch Mobile credentials are correct
- Check if your EC2 server can reach `bsms.hutch.lk`
- Test connectivity: `curl -I https://bsms.hutch.lk/api/login`

### Issue 3: Database Migration Failed
**Solution**:
- Check database connection in production
- Verify PostgreSQL user has ALTER TABLE permissions
- Re-run migration with verbose logging

## Security Notes

1. **API Credentials**: Store Hutch Mobile credentials securely in database
2. **HTTPS**: All communication uses HTTPS (✅ already configured)
3. **Rate Limiting**: Built-in rate limiting prevents abuse
4. **Audit Trail**: All SMS operations are logged with approval history

## Success Indicators

✅ Migration completed without errors
✅ Admin portal connects to `api.alphabet.lk`
✅ Hutch Mobile provider appears in provider list
✅ Test SMS sends successfully
✅ OTP verification works
✅ Cost tracking updates correctly

## Next Steps

1. **Production Testing**: Send test OTPs to real Sri Lankan numbers
2. **Mobile App Integration**: Update mobile app to use production API
3. **Monitoring Setup**: Configure alerts for SMS failures
4. **Cost Optimization**: Monitor and optimize SMS costs

## Support

If you encounter any issues:
1. Check the application logs on EC2
2. Verify database connectivity
3. Test API endpoints manually with curl
4. Contact Hutch Mobile support for API issues

---

**Server**: `api.alphabet.lk`  
**Status**: Production Ready  
**Provider**: Hutch Mobile (Sri Lanka)  
**Cost**: ~$0.008-0.015 per SMS
