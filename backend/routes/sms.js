const express = require('express');
const router = express.Router();
const smsService = require('../services/smsService');
const database = require('../services/database');
const auth = require('../services/auth');

console.log('📱 SMS routes loaded');

// Helper function to ensure SMS provider table exists
async function ensureProviderTable() {
  try {
    await database.query(`
      CREATE TABLE IF NOT EXISTS sms_provider_configs (
        id SERIAL PRIMARY KEY,
        country_code VARCHAR(5) NOT NULL,
        provider VARCHAR(50) NOT NULL,
        config JSONB DEFAULT '{}',
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(country_code, provider)
      )
    `);
  } catch (error) {
    console.error('Error ensuring provider table:', error);
  }
}

// Helper function to clean and validate phone numbers
function cleanPhoneNumber(phoneNumber, countryCode) {
  if (!phoneNumber) throw new Error('Phone number is required');
  // Remove spaces, dashes, parentheses and keep digits/+
  let raw = String(phoneNumber).trim().replace(/[^\d+]/g, '');

  // Convert international dialing prefix 00 to +
  if (raw.startsWith('00')) raw = '+' + raw.slice(2);

  const e164 = /^\+[1-9]\d{6,14}$/; // E.164 allows up to 15 digits total
  if (e164.test(raw)) return raw;

  // Known mappings between 2-letter country codes and phone codes
  const ccToPhone = { LK: '94', IN: '91', US: '1', UK: '44', AE: '971' };

  // If it starts with a known phone code without +, add it
  const knownCodes = Object.values(ccToPhone).sort((a, b) => b.length - a.length);
  for (const code of knownCodes) {
    if (raw.startsWith(code)) {
      const candidate = '+' + code + raw.slice(code.length).replace(/^0+/, '');
      if (e164.test(candidate)) return candidate;
    }
  }

  // Derive country from provided countryCode, falling back to LK
  let cc = 'LK';
  if (countryCode) {
    if (typeof countryCode === 'string' && countryCode.length === 2 && !countryCode.startsWith('+')) {
      cc = countryCode.toUpperCase();
    } else if (typeof countryCode === 'string') {
      // If a phone code like +94 was provided, convert to country code via smsService helper
      try { cc = smsService.phoneCodeToCountryCode(countryCode); } catch (e) { /* ignore */ }
    }
  }
  const phoneCode = ccToPhone[cc] || ccToPhone['LK'];

  // Handle local formats like 0771234567 or 771234567
  let local = raw.replace(/^0+/, '');
  const candidate = '+' + phoneCode + local;
  if (e164.test(candidate)) return candidate;

  throw new Error('Invalid phone number format. Use +94771234567 or local format with countryCode (e.g., 0771234567 + LK).');
}

/**
 * @route POST /api/sms/send-otp
 * @desc Send OTP to phone number
 * @access Public
 */
router.post('/send-otp', async (req, res) => {
  try {
  // Accept both modern and legacy keys
  let { phoneNumber, countryCode, purpose = 'login' } = req.body;
  phoneNumber = phoneNumber || req.body.phone || req.body.phone_number;
  countryCode = countryCode || req.body.country_code || req.body.cc;

    if (!phoneNumber) {
      return res.status(400).json({
        success: false,
        message: 'Phone number is required'
      });
    }

    // Normalize phone number to E.164 (+xxxxxxxxxxxx)
    let cleanedPhone;
    try {
      cleanedPhone = cleanPhoneNumber(phoneNumber, countryCode);
    } catch (err) {
      return res.status(400).json({ success: false, message: err.message });
    }

    console.log(`📱 Sending OTP to ${cleanedPhone} for purpose: ${purpose}`);

    const result = await smsService.sendOTP(cleanedPhone, countryCode);

    res.json({
      success: true,
      data: {
        otpId: result.otpId,
        expiresIn: result.expiresIn,
        provider: result.provider,
        message: result.message
      }
    });

  } catch (error) {
    console.error('Send OTP error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Failed to send OTP'
    });
  }
});

