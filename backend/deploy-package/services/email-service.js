const { SESClient, SendEmailCommand } = require('@aws-sdk/client-ses');
const database = require('./database');

class EmailService {
  constructor() {
    // Configure AWS SES v3
    const region = process.env.AWS_REGION || process.env.AWS_SES_REGION || 'us-east-1';
    this.ses = new SESClient({
      region,
      // Use default credential provider chain (IAM role preferred)
    });
    
    this.fromEmail = process.env.AWS_SES_FROM_EMAIL || 'noreply@requestmarketplace.com';
    this.fromName = process.env.AWS_SES_FROM_NAME || 'Request Marketplace';
    
    console.log('📧 EmailService initialized with SES');
  }

  /**
   * Generate a 6-digit OTP
   */
  generateOTP() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  /**
   * Send OTP via AWS SES
   * @param {string} email - Recipient email address
   * @param {string} otp - OTP code to send
   * @param {string} purpose - Purpose of verification (business, driver, etc.)
   * @returns {Promise<string>} - OTP ID for verification
   */
  async sendOTP(email, otp, purpose = 'verification') {
    try {
      console.log(`📧 Sending OTP to ${email} for ${purpose}`);
      
      const subject = 'Verify Your Email - Request Marketplace';
      const htmlBody = this.generateEmailTemplate(otp, purpose);
      const textBody = `Your verification code is: ${otp}\n\nThis code will expire in 10 minutes.\n\nIf you didn't request this, please ignore this email.`;
      
      const params = {
        Source: `${this.fromName} <${this.fromEmail}>`,
        Destination: {
          ToAddresses: [email]
        },
        Message: {
          Subject: {
            Data: subject,
            Charset: 'UTF-8'
          },
          Body: {
            Html: {
              Data: htmlBody,
              Charset: 'UTF-8'
            },
            Text: {
              Data: textBody,
              Charset: 'UTF-8'
            }
          }
        }
      };
      
      const result = await this.ses.send(new SendEmailCommand(params));
      console.log(`✅ Email sent successfully: ${result.MessageId}`);
      
      // Store OTP in database
      const otpId = await this.storeOTP(email, otp, purpose);
      
      return otpId;
    } catch (error) {
      console.error('❌ Failed to send email:', error);
      throw new Error(`Failed to send verification email: ${error.message}`);
    }
  }

  /**
   * Store OTP in database
   */
  async storeOTP(email, otp, purpose) {
    try {
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes
      
      const query = `
        INSERT INTO email_otp_verifications 
        (email, otp, purpose, expires_at, created_at, verified, attempts) 
        VALUES ($1, $2, $3, $4, NOW(), false, 0)
        RETURNING id
      `;
      
      const result = await database.query(query, [email, otp, purpose, expiresAt]);
      const otpId = result.rows[0].id;
      
      console.log(`📧 OTP stored with ID: ${otpId}`);
      return otpId;
    } catch (error) {
      console.error('❌ Failed to store OTP:', error);
      throw error;
    }
  }

  /**
   * Verify OTP
   * @param {string} email - Email address
   * @param {string} otp - OTP to verify
   * @param {string} otpId - OTP ID from send operation
   * @returns {Promise<boolean>} - Verification result
   */
  async verifyOTP(email, otp, otpId) {
    try {
      console.log(`🔍 Verifying OTP for email: ${email}, OTP: ${otp}, ID: ${otpId}`);
      
      // Get OTP record
      const query = `
        SELECT * FROM email_otp_verifications 
        WHERE id = $1 AND email = $2 AND verified = false 
        AND expires_at > NOW()
      `;
      
      const result = await database.query(query, [otpId, email]);
      
      if (result.rows.length === 0) {
        console.log('❌ OTP not found or expired');
        return { success: false, message: 'OTP not found or expired' };
      }
      
      const otpRecord = result.rows[0];
      
      // Check attempts limit
      if (otpRecord.attempts >= 3) {
        console.log('❌ Too many attempts');
        return { success: false, message: 'Too many verification attempts' };
      }
      
      // Increment attempts
      await database.query(
        'UPDATE email_otp_verifications SET attempts = attempts + 1 WHERE id = $1',
        [otpId]
      );
      
      // Check OTP
      if (otpRecord.otp !== otp) {
        console.log('❌ Invalid OTP');
        return { success: false, message: 'Invalid OTP' };
      }
      
      // Mark as verified
      await database.query(
        'UPDATE email_otp_verifications SET verified = true, verified_at = NOW() WHERE id = $1',
        [otpId]
      );
      
      console.log('✅ OTP verified successfully');
      return { success: true, message: 'Email verified successfully' };
      
    } catch (error) {
      console.error('❌ Failed to verify OTP:', error);
      throw error;
    }
  }

  /**
   * Generate HTML email template
   */
  generateEmailTemplate(otp, purpose) {
    return `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Email Verification - Request Marketplace</title>
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f5f5f5;">
    <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; margin-top: 20px;">
        <div style="text-align: center; margin-bottom: 30px;">
            <h1 style="color: #2563eb; margin: 0;">Request Marketplace</h1>
            <p style="color: #64748b; margin: 5px 0;">Email Verification</p>
        </div>
        
        <div style="background-color: #f8fafc; padding: 20px; border-radius: 6px; margin-bottom: 20px;">
            <h2 style="color: #1e293b; margin: 0 0 15px 0;">Verify Your Email Address</h2>
            <p style="color: #475569; margin: 0 0 15px 0;">
                Please use the following verification code to complete your ${purpose} verification:
            </p>
            
            <div style="background-color: white; padding: 20px; border-radius: 6px; text-align: center; border: 2px dashed #e2e8f0;">
                <div style="font-size: 32px; font-weight: bold; color: #2563eb; letter-spacing: 8px; font-family: monospace;">
                    ${otp}
                </div>
            </div>
        </div>
        
        <div style="color: #64748b; font-size: 14px; line-height: 1.5;">
            <p><strong>Important:</strong></p>
            <ul style="margin: 10px 0; padding-left: 20px;">
                <li>This code will expire in <strong>10 minutes</strong></li>
                <li>Don't share this code with anyone</li>
                <li>If you didn't request this verification, please ignore this email</li>
            </ul>
        </div>
        
        <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #e2e8f0; text-align: center; color: #64748b; font-size: 12px;">
            <p>© 2025 Request Marketplace. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
    `;
  }

  /**
   * Add email to user_email_addresses table after verification
   */
  async addVerifiedEmail(userId, email, purpose = 'verification', verificationMethod = 'otp') {
    try {
      const query = `
        INSERT INTO user_email_addresses 
        (user_id, email_address, is_verified, verified_at, purpose, verification_method)
        VALUES ($1, $2, true, NOW(), $3, $4)
        ON CONFLICT (user_id, email_address) 
        DO UPDATE SET 
          is_verified = true, 
          verified_at = NOW(), 
          verification_method = $4
        RETURNING *
      `;
      
      const result = await database.query(query, [userId, email, purpose, verificationMethod]);
      console.log(`✅ Added verified email to user_email_addresses: ${email}`);
      
      return result.rows[0];
    } catch (error) {
      console.error('❌ Failed to add verified email:', error);
      throw error;
    }
  }
}

module.exports = new EmailService();
