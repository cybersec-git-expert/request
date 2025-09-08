const { SESClient, SendEmailCommand } = require('@aws-sdk/client-ses');

// Configure AWS SES v3
const SES_REGION = process.env.AWS_REGION || process.env.AWS_SES_REGION || 'us-east-1';
const ses = new SESClient({
  region: SES_REGION,
  // Use default credential provider chain (IAM role preferred)
});

class EmailService {
  constructor() {
    this.fromEmail = process.env.SES_FROM_EMAIL || 'info@alphabet.lk';
    this.fromName = process.env.SES_FROM_NAME || 'Request';
        
    // Debug: Log AWS SES configuration (without showing secret key)
    console.log('📧 AWS SES initialized:', {
      region: process.env.AWS_REGION || 'us-east-1',
      usingStaticKeys: Boolean(process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY),
      fromEmail: this.fromEmail,
      fromName: this.fromName,
    });
  }

  /**
     * Send OTP email using AWS SES
     */
  async sendOTP(email, otp, purpose = 'registration') {
    console.log(`📧 Attempting to send OTP email to: ${email}`);
        
    const subject = this.getOTPSubject(purpose);
    const htmlBody = this.getOTPTemplate(otp, purpose);
    const textBody = this.getOTPTextTemplate(otp, purpose);

    const params = {
      Destination: {
        ToAddresses: [email]
      },
      Message: {
        Body: {
          Html: {
            Charset: 'UTF-8',
            Data: htmlBody
          },
          Text: {
            Charset: 'UTF-8',
            Data: textBody
          }
        },
        Subject: {
          Charset: 'UTF-8',
          Data: subject
        }
      },
      Source: `${this.fromName} <${this.fromEmail}>`
    };

    console.log('📤 Sending email via AWS SES...');
        
    try {
      const result = await ses.send(new SendEmailCommand(params));
      console.log(`✅ Email sent successfully to ${email} - MessageId: ${result.MessageId}`);
      return {
        success: true,
        messageId: result.MessageId
      };
    } catch (error) {
      console.error(`❌ Failed to send email to ${email}:`);
      console.error('Error details:', error.message);
      console.error('Error code:', error.code);
      console.error('Status code:', error.statusCode);
            
      // Check if it's an unverified email error
      if (error.code === 'MessageRejected' && error.message.includes('Email address not verified')) {
        console.log(`🔍 Email ${this.fromEmail} is not verified in AWS SES`);
        console.log('   Please verify it at: https://console.aws.amazon.com/ses/');
      }
            
      // Fall back to console logging for development
      if (process.env.NODE_ENV === 'development') {
        console.log(`📧 DEVELOPMENT FALLBACK - OTP for ${email}: ${otp}`);
        console.log('📝 Note: Check AWS SES configuration and email verification status');
        return {
          success: true,
          messageId: 'dev-fallback',
          fallback: true,
          error: error.message
        };
      }
            
      throw error;
    }
  }

  /**
     * Get email subject based on purpose
     */
  getOTPSubject(purpose) {
    const subjects = {
      registration: 'Complete Your Registration - OTP Verification',
      login: 'Login Verification Code',
      password_reset: 'Password Reset Verification Code',
      email_verification: 'Verify Your Email Address'
    };
    return subjects[purpose] || 'Verification Code - Request Marketplace';
  }

  /**
     * Get HTML email template
     */
  getOTPTemplate(otp, purpose) {
    const purposeText = purpose === 'registration' ? 'complete your registration' : 'verify your identity';
        
    return `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Verification Code</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #007bff; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
        .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 5px 5px; }
        .otp-code { font-size: 32px; font-weight: bold; color: #007bff; text-align: center; background: white; padding: 20px; border-radius: 5px; margin: 20px 0; letter-spacing: 5px; }
        .footer { text-align: center; margin-top: 20px; color: #666; font-size: 14px; }
        .warning { background: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Request Marketplace</h1>
        </div>
        <div class="content">
            <h2>Verification Code</h2>
            <p>Hello,</p>
            <p>Use the following verification code to ${purposeText}:</p>
            
            <div class="otp-code">${otp}</div>
            
            <div class="warning">
                <strong>⚠️ Important:</strong>
                <ul>
                    <li>This code will expire in 10 minutes</li>
                    <li>Never share this code with anyone</li>
                    <li>If you didn't request this code, please ignore this email</li>
                </ul>
            </div>
            
            <p>If you have any questions, please contact our support team.</p>
            <p>Best regards,<br>Request Marketplace Team</p>
        </div>
        <div class="footer">
            <p>This is an automated message. Please do not reply to this email.</p>
        </div>
    </div>
</body>
</html>`;
  }

  /**
     * Get plain text email template (fallback)
     */
  getOTPTextTemplate(otp, purpose) {
    const purposeText = purpose === 'registration' ? 'complete your registration' : 'verify your identity';
        
    return `
Request Marketplace - Verification Code

Hello,

Use the following verification code to ${purposeText}: ${otp}

IMPORTANT:
- This code will expire in 10 minutes
- Never share this code with anyone
- If you didn't request this code, please ignore this email

Best regards,
Request Marketplace Team

This is an automated message. Please do not reply to this email.
`;
  }
}

module.exports = new EmailService();