/**
 * @route POST /api/sms/verify-otp
 * @desc Verify OTP code
 * @access Public
 */
router.post('/verify-otp', async (req, res) => {
  try {
  // Accept both modern and legacy keys
  let { phoneNumber, otp, otpId, purpose = 'login' } = req.body;
  phoneNumber = phoneNumber || req.body.phone || req.body.phone_number;
  otpId = otpId || req.body.verificationId || req.body.otp_token || req.body.otpToken;

    if (!phoneNumber || !otp) {
      return res.status(400).json({
        success: false,
        message: 'Phone number and OTP are required'
      });
    }

    // Normalize phone number to match stored format
    let cleanedPhone;
    try {
      cleanedPhone = cleanPhoneNumber(phoneNumber);
    } catch (err) {
      return res.status(400).json({ success: false, message: err.message });
    }

    console.log(`✅ Verifying OTP for ${cleanedPhone}`);

  const result = await smsService.verifyOTP(cleanedPhone, otp, otpId);

    if (result.success) {
      // Handle different verification purposes
      await handleOTPVerificationSuccess(phoneNumber, purpose, req);
    }

    res.json({
      success: true,
      data: {
        verified: result.verified,
        message: result.message
      }
    });

  } catch (error) {
    console.error('Verify OTP error:', error);
    res.status(400).json({
      success: false,
      message: error.message || 'OTP verification failed'
    });
  }
});

/**
 * @route POST /api/sms/add-phone
 * @desc Add phone number to user account
 * @access Private
 */
router.post('/add-phone', auth.authMiddleware(), async (req, res) => {
  try {
    const { phoneNumber, label = 'personal', purpose = 'general', isPrimary = false } = req.body;
    const userId = req.user.id;

    if (!phoneNumber) {
      return res.status(400).json({
        success: false,
        message: 'Phone number is required'
      });
    }

    // Check if phone already exists for this user
    const existingPhone = await database.query(
      'SELECT id FROM user_phone_numbers WHERE user_id = $1 AND phone_number = $2',
      [userId, phoneNumber]
    );

    if (existingPhone.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'Phone number already exists for this user'
      });
    }

    // Detect country from phone number
    const countryCode = smsService.detectCountry(phoneNumber);

    // Insert new phone number
    const result = await database.query(`
      INSERT INTO user_phone_numbers 
      (user_id, phone_number, country_code, label, purpose, is_primary, is_verified)
      VALUES ($1, $2, $3, $4, $5, $6, false)
      RETURNING *
    `, [userId, phoneNumber, countryCode, label, purpose, isPrimary]);

    const newPhone = result.rows[0];

    res.json({
      success: true,
      data: {
        phoneId: newPhone.id,
        phoneNumber: newPhone.phone_number,
        label: newPhone.label,
        purpose: newPhone.purpose,
        isPrimary: newPhone.is_primary,
        isVerified: newPhone.is_verified,
        message: 'Phone number added successfully. Please verify it.'
      }
    });

  } catch (error) {
    console.error('Add phone error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Failed to add phone number'
    });
  }
});

/**
 * @route GET /api/sms/user-phones
 * @desc Get all phone numbers for user
 * @access Private
 */
router.get('/user-phones', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;

    const result = await database.query(`
      SELECT 
        id,
        phone_number,
        country_code,
        label,
        purpose,
        is_verified,
        is_primary,
        verified_at,
        created_at
      FROM user_phone_numbers 
      WHERE user_id = $1 
      ORDER BY is_primary DESC, created_at ASC
    `, [userId]);

    res.json({
      success: true,
      data: result.rows.map(phone => ({
        phoneId: phone.id,
        phoneNumber: phone.phone_number,
        countryCode: phone.country_code,
        label: phone.label,
        purpose: phone.purpose,
        isVerified: phone.is_verified,
        isPrimary: phone.is_primary,
        verifiedAt: phone.verified_at,
        createdAt: phone.created_at
      }))
    });

  } catch (error) {
    console.error('Get user phones error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch phone numbers'
    });
  }
});

