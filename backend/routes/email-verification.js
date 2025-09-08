const express = require('express');
const router = express.Router();
const auth = require('../services/auth');
const emailService = require('../services/email-service');
const database = require('../services/database');

/**
 * Send email OTP for verification
 * POST /api/email-verification/send-otp
 */
router.post('/send-otp', auth.authMiddleware(), async (req, res) => {
  try {
    const { email, purpose = 'verification' } = req.body;
    const userId = req.user.userId;

    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Email is required'
      });
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid email format'
      });
    }

    console.log(`📧 Sending OTP to ${email} for user ${userId}, purpose: ${purpose}`);

    // Check if email is already verified
    const verifiedQuery = `
      SELECT * FROM user_email_addresses 
      WHERE user_id = $1 AND email_address = $2 AND is_verified = true
    `;
    const verifiedResult = await database.query(verifiedQuery, [userId, email]);

    if (verifiedResult.rows.length > 0) {
      return res.json({
        success: true,
        message: 'Email is already verified',
        alreadyVerified: true
      });
    }

    // Generate and send OTP
    const otp = emailService.generateOTP();
    const otpId = await emailService.sendOTP(email, otp, purpose);

    res.json({
      success: true,
      message: 'Verification code sent to your email',
      otpId: otpId,
      expiresIn: 600 // 10 minutes in seconds
    });

  } catch (error) {
    console.error('Error sending email OTP:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to send verification code',
      error: error.message
    });
  }
});

/**
 * Verify email OTP
 * POST /api/email-verification/verify-otp
 */
router.post('/verify-otp', auth.authMiddleware(), async (req, res) => {
  try {
    const { email, otp, otpId, purpose = 'verification' } = req.body;
    const userId = req.user.userId;

    if (!email || !otp || !otpId) {
      return res.status(400).json({
        success: false,
        message: 'Email, OTP, and OTP ID are required'
      });
    }

    console.log(`🔍 Verifying OTP for user ${userId}, email: ${email}`);

    // Verify OTP
    const verificationResult = await emailService.verifyOTP(email, otp, otpId);

    if (!verificationResult.success) {
      return res.status(400).json({
        success: false,
        message: verificationResult.message
      });
    }

    // Add email to verified emails list
    await emailService.addVerifiedEmail(userId, email, purpose, 'otp');

    // Update user's email verification status if this is their primary email
    const userQuery = 'SELECT email FROM users WHERE id = $1';
    const userResult = await database.query(userQuery, [userId]);
    
    if (userResult.rows.length > 0 && userResult.rows[0].email === email) {
      await database.query(
        'UPDATE users SET email_verified = true WHERE id = $1',
        [userId]
      );
      console.log(`✅ Updated primary email verification for user ${userId}`);
    }

    res.json({
      success: true,
      message: 'Email verified successfully',
      emailVerified: true,
      verificationSource: 'otp'
    });

  } catch (error) {
    console.error('Error verifying email OTP:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to verify email',
      error: error.message
    });
  }
});

/**
 * Get email verification status
 * GET /api/email-verification/status/:email
 */
router.get('/status/:email', auth.authMiddleware(), async (req, res) => {
  try {
    const { email } = req.params;
    const userId = req.user.userId;

    // Check verification status
    const verifiedQuery = `
      SELECT email_address, is_verified, verified_at, purpose, verification_method
      FROM user_email_addresses 
      WHERE user_id = $1 AND email_address = $2
    `;
    const verifiedResult = await database.query(verifiedQuery, [userId, email]);

    if (verifiedResult.rows.length > 0) {
      const emailRecord = verifiedResult.rows[0];
      return res.json({
        success: true,
        verified: emailRecord.is_verified,
        verifiedAt: emailRecord.verified_at,
        purpose: emailRecord.purpose,
        verificationMethod: emailRecord.verification_method
      });
    }

    // Check if it's the user's primary email
    const userQuery = 'SELECT email, email_verified FROM users WHERE id = $1';
    const userResult = await database.query(userQuery, [userId]);
    
    if (userResult.rows.length > 0 && userResult.rows[0].email === email) {
      return res.json({
        success: true,
        verified: userResult.rows[0].email_verified,
        verificationMethod: 'registration',
        isPrimaryEmail: true
      });
    }

    res.json({
      success: true,
      verified: false,
      message: 'Email not found or not verified'
    });

  } catch (error) {
    console.error('Error checking email verification status:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to check verification status',
      error: error.message
    });
  }
});

/**
 * List all verified emails for user
 * GET /api/email-verification/list
 */
router.get('/list', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.userId;

    // Get verified emails from user_email_addresses
    const emailsQuery = `
      SELECT email_address, verified_at, purpose, verification_method, is_verified
      FROM user_email_addresses 
      WHERE user_id = $1 
      ORDER BY verified_at DESC
    `;
    const emailsResult = await database.query(emailsQuery, [userId]);

    // Get primary email from users table
    const userQuery = 'SELECT email, email_verified FROM users WHERE id = $1';
    const userResult = await database.query(userQuery, [userId]);

    const emails = emailsResult.rows.map(row => ({
      email: row.email_address,
      verified: row.is_verified,
      verifiedAt: row.verified_at,
      purpose: row.purpose,
      verificationMethod: row.verification_method,
      isPrimary: false
    }));

    // Add primary email if it exists and is verified
    if (userResult.rows.length > 0 && userResult.rows[0].email && userResult.rows[0].email_verified) {
      const primaryEmail = userResult.rows[0].email;
      const existsInList = emails.some(e => e.email === primaryEmail);
      
      if (!existsInList) {
        emails.unshift({
          email: primaryEmail,
          verified: true,
          verificationMethod: 'registration',
          purpose: 'primary',
          isPrimary: true
        });
      }
    }

    res.json({
      success: true,
      emails: emails,
      total: emails.length
    });

  } catch (error) {
    console.error('Error listing verified emails:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to list verified emails',
      error: error.message
    });
  }
});

module.exports = router;
