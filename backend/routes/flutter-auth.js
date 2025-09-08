// Add these authentication endpoints to your existing Node.js backend

const express = require('express');
const router = express.Router();
const dbService = require('../services/database'); // Your existing database connection
const emailService = require('../services/email'); // Email service for OTP
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

// JWT Secret (use your existing one or set in environment)
const JWT_SECRET = process.env.JWT_SECRET || 'your-jwt-secret-key';

// 1. Check if user exists (needed for login flow routing)
router.post('/check-user-exists', async (req, res) => {
  try {
    const { emailOrPhone } = req.body;

    if (!emailOrPhone) {
      return res.status(400).json({
        success: false,
        message: 'Email or phone number is required'
      });
    }

    console.log(`🔍 Checking if user exists: ${emailOrPhone}`);

    const result = await dbService.query(
      'SELECT id, email, phone FROM users WHERE (email = $1 OR phone = $1) AND is_active = true',
      [emailOrPhone]
    );

    console.log(`📊 Query result: found ${result.rows.length} users`);
    if (result.rows.length > 0) {
      console.log(`👤 Found user: ${JSON.stringify(result.rows[0])}`);
    }

    res.json({
      success: true,
      exists: result.rows.length > 0,
      message: result.rows.length > 0 ? 'User found' : 'User not found'
    });

  } catch (error) {
    console.error('Check user exists error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// 2. Send OTP (for new user registration)
router.post('/send-otp', async (req, res) => {
  try {
    const { emailOrPhone, isEmail, countryCode } = req.body;

    if (!emailOrPhone) {
      return res.status(400).json({
        success: false,
        message: 'Email or phone number is required'
      });
    }

    // Generate 6-digit OTP
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    
    // Generate secure token for OTP verification
    const otpToken = crypto.randomBytes(32).toString('hex');
    
    // Set expiration time (10 minutes from now)
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    // Store OTP in database
    await dbService.query(
      `INSERT INTO otp_tokens (email_or_phone, otp_code, token_hash, expires_at, purpose)
       VALUES ($1, $2, $3, $4, $5)`,
      [emailOrPhone, otpCode, otpToken, expiresAt, 'registration']
    );

    // Send OTP via email or SMS
    let emailMeta = null;
    if (isEmail) {
      // Send email OTP using AWS SES
      try {
        emailMeta = await emailService.sendOTP(emailOrPhone, otpCode, 'registration');
        console.log(`✅ Email OTP sent to ${emailOrPhone}: ${otpCode}`);
      } catch (error) {
        console.error('❌ Failed to send email OTP:', error.message);
        emailMeta = { success: false, error: error.message };
        // Continue anyway - OTP is still stored in database for verification
      }
    } else {
      // Send SMS OTP using your SMS provider
      console.log(`SMS OTP for ${emailOrPhone}: ${otpCode}`);
      // await sendSMSOTP(emailOrPhone, otpCode, countryCode);
    }

    res.json({
      success: true,
      otpToken: otpToken,
      message: `OTP sent to ${emailOrPhone}`,
      channel: isEmail ? 'email' : 'sms',
      email: isEmail ? {
        messageId: emailMeta?.messageId || null,
        fallback: emailMeta?.fallback || false,
        error: emailMeta?.error || null
      } : undefined
    });

  } catch (error) {
    console.error('Send OTP error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to send OTP'
    });
  }
});

// 3. Verify OTP (for new user registration)
router.post('/verify-otp', async (req, res) => {
  try {
    const { emailOrPhone, otp, otpToken } = req.body;

    if (!emailOrPhone || !otp || !otpToken) {
      return res.status(400).json({
        success: false,
        message: 'Email/phone, OTP, and token are required'
      });
    }

    // Find valid OTP token
    const result = await dbService.query(
      `SELECT * FROM otp_tokens 
       WHERE email_or_phone = $1 AND token_hash = $2 AND used = false AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1`,
      [emailOrPhone, otpToken]
    );

    if (result.rows.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired OTP token'
      });
    }

    const otpRecord = result.rows[0];

    // Verify OTP code
    if (otpRecord.otp_code !== otp) {
      // Increment attempts
      await dbService.query(
        'UPDATE otp_tokens SET attempts = attempts + 1 WHERE id = $1',
        [otpRecord.id]
      );

      return res.status(400).json({
        success: false,
        message: 'Invalid OTP code'
      });
    }

    // Mark OTP as used
    await dbService.query(
      'UPDATE otp_tokens SET used = true WHERE id = $1',
      [otpRecord.id]
    );

    // Attempt to mark user as verified (legacy enhancement)
    try {
      if (emailOrPhone.includes('@')) {
        await dbService.query(
          'UPDATE users SET email_verified = true, updated_at = NOW() WHERE email = $1',
          [emailOrPhone]
        );
      } else {
        await dbService.query(
          'UPDATE users SET phone_verified = true, updated_at = NOW() WHERE phone = $1',
          [emailOrPhone]
        );
      }
    } catch (e) {
      console.warn('⚠️ Failed to update user verification status (legacy path):', e.message);
    }

    // OTP verified successfully - return success
    res.json({
      success: true,
      verified: true,
      message: 'OTP verified successfully'
    });

  } catch (error) {
    console.error('Verify OTP error:', error);
    res.status(500).json({
      success: false,
      message: 'OTP verification failed'
    });
  }
});

// 4. Update existing login endpoint for Flutter compatibility
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required'
      });
    }

    // Find user by email or phone
    const userResult = await dbService.query(
      'SELECT * FROM users WHERE (email = $1 OR phone = $1) AND is_active = true',
      [email]
    );

    if (userResult.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    const user = userResult.rows[0];

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    // Generate JWT token
    const token = jwt.sign(
      { 
        userId: user.id, 
        email: user.email,
        role: user.role,
        countryCode: user.country_code
      },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    // Remove password from response and ensure no null values
    const { password_hash, ...userWithoutPassword } = user;

    res.json({
      success: true,
      message: 'Login successful',
      token: token,
      user: {
        id: userWithoutPassword.id,
        email: userWithoutPassword.email || '',
        phone: userWithoutPassword.phone || '',
        display_name: userWithoutPassword.display_name || '',
        first_name: userWithoutPassword.first_name || '',
        last_name: userWithoutPassword.last_name || '',
        role: userWithoutPassword.role || 'user',
        country_code: userWithoutPassword.country_code || '',
        email_verified: userWithoutPassword.email_verified || false,
        phone_verified: userWithoutPassword.phone_verified || false,
        is_active: userWithoutPassword.is_active || true,
        photo_url: userWithoutPassword.photo_url || '',
        created_at: userWithoutPassword.created_at,
        updated_at: userWithoutPassword.updated_at,
        permissions: userWithoutPassword.permissions || {}
      }
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Login failed'
    });
  }
});

