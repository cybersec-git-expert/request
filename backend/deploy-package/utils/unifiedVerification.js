const database = require('../services/database');

/**
 * Normalize phone number to +94 format for Sri Lankan numbers
 */
function normalizePhoneNumber(phone) {
  if (!phone) return null;
  
  // Remove all non-digit characters
  const cleaned = phone.replace(/\D/g, '');
  
  // Handle different Sri Lankan number formats
  if (cleaned.length === 9 && cleaned.startsWith('7')) {
    return `+94${cleaned}`;
  }
  if (cleaned.length === 10 && cleaned.startsWith('07')) {
    return `+94${cleaned.substring(1)}`;
  }
  if (cleaned.length === 12 && cleaned.startsWith('947')) {
    return `+${cleaned}`;
  }
  if (cleaned.length === 13 && cleaned.startsWith('9947')) {
    return `+${cleaned.substring(1)}`;
  }
  
  // If already has country code, just ensure + prefix
  if (phone.startsWith('+')) {
    return phone;
  }
  
  // Return as-is if unrecognized format
  return phone;
}

/**
 * Unified phone verification checker - checks across all three tables
 * Priority: 
 * 1. business_verifications (if matching business_phone)
 * 2. driver_verifications (if matching phone_number) 
 * 3. users table (if matching phone)
 * 4. OTP verification history
 */
