// Unified Entitlements System
// Handles all subscription, response limits, and permissions logic

const dbService = require('./services/database');

function ym(date = new Date()) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, '0');
  return `${y}${m}`; // 202508
}

// Core entitlements logic
async function getEntitlements(userId, role, now = new Date()) {
  console.log('[entitlements] Getting entitlements for user:', userId, 'role:', role);
  const client = await dbService.pool.connect();
  try {
    const yearMonth = ym(now);
    const audience = role === 'business' ? 'business' : 'normal';
    console.log('[entitlements] Year month:', yearMonth, 'audience:', audience);

    // For now, assume no subscriptions - all users are free
    const subscription = null;
    let responseCount = 0;
    
    try {
      const usageRes = await client.query(
        'SELECT response_count FROM usage_monthly WHERE user_id = $1 AND year_month = $2',
        [userId, yearMonth]
      );
      responseCount = usageRes.rows[0]?.response_count || 0;
      console.log('[entitlements] Found usage count:', responseCount, 'for user:', userId);
    } catch (e) {
      // Table might not exist yet; treat as zero usage
      if (e.code === '42P01') { // undefined table
        console.warn('[entitlements] usage_monthly missing, treating count=0');
      } else {
        console.warn('[entitlements] usage query failed, treating count=0', e.message || e);
      }
      responseCount = 0;
      console.log('[entitlements] Defaulting to response count 0 due to error');
    }
    
    const freeLimit = 3;
    const canViewContact = responseCount < freeLimit;
    const canMessage = responseCount < freeLimit;
    const canRespond = responseCount < freeLimit;

    const result = {
      isSubscribed: false,
      audience,
      responseCountThisMonth: responseCount,
      canViewContact,
      canMessage,
      canRespond,
      remainingResponses: Math.max(0, freeLimit - responseCount),
      subscriptionType: 'free',
      planName: 'Free Plan',
      subscription
    };
    
    console.log('[entitlements] Returning entitlements:', JSON.stringify(result, null, 2));
    return result;
  } finally {
    client.release();
  }
}

// User entitlements API format
async function getUserEntitlements(userId) {
  try {
    const ent = await getEntitlements(userId, 'normal');
    return {
      canSeeContactDetails: ent.canViewContact,
      canSendMessages: ent.canMessage,
      canRespond: ent.canRespond,
      responseCount: ent.responseCountThisMonth,
      remainingResponses: ent.remainingResponses,
      subscriptionType: ent.subscriptionType,
      planName: ent.planName
    };
  } catch (error) {
    console.error('Error getting user entitlements:', error);
    // Return safe defaults for free user
    return {
      canSeeContactDetails: true,
      canSendMessages: true,
      canRespond: true,
      responseCount: 0,
      remainingResponses: 3,
      subscriptionType: 'free',
      planName: 'Free Plan'
    };
  }
}

// Check specific permissions
async function canSeeContactDetails(userId) {
  try {
    const ent = await getEntitlements(userId, 'normal');
    return ent.canViewContact;
  } catch (error) {
    console.error('Error checking contact details permission:', error);
    return false;
  }
}

async function canSendMessages(userId) {
  try {
    const ent = await getEntitlements(userId, 'normal');
    return ent.canMessage;
  } catch (error) {
    console.error('Error checking messaging permission:', error);
    return false;
  }
}

async function canRespond(userId) {
  try {
    const ent = await getEntitlements(userId, 'normal');
    return ent.canRespond;
  } catch (error) {
    console.error('Error checking response permission:', error);
    return false;
  }
}

// Express middleware for response entitlement checking
function requireResponseEntitlement({ enforce = false } = {}) {
  return async (req, res, next) => {
    try {
      const userId = req.user?.id; // set by auth middleware
      const role = req.user?.role; // 'normal' | 'business'
      if (!userId) return res.status(401).json({ error: 'unauthorized' });
      
      const ent = await getEntitlements(userId, role);
      req.entitlements = ent;
      
      // Only enforce limit if explicitly enabled
      if (enforce && !ent.canRespond) {
        return res.status(403).json({ 
          error: 'limit_reached', 
          message: 'Monthly response limit reached', 
          remaining: ent.remainingResponses 
        });
      }
      return next();
    } catch (e) {
      console.error('entitlement error (downgrading)', e.message || e);
      // Allow request to continue rather than failing creation
      req.entitlements = { 
        audience: 'normal', 
        isSubscribed: false, 
        responseCountThisMonth: 0, 
        canViewContact: true, 
        canMessage: true,
        canRespond: true,
        remainingResponses: 3
      };
      return next();
    }
  };
}

// Increment user's response count
async function incrementResponseCount(userId, now = new Date()) {
  console.log('[entitlements] Incrementing response count for user:', userId);
  const client = await dbService.pool.connect();
  try {
    const yearMonth = ym(now);
    console.log('[entitlements] Incrementing for year_month:', yearMonth);
    await client.query('BEGIN');
    const result = await client.query(
      `INSERT INTO usage_monthly (user_id, year_month, response_count)
       VALUES ($1, $2, 1)
       ON CONFLICT (user_id, year_month)
       DO UPDATE SET response_count = usage_monthly.response_count + 1, updated_at = now()`,
      [userId, yearMonth]
    );
    await client.query('COMMIT');
    console.log('[entitlements] Successfully incremented response count for user:', userId);
    console.log(`[entitlements] Incremented response count for user ${userId} in ${yearMonth}`);
  } catch (e) {
    await client.query('ROLLBACK');
    console.error(`[entitlements] Failed to increment response count:`, e);
    throw e;
  } finally {
    client.release();
  }
}

// Express routes for entitlements API
function createRoutes() {
  const express = require('express');
  const router = express.Router();

  // Get user's current entitlements (simple version with user_id param)
  router.get('/me', async (req, res) => {
    try {
      const userId = req.query.user_id || req.user?.id;
      if (!userId) {
        return res.status(400).json({
          success: false,
          error: 'user_id parameter required'
        });
      }
      
      const entitlements = await getUserEntitlements(userId);
      
      res.json({
        success: true,
        data: entitlements
      });
    } catch (error) {
      console.error('Error getting user entitlements:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to get entitlements'
      });
    }
  });

  // Check if user can see contact details
  router.get('/contact-details', async (req, res) => {
    try {
      const userId = req.query.user_id || req.user?.id;
      if (!userId) {
        return res.status(400).json({
          success: false,
          error: 'user_id parameter required'
        });
      }
      
      const canSee = await canSeeContactDetails(userId);
      
      res.json({
        success: true,
        data: { canSeeContactDetails: canSee }
      });
    } catch (error) {
      console.error('Error checking contact details permission:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to check contact details permission'
      });
    }
  });

  // Check if user can respond to requests
  router.get('/respond', async (req, res) => {
    try {
      const userId = req.query.user_id || req.user?.id;
      if (!userId) {
        return res.status(400).json({
          success: false,
          error: 'user_id parameter required'
        });
      }
      
      const can = await canRespond(userId);
      
      res.json({
        success: true,
        data: { canRespond: can }
      });
    } catch (error) {
      console.error('Error checking response permission:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to check response permission'
      });
    }
  });

  return router;
}

module.exports = { 
  getEntitlements, 
  requireResponseEntitlement, 
  incrementResponseCount,
  getUserEntitlements,
  canSeeContactDetails,
  canSendMessages,
  canRespond,
  createRoutes
};
