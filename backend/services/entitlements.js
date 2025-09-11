// Entitlements Service - Simplified for CI/CD deployment
// Handles user subscription and response limits

/**
 * Get user entitlements (simplified version)
 * @param {string} userId - User ID
 * @param {string} role - User role (optional)
 * @returns {object} User entitlements
 */
async function getEntitlements(userId, role = null) {
  // Simplified - everyone has full access for now
  // This was changed after CI/CD deployment to remove complex subscription logic
  return {
    canSeeContactDetails: true,
    canSendMessages: true,
    canRespond: true,
    responseCount: 0,
    remainingResponses: -1, // unlimited
    subscriptionType: 'free',
    planName: 'Free Plan',
    canViewContact: true,
    canMessage: true,
    audience: 'normal',
    isSubscribed: false
  };
}

/**
 * Check if user can see contact details
 * @param {string} userId - User ID
 * @returns {boolean}
 */
async function canSeeContactDetails(userId) {
  return true; // Simplified - everyone can see contact details
}

/**
 * Check if user can send messages
 * @param {string} userId - User ID
 * @returns {boolean}
 */
async function canSendMessages(userId) {
  return true; // Simplified - everyone can send messages
}

/**
 * Check if user can respond to requests
 * @param {string} userId - User ID
 * @returns {boolean}
 */
async function canRespond(userId) {
  return true; // Simplified - everyone can respond
}

/**
 * Middleware to require response entitlement
 * @param {object} options - Options for the middleware
 * @returns {function} Express middleware function
 */
function requireResponseEntitlement(options = {}) {
  return async (req, res, next) => {
    // Simplified - allow all responses for now
    // In the future, this could check actual subscription limits
    try {
      const userId = req.user?.id || req.user?.userId;
      if (!userId && options.enforce) {
        return res.status(401).json({
          success: false,
          error: 'Authentication required'
        });
      }
      
      // For now, always allow
      next();
    } catch (error) {
      console.error('Error in requireResponseEntitlement middleware:', error);
      if (options.enforce) {
        return res.status(500).json({
          success: false,
          error: 'Failed to check entitlements'
        });
      }
      next();
    }
  };
}

/**
 * Get user entitlements for API response
 * @param {string} userId - User ID
 * @returns {object} API-formatted entitlements
 */
async function getUserEntitlements(userId) {
  const entitlements = await getEntitlements(userId);
  return {
    canRespond: entitlements.canRespond,
    responseCountThisMonth: entitlements.responseCount,
    remainingResponses: entitlements.remainingResponses,
    canViewContact: entitlements.canViewContact,
    canMessage: entitlements.canMessage,
    audience: entitlements.audience,
    isSubscribed: entitlements.isSubscribed
  };
}

module.exports = {
  getEntitlements,
  canSeeContactDetails,
  canSendMessages,
  canRespond,
  requireResponseEntitlement,
  getUserEntitlements
};