async function checkUnifiedPhoneVerification(userId, phoneNumber) {
  try {
    console.log(`🔍 [UNIFIED] Checking phone verification for user ${userId}, phone: ${phoneNumber}`);
    
    if (!phoneNumber) {
      return { 
        phoneVerified: false, 
        needsUpdate: false, 
        requiresManualVerification: true,
        verificationSource: null,
        checkedTables: []
      };
    }

    const normalizedPhone = normalizePhoneNumber(phoneNumber);
    const checkedTables = [];
    
    // 1. Check business_verifications table first (highest priority for business verification)
    console.log('📱 [UNIFIED] Checking business_verifications table...');
    const businessQuery = `
      SELECT phone_verified, business_phone
      FROM business_verifications 
      WHERE user_id = $1 AND (business_phone = $2 OR business_phone = $3) AND phone_verified = true
    `;
    const businessResult = await database.query(businessQuery, [userId, normalizedPhone, phoneNumber]);
    checkedTables.push({ table: 'business_verifications', found: businessResult.rows.length > 0 });
    
    if (businessResult.rows.length > 0) {
      console.log('✅ [UNIFIED] Phone verification found in business_verifications table!');
      return { 
        phoneVerified: true, 
        needsUpdate: false, 
        requiresManualVerification: false, 
        verificationSource: 'business_verification',
        verifiedPhone: businessResult.rows[0].business_phone,
        checkedTables
      };
    }

    // 2. Check driver_verifications table
    console.log('📱 [UNIFIED] Checking driver_verifications table...');
    const driverQuery = `
      SELECT phone_verified, phone_number
      FROM driver_verifications 
      WHERE user_id = $1 AND (phone_number = $2 OR phone_number = $3) AND phone_verified = true
    `;
    const driverResult = await database.query(driverQuery, [userId, normalizedPhone, phoneNumber]);
    checkedTables.push({ table: 'driver_verifications', found: driverResult.rows.length > 0 });
    
    if (driverResult.rows.length > 0) {
      console.log('✅ [UNIFIED] Phone verification found in driver_verifications table!');
      return { 
        phoneVerified: true, 
        needsUpdate: true, 
        requiresManualVerification: false, 
        verificationSource: 'driver_verification',
        verifiedPhone: driverResult.rows[0].phone_number,
        checkedTables
      };
    }

    // 3. Check users table
    console.log('📱 [UNIFIED] Checking users table...');
    const userResult = await database.query(
      'SELECT phone, phone_verified FROM users WHERE id = $1',
      [userId]
    );
    checkedTables.push({ table: 'users', found: userResult.rows.length > 0 });
    
    if (userResult.rows.length === 0) {
      console.log(`❌ [UNIFIED] User ${userId} not found`);
      return { 
        phoneVerified: false, 
        needsUpdate: false, 
        requiresManualVerification: true,
        verificationSource: null,
        checkedTables
      };
    }
    
    const user = userResult.rows[0];
    const normalizedUserPhone = normalizePhoneNumber(user.phone);

    // Check if phones match and user is verified
    if (normalizedUserPhone === normalizedPhone && user.phone_verified) {
      console.log(`✅ [UNIFIED] Phone verified via users table: ${normalizedUserPhone}`);
      return { 
        phoneVerified: true, 
        needsUpdate: false, 
        requiresManualVerification: false, 
        verificationSource: 'personal_phone',
        verifiedPhone: user.phone,
        checkedTables
      };
    }

    // 4. Check OTP verification history if phones match
    if (normalizedUserPhone === normalizedPhone || !user.phone) {
      console.log('📱 [UNIFIED] Checking phone_otp_verifications table...');
      const otpResult = await database.query(
        'SELECT phone, verified FROM phone_otp_verifications WHERE phone = $1 AND verified = true ORDER BY verified_at DESC LIMIT 1',
        [normalizedPhone]
      );
      checkedTables.push({ table: 'phone_otp_verifications', found: otpResult.rows.length > 0 });
      
      if (otpResult.rows.length > 0) {
        console.log(`✅ [UNIFIED] Phone verified via OTP history: ${normalizedPhone}`);
        
        // Auto-update user phone if not set
        if (!user.phone) {
          await database.query(
            'UPDATE users SET phone = $1, phone_verified = true, updated_at = NOW() WHERE id = $2',
            [normalizedPhone, userId]
          );
          console.log(`📱 [UNIFIED] Updated user ${userId} phone to ${normalizedPhone}`);
        } else if (!user.phone_verified) {
          await database.query(
            'UPDATE users SET phone_verified = true, updated_at = NOW() WHERE id = $1',
            [userId]
          );
          console.log(`✅ [UNIFIED] Auto-verified phone for user ${userId}`);
        }
        
        return { 
          phoneVerified: true, 
          needsUpdate: true, 
          requiresManualVerification: false, 
          verificationSource: 'otp_history',
          verifiedPhone: normalizedPhone,
          checkedTables
        };
      }
    }

    console.log(`❌ [UNIFIED] Phone ${normalizedPhone} not verified - manual verification required`);
    return { 
      phoneVerified: false, 
      needsUpdate: false, 
      requiresManualVerification: true,
      verificationSource: null,
      checkedTables
    };
  } catch (error) {
    console.error('❌ [UNIFIED] Error checking phone verification:', error);
    return { 
      phoneVerified: false, 
      needsUpdate: false, 
      requiresManualVerification: true,
      verificationSource: null,
      error: error.message,
      checkedTables: []
    };
  }
}

/**
 * Unified email verification checker - checks across all three tables
 * Priority: 
 * 1. business_verifications (if matching business_email)
 * 2. driver_verifications (if matching email) 
 * 3. users table (if matching email)
 * 4. Email OTP verification history
 */
