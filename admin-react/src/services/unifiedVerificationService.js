import api from './apiClient';

/**
 * Unified Verification Service for Admin Panel
 * 
 * This service provides access to the unified verification system
 * that checks across users, business_verifications, and driver_verifications tables
 */

class UnifiedVerificationService {
  
  /**
   * Get complete verification status for a user
   * @param {string} userId - User ID to check
   * @param {Object} options - Optional parameters
   * @param {string} options.phone - Specific phone to check
   * @param {string} options.email - Specific email to check  
   * @param {boolean} options.debug - Include debug information
   * @returns {Promise<Object>} Unified verification status
   */
  async getUserVerificationStatus(userId, options = {}) {
    try {
      const params = new URLSearchParams();
      if (options.phone) params.append('phone', options.phone);
      if (options.email) params.append('email', options.email);
      if (options.debug) params.append('debug', 'true');

      const url = `/unified-verification/user/${userId}${params.toString() ? '?' + params.toString() : ''}`;
      const response = await api.get(url);
      
      return response.data.data;
    } catch (error) {
      console.error('Error fetching unified verification status:', error);
      throw new Error(error.response?.data?.message || 'Failed to fetch verification status');
    }
  }

  /**
   * Get verification status for multiple users (bulk operation)
   * @param {string[]} userIds - Array of user IDs
   * @param {boolean} includeDebugInfo - Include debug information
   * @returns {Promise<Object>} Bulk verification results
   */
  async getBulkVerificationStatus(userIds, includeDebugInfo = false) {
    try {
      const response = await api.post('/unified-verification/bulk-check', {
        userIds,
        includeDebugInfo
      });
      
      return response.data.data;
    } catch (error) {
      console.error('Error fetching bulk verification status:', error);
      throw new Error(error.response?.data?.message || 'Failed to fetch bulk verification status');
    }
  }

  /**
   * Get verification service health status
   * @returns {Promise<Object>} Service health information
   */
  async getServiceHealth() {
    try {
      const response = await api.get('/unified-verification/health');
      return response.data;
    } catch (error) {
      console.error('Error fetching verification service health:', error);
      throw new Error('Verification service unavailable');
    }
  }

  /**
   * Enhanced user mapping with unified verification status
   * @param {Object} user - Basic user object
   * @param {Object} verificationStatus - Unified verification status
   * @returns {Object} Enhanced user object
   */
  mapUserWithUnifiedVerification(user, verificationStatus) {
    if (!user) return null;
    
    // Get unified verification results
    const phoneVerification = verificationStatus?.verification?.phone || {};
    const emailVerification = verificationStatus?.verification?.email || {};
    const businessVerification = verificationStatus?.verification?.business || {};
    const driverVerification = verificationStatus?.verification?.driver || {};

    return {
      ...user,
      // Enhanced verification information
      verification: {
        phone: {
          isVerified: phoneVerification.isVerified || false,
          verificationSource: phoneVerification.verificationSource,
          phoneNumber: phoneVerification.phoneNumber,
          normalizedPhone: phoneVerification.normalizedPhone,
          requiresManualVerification: phoneVerification.requiresManualVerification
        },
        email: {
          isVerified: emailVerification.isVerified || false,
          verificationSource: emailVerification.verificationSource,
          email: emailVerification.email,
          normalizedEmail: emailVerification.normalizedEmail,
          requiresManualVerification: emailVerification.requiresManualVerification
        },
        business: businessVerification,
        driver: driverVerification
      },
      // Legacy fields for backward compatibility
      emailVerified: emailVerification.isVerified || user.email_verified || false,
      phoneVerified: phoneVerification.isVerified || user.phone_verified || false,
      // Enhanced verification status
      isFullyVerified: (phoneVerification.isVerified && emailVerification.isVerified),
      hasBusinessVerification: !!businessVerification,
      hasDriverVerification: !!driverVerification,
      verificationScore: this.calculateVerificationScore(phoneVerification, emailVerification, businessVerification, driverVerification)
    };
  }

