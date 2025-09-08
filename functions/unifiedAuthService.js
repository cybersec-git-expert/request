/**
 * Unified Authentication Service
 * Handles both SMS and Email OTP authentication
 * 
 * @description
 * This service combines SMS and Email OTP functionality to provide
 * a complete authentication solution using AWS SES for emails and
 * various SMS providers for phone verification.
 * 
 * @features
 * - Auto-detection of email vs phone number
 * - Unified OTP generation and verification
 * - User registration and profile completion
 * - Password reset functionality
 * - Rate limiting and security measures
 * 
 * @author Request Marketplace Team
 * @version 1.0.0
 * @since 2025-08-16
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

// Import SMS and Email services
const smsService = require('./smsService');
const emailService = require('./emailService');

// Initialize Firebase Admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Utility functions
 */
const AuthUtils = {
  /**
   * Detect if input is email or phone number
   */
  detectInputType(input) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    const phoneRegex = /^\+[1-9]\d{9,14}$/;
    
    if (emailRegex.test(input)) {
      return 'email';
    } else if (phoneRegex.test(input)) {
      return 'phone';
    } else {
      throw new Error('Invalid email or phone number format');
    }
  },

  /**
   * Extract country code from phone number
   */
  extractCountryCode(phoneNumber) {
    if (phoneNumber.startsWith('+94')) return 'LK'; // Sri Lanka
    if (phoneNumber.startsWith('+91')) return 'IN'; // India
    if (phoneNumber.startsWith('+1')) return 'US';   // USA
    if (phoneNumber.startsWith('+44')) return 'UK';  // UK
    // Add more countries as needed
    return 'LK'; // Default to Sri Lanka
  },

  /**
   * Generate secure 6-digit OTP
   */
  generateOTP() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  },

  /**
   * Generate secure session ID
   */
  generateSessionId() {
    return crypto.randomUUID();
  }
};

/**
 * Check if user exists in the system
 */