async function checkUnifiedEmailVerification(userId, email) {
  try {
    console.log(`🔍 [UNIFIED] Checking email verification for user ${userId}, email: ${email}`);
    
    if (!email) {
      return { 
        emailVerified: false, 
        needsUpdate: false, 
        requiresManualVerification: true,
        verificationSource: null,
        checkedTables: []
      };
    }

    const normalizedEmail = email.toLowerCase();
    const checkedTables = [];

    // 1. Check business_verifications table first
    console.log('📧 [UNIFIED] Checking business_verifications table...');
    const businessQuery = `
      SELECT email_verified, business_email
      FROM business_verifications 
      WHERE user_id = $1 AND LOWER(business_email) = $2 AND email_verified = true
    `;
    const businessResult = await database.query(businessQuery, [userId, normalizedEmail]);
    checkedTables.push({ table: 'business_verifications', found: businessResult.rows.length > 0 });
    
    if (businessResult.rows.length > 0) {
      console.log('✅ [UNIFIED] Email verification found in business_verifications table!');
      return { 
        emailVerified: true, 
        needsUpdate: false, 
        requiresManualVerification: false, 
        verificationSource: 'business_verification',
        verifiedEmail: businessResult.rows[0].business_email,
        checkedTables
      };
    }

    // 2. Check driver_verifications table
    console.log('📧 [UNIFIED] Checking driver_verifications table...');
    const driverQuery = `
      SELECT email_verified, email
      FROM driver_verifications 
      WHERE user_id = $1 AND LOWER(email) = $2 AND email_verified = true
    `;
    const driverResult = await database.query(driverQuery, [userId, normalizedEmail]);
    checkedTables.push({ table: 'driver_verifications', found: driverResult.rows.length > 0 });
    
    if (driverResult.rows.length > 0) {
      console.log('✅ [UNIFIED] Email verification found in driver_verifications table!');
      return { 
        emailVerified: true, 
        needsUpdate: true, 
        requiresManualVerification: false, 
        verificationSource: 'driver_verification',
        verifiedEmail: driverResult.rows[0].email,
        checkedTables
      };
    }

    // 3. Check users table
    console.log('📧 [UNIFIED] Checking users table...');
    const userResult = await database.query(
      'SELECT email, email_verified FROM users WHERE id = $1',
      [userId]
    );
    checkedTables.push({ table: 'users', found: userResult.rows.length > 0 });
    
    if (userResult.rows.length === 0) {
      console.log(`❌ [UNIFIED] User ${userId} not found`);
      return { 
        emailVerified: false, 
        needsUpdate: false, 
        requiresManualVerification: true,
        verificationSource: null,
        checkedTables
      };
    }
    
    const user = userResult.rows[0];

    // Check if emails match and user is verified
    if (user.email && user.email.toLowerCase() === normalizedEmail && user.email_verified) {
      console.log(`✅ [UNIFIED] Email verified via users table: ${user.email}`);
      return { 
        emailVerified: true, 
        needsUpdate: false, 
        requiresManualVerification: false, 
        verificationSource: 'personal_email',
        verifiedEmail: user.email,
        checkedTables
      };
    }

    // 4. Check email OTP verification history if emails match
    if ((user.email && user.email.toLowerCase() === normalizedEmail) || !user.email) {
      console.log('📧 [UNIFIED] Checking email_otp_verifications table...');
      const emailVerificationResult = await database.query(
        'SELECT email, verified FROM email_otp_verifications WHERE email = $1 AND verified = true ORDER BY verified_at DESC LIMIT 1',
        [normalizedEmail]
      );
      checkedTables.push({ table: 'email_otp_verifications', found: emailVerificationResult.rows.length > 0 });
      
      if (emailVerificationResult.rows.length > 0) {
        console.log(`✅ [UNIFIED] Email verified via OTP history: ${normalizedEmail}`);
        
        // Auto-update user email if not set
        if (!user.email) {
          await database.query(
            'UPDATE users SET email = $1, email_verified = true, updated_at = NOW() WHERE id = $2',
            [normalizedEmail, userId]
          );
          console.log(`📧 [UNIFIED] Updated user ${userId} email to ${normalizedEmail}`);
        } else if (!user.email_verified) {
          await database.query(
            'UPDATE users SET email_verified = true, updated_at = NOW() WHERE id = $1',
            [userId]
          );
          console.log(`✅ [UNIFIED] Auto-verified email for user ${userId}`);
        }
        
        return { 
          emailVerified: true, 
          needsUpdate: true, 
          requiresManualVerification: false, 
          verificationSource: 'otp_history',
          verifiedEmail: normalizedEmail,
          checkedTables
        };
      }
    }

    console.log(`❌ [UNIFIED] Email ${normalizedEmail} not verified for user ${userId}`);
    return { 
      emailVerified: false, 
      needsUpdate: false, 
      requiresManualVerification: true,
      verificationSource: null,
      checkedTables
    };
  } catch (error) {
    console.error('❌ [UNIFIED] Error checking email verification:', error);
    return { 
      emailVerified: false, 
      needsUpdate: false, 
      requiresManualVerification: true,
      verificationSource: null,
      error: error.message,
      checkedTables: []
    };
  }
}

