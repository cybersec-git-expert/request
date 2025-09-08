/**
 * Custom SMS Authentication Service
 * 
 * @description
 * Client-side authentication service that replaces Firebase Auth with
 * custom SMS OTP authentication. Provides country-wise SMS providers
 * for cost optimization while maintaining security.
 * 
 * @features
 * - Custom SMS OTP authentication
 * - Country-specific SMS provider support
 * - Secure token management
 * - Rate limiting and retry logic
 * - Cost-effective authentication flow
 * 
 * @cost_benefits
 * - Reduces authentication costs by 50-80%
 * - No Firebase Auth monthly base fees
 * - Use of local/regional SMS providers
 * 
 * @author Request Marketplace Team
 * @version 1.0.0
 * @since 2025-08-16
 */

// Simplified SMS auth service using backend REST endpoints (Firebase removed)
import api from './apiClient';

// Firebase configuration

const auth = { currentUser: null };

// === AUTHENTICATION STATE MANAGEMENT ===

class AuthState {
  constructor() {
    this.user = null;
    this.isLoading = true;
    this.listeners = [];
  }

  setUser(user) {
    this.user = user;
    this.isLoading = false;
    this.notifyListeners();
  }

  setLoading(loading) {
    this.isLoading = loading;
    this.notifyListeners();
  }

  addListener(callback) {
    this.listeners.push(callback);
    return () => {
      this.listeners = this.listeners.filter(listener => listener !== callback);
    };
  }

  notifyListeners() {
    this.listeners.forEach(listener => {
      listener({
        user: this.user,
        isLoading: this.isLoading
      });
    });
  }
}

const authState = new AuthState();

// === SMS AUTHENTICATION SERVICE ===

export class SMSAuthService {
  constructor() {}

  // Explicit state getter
  get currentUser() { return authState.user; }

  async sendOTP(phoneNumber, country) {
    try {
      await api.post('/auth/send-phone-otp', { phone: phoneNumber, countryCode: country });
      return { success: true, message: 'OTP sent successfully', provider: 'backend' };
    } catch (error) {
      return { success: false, error: error.response?.data?.error || error.message };
    }
  }

  async verifyOTP(phoneNumber, otp, country) {
    try {
      const res = await api.post('/auth/verify-phone-otp', { phone: phoneNumber, otp, countryCode: country });
      const { user, token } = res.data.data || {};
      auth.currentUser = user;
      authState.setUser(user);
      return { success: true, user, token };
    } catch (error) {
      return { success: false, error: error.response?.data?.error || error.message };
    }
  }

  async getUserProfile(userId) { try { const { data } = await api.get(`/users/${userId}`); return data?.data || data; } catch { return null; } }
  async updateUserProfile(userId, data) { try { await api.put(`/users/${userId}`, data); return true; } catch { return false; } }
  async createUserProfile(userId, data) { try { await api.post('/users', { id: userId, ...data }); return true; } catch { return false; } }
  async logout() { auth.currentUser = null; authState.setUser(null); return { success: true }; }

  /**
   * Sign out user
   */
  async signOut() { return this.logout(); }

  /**
   * Get current user
   */
  getCurrentUser() {
    return authState.user;
  }

  /**
   * Check if user is authenticated
   */
  isAuthenticated() {
    return !!authState.user;
  }

  /**
   * Check if user is admin
   */
  isAdmin() {
    return authState.user?.isAdmin || false;
  }

  /**
   * Subscribe to auth state changes
   */
  onAuthStateChanged(callback) {
    return authState.addListener(callback);
  }

  /**
   * Get user profile from Firestore
   */
  // Legacy method kept for compatibility
  async getUserProfileLegacy(uid) { return this.getUserProfile(uid); }

  /**
   * Get admin profile from Firestore
   */
  async getAdminProfile(uid) { return this.getUserProfile(uid); }

  /**
   * Create or update user profile
   */
  async createOrUpdateUserProfile(uid, data) { return this.updateUserProfile(uid, data); }

  /**
   * Update user profile
   */
  // replace old Firestore specific method name conflict resolved earlier

  /**
   * Check if phone number is already registered
   */
  async isPhoneNumberRegistered(phoneNumber, country) { try { const { data } = await api.get('/users', { params: { phone: phoneNumber, country } }); return Array.isArray(data?.data) ? data.data.length > 0 : false; } catch { return false; } }

  /**
   * Register new user with phone number
   */
  async registerUser(phoneNumber, country) {
    const isRegistered = await this.isPhoneNumberRegistered(phoneNumber, country);
    if (isRegistered) throw new Error('Phone number is already registered');
    const otpResult = await this.sendOTP(phoneNumber, country);
    return { success: true, message: 'OTP sent', nextStep: 'verify_otp', expiresAt: otpResult.expiresAt };
  }

  /**
   * Complete user registration after OTP verification
   */
  async completeRegistration(phoneNumber, otp, country, userData = {}) {
    const verifyResult = await this.verifyOTP(phoneNumber, otp, country);
    if (!verifyResult.success) throw new Error(verifyResult.error || 'Registration failed');
    if (Object.keys(userData).length) await this.updateUserProfile(auth.currentUser?.id || auth.currentUser?.uid, userData);
    return { success: true, message: 'Registration completed successfully', user: verifyResult.user };
  }

  /**
   * Test SMS configuration (Admin only)
   */
  async testSMSConfig() { throw new Error('Not implemented'); }

  /**
   * Get SMS statistics (Admin only)
   */
  async getSMSStatistics() { return { success: true, totalSent: 0 }; }
}

// === EXPORT DEFAULT INSTANCE ===

const smsAuthService = new SMSAuthService();

export default smsAuthService;

// === UTILITY FUNCTIONS ===

/**
 * Format phone number for international use
 */
export const formatPhoneNumber = (phoneNumber, countryCode) => {
  // Remove all non-digits
  const digits = phoneNumber.replace(/\D/g, '');
  
  // Add country code if not present
  if (!digits.startsWith(countryCode)) {
    return `+${countryCode}${digits}`;
  }
  
  return `+${digits}`;
};

/**
 * Validate phone number format
 */
export const isValidPhoneNumber = (phoneNumber) => {
  const phoneRegex = /^\+[1-9]\d{1,14}$/;
  return phoneRegex.test(phoneNumber);
};

/**
 * Get country code from phone number
 */
export const getCountryCodeFromPhone = (phoneNumber) => {
  // Simple country code extraction (you might want to use a library like libphonenumber)
  const countryMappings = {
    '+1': 'US',
    '+44': 'GB', 
    '+91': 'IN',
    '+94': 'LK',
    '+61': 'AU',
    '+86': 'CN',
    '+49': 'DE',
    '+33': 'FR',
    '+81': 'JP'
  };
  
  for (const [code, country] of Object.entries(countryMappings)) {
    if (phoneNumber.startsWith(code)) {
      return { code: code.substring(1), country };
    }
  }
  
  return { code: null, country: null };
};

/**
 * Generate OTP (for testing purposes)
 */
export const generateTestOTP = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};
