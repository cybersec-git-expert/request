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
    // Prefer the same source used by simple-subscription-service (user_usage, YYYY-MM)
    const now = new Date();
    const ymDash = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`; // e.g., 2025-09

    let responseCountThisMonth = 0;
    try {
      const r = await db.query(
        `SELECT responses_used FROM user_usage WHERE user_id = $1 AND month_year = $2`,
        [userId, ymDash]
      );
      if (r?.rows?.length) {
        responseCountThisMonth = Number(r.rows[0].responses_used) || 0;
        console.log(`[entitlements] user_usage count for ${userId} @ ${ymDash} = ${responseCountThisMonth}`);
      } else {
        // Fallback: derive from responses table for current month
        const start = new Date(now.getFullYear(), now.getMonth(), 1);
        const end = new Date(now.getFullYear(), now.getMonth() + 1, 1);
        const derived = await db.query(
          `SELECT COUNT(*)::int AS cnt FROM responses WHERE user_id = $1 AND created_at >= $2 AND created_at < $3`,
          [userId, start.toISOString(), end.toISOString()]
        );
        responseCountThisMonth = derived?.rows?.[0]?.cnt || 0;
        console.log(`[entitlements] derived responses count for ${userId} = ${responseCountThisMonth}`);
      }
    } catch (dbError) {
      console.warn('[entitlements] usage lookup failed, defaulting to 0', dbError?.message || dbError);
    }
    
    // Calculate remaining responses (3 per month for free tier)
    const freeMonthlyLimit = 3;
    const remainingResponses = Math.max(0, freeMonthlyLimit - responseCountThisMonth);
    const canRespond = remainingResponses > 0;
    
    // Hide contact details if user has reached limit
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