/**
 * Get complete unified verification status for a user
 * This checks all verification methods and returns comprehensive status
 */
async function getUnifiedVerificationStatus(userId, options = {}) {
  try {
    const { 
      checkPhone = null, 
      checkEmail = null,
      includeDebugInfo = false 
    } = options;

    console.log(`🔍 [UNIFIED] Getting complete verification status for user ${userId}`);

    // Get user's basic information
    const userResult = await database.query(
      'SELECT id, email, phone, email_verified, phone_verified, first_name, last_name FROM users WHERE id = $1',
      [userId]
    );

    if (userResult.rows.length === 0) {
      return {
        success: false,
        error: 'User not found',
        userId
      };
    }

    const user = userResult.rows[0];
    const results = {
      success: true,
      userId,
      user: {
        id: user.id,
        email: user.email,
        phone: user.phone,
        emailVerified: user.email_verified,
        phoneVerified: user.phone_verified,
        name: `${user.first_name || ''} ${user.last_name || ''}`.trim()
      },
      verification: {}
    };

    // Check phone verification
    if (checkPhone || user.phone) {
      const phoneToCheck = checkPhone || user.phone;
      const phoneStatus = await checkUnifiedPhoneVerification(userId, phoneToCheck);
      results.verification.phone = {
        phoneNumber: phoneToCheck,
        normalizedPhone: normalizePhoneNumber(phoneToCheck),
        isVerified: phoneStatus.phoneVerified,
        verificationSource: phoneStatus.verificationSource,
        verifiedPhone: phoneStatus.verifiedPhone,
        requiresManualVerification: phoneStatus.requiresManualVerification,
        needsUpdate: phoneStatus.needsUpdate,
        ...(includeDebugInfo && { checkedTables: phoneStatus.checkedTables })
      };
    }

    // Check email verification
    if (checkEmail || user.email) {
      const emailToCheck = checkEmail || user.email;
      const emailStatus = await checkUnifiedEmailVerification(userId, emailToCheck);
      results.verification.email = {
        email: emailToCheck,
        normalizedEmail: emailToCheck ? emailToCheck.toLowerCase() : null,
        isVerified: emailStatus.emailVerified,
        verificationSource: emailStatus.verificationSource,
        verifiedEmail: emailStatus.verifiedEmail,
        requiresManualVerification: emailStatus.requiresManualVerification,
        needsUpdate: emailStatus.needsUpdate,
        ...(includeDebugInfo && { checkedTables: emailStatus.checkedTables })
      };
    }

    // Get business verification status
    const businessResult = await database.query(
      'SELECT business_phone, business_email, phone_verified, email_verified, status FROM business_verifications WHERE user_id = $1',
      [userId]
    );
    
    if (businessResult.rows.length > 0) {
      const business = businessResult.rows[0];
      results.verification.business = {
        businessPhone: business.business_phone,
        businessEmail: business.business_email,
        phoneVerified: business.phone_verified,
        emailVerified: business.email_verified,
        status: business.status
      };
    }

    // Get driver verification status
    const driverResult = await database.query(
      'SELECT phone_number, email, phone_verified, email_verified, status FROM driver_verifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1',
      [userId]
    );
    
    if (driverResult.rows.length > 0) {
      const driver = driverResult.rows[0];
      results.verification.driver = {
        phoneNumber: driver.phone_number,
        email: driver.email,
        phoneVerified: driver.phone_verified,
        emailVerified: driver.email_verified,
        status: driver.status
      };
    }

    return results;
  } catch (error) {
    console.error('❌ [UNIFIED] Error getting verification status:', error);
    return {
      success: false,
      error: error.message,
      userId
    };
  }
}

module.exports = {
  normalizePhoneNumber,
  checkUnifiedPhoneVerification,
  checkUnifiedEmailVerification,
  getUnifiedVerificationStatus
};