/**
 * @route PUT /api/sms/set-primary/:phoneId
 * @desc Set phone as primary for user
 * @access Private
 */
router.put('/set-primary/:phoneId', auth.authMiddleware(), async (req, res) => {
  try {
    const { phoneId } = req.params;
    const userId = req.user.id;

    // Verify phone belongs to user and is verified
    const phoneResult = await database.query(
      'SELECT * FROM user_phone_numbers WHERE id = $1 AND user_id = $2 AND is_verified = true',
      [phoneId, userId]
    );

    if (phoneResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Phone number not found or not verified'
      });
    }

    // Update primary status (trigger will handle unsetting other primary phones)
    await database.query(
      'UPDATE user_phone_numbers SET is_primary = true WHERE id = $1',
      [phoneId]
    );

    res.json({
      success: true,
      data: {
        phoneId: phoneId,
        message: 'Primary phone updated successfully'
      }
    });

  } catch (error) {
    console.error('Set primary phone error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update primary phone'
    });
  }
});

/**
 * @route DELETE /api/sms/remove-phone/:phoneId
 * @desc Remove phone number from user account
 * @access Private
 */
router.delete('/remove-phone/:phoneId', auth.authMiddleware(), async (req, res) => {
  try {
    const { phoneId } = req.params;
    const userId = req.user.id;

    // Check if this is the primary phone
    const phoneResult = await database.query(
      'SELECT is_primary FROM user_phone_numbers WHERE id = $1 AND user_id = $2',
      [phoneId, userId]
    );

    if (phoneResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Phone number not found'
      });
    }

    // Don't allow removing primary phone if user has multiple phones
    if (phoneResult.rows[0].is_primary) {
      const phoneCount = await database.query(
        'SELECT COUNT(*) as count FROM user_phone_numbers WHERE user_id = $1',
        [userId]
      );

      if (parseInt(phoneCount.rows[0].count) > 1) {
        return res.status(400).json({
          success: false,
          message: 'Cannot remove primary phone. Set another phone as primary first.'
        });
      }
    }

    // Remove phone number
    await database.query(
      'DELETE FROM user_phone_numbers WHERE id = $1 AND user_id = $2',
      [phoneId, userId]
    );

    res.json({
      success: true,
      data: {
        message: 'Phone number removed successfully'
      }
    });

  } catch (error) {
    console.error('Remove phone error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to remove phone number'
    });
  }
});

/**
 * Handle OTP verification success based on purpose
 */
async function handleOTPVerificationSuccess(phoneNumber, purpose, req) {
  try {
    switch (purpose) {
      case 'login':
        // Find or create user account
        await handleLoginVerification(phoneNumber);
        break;
      
      case 'driver_verification':
        // Update driver verification phone status
        if (req.user) {
          await handleDriverVerification(phoneNumber, req.user.id);
        }
        break;
      
      case 'business_profile':
        // Update business profile phone status
        if (req.user) {
          await handleBusinessProfileVerification(phoneNumber, req.user.id);
        }
        break;
      
      case 'profile_update':
        // Add verified phone to user profile
        if (req.user) {
          await handleProfilePhoneVerification(phoneNumber, req.user.id);
        }
        break;
      
      default:
        console.log(`Unknown verification purpose: ${purpose}`);
    }
  } catch (error) {
    console.error('Error handling OTP verification success:', error);
  }
}

/**
 * Handle login verification
 */
