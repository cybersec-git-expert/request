// Entitlements service for managing user subscription and response limits
// This enforces proper response limits and contact visibility

const db = require('./database');

/**
 * Get user entitlements with proper limit enforcement
 * @param {string} userId - User ID
 * @param {string} role - User role
 * @returns {object} User entitlements
 */
async function getEntitlements(userId, role) {
  try {
    // Source of truth: usage_monthly (year_month as YYYYMM, response_count)
    const now = new Date();
    const ym = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}`; // e.g., 202509

    let responseCountThisMonth = 0;
    const r = await db.query(
      `SELECT response_count FROM usage_monthly WHERE user_id = $1 AND year_month = $2`,
      [userId, ym]
    );
    if (r?.rows?.length) {
      responseCountThisMonth = Number(r.rows[0].response_count) || 0;
      console.log(`[entitlements] usage_monthly count for ${userId} @ ${ym} = ${responseCountThisMonth}`);
    } else {
      // No row => zero used
      responseCountThisMonth = 0;
      console.log(`[entitlements] usage_monthly no row for ${userId} @ ${ym}, defaulting to 0`);
    }
    
    // Calculate remaining responses (3 per month for free tier)
    const freeMonthlyLimit = 3;
    const remainingResponses = Math.max(0, freeMonthlyLimit - responseCountThisMonth);
    const canRespond = remainingResponses > 0;
    
  // Hide contact details if user has reached limit (note: request detail endpoint may override when user hasResponded)
  const canSeeContactDetails = remainingResponses > 0;
  const canSendMessages = remainingResponses > 0;
    
    return {
      canSeeContactDetails,
      canSendMessages,
      canRespond,
      responseCount: responseCountThisMonth,
      responseCountThisMonth: responseCountThisMonth, // for Flutter mapping
      remainingResponses,
      subscriptionType: 'free',
      planName: 'Free Plan',
      canViewContact: canSeeContactDetails,
      canMessage: canSendMessages
    };
  } catch (error) {
    console.error('[entitlements] Error in getEntitlements:', error);
    // Return restrictive defaults on error
    return {
      canSeeContactDetails: false,
      canSendMessages: false,
      canRespond: false,
      responseCount: 3,
      responseCountThisMonth: 3,
      remainingResponses: 0,
      subscriptionType: 'free',
      planName: 'Free Plan',
      canViewContact: false,
      canMessage: false
    };
  }
}

/**
 * Check if user can see contact details
 * @param {string} userId - User ID
 * @returns {boolean}
 */
async function canSeeContactDetails(userId) {
  try {
    const entitlements = await getEntitlements(userId);
    return entitlements.canSeeContactDetails;
  } catch (error) {
    console.error('[entitlements] Error checking contact details:', error);
    return false; // Restrictive default
  }
}

/**
 * Check if user can send messages
 * @param {string} userId - User ID
 * @returns {boolean}
 */
async function canSendMessages(userId) {
  try {
    const entitlements = await getEntitlements(userId);
    return entitlements.canSendMessages;
  } catch (error) {
    console.error('[entitlements] Error checking messaging:', error);
    return false; // Restrictive default
  }
}

/**
 * Check if user can respond to requests
 * @param {string} userId - User ID
 * @returns {boolean}
 */
async function canRespond(userId) {
  try {
    const entitlements = await getEntitlements(userId);
    return entitlements.canRespond;
  } catch (error) {
    console.error('[entitlements] Error checking respond permission:', error);
    return false; // Restrictive default
  }
}

/**
 * Middleware to require response entitlement
 * @param {object} options - Options for the middleware
 * @returns {function} Express middleware function
 */
function requireResponseEntitlement(options = {}) {
  return async (req, res, next) => {
    try {
      const userId = req.user?.id || req.user?.userId;
      if (!userId) {
        return res.status(401).json({ 
          success: false, 
          error: 'Authentication required' 
        });
      }

      const entitlements = await getEntitlements(userId);
      if (!entitlements.canRespond) {
        return res.status(403).json({ 
          success: false, 
          error: 'Response limit reached. Please upgrade your plan.',
          remainingResponses: entitlements.remainingResponses
        });
      }

      // Add entitlements to request for use in route handlers
      req.entitlements = entitlements;
      next();
    } catch (error) {
      console.error('[entitlements] Middleware error:', error);
      return res.status(500).json({ 
        success: false, 
        error: 'Failed to check entitlements' 
      });
    }
  };
}

module.exports = {
  getEntitlements,
  canSeeContactDetails,
  canSendMessages,
  canRespond,
  requireResponseEntitlement
};
