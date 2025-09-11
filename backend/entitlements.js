// Simplified entitlements service for the backend
// This provides basic entitlements functionality after CI/CD deployment simplification

/**
 * Get user entitlements (simplified version)
 * @param {string} userId - User ID
 * @param {string} role - User role
 * @returns {object} User entitlements
 */
async function getEntitlements(userId, role) {
  // Simplified - everyone has full access for now
  return {
    canSeeContactDetails: true,
    canSendMessages: true,
    canRespond: true,
    responseCount: 0,
    remainingResponses: -1, // unlimited
    subscriptionType: 'free',
    planName: 'Free Plan',
    canViewContact: true,
    canMessage: true
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

module.exports = {
  getEntitlements,
  canSeeContactDetails,
  canSendMessages,
  canRespond
};
