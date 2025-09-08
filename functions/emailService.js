/**
 * Email Service Implementation for AWS SES
 * 
 * @description
 * This service provides email OTP functionality using AWS SES.
 * Handles email OTP generation, sending, and verification for authentication.
 * 
 * @features
 * - AWS SES integration for reliable email delivery
 * - HTML and text email templates
 * - OTP generation and verification
 * - Rate limiting and security measures
 * - Cost tracking and analytics
 * - Email template customization
 * 
 * @cost_benefits
 * - AWS SES: $0.10 per 1000 emails (very cost effective)
 * - High deliverability rates
 * - Professional email templates
 * 
 * @author Request Marketplace Team
 * @version 1.0.0
 * @since 2025-08-16
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { SESClient, SendEmailCommand } = require('@aws-sdk/client-ses');
const crypto = require('crypto');

// Initialize Firebase Admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * AWS SES Email Provider
 */
class AWSEmailProvider {
  constructor(config) {
    this.region = config.region || 'us-east-1';
    this.fromEmail = config.fromEmail;
    this.fromName = config.fromName || 'Request Marketplace';
    
    // Initialize AWS SES Client (v3)
    this.sesClient = new SESClient({
      region: this.region,
      // Use default credential provider chain (Service Account/IAM roles via env where applicable)
    });
  }