async function handleLoginVerification(phoneNumber) {
  try {
    // Check if user exists with this phone
    const user = await database.query(
      'SELECT u.* FROM users u JOIN user_phone_numbers up ON u.id = up.user_id WHERE up.phone_number = $1',
      [phoneNumber]
    );

    if (user.rows.length === 0) {
      // Create new user account
      const newUser = await database.query(`
        INSERT INTO users (email, display_name, role, is_active, email_verified, phone_verified, country_code, created_at, updated_at)
        VALUES ($1, $2, 'user', true, false, true, $3, NOW(), NOW())
        RETURNING *
      `, [`${phoneNumber.replace(/[^\d]/g, '')}@phone.local`, `User ${phoneNumber}`, smsService.detectCountry(phoneNumber)]);

      const userId = newUser.rows[0].id;

      // Add phone number to user_phone_numbers
      await database.query(`
        INSERT INTO user_phone_numbers (user_id, phone_number, country_code, is_verified, is_primary, label, purpose, verified_at)
        VALUES ($1, $2, $3, true, true, 'personal', 'login', NOW())
      `, [userId, phoneNumber, smsService.detectCountry(phoneNumber)]);

      console.log(`📱 Created new user account for ${phoneNumber}`);
    } else {
      // Update existing user phone verification
      await database.query(
        'UPDATE user_phone_numbers SET is_verified = true, verified_at = NOW() WHERE phone_number = $1',
        [phoneNumber]
      );
      
      console.log(`📱 Updated phone verification for existing user: ${phoneNumber}`);
    }
  } catch (error) {
    console.error('Error handling login verification:', error);
  }
}

/**
 * Handle driver verification
 */
async function handleDriverVerification(phoneNumber, userId) {
  try {
    // Update user's phone number in users table if needed
    await database.query(
      'UPDATE users SET phone = $1, phone_verified = true WHERE id = $2 AND (phone IS NULL OR phone = \'\')',
      [phoneNumber, userId]
    );

    // Add/update phone in user_phone_numbers if not exists
    await database.query(`
      INSERT INTO user_phone_numbers (user_id, phone_number, country_code, is_verified, label, purpose, verified_at)
      VALUES ($1, $2, $3, true, 'driver', 'driver_verification', NOW())
      ON CONFLICT (user_id, phone_number) 
      DO UPDATE SET is_verified = true, verified_at = NOW(), purpose = 'driver_verification'
    `, [userId, phoneNumber, smsService.detectCountry(phoneNumber)]);

    console.log(`🚗 Updated driver verification phone for user ${userId}`);
  } catch (error) {
    console.error('Error handling driver verification:', error);
  }
}

/**
 * Handle business profile verification
 */
async function handleBusinessProfileVerification(phoneNumber, userId) {
  try {
    // Add/update phone in user_phone_numbers
    await database.query(`
      INSERT INTO user_phone_numbers (user_id, phone_number, country_code, is_verified, label, purpose, verified_at)
      VALUES ($1, $2, $3, true, 'business', 'business_profile', NOW())
      ON CONFLICT (user_id, phone_number) 
      DO UPDATE SET is_verified = true, verified_at = NOW(), purpose = 'business_profile'
    `, [userId, phoneNumber, smsService.detectCountry(phoneNumber)]);

    console.log(`🏢 Updated business profile phone for user ${userId}`);
  } catch (error) {
    console.error('Error handling business profile verification:', error);
  }
}

/**
 * Handle profile phone verification
 */
async function handleProfilePhoneVerification(phoneNumber, userId) {
  try {
    // Add verified phone to user profile
    await database.query(`
      INSERT INTO user_phone_numbers (user_id, phone_number, country_code, is_verified, label, purpose, verified_at)
      VALUES ($1, $2, $3, true, 'personal', 'profile_update', NOW())
      ON CONFLICT (user_id, phone_number) 
      DO UPDATE SET is_verified = true, verified_at = NOW()
    `, [userId, phoneNumber, smsService.detectCountry(phoneNumber)]);

    console.log(`👤 Updated profile phone for user ${userId}`);
  } catch (error) {
    console.error('Error handling profile phone verification:', error);
  }
}

module.exports = router;

/**
 * @route POST /api/sms/send-otp
 * @desc Send OTP to phone number
 * @access Public
 */