// 5. Update existing register endpoint for Flutter compatibility
router.post('/register', async (req, res) => {
  try {
    let { email, password, display_name, phone, first_name, last_name } = req.body;

    // Normalize names (frontend may send first_name & last_name instead of display_name)
    if (!display_name) {
      const fn = (first_name || '').trim();
      const ln = (last_name || '').trim();
      if (fn || ln) {
        display_name = `${fn} ${ln}`.trim();
      }
    }

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required'
      });
    }

    // Check if user already exists
    const existingUser = await dbService.query(
      'SELECT id FROM users WHERE email = $1 OR phone = $2',
      [email, phone]
    );

    if (existingUser.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'User already exists with this email or phone'
      });
    }

    // Hash password
    const saltRounds = 12;
    const hashedPassword = await bcrypt.hash(password, saltRounds);

    // Create user
    const userResult = await dbService.query(
      `INSERT INTO users (email, password_hash, display_name, first_name, last_name, phone, country_code, email_verified, phone_verified)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING id, email, phone, display_name, first_name, last_name, email_verified, phone_verified, is_active, role, country_code, photo_url, created_at, updated_at`,
      [
        email, 
        hashedPassword, 
        display_name || '', 
        first_name || (display_name ? display_name.split(' ')[0] : '') || '', 
        last_name || (display_name ? display_name.split(' ').slice(1).join(' ') : '') || '', 
        phone || '', 
        'LK', 
        false, 
        false
      ]
    );

    const newUser = userResult.rows[0];

    // Generate JWT token
    const token = jwt.sign(
      { 
        userId: newUser.id, 
        email: newUser.email,
        role: newUser.role,
        countryCode: newUser.country_code
      },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    // Generate refresh token (simple random string for now)
    const refreshToken = crypto.randomBytes(48).toString('hex');

    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      token: token,
      refreshToken: refreshToken,
      user: {
        id: newUser.id,
        email: newUser.email || '',
        phone: newUser.phone || '',
        display_name: newUser.display_name || '',
        first_name: newUser.first_name || '',
        last_name: newUser.last_name || '',
        role: newUser.role || 'user',
        country_code: newUser.country_code || '',
        email_verified: newUser.email_verified || false,
        phone_verified: newUser.phone_verified || false,
        is_active: newUser.is_active || true,
        photo_url: newUser.photo_url || '',
        created_at: newUser.created_at,
        updated_at: newUser.updated_at
      }
    });

  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({
      success: false,
      message: 'Registration failed'
    });
  }
});