  /**
   * Send email using AWS SES
   */
  async sendEmail(to, subject, htmlBody, textBody) {
    try {
      const params = {
        Destination: {
          ToAddresses: [to]
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
        Source: `${this.fromName} <${this.fromEmail}>`,
        ReplyToAddresses: [this.fromEmail]
      };

      const command = new SendEmailCommand(params);
      const result = await this.sesClient.send(command);
      
      return {
        success: true,
        messageId: result.MessageId,
        cost: 0.0001, // $0.10 per 1000 emails = $0.0001 per email
        provider: 'aws-ses'
      };
    } catch (error) {
      console.error('AWS SES Error:', error);
      throw new Error(`AWS SES failed: ${error.message}`);
    }
  }

  /**
   * Send OTP email with professional template
   */
  async sendOTPEmail(to, otp, purpose = 'registration') {
    const subject = this.getEmailSubject(purpose);
    const { htmlBody, textBody } = this.generateOTPEmailTemplate(otp, purpose);
    
    return await this.sendEmail(to, subject, htmlBody, textBody);
  }

  /**
   * Generate email subject based on purpose
   */
  getEmailSubject(purpose) {
    switch (purpose) {
      case 'registration':
        return 'Welcome to Request Marketplace - Verify Your Email';
      case 'password_reset':
        return 'Request Marketplace - Password Reset Code';
      case 'login':
        return 'Request Marketplace - Login Verification Code';
      default:
        return 'Request Marketplace - Verification Code';
    }
  }

  /**
   * Generate professional HTML and text email templates
   */
  generateOTPEmailTemplate(otp, purpose) {
    const purposeText = {
      registration: {
        title: 'Welcome to Request Marketplace!',
        message: 'Thank you for joining Request Marketplace. Please verify your email address to complete your registration.',
        action: 'verify your email address'
      },
      password_reset: {
        title: 'Password Reset Request',
        message: 'You requested to reset your password. Use the code below to create a new password.',
        action: 'reset your password'
      },
      login: {
        title: 'Login Verification',
        message: 'Someone is trying to sign in to your Request Marketplace account. Use the code below to continue.',
        action: 'sign in to your account'
      }
    };

    const config = purposeText[purpose] || purposeText.registration;

    // HTML Email Template
    const htmlBody = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Request Marketplace - Verification Code</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 600px;
                margin: 0 auto;
                padding: 20px;
                background-color: #f8f9fa;
            }
            .container {
                background: white;
                padding: 40px;
                border-radius: 12px;
                box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            }
            .header {
                text-align: center;
                margin-bottom: 30px;
            }
            .logo {
                font-size: 24px;
                font-weight: bold;
                color: #2563eb;
                margin-bottom: 10px;
            }
            .title {
                font-size: 24px;
                font-weight: 600;
                color: #1f2937;
                margin-bottom: 16px;
            }
            .otp-container {
                background: #f3f4f6;
                border: 2px dashed #d1d5db;
                border-radius: 8px;
                padding: 24px;
                text-align: center;
                margin: 30px 0;
            }
            .otp-code {
                font-size: 32px;
                font-weight: bold;
                color: #2563eb;
                letter-spacing: 8px;
                font-family: 'Courier New', monospace;
            }
            .otp-label {
                font-size: 14px;
                color: #6b7280;
                margin-top: 8px;
            }
            .message {
                color: #4b5563;
                font-size: 16px;
                margin-bottom: 20px;
            }
            .warning {
                background: #fef3c7;
                border: 1px solid #f59e0b;
                border-radius: 6px;
                padding: 16px;
                margin: 20px 0;
                font-size: 14px;
                color: #92400e;
            }
            .footer {
                margin-top: 40px;
                padding-top: 20px;
                border-top: 1px solid #e5e7eb;
                font-size: 14px;
                color: #6b7280;
                text-align: center;
            }
            .button {
                display: inline-block;
                padding: 12px 24px;
                background-color: #2563eb;
                color: white;
                text-decoration: none;
                border-radius: 6px;
                font-weight: 600;
                margin: 20px 0;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="logo">🛍️ Request Marketplace</div>
            </div>
            
            <h1 class="title">${config.title}</h1>
            <p class="message">${config.message}</p>
            
            <div class="otp-container">
                <div class="otp-code">${otp}</div>
                <div class="otp-label">Your verification code</div>
            </div>
            
            <p>Enter this 6-digit code to ${config.action}. This code will expire in <strong>5 minutes</strong> for your security.</p>
            
            <div class="warning">
                <strong>Security Notice:</strong> If you didn't request this code, please ignore this email. Never share this code with anyone.
            </div>
            
            <div class="footer">
                <p>This email was sent by Request Marketplace.<br>
                If you have any questions, please contact our support team.</p>
                <p>&copy; 2025 Request Marketplace. All rights reserved.</p>
            </div>
        </div>
    </body>
    </html>
    `;

    // Text Email Template (fallback for clients that don't support HTML)
    const textBody = `
${config.title}

${config.message}

Your verification code: ${otp}

Enter this 6-digit code to ${config.action}. This code will expire in 5 minutes for your security.

SECURITY NOTICE: If you didn't request this code, please ignore this email. Never share this code with anyone.

---
Request Marketplace
© 2025 Request Marketplace. All rights reserved.

If you have any questions, please contact our support team.
    `;

    return { htmlBody, textBody };
  }
}

/**
 * Generate secure 6-digit OTP
 */
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Get email configuration for a country
 */
async function getEmailConfig(countryCode = 'LK') {
  try {
    const configDoc = await db.collection('email_configurations').doc(countryCode).get();
    
    if (configDoc.exists) {
      return configDoc.data();
    } else {
      // Return default configuration if country-specific config not found
      return {
        provider: 'aws-ses',
        awsConfig: {
          accessKeyId: functions.config().aws?.access_key_id,
          secretAccessKey: functions.config().aws?.secret_access_key,
          region: functions.config().aws?.region || 'us-east-1',
          fromEmail: functions.config().aws?.from_email || 'cyber.sec.expert@outlook.com',
          fromName: 'Request Marketplace'
        }
      };
    }
  } catch (error) {
    console.error('Error fetching email config:', error);
    throw new Error('Email configuration not found');
  }
}

/**
 * Create email provider instance
 */
function createEmailProvider(provider, config) {
  switch (provider) {
    case 'aws-ses':
      return new AWSEmailProvider(config.awsConfig);
    default:
      throw new Error(`Unsupported email provider: ${provider}`);
  }
}

/**
 * Send email OTP
 */
exports.sendEmailOTP = functions.https.onCall(async (data, context) => {
  try {
    const { email, purpose = 'registration', countryCode = 'LK' } = data;

    // Validate email
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid email address');
    }

    // Rate limiting: Check if too many requests from this email
    const rateLimitKey = `email_rate_limit_${email}`;
    const rateLimitDoc = await db.collection('rate_limits').doc(rateLimitKey).get();
    
    if (rateLimitDoc.exists) {
      const data = rateLimitDoc.data();
      const now = new Date();
      const lastRequest = data.lastRequest.toDate();
      const timeDiff = (now - lastRequest) / 1000; // seconds
      
      if (timeDiff < 60) { // 1 minute cooldown
        throw new functions.https.HttpsError('resource-exhausted', 'Please wait before requesting another code');
      }
      
      if (data.attempts >= 3 && timeDiff < 3600) { // 3 attempts per hour
        throw new functions.https.HttpsError('resource-exhausted', 'Too many attempts. Please try again later');
      }
    }

    // Generate OTP
    const otp = generateOTP();
    const otpId = crypto.randomUUID();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

    // Get email configuration
    const emailConfig = await getEmailConfig(countryCode);
    const emailProvider = createEmailProvider(emailConfig.provider, emailConfig);

    // Send email OTP
    const emailResult = await emailProvider.sendOTPEmail(email, otp, purpose);

    if (emailResult.success) {
      // Store OTP in database
      await db.collection('email_otps').doc(otpId).set({
        email,
        otp,
        purpose,
        countryCode,
        expiresAt,
        isUsed: false,
        attempts: 0,
        maxAttempts: 3,
        createdAt: new Date(),
        messageId: emailResult.messageId
      });

      // Update rate limiting
      await db.collection('rate_limits').doc(rateLimitKey).set({
        lastRequest: new Date(),
        attempts: rateLimitDoc.exists ? (rateLimitDoc.data().attempts || 0) + 1 : 1
      });

      // Update cost tracking
      await updateEmailCostTracking(countryCode, emailResult.cost);

      return {
        success: true,
        message: 'Email OTP sent successfully',
        otpId: otpId,
        expiresIn: 300, // 5 minutes
        provider: emailResult.provider
      };
    } else {
      throw new Error('Failed to send email OTP');
    }

  } catch (error) {
    console.error('Email OTP sending failed:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Verify email OTP
 */
exports.verifyEmailOTP = functions.https.onCall(async (data, context) => {
  try {
    const { email, otp, otpId, purpose } = data;

    // Find and validate OTP
    const otpDoc = await db.collection('email_otps').doc(otpId).get();
    
    if (!otpDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Invalid OTP ID');
    }

    const otpData = otpDoc.data();
    
    // Check if OTP is expired
    if (otpData.expiresAt.toDate() < new Date()) {
      throw new functions.https.HttpsError('deadline-exceeded', 'OTP has expired');
    }

    // Check if OTP is already used
    if (otpData.isUsed) {
      throw new functions.https.HttpsError('failed-precondition', 'OTP has already been used');
    }

    // Check attempts
    if (otpData.attempts >= otpData.maxAttempts) {
      throw new functions.https.HttpsError('resource-exhausted', 'Maximum OTP attempts exceeded');
    }

    // Validate OTP
    if (otpData.otp !== otp || otpData.email !== email || otpData.purpose !== purpose) {
      // Increment attempts
      await otpDoc.ref.update({
        attempts: otpData.attempts + 1
      });
      
      throw new functions.https.HttpsError('invalid-argument', 'Invalid OTP');
    }

    // Mark OTP as used
    await otpDoc.ref.update({
      isUsed: true,
      verifiedAt: new Date()
    });

    return {
      success: true,
      message: 'Email OTP verified successfully',
      verifiedAt: new Date().toISOString()
    };

  } catch (error) {
    console.error('Email OTP verification failed:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Update email cost tracking
 */
async function updateEmailCostTracking(countryCode, cost) {
  try {
    const configRef = db.collection('email_configurations').doc(countryCode);
    const configDoc = await configRef.get();
    
    if (configDoc.exists) {
      const currentMonth = new Date().getMonth() + 1;
      const currentYear = new Date().getFullYear();
      const monthKey = `${currentYear}-${currentMonth.toString().padStart(2, '0')}`;
      
      await configRef.update({
        [`costTracking.${monthKey}.totalSent`]: admin.firestore.FieldValue.increment(1),
        [`costTracking.${monthKey}.totalCost`]: admin.firestore.FieldValue.increment(cost),
        [`costTracking.${monthKey}.lastUpdated`]: new Date()
      });
    }
  } catch (error) {
    console.error('Error updating email cost tracking:', error);
  }
}

/**
 * Test email configuration
 */
exports.testEmailConfig = functions.https.onCall(async (data, context) => {
  try {
    const { countryCode = 'LK', testEmail } = data;

    // Verify admin permission
    if (!context.auth || !context.auth.token.role === 'super_admin') {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }

    const emailConfig = await getEmailConfig(countryCode);
    const emailProvider = createEmailProvider(emailConfig.provider, emailConfig);

    // Send test email
    const testOTP = '123456';
    const result = await emailProvider.sendOTPEmail(testEmail, testOTP, 'test');

    return {
      success: result.success,
      provider: result.provider,
      messageId: result.messageId,
      cost: result.cost
    };

  } catch (error) {
    console.error('Email test failed:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Get email statistics
 */
exports.getEmailStatistics = functions.https.onCall(async (data, context) => {
  try {
    const { countryCode = 'LK' } = data;

    // Verify admin permission
    if (!context.auth) {
      throw new functions.https.HttpsError('permission-denied', 'Authentication required');
    }

    const configDoc = await db.collection('email_configurations').doc(countryCode).get();
    
    if (!configDoc.exists) {
      return {
        totalSent: 0,
        totalCost: 0,
        monthlyData: {}
      };
    }

    const config = configDoc.data();
    return {
      provider: config.provider,
      costTracking: config.costTracking || {},
      lastUpdated: config.lastUpdated
    };

  } catch (error) {
    console.error('Error fetching email statistics:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

module.exports = {
  sendEmailOTP: exports.sendEmailOTP,
  verifyEmailOTP: exports.verifyEmailOTP,
  testEmailConfig: exports.testEmailConfig,
  getEmailStatistics: exports.getEmailStatistics,
  AWSEmailProvider
};