router.post('/send-otp', async (req, res) => {
  try {
    const { phoneNumber, countryCode, purpose = 'login' } = req.body;

    if (!phoneNumber) {
      return res.status(400).json({
        success: false,
        message: 'Phone number is required'
      });
    }

    // Validate phone number format
    const phoneRegex = /^\+[1-9]\d{1,14}$/;
    const cleanedPhone = phoneNumber.replace(/\s+/g, ""); if (!phoneRegex.test(cleanedPhone)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid phone number format'
      });
    }

    console.log(`📱 Sending OTP to ${phoneNumber} for purpose: ${purpose}`);

    const result = await smsService.sendOTP(cleanedPhone, countryCode);

    res.json({
      success: true,
      data: {
        otpId: result.otpId,
        expiresIn: result.expiresIn,
        provider: result.provider,
        message: result.message
      }
    });

  } catch (error) {
    console.error('Send OTP error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Failed to send OTP'
    });
  }
});

/**
 * @route POST /api/sms/verify-otp
 * @desc Verify OTP code
 * @access Public
 */
router.post('/verify-otp', async (req, res) => {
  try {
    const { phoneNumber, otp, otpId, purpose = 'login' } = req.body;

    if (!phoneNumber || !otp) {
      return res.status(400).json({
        success: false,
        message: 'Phone number and OTP are required'
      });
    }

    console.log(`✅ Verifying OTP for ${phoneNumber}`);

    const result = await smsService.verifyOTP(phoneNumber, otp, otpId);

    if (result.success) {
      // Handle different verification purposes
      await handleOTPVerificationSuccess(phoneNumber, purpose, req);
    }

    res.json({
      success: true,
      data: {
        verified: result.verified,
        message: result.message
      }
    });

  } catch (error) {
    console.error('Verify OTP error:', error);
    res.status(400).json({
      success: false,
      message: error.message || 'OTP verification failed'
    });
  }
});

/**
 * @route POST /api/sms/add-phone
 * @desc Add phone number to user account
 * @access Private
 */
router.post('/add-phone', auth.authMiddleware(), async (req, res) => {
  try {
    const { phoneNumber, label = 'personal', purpose = 'general', isPrimary = false } = req.body;
    const userId = req.user.id;

    if (!phoneNumber) {
      return res.status(400).json({
        success: false,
        message: 'Phone number is required'
      });
    }

    // Check if phone already exists for this user
    const existingPhone = await database.query(
      'SELECT id FROM user_phone_numbers WHERE user_id = $1 AND phone_number = $2',
      [userId, phoneNumber]
    );

    if (existingPhone.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'Phone number already exists for this user'
      });
    }

    // Detect country from phone number
    const countryCode = smsService.detectCountry(phoneNumber);

    // Insert new phone number
    const result = await database.query(`
      INSERT INTO user_phone_numbers 
      (user_id, phone_number, country_code, label, purpose, is_primary, is_verified)
      VALUES ($1, $2, $3, $4, $5, $6, false)
      RETURNING *
    `, [userId, phoneNumber, countryCode, label, purpose, isPrimary]);

    const newPhone = result.rows[0];

    res.json({
      success: true,
      data: {
        phoneId: newPhone.id,
        phoneNumber: newPhone.phone_number,
        label: newPhone.label,
        purpose: newPhone.purpose,
        isPrimary: newPhone.is_primary,
        isVerified: newPhone.is_verified,
        message: 'Phone number added successfully. Please verify it.'
      }
    });

  } catch (error) {
    console.error('Add phone error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Failed to add phone number'
    });
  }
});

// List provider configs for a country
router.get('/config/:countryCode', auth.authMiddleware(), auth.roleMiddleware(['super_admin','country_admin']), async (req,res)=>{
  try {
    const { countryCode } = req.params;
    await ensureProviderTable();
    const rows = await database.query('SELECT provider, config, is_active FROM sms_provider_configs WHERE country_code = $1 ORDER BY updated_at DESC', [countryCode.toUpperCase()]);
    res.json({ success:true, data: rows.rows });
  } catch(e){
    console.error('[sms][get-config] error', e);
    res.status(500).json({ success:false, message:'Failed to fetch config' });
  }
});