// 5. Register new user with complete profile (for profile completion flow)
router.post('/register-complete', async (req, res) => {
  try {
    const { emailOrPhone, firstName, lastName, displayName, password, isEmail, countryCode } = req.body;

    console.log(`👤 Registration request for: ${emailOrPhone}`);
    console.log(`👤 isEmail flag: ${isEmail}`);
    console.log(`👤 firstName: ${firstName}, lastName: ${lastName}`);
    console.log(`👤 displayName: ${displayName}`);
    console.log(`👤 countryCode: ${countryCode}`);

    if (!emailOrPhone || !firstName || !lastName || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email/phone, first name, last name, and password are required'
      });
    }

    console.log(`👤 Creating new user account: ${emailOrPhone}`);

    // Check if user already exists
    const existingUserResult = await dbService.query(
      'SELECT * FROM users WHERE (email = $1 OR phone = $1)',
      [emailOrPhone]
    );

    let user;
    let isNewUser = false;

    if (existingUserResult.rows.length > 0) {
      // User already exists, log them in
      user = existingUserResult.rows[0];
      console.log(`👤 User already exists, logging in: ${user.id}`);
    } else {
      // Create new user
      isNewUser = true;
      
      // Hash password
      const saltRounds = 12;
      const hashedPassword = await bcrypt.hash(password, saltRounds);

      // Create new user account (without profile_completed column)
      const userData = {
        email: isEmail ? emailOrPhone : null,
        phone: !isEmail ? emailOrPhone : null,
        first_name: firstName,
        last_name: lastName,
        display_name: displayName,
        password_hash: hashedPassword,
        email_verified: isEmail,
        phone_verified: !isEmail,
        is_active: true,
        role: 'user',
        country_code: countryCode || 'LK' // Default to LK if not provided
      };

      const createUserResult = await dbService.query(
        `INSERT INTO users (
          id, email, phone, first_name, last_name, display_name, password_hash,
          email_verified, phone_verified, is_active, role, country_code,
          created_at, updated_at
        ) VALUES (
          gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW(), NOW()
        ) RETURNING *`,
        [
          userData.email, userData.phone, userData.first_name, userData.last_name,
          userData.display_name, userData.password_hash, userData.email_verified,
          userData.phone_verified, userData.is_active, userData.role, userData.country_code
        ]
      );
      
      user = createUserResult.rows[0];
      console.log(`✅ User registration successful: ${user.id}`);
    }

    // Generate JWT tokens (for both new and existing users)
    const tokenPayload = {
      userId: user.id,
      id: user.id,
      email: user.email,
      phone: user.phone,
      role: user.role
    };

    const token = jwt.sign(tokenPayload, JWT_SECRET, { expiresIn: '7d' });
    const refreshToken = jwt.sign(tokenPayload, JWT_SECRET, { expiresIn: '30d' });

    // Store refresh token in database
    await dbService.query(
      `INSERT INTO user_refresh_tokens (user_id, token_hash, expires_at, created_at)
       VALUES ($1, $2, NOW() + INTERVAL '30 days', NOW())`,
      [user.id, refreshToken]
    );

    res.json({
      success: true,
      message: isNewUser ? 'User registered successfully' : 'User logged in successfully',
      data: {
        user: {
          id: user.id,
          email: user.email,
          phone: user.phone,
          first_name: user.first_name,
          last_name: user.last_name,
          display_name: user.display_name,
          email_verified: user.email_verified,
          phone_verified: user.phone_verified,
          role: user.role
        },
        token,
        refreshToken
      }
    });

  } catch (error) {
    console.error('Register complete user error:', error);
    res.status(500).json({
      success: false,
      message: 'Registration failed'
    });
  }
});

module.exports = router;
