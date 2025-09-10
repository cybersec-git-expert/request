// Simplified Unified Entitlements System
const { Pool } = require('pg');
const pool = new Pool();

function ym(date = new Date()) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, '0');
  return `${y}${m}`;
}

// Core entitlements logic
async function getEntitlements(userId, role, now = new Date()) {
  const client = await pool.connect();
  try {
    const yearMonth = ym(now);
    const audience = role === 'business' ? 'business' : 'normal';

    let responseCount = 0;
    try {
      const usageRes = await client.query(
        'SELECT response_count FROM usage_monthly WHERE user_id = $1 AND year_month = $2',
        [userId, yearMonth]
      );
      responseCount = usageRes.rows[0]?.response_count || 0;
    } catch (e) {
      if (e.code === '42P01') {
        console.warn('[entitlements] usage_monthly missing, treating count=0');
      } else {
        console.warn('[entitlements] usage query failed, treating count=0', e.message || e);
      }
      responseCount = 0;
    }
    
    const freeLimit = 3;
    const canViewContact = responseCount < freeLimit;
    const canMessage = responseCount < freeLimit;
    const canRespond = responseCount < freeLimit;

    return {
      isSubscribed: false,
      audience,
      responseCountThisMonth: responseCount,
      canViewContact,
      canMessage,
      canRespond,
      remainingResponses: Math.max(0, freeLimit - responseCount),
      subscriptionType: 'free',
      planName: 'Free Plan'
    };
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

// Express middleware for response entitlement checking
function requireResponseEntitlement({ enforce = false } = {}) {
  return async (req, res, next) => {
    try {
      const userId = req.user?.id;
      const role = req.user?.role;
      if (!userId) return res.status(401).json({ error: 'unauthorized' });
      
      const ent = await getEntitlements(userId, role);
      req.entitlements = ent;
      
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
  const client = await pool.connect();
  try {
    const yearMonth = ym(now);
    await client.query('BEGIN');
    await client.query(
      `INSERT INTO usage_monthly (user_id, year_month, response_count)
       VALUES ($1, $2, 1)
       ON CONFLICT (user_id, year_month)
       DO UPDATE SET response_count = usage_monthly.response_count + 1, updated_at = now()`,
      [userId, yearMonth]
    );
    await client.query('COMMIT');
    console.log(`[entitlements] Incremented response count for user ${userId} in ${yearMonth}`);
  } catch (e) {
    await client.query('ROLLBACK');
    console.error(`[entitlements] Failed to increment response count:`, e);
    throw e;
  } finally {
    client.release();
  }
}

module.exports = { 
  getEntitlements, 
  requireResponseEntitlement, 
  incrementResponseCount,
  getUserEntitlements
};