// Admin diagnostic: send a plain text message via active provider
router.post('/admin-test', auth.authMiddleware(), auth.roleMiddleware(['super_admin','country_admin']), async (req,res)=>{
  try {
    let { phoneNumber, message = 'Test SMS from Request', countryCode } = req.body || {};
    phoneNumber = phoneNumber || req.body.phone || req.body.phone_number;
    if (!phoneNumber) return res.status(400).json({ success:false, message:'phoneNumber is required' });
    const result = await smsService.sendText(countryCode, phoneNumber, message);
    res.json({ success:true, data: { provider: result.provider || 'unknown', messageId: result.messageId || null, response: result.response || null } });
  } catch(e){
    console.error('[sms][admin-test] error', e);
    res.status(400).json({ success:false, message: e.message || 'Failed to send test SMS' });
  }
});

// Upsert a provider config
router.put('/config/:countryCode/:provider', auth.authMiddleware(), auth.roleMiddleware(['super_admin','country_admin']), async (req,res)=>{
  try {
    const { countryCode, provider } = req.params;
  const { config = {}, is_active = true, exclusive = true } = req.body || {};
    if (!smsService.supportedProviders.has(provider)) {
      return res.status(400).json({ success:false, message:'Unsupported provider' });
    }
    await ensureProviderTable();
    const upsert = await database.queryOne(`
      INSERT INTO sms_provider_configs (country_code, provider, config, is_active)
      VALUES ($1,$2,$3::jsonb,$4)
      ON CONFLICT (country_code, provider) DO UPDATE SET config = EXCLUDED.config, is_active = EXCLUDED.is_active, updated_at = NOW()
      RETURNING country_code, provider, config, is_active, updated_at
    `, [countryCode.toUpperCase(), provider, JSON.stringify(config), is_active]);
    if (exclusive && is_active) {
      // Deactivate other providers for this country
      await database.query('UPDATE sms_provider_configs SET is_active = FALSE, updated_at = NOW() WHERE country_code=$1 AND provider <> $2', [countryCode.toUpperCase(), provider]);
    }
    res.json({ success:true, message:'Configuration saved', data: upsert });
  } catch(e){
    console.error('[sms][upsert-config] error', e);
    res.status(500).json({ success:false, message:'Failed to save config' });
  }
});

// Send OTP
router.post('/send-otp', async (req,res)=>{
  try { 
    const { phone, country_code } = req.body || {}; 
    if (!phone) return res.status(400).json({ success:false, message:'phone required'});
    const otp = Math.floor(100000 + Math.random()*900000).toString();
    await database.query(`CREATE TABLE IF NOT EXISTS otp_codes (id SERIAL PRIMARY KEY, phone TEXT, country_code TEXT, code TEXT, created_at TIMESTAMPTZ DEFAULT NOW())`);
    await database.query('INSERT INTO otp_codes (phone, country_code, code) VALUES ($1,$2,$3)', [phone, (country_code||'').toUpperCase() || null, otp]);
    const result = await smsService.sendOTP({ phone, otp, countryCode: country_code });
    res.json({ success:true, message:'OTP sent', provider: result.provider });
  } catch(e){
    console.error('[sms][send-otp] error', e);
    res.status(500).json({ success:false, message:'Failed to send OTP' });
  }
});

