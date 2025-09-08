const express = require('express');
const authService = require('../services/auth');
const dbService = require('../services/database');

const router = express.Router();

/**
 * @route POST /api/auth/register
 * @desc Register a new user
 */
router.post('/register', async (req, res) => {
  try {
    const { email, phone, password, displayName } = req.body;

    // Validate input
    if (!email && !phone) {
      return res.status(400).json({ 
        error: 'Either email or phone is required' 
      });
    }

    const result = await authService.register({
      email,
      phone,
      password,
      displayName
    });

    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      ...result
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * @route POST /api/auth/login
 * @desc Login user
 */
router.post('/login', async (req, res) => {
  try {
    const { email, phone, password } = req.body;

    const result = await authService.login({
      email,
      phone,
      password
    });

    res.json({
      success: true,
      message: 'Login successful',
      data: result
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(401).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * @route POST /api/auth/refresh
 * @desc Rotate refresh token and issue new access & refresh tokens
 */
router.post('/refresh', async (req, res) => {
  try {
    const { userId, refreshToken } = req.body;
    if (!userId || !refreshToken) {
      return res.status(400).json({ success: false, error: 'userId and refreshToken required' });
    }
    // Verify user exists
    const users = await authService.sanitizeUser(await require('../services/database').findById('users', userId));
    if (!users) return res.status(401).json({ success: false, error: 'Invalid user' });
    const newRawRefresh = await authService.verifyAndRotateRefreshToken(userId, refreshToken);
    const newAccess = authService.generateToken({ id: userId, email: users.email, phone: users.phone, role: users.role, email_verified: users.email_verified, phone_verified: users.phone_verified });
    res.json({ success: true, message: 'Token refreshed', data: { token: newAccess, refreshToken: newRawRefresh } });
  } catch (error) {
    console.error('Refresh error:', error);
    res.status(401).json({ success: false, error: error.message });
  }
});

/**
 * @route POST /api/auth/send-email-otp
 * @desc Send OTP to email
 */
router.post('/send-email-otp', async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ 
        error: 'Email is required' 
      });
    }

    const result = await authService.sendEmailOTP(email);
    res.json({ success: true, message: result.message, channel: result.channel, email: result.email });
  } catch (error) {
    console.error('Send email OTP error:', error);
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * @route POST /api/auth/send-phone-otp
 * @desc Send OTP to phone
 */
router.post('/send-phone-otp', async (req, res) => {
  try {
    const { phone, countryCode } = req.body;

    if (!phone) {
      return res.status(400).json({ 
        error: 'Phone number is required' 
      });
    }

    const result = await authService.sendPhoneOTP(phone, countryCode);

    res.json({
      success: true,
      message: result.message,
      channel: result.channel,
      sms: result.sms
    });
  } catch (error) {
    console.error('Send phone OTP error:', error);
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * @route POST /api/auth/verify-email-otp
 * @desc Verify email OTP
 */
router.post('/verify-email-otp', async (req, res) => {
  try {
    const { email, otp } = req.body;

    if (!email || !otp) {
      return res.status(400).json({ 
        error: 'Email and OTP are required' 
      });
    }

    const result = await authService.verifyEmailOTP(email, otp);
    res.json({
      success: true,
      message: result.message,
      data: {
        verified: result.verified,
        user: result.user,
        token: result.token,
        refreshToken: result.refreshToken
      }
    });
  } catch (error) {
    console.error('Verify email OTP error:', error);
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * @route POST /api/auth/verify-phone-otp
 * @desc Verify phone OTP
 */
router.post('/verify-phone-otp', async (req, res) => {
  try {
    const { phone, otp } = req.body;

    if (!phone || !otp) {
      return res.status(400).json({ 
        error: 'Phone and OTP are required' 
      });
    }

    const result = await authService.verifyPhoneOTP(phone, otp);
    res.json({
      success: true,
      message: result.message,
      data: {
        verified: result.verified,
        user: result.user,
        token: result.token,
        refreshToken: result.refreshToken
      }
    });
  } catch (error) {
    console.error('Verify phone OTP error:', error);
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * @route GET /api/auth/profile
 * @desc Get user profile
 */
router.get('/profile', authService.authMiddleware(), async (req, res) => {
  try {
    res.json({
      success: true,
      data: { ...req.user, permissions: req.user.permissions || {} }
    });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * @route PUT /api/auth/profile
 * @desc Update user profile
 */
router.put('/profile', authService.authMiddleware(), async (req, res) => {
  try {
    const { displayName, photoUrl, firstName, lastName, first_name, last_name, password } = req.body;

    // Support both camelCase and snake_case field names
    const updateData = {
      displayName,
      photoUrl,
      firstName: firstName || first_name,
      lastName: lastName || last_name,
      password
    };

    // Remove undefined values
    Object.keys(updateData).forEach(key => {
      if (updateData[key] === undefined) {
        delete updateData[key];
      }
    });

    const updatedUser = await authService.updateProfile(req.user.id, updateData);

    res.json({
      success: true,
      message: 'Profile updated successfully',
      user: updatedUser
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * @route POST /api/auth/change-password
 * @desc Change user password
 */
router.post('/change-password', authService.authMiddleware(), async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!newPassword) {
      return res.status(400).json({ 
        error: 'New password is required' 
      });
    }

    const result = await authService.changePassword(
      req.user.id, 
      currentPassword, 
      newPassword
    );

    res.json({
      success: true,
      message: result.message
    });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * @route POST /api/auth/reset-password
 * @desc Reset password using OTP verification
 */
router.post('/reset-password', async (req, res) => {
  try {
    const { emailOrPhone, otp, newPassword, isEmail } = req.body;

    if (!emailOrPhone || !otp || !newPassword) {
      return res.status(400).json({ 
        error: 'Email/phone, OTP, and new password are required' 
      });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ 
        error: 'New password must be at least 6 characters' 
      });
    }

    // Find user by email or phone first
    const user = await dbService.query(
      isEmail 
        ? 'SELECT * FROM users WHERE email = $1' 
        : 'SELECT * FROM users WHERE phone = $1',
      [emailOrPhone]
    );

    if (user.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    const userId = user.rows[0].id;

    // Verify OTP without consuming it
    if (isEmail) {
      // Check email OTP validity
      const otpResult = await dbService.query(`
                SELECT * FROM email_otp_verifications 
                WHERE email = $1 AND otp = $2 AND expires_at > NOW() AND verified = false
            `, [emailOrPhone, otp]);

      if (otpResult.rows.length === 0) {
        return res.status(400).json({
          success: false,
          error: 'Invalid or expired OTP'
        });
      }

      // Update password and mark OTP as verified in transaction
      await dbService.query('BEGIN');
      try {
        const hashedPassword = await authService.hashPassword(newPassword);
                
        // Update user password
        await dbService.update('users', userId, {
          password_hash: hashedPassword
        });

        // Mark OTP as verified
        await dbService.query(`
                    UPDATE email_otp_verifications 
                    SET verified = true, verified_at = NOW() 
                    WHERE email = $1 AND otp = $2
                `, [emailOrPhone, otp]);

        await dbService.query('COMMIT');
      } catch (error) {
        await dbService.query('ROLLBACK');
        throw error;
      }
    } else {
      // For phone OTP, use SMS service verification
      const smsService = require('../services/smsService');
      const verificationResult = await smsService.verifyOTP(emailOrPhone, otp);
            
      if (!verificationResult.verified) {
        return res.status(400).json({
          success: false,
          error: 'Invalid or expired OTP'
        });
      }

      const hashedPassword = await authService.hashPassword(newPassword);
            
      // Update user password
      await dbService.update('users', userId, {
        password_hash: hashedPassword
      });
    }

    res.json({
      success: true,
      message: 'Password reset successfully'
    });
  } catch (error) {
    console.error('Reset password error:', error);
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * @route POST /api/auth/logout
 * @desc Logout user (client-side token removal)
 */
router.post('/logout', authService.authMiddleware(), async (req, res) => {
  try {
    // In JWT, logout is handled client-side by removing the token
    // For enhanced security, you could implement a token blacklist
        
    res.json({
      success: true,
      message: 'Logged out successfully'
    });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * @route POST /api/auth/dev/seed-admin
 * @desc Development helper: create a default super admin user if none exists
 * Body (optional): { email, password, displayName }
 * Safeguards: Disabled in production (NODE_ENV==='production')
 */
router.post('/dev/seed-admin', async (req, res) => {
  try {
    if (process.env.NODE_ENV === 'production') {
      return res.status(403).json({ success: false, error: 'Not available in production' });
    }
    const {
      email = 'admin@example.com',
      password = 'Admin123!',
      displayName = 'Super Admin'
    } = req.body || {};

    // Check existing super admin
    const existingAdmins = await dbService.query('SELECT id, email FROM users WHERE role = \'super_admin\' LIMIT 1');
    if (existingAdmins.rows.length > 0) {
      return res.json({ success: true, message: 'Super admin already exists', data: existingAdmins.rows[0] });
    }

    // Check existing by email
    const existingByEmail = await dbService.findMany('users', { email });
    if (existingByEmail.length > 0) {
      // Promote existing user
      const promoted = await dbService.update('users', existingByEmail[0].id, {
        role: 'super_admin',
        email_verified: true,
        is_active: true,
        updated_at: new Date().toISOString()
      });
      const token = authService.generateToken(promoted);
      const refreshToken = await authService.generateAndStoreRefreshToken(promoted.id);
      return res.json({ success: true, message: 'Existing user promoted to super_admin', data: { user: authService.sanitizeUser(promoted), token, refreshToken } });
    }

    // Create fresh user (manual to ensure role & verification flags)
    const passwordHash = password ? await authService.hashPassword(password) : null;
    const newUser = await dbService.insert('users', {
      email,
      phone: null,
      password_hash: passwordHash,
      display_name: displayName,
      first_name: displayName.split(' ')[0],
      last_name: displayName.split(' ').slice(1).join(' ') || null,
      role: 'super_admin',
      is_active: true,
      email_verified: true,
      phone_verified: false,
      country_code: 'LK',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    });
    const token = authService.generateToken(newUser);
    const refreshToken = await authService.generateAndStoreRefreshToken(newUser.id);
    res.status(201).json({ success: true, message: 'Super admin user created', data: { user: authService.sanitizeUser(newUser), token, refreshToken, credentials: { email, password } } });
  } catch (error) {
    console.error('Seed admin error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route POST /api/auth/profile/send-phone-otp
 * @desc Send OTP to verify phone number for profile update
 */
router.post('/profile/send-phone-otp', authService.authMiddleware(), async (req, res) => {
  try {
    const { phoneNumber, countryCode } = req.body;
    const userId = req.user.id;

    if (!phoneNumber) {
      return res.status(400).json({ 
        success: false,
        error: 'Phone number is required' 
      });
    }

    // Normalize phone number
    function normalizePhoneNumber(phone) {
      if (!phone) return null;
      const normalized = phone.replace(/[^\d+]/g, '');
      if (normalized.startsWith('+94')) return normalized;
      if (normalized.startsWith('94') && normalized.length === 11) return '+' + normalized;
      if (normalized.startsWith('0') && normalized.length === 10) return '+94' + normalized.substring(1);
      if (normalized.length === 9) return '+94' + normalized;
      return normalized;
    }

    const normalizedPhone = normalizePhoneNumber(phoneNumber);
    console.log(`📱 Profile: Sending OTP for phone update - Phone: ${phoneNumber} → ${normalizedPhone}, User: ${userId}`);

    // Use country-specific SMS service
    const SMSService = require('../services/smsService');
    const smsService = new SMSService();
        
    // Auto-detect country if not provided
    const detectedCountry = countryCode || smsService.detectCountry(normalizedPhone);
    console.log(`🌍 Profile: Using country: ${detectedCountry} for SMS delivery`);

    // Send OTP using country-specific SMS provider
    const result = await smsService.sendOTP(normalizedPhone, detectedCountry);

    // Store additional metadata for profile phone verification
    await dbService.query(
      `UPDATE phone_otp_verifications 
             SET user_id = $1, verification_type = 'profile_phone_update'
             WHERE phone = $2 AND otp_id = $3`,
      [userId, normalizedPhone, result.otpId]
    );

    console.log(`✅ OTP sent via ${result.provider} for profile phone update: ${normalizedPhone}`);

    res.json({
      success: true,
      message: 'OTP sent successfully for phone verification',
      phoneNumber: normalizedPhone,
      otpId: result.otpId,
      provider: result.provider,
      countryCode: detectedCountry,
      expiresIn: result.expiresIn
    });
  } catch (error) {
    console.error('Error sending profile phone OTP:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * @route POST /api/auth/profile/verify-phone-otp
 * @desc Verify OTP and update user's phone number
 */
router.post('/profile/verify-phone-otp', authService.authMiddleware(), async (req, res) => {
  try {
    const { phoneNumber, otp, otpId } = req.body;
    const userId = req.user.id;

    if (!phoneNumber || !otp) {
      return res.status(400).json({
        success: false,
        error: 'Phone number and OTP are required'
      });
    }

    // Normalize phone number
    function normalizePhoneNumber(phone) {
      if (!phone) return null;
      const normalized = phone.replace(/[^\d+]/g, '');
      if (normalized.startsWith('+94')) return normalized;
      if (normalized.startsWith('94') && normalized.length === 11) return '+' + normalized;
      if (normalized.startsWith('0') && normalized.length === 10) return '+94' + normalized.substring(1);
      if (normalized.length === 9) return '+94' + normalized;
      return normalized;
    }

    const normalizedPhone = normalizePhoneNumber(phoneNumber);
    console.log(`🔍 Profile: Verifying OTP for phone update - Phone: ${phoneNumber} → ${normalizedPhone}, OTP: ${otp}, User: ${userId}`);

    // Use country-specific SMS service for verification
    const SMSService = require('../services/smsService');
    const smsService = new SMSService();
        
    const verificationResult = await smsService.verifyOTP(normalizedPhone, otp, otpId);

    if (verificationResult.verified) {
      // Update user's phone number and mark as verified
      await dbService.query(
        `UPDATE users 
                 SET phone = $1, phone_verified = true, updated_at = NOW() 
                 WHERE id = $2`,
        [normalizedPhone, userId]
      );

      // Add or update phone in user_phone_numbers table (align with schema: label, is_verified)
      await dbService.query(
        `INSERT INTO user_phone_numbers (user_id, phone_number, label, is_verified, verified_at, purpose, created_at)
                 VALUES ($1, $2, 'personal', true, NOW(), 'profile_update', NOW())
                 ON CONFLICT (user_id, phone_number) DO UPDATE SET
                 is_verified = true, verified_at = NOW(), label = 'personal', purpose = 'profile_update'`,
        [userId, normalizedPhone]
      );

      // Get updated user data
      const updatedUserResult = await dbService.query('SELECT * FROM users WHERE id = $1', [userId]);
      const updatedUser = updatedUserResult.rows[0];

      console.log(`✅ Phone verified and updated for user profile: ${normalizedPhone}`);

      res.json({
        success: true,
        message: 'Phone number verified and updated successfully',
        phoneNumber: normalizedPhone,
        verified: true,
        provider: verificationResult.provider,
        user: authService.sanitizeUser(updatedUser)
      });
    } else {
      res.status(400).json({
        success: false,
        error: verificationResult.message || 'Invalid or expired OTP'
      });
    }
  } catch (error) {
    console.error('Error verifying profile phone OTP:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