  /**
   * Calculate a verification score (0-100) based on verification status
   * @param {Object} phoneVerification - Phone verification status
   * @param {Object} emailVerification - Email verification status
   * @param {Object} businessVerification - Business verification status  
   * @param {Object} driverVerification - Driver verification status
   * @returns {number} Verification score (0-100)
   */
  calculateVerificationScore(phoneVerification, emailVerification, businessVerification, driverVerification) {
    let score = 0;
    
    // Basic verification (40 points total)
    if (phoneVerification?.isVerified) score += 20;
    if (emailVerification?.isVerified) score += 20;
    
    // Business verification (30 points)
    if (businessVerification) {
      if (businessVerification.status === 'approved') score += 30;
      else if (businessVerification.status === 'pending') score += 15;
    }
    
    // Driver verification (30 points)
    if (driverVerification) {
      if (driverVerification.status === 'approved') score += 30;
      else if (driverVerification.status === 'pending') score += 15;
    }
    
    return Math.min(score, 100);
  }

  /**
   * Format verification status for admin display
   * @param {Object} verificationStatus - Unified verification status
   * @returns {Object} Formatted status for UI display
   */
  formatVerificationForDisplay(verificationStatus) {
    const phone = verificationStatus?.verification?.phone || {};
    const email = verificationStatus?.verification?.email || {};
    const business = verificationStatus?.verification?.business || {};
    const driver = verificationStatus?.verification?.driver || {};

    return {
      phone: {
        status: phone.isVerified ? 'verified' : 'unverified',
        source: phone.verificationSource || 'none',
        display: phone.normalizedPhone || phone.phoneNumber || 'No phone',
        badge: phone.isVerified ? '✅' : '❌',
        needsAttention: phone.requiresManualVerification
      },
      email: {
        status: email.isVerified ? 'verified' : 'unverified', 
        source: email.verificationSource || 'none',
        display: email.normalizedEmail || email.email || 'No email',
        badge: email.isVerified ? '✅' : '❌',
        needsAttention: email.requiresManualVerification
      },
      business: {
        hasVerification: !!business,
        status: business?.status || 'none',
        phone: business?.businessPhone || 'N/A',
        email: business?.businessEmail || 'N/A',
        phoneVerified: business?.phoneVerified || false,
        emailVerified: business?.emailVerified || false
      },
      driver: {
        hasVerification: !!driver,
        status: driver?.status || 'none', 
        phone: driver?.phoneNumber || 'N/A',
        email: driver?.email || 'N/A',
        phoneVerified: driver?.phoneVerified || false,
        emailVerified: driver?.emailVerified || false
      },
      overall: {
        score: this.calculateVerificationScore(phone, email, business, driver),
        isComplete: phone.isVerified && email.isVerified,
        summary: this.getVerificationSummary(phone, email, business, driver)
      }
    };
  }

  /**
   * Get a human-readable verification summary
   * @param {Object} phone - Phone verification status
   * @param {Object} email - Email verification status
   * @param {Object} business - Business verification status
   * @param {Object} driver - Driver verification status
   * @returns {string} Verification summary
   */
  getVerificationSummary(phone, email, business, driver) {
    const phoneStatus = phone?.isVerified ? 'Phone ✅' : 'Phone ❌';
    const emailStatus = email?.isVerified ? 'Email ✅' : 'Email ❌';
    
    let businessStatus = '';
    if (business) {
      businessStatus = ` | Business: ${business.status}`;
    }
    
    let driverStatus = '';
    if (driver) {
      driverStatus = ` | Driver: ${driver.status}`;
    }
    
    return `${phoneStatus} | ${emailStatus}${businessStatus}${driverStatus}`;
  }
}

const unifiedVerificationService = new UnifiedVerificationService();
export default unifiedVerificationService;