// Verify OTP
router.post('/verify-otp', async (req,res)=>{
  try { 
    const { phone, code } = req.body || {}; 
    if (!phone || !code) return res.status(400).json({ success:false, message:'phone & code required'});
    await database.query(`CREATE TABLE IF NOT EXISTS otp_codes (id SERIAL PRIMARY KEY, phone TEXT, country_code TEXT, code TEXT, created_at TIMESTAMPTZ DEFAULT NOW())`);
    const row = await database.queryOne('SELECT * FROM otp_codes WHERE phone=$1 ORDER BY created_at DESC LIMIT 1', [phone]);
    if (!row) return res.status(400).json({ success:false, message:'No OTP sent' });
    if (Date.now() - new Date(row.created_at).getTime() > 10*60*1000) return res.status(400).json({ success:false, message:'OTP expired'});
    if (row.code !== code) return res.status(400).json({ success:false, message:'Invalid code'});
    res.json({ success:true, message:'OTP verified' });
  } catch(e){
    console.error('[sms][verify-otp] error', e);
    res.status(500).json({ success:false, message:'Failed to verify OTP' });
  }
});

// Basic statistics per country
router.get('/statistics/:countryCode', auth.authMiddleware(), auth.roleMiddleware(['super_admin','country_admin']), async (req,res)=>{
  try {
    const { countryCode } = req.params;

    // Ensure table exists (defensive) matching current OTP flow storage
    await database.query(`
      CREATE TABLE IF NOT EXISTS phone_otp_verifications (
        id SERIAL PRIMARY KEY,
        otp_id TEXT,
        phone TEXT,
        otp TEXT,
        country_code TEXT,
        expires_at TIMESTAMPTZ,
        attempts INT DEFAULT 0,
        max_attempts INT DEFAULT 3,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        verified BOOLEAN DEFAULT FALSE,
        verified_at TIMESTAMPTZ,
        provider_used TEXT
      )
    `);

    const cc = (countryCode || '').toUpperCase();

    // Totals and success breakdown
    const totalRow = await database.queryOne(
      'SELECT COUNT(*)::int AS total FROM phone_otp_verifications WHERE country_code = $1',
      [cc]
    );
    const verifiedRow = await database.queryOne(
      'SELECT COUNT(*)::int AS verified FROM phone_otp_verifications WHERE country_code = $1 AND verified = TRUE',
      [cc]
    );
    const totalSent = totalRow?.total || 0;
    const totalVerified = verifiedRow?.verified || 0;
    const successRate = totalSent > 0 ? Math.round((totalVerified / totalSent) * 100) : 0;

    // Get active provider via SMS config API with safe fallback
    let provider = 'dev';
    try {
      const cfg = await smsService.getSMSConfig(cc);
      provider = cfg?.provider || 'dev';
    } catch (cfgErr) {
      console.warn(`[sms][statistics] No active SMS config for ${cc}, falling back to 'dev' provider.`, cfgErr?.message || cfgErr);
    }

    // Rough unit cost mapping (USD-equivalent estimates), fallback to default
    const unitCostMap = { twilio: 0.0075, aws: 0.0075, aws_sns: 0.0075, vonage: 0.0072, local: 0.003, local_http: 0.003, hutch_mobile: 0.0075, dev: 0 };
    const providerUnitCost = unitCostMap[provider] ?? 0.0075;
    const firebaseAvg = 0.015; // assumed baseline
    const costSavings = Number(Math.max(0, (firebaseAvg - providerUnitCost) * totalSent).toFixed(2));

    // Last 30 days snapshot
    const last30Row = await database.queryOne(
      'SELECT COUNT(*)::int AS sent FROM phone_otp_verifications WHERE country_code = $1 AND created_at > NOW() - INTERVAL \'30 days\'',
      [cc]
    );
    const last30Sent = last30Row?.sent || 0;
    const last30Cost = Number((last30Sent * providerUnitCost).toFixed(2));

    res.json({
      success: true,
      data: {
        countryCode: cc,
        totalSent,
        successRate,
        costSavings,
        provider,
        lastMonth: { sent: last30Sent, cost: last30Cost }
      }
    });
  } catch(e){
    console.error('[sms][statistics] error', e);
    res.status(500).json({ success:false, message:'Failed to load statistics' });
  }
});

module.exports = router;
