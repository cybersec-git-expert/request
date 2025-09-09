// Minimal entitlement resolver and middleware
// Assumes Express app and Postgres via a db client (pg)

const { Pool } = require('pg');
const pool = new Pool();

function ym(date = new Date()) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, '0');
  return `${y}${m}`; // 202508
}

async function getEntitlements(userId, role, now = new Date()) {
  const client = await pool.connect();
  try {
    const yearMonth = ym(now);
    const audience = role === 'business' ? 'business' : 'normal';

    // Subscriptions removed: always assume no active subscription
    const subscription = null;
    const usageRes = await client.query(
      'SELECT response_count FROM usage_monthly WHERE user_id = $1 AND year_month = $2',
      [userId, yearMonth]
    );
    const responseCount = usageRes.rows[0]?.response_count || 0;
    const freeLimit = 3;
  let canViewContact = responseCount < freeLimit;
  // New logic: allow messaging/responding by default; only block after limit
  let canMessage = true;

    return {
      isSubscribed: false,
      audience,
      responseCountThisMonth: responseCount,
      canViewContact,
      canMessage,
      subscription
    };
  } finally {
    client.release();
  }
}

function requireResponseEntitlement({ enforce = false } = {}) {
  return async (req, res, next) => {
    try {
      const userId = req.user?.id; // set by auth middleware
      const role = req.user?.role; // 'normal' | 'business'
      if (!userId) return res.status(401).json({ error: 'unauthorized' });
      const ent = await getEntitlements(userId, role);
      req.entitlements = ent;
      // Only enforce limit if explicitly enabled (future subscription feature)
      if (enforce && ent.responseCountThisMonth >= 3 && !ent.isSubscribed) {
        return res.status(403).json({ error: 'limit_reached', message: 'Monthly response limit reached', remaining: 0 });
      }
      return next();
    } catch (e) {
      console.error('entitlement error', e);
      return res.status(500).json({ error: 'entitlement_failed' });
    }
  };
}

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
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

module.exports = { getEntitlements, requireResponseEntitlement, incrementResponseCount };
