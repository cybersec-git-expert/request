# AWS SES Configuration for Firebase Functions

## Overview
This document provides step-by-step instructions to configure AWS SES (Simple Email Service) with Firebase Functions for sending professional OTP emails in your request marketplace application.

## Prerequisites
- AWS SES account activated
- Firebase Functions project setup
- Domain verification completed in AWS SES (for production)

## Configuration Steps

### 1. AWS SES Setup

#### Create AWS Access Keys
1. Go to AWS IAM Console
2. Create a new user for SES access
3. Attach the policy: `AmazonSESFullAccess`
4. Generate Access Key ID and Secret Access Key

#### Verify Email Addresses/Domains
1. Go to AWS SES Console
2. Navigate to "Verified identities"
3. Add and verify your sender email address
4. For production: verify your domain

### 2. Firebase Functions Environment Configuration

Set the AWS SES credentials in Firebase Functions environment:

```bash
cd /home/cyberexpert/Dev/request-marketplace/functions

# Set AWS SES credentials
firebase functions:config:set aws.access_key_id="YOUR_ACCESS_KEY_ID"
firebase functions:config:set aws.secret_access_key="YOUR_SECRET_ACCESS_KEY"
firebase functions:config:set aws.region="us-east-1"
firebase functions:config:set aws.ses_from_email="noreply@yourdomain.com"
firebase functions:config:set aws.ses_from_name="Request Marketplace"

# Deploy to apply configuration
firebase deploy --only functions
```

### 3. Environment Variables Reference

The emailService.js uses these environment variables:

- `functions.config().aws.access_key_id` - AWS Access Key ID
- `functions.config().aws.secret_access_key` - AWS Secret Access Key  
- `functions.config().aws.region` - AWS region (default: us-east-1)
- `functions.config().aws.ses_from_email` - Sender email address
- `functions.config().aws.ses_from_name` - Sender name

### 4. Local Development Configuration

For local testing, create a `.env` file in the functions directory:

```env
AWS_ACCESS_KEY_ID=your_access_key_id
AWS_SECRET_ACCESS_KEY=your_secret_access_key
AWS_REGION=us-east-1
SES_FROM_EMAIL=noreply@yourdomain.com
SES_FROM_NAME=Request Marketplace
```

### 5. Email Templates Included

The system includes professional HTML email templates for:

1. **Registration OTP**
   - Welcome message with OTP code
   - Company branding
   - Security information

2. **Password Reset OTP**
   - Professional reset notification
   - OTP code with expiration
   - Security warnings

3. **Login Verification OTP**
   - Login attempt notification
   - Verification code
   - Security alerts

### 6. Cost Optimization

AWS SES pricing (as of 2024):
- First 62,000 emails per month: FREE
- Additional emails: $0.10 per 1,000 emails
- No monthly minimum fees

### 7. Production Considerations

#### Security
- Use least privilege IAM policies
- Rotate access keys regularly
- Monitor SES sending quotas

#### Monitoring
- Set up CloudWatch alarms for bounce rates
- Monitor SES reputation
- Track email delivery metrics

#### Compliance
- Include unsubscribe links for marketing emails
- Comply with CAN-SPAM and GDPR
- Handle bounces and complaints

### 8. Testing the Integration

After configuration, test with:

```javascript
// In Firebase Functions console or local emulator
const { sendRegistrationOTP } = require('./unifiedAuthService');

// Test email OTP
sendRegistrationOTP('test@example.com', 'Email')
  .then(result => console.log('Test successful:', result))
  .catch(error => console.error('Test failed:', error));
```

### 9. Troubleshooting

#### Common Issues

1. **Authentication Failed**
   - Check AWS credentials are correct
   - Verify IAM permissions include SES access

2. **Email Not Sending**
   - Verify sender email in AWS SES
   - Check AWS SES sending limits
   - Verify recipient email (for sandbox mode)

3. **Templates Not Loading**
   - Check HTML template syntax
   - Verify CSS is inline (email clients)

#### Debug Mode

Enable debug logging in emailService.js:

```javascript
// Add to emailService.js for debugging
console.log('AWS SES Configuration:', {
  region: functions.config().aws.region,
  fromEmail: functions.config().aws.ses_from_email,
  fromName: functions.config().aws.ses_from_name
});
```

### 10. Migration from Development to Production

1. Move from AWS SES Sandbox to Production
2. Verify domain ownership
3. Set up DKIM authentication
4. Configure SPF and DMARC records
5. Monitor reputation metrics

## Next Steps

1. Configure AWS SES credentials in Firebase Functions
2. Test email delivery with development addresses
3. Verify HTML email templates render correctly
4. Monitor delivery metrics and bounce rates
5. Move to production when ready

## Support

For issues with this configuration:
1. Check AWS SES documentation
2. Review Firebase Functions logs
3. Test with AWS SES console directly
4. Monitor CloudWatch logs for detailed errors