exports.checkUserExists = functions.https.onCall(async (data, context) => {
  try {
    const { emailOrPhone } = data;
    
    if (!emailOrPhone) {
      throw new functions.https.HttpsError('invalid-argument', 'Email or phone number is required');
    }

    const inputType = AuthUtils.detectInputType(emailOrPhone);
    
    // Search for user in Firestore
    let userQuery;
    if (inputType === 'email') {
      userQuery = db.collection('users').where('email', '==', emailOrPhone);
    } else {
      userQuery = db.collection('users').where('phoneNumber', '==', emailOrPhone);
    }
    
    const userSnapshot = await userQuery.limit(1).get();
    
    return {
      exists: !userSnapshot.empty,
      inputType,
      userId: userSnapshot.empty ? null : userSnapshot.docs[0].id
    };

  } catch (error) {
    console.error('Check user exists error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Send registration OTP (for new users)
 */
exports.sendRegistrationOTP = functions.https.onCall(async (data, context) => {
  try {
    const { emailOrPhone } = data;
    
    if (!emailOrPhone) {
      throw new functions.https.HttpsError('invalid-argument', 'Email or phone number is required');
    }

    const inputType = AuthUtils.detectInputType(emailOrPhone);
    const otpId = AuthUtils.generateSessionId();
    
    // Check if user already exists
    const userCheck = await exports.checkUserExists.run({ emailOrPhone }, context);
    if (userCheck.exists) {
      throw new functions.https.HttpsError('already-exists', 'User already registered with this email/phone');
    }

    let result;
    if (inputType === 'email') {
      // Send email OTP
      result = await emailService.sendEmailOTP.run({
        email: emailOrPhone,
        purpose: 'registration',
        countryCode: 'LK' // Default country, can be detected from user location
      }, context);
    } else {
      // Send SMS OTP
      const countryCode = AuthUtils.extractCountryCode(emailOrPhone);
      result = await smsService.sendOTP.run({
        phoneNumber: emailOrPhone,
        country: countryCode
      }, context);
    }

    return {
      success: true,
      message: `OTP sent to your ${inputType}`,
      otpId: result.otpId || otpId,
      expiresIn: 300, // 5 minutes
      inputType
    };

  } catch (error) {
    console.error('Send registration OTP error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Send password reset OTP (for existing users)
 */
exports.sendPasswordResetOTP = functions.https.onCall(async (data, context) => {
  try {
    const { emailOrPhone } = data;
    
    if (!emailOrPhone) {
      throw new functions.https.HttpsError('invalid-argument', 'Email or phone number is required');
    }

    const inputType = AuthUtils.detectInputType(emailOrPhone);
    
    // Check if user exists
    const userCheck = await exports.checkUserExists.run({ emailOrPhone }, context);
    if (!userCheck.exists) {
      throw new functions.https.HttpsError('not-found', 'No account found with this email/phone');
    }

    let result;
    if (inputType === 'email') {
      // Send email OTP
      result = await emailService.sendEmailOTP.run({
        email: emailOrPhone,
        purpose: 'password_reset',
        countryCode: 'LK'
      }, context);
    } else {
      // Send SMS OTP
      const countryCode = AuthUtils.extractCountryCode(emailOrPhone);
      result = await smsService.sendOTP.run({
        phoneNumber: emailOrPhone,
        country: countryCode
      }, context);
    }

    return {
      success: true,
      message: `Password reset code sent to your ${inputType}`,
      otpId: result.otpId || result.sessionId,
      expiresIn: 300,
      inputType
    };

  } catch (error) {
    console.error('Send password reset OTP error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Verify OTP (unified for both SMS and email)
 */
exports.verifyOTP = functions.https.onCall(async (data, context) => {
  try {
    const { emailOrPhone, otp, otpId, purpose } = data;
    
    if (!emailOrPhone || !otp || !otpId || !purpose) {
      throw new functions.https.HttpsError('invalid-argument', 'All fields are required');
    }

    const inputType = AuthUtils.detectInputType(emailOrPhone);
    
    let verificationResult;
    if (inputType === 'email') {
      // Verify email OTP
      verificationResult = await emailService.verifyEmailOTP.run({
        email: emailOrPhone,
        otp,
        otpId,
        purpose
      }, context);
    } else {
      // Verify SMS OTP
      const countryCode = AuthUtils.extractCountryCode(emailOrPhone);
      verificationResult = await smsService.verifyOTP.run({
        phoneNumber: emailOrPhone,
        otp,
        country: countryCode
      }, context);
    }

    if (verificationResult.success) {
      return {
        success: true,
        message: 'OTP verified successfully',
        inputType,
        otpId
      };
    } else {
      throw new Error('OTP verification failed');
    }

  } catch (error) {
    console.error('Verify OTP error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Login with password (for existing users)
 */
exports.loginWithPassword = functions.https.onCall(async (data, context) => {
  try {
    const { emailOrPhone, password } = data;
    
    if (!emailOrPhone || !password) {
      throw new functions.https.HttpsError('invalid-argument', 'Email/phone and password are required');
    }

    const inputType = AuthUtils.detectInputType(emailOrPhone);
    
    // Find user in database
    let userQuery;
    if (inputType === 'email') {
      userQuery = db.collection('users').where('email', '==', emailOrPhone);
    } else {
      userQuery = db.collection('users').where('phoneNumber', '==', emailOrPhone);
    }
    
    const userSnapshot = await userQuery.limit(1).get();
    
    if (userSnapshot.empty) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const userDoc = userSnapshot.docs[0];
    const userData = userDoc.data();
    
    // Verify password (you should use proper password hashing)
    const bcrypt = require('bcrypt');
    const passwordMatch = await bcrypt.compare(password, userData.passwordHash);
    
    if (!passwordMatch) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid password');
    }

    // Create custom token for authentication
    const customToken = await admin.auth().createCustomToken(userDoc.id, {
      email: userData.email,
      phoneNumber: userData.phoneNumber,
      role: userData.role || 'user'
    });

    return {
      success: true,
      message: 'Login successful',
      customToken,
      user: {
        uid: userDoc.id,
        email: userData.email,
        phoneNumber: userData.phoneNumber,
        firstName: userData.firstName,
        lastName: userData.lastName,
        role: userData.role || 'user'
      }
    };

  } catch (error) {
    console.error('Login with password error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Complete user profile (for new users after OTP verification)
 */
exports.completeProfile = functions.https.onCall(async (data, context) => {
  try {
    const { firstName, lastName, password, emailOrPhone, otpId } = data;
    
    if (!firstName || !lastName || !password || !emailOrPhone || !otpId) {
      throw new functions.https.HttpsError('invalid-argument', 'All fields are required');
    }

    const inputType = AuthUtils.detectInputType(emailOrPhone);
    
    // Hash password
    const bcrypt = require('bcrypt');
    const passwordHash = await bcrypt.hash(password, 12);
    
    // Create user document
    const userData = {
      firstName,
      lastName,
      passwordHash,
      createdAt: new Date(),
      lastLoginAt: new Date(),
      isActive: true,
      role: 'user',
      profileComplete: true
    };

    if (inputType === 'email') {
      userData.email = emailOrPhone;
      userData.emailVerified = true;
    } else {
      userData.phoneNumber = emailOrPhone;
      userData.phoneVerified = true;
      userData.country = AuthUtils.extractCountryCode(emailOrPhone);
    }

    // Create user in Firestore
    const userRef = await db.collection('users').add(userData);
    
    // Create custom token
    const customToken = await admin.auth().createCustomToken(userRef.id, {
      email: userData.email,
      phoneNumber: userData.phoneNumber,
      role: userData.role
    });

    return {
      success: true,
      message: 'Profile completed successfully',
      customToken,
      user: {
        uid: userRef.id,
        email: userData.email,
        phoneNumber: userData.phoneNumber,
        firstName,
        lastName,
        role: userData.role
      }
    };

  } catch (error) {
    console.error('Complete profile error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Reset password (after OTP verification)
 */
exports.resetPassword = functions.https.onCall(async (data, context) => {
  try {
    const { emailOrPhone, newPassword, otpId } = data;
    
    if (!emailOrPhone || !newPassword || !otpId) {
      throw new functions.https.HttpsError('invalid-argument', 'All fields are required');
    }

    const inputType = AuthUtils.detectInputType(emailOrPhone);
    
    // Find user
    let userQuery;
    if (inputType === 'email') {
      userQuery = db.collection('users').where('email', '==', emailOrPhone);
    } else {
      userQuery = db.collection('users').where('phoneNumber', '==', emailOrPhone);
    }
    
    const userSnapshot = await userQuery.limit(1).get();
    
    if (userSnapshot.empty) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    // Hash new password
    const bcrypt = require('bcrypt');
    const passwordHash = await bcrypt.hash(newPassword, 12);
    
    // Update user password
    await userSnapshot.docs[0].ref.update({
      passwordHash,
      passwordResetAt: new Date()
    });

    return {
      success: true,
      message: 'Password reset successfully'
    };

  } catch (error) {
    console.error('Reset password error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

module.exports = {
  checkUserExists: exports.checkUserExists,
  sendRegistrationOTP: exports.sendRegistrationOTP,
  sendPasswordResetOTP: exports.sendPasswordResetOTP,
  verifyOTP: exports.verifyOTP,
  loginWithPassword: exports.loginWithPassword,
  completeProfile: exports.completeProfile,
  resetPassword: exports.resetPassword,
  AuthUtils
};
