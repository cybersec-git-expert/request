// Fixed entitlements.js - Works with existing database service and adds IAM token support
const AWS = require('aws-sdk');

// Try to use existing database service, fallback to manual pool creation
let dbService;
try {
  dbService = require('./services/database');
} catch (error) {
  console.log('Using fallback database connection');
  const { Pool } = require('pg');
  
  // IAM token generator
  const rdsigner = new AWS.RDS.Signer({
    region: process.env.AWS_REGION || 'us-east-1'
  });

  async function generateIAMToken() {
    try {
      const token = await rdsigner.getAuthToken({
        hostname: process.env.DB_HOST,
        port: parseInt(process.env.DB_PORT) || 5432,
        username: process.env.DB_USERNAME,
        region: process.env.AWS_REGION || 'us-east-1'
      });
      return token;
    } catch (error) {
      console.error('Failed to generate IAM token:', error);
      return process.env.DB_PASSWORD; // fallback to password
    }
  }

  // Create pool with IAM or password auth
  let pool;
  async function initPool() {
    try {
      let password = process.env.DB_PASSWORD;
      
      if (process.env.DB_IAM_AUTH === 'true') {
        console.log('🔐 Attempting IAM authentication...');
        password = await generateIAMToken();
      }

      pool = new Pool({
        host: process.env.DB_HOST,
        port: parseInt(process.env.DB_PORT) || 5432,
        database: process.env.DB_NAME,
        user: process.env.DB_USERNAME,
        password: password,
        ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
        max: parseInt(process.env.DB_MAX_CONNECTIONS) || 20,
        idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT) || 30000,
        connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT) || 60000,
      });

      // Test connection
      const client = await pool.connect();
      client.release();
      console.log('✅ Database connection established');
    } catch (error) {
      console.error('❌ Database connection failed:', error.message);
      
      // Fallback to password auth if IAM fails
      if (process.env.DB_IAM_AUTH === 'true' && process.env.DB_PASSWORD) {
        console.log('🔄 Falling back to password authentication...');
        pool = new Pool({
          host: process.env.DB_HOST,
          port: parseInt(process.env.DB_PORT) || 5432,
          database: process.env.DB_NAME,
          user: process.env.DB_USERNAME,
          password: process.env.DB_PASSWORD,
          ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
        });
      }
    }
  }

  // Initialize pool
  initPool();

  // Fallback database service
  dbService = {
    query: async (text, params) => {
      if (!pool) await initPool();
      return await pool.query(text, params);
    }
  };
}

function ym(date = new Date()) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, '0');
  return `${y}${m}`; // 202508
}

async function getEntitlements(userId, role, now = new Date()) {
  try {
    const yearMonth = ym(now);
    const audience = role === 'business' ? 'business' : 'normal';
    const subscription = null;
    
    let responseCount = 0;
    try {
      const usageRes = await dbService.query(
        'SELECT response_count FROM usage_monthly WHERE user_id = $1 AND year_month = $2',
        [userId, yearMonth]
      );
      responseCount = usageRes.rows[0]?.response_count || 0;
    } catch (error) {
      console.log('Usage query failed, defaulting to 0:', error.message);
      responseCount = 0;
    }
    
    const freeLimit = 3;
    let canViewContact = responseCount < freeLimit;
    let canMessage = canViewContact;

    return {
      isSubscribed: false,
      audience,
      responseCountThisMonth: responseCount,
      canViewContact,
      canMessage,
      subscription
    };
  } catch (error) {
    console.error('Error in getEntitlements:', error);
    return {
      isSubscribed: false,
      audience: role === 'business' ? 'business' : 'normal',
      responseCountThisMonth: 0,
      canViewContact: true,
      canMessage: true,
      subscription: null
    };
  }
}

function requireResponseEntitlement() {
  return async (req, res, next) => {
    try {
      const userId = req.user?.id;
      const role = req.user?.role;
      if (!userId) return res.status(401).json({ error: 'unauthorized' });
      
      const ent = await getEntitlements(userId, role);
      req.entitlements = ent;
      
      if (ent.audience === 'normal' && !ent.isSubscribed && ent.canMessage !== true) {
        return res.status(402).json({ 
          error: 'limit_reached', 
          message: 'Monthly response limit reached',
          responseCount: ent.responseCountThisMonth,
          limit: 3
        });
      }
      return next();
    } catch (e) {
      console.error('entitlement error', e);
      return res.status(500).json({ error: 'entitlement_failed' });
    }
  };
}

async function incrementResponseCount(userId, now = new Date()) {
  try {
    const yearMonth = ym(now);
    await dbService.query(
      `INSERT INTO usage_monthly (user_id, year_month, response_count, created_at, updated_at)
       VALUES ($1, $2, 1, now(), now())
       ON CONFLICT (user_id, year_month)
       DO UPDATE SET response_count = usage_monthly.response_count + 1, updated_at = now()`,
      [userId, yearMonth]
    );
    console.log(`✅ Incremented response count for user ${userId}`);
  } catch (e) {
    console.error('Error incrementing response count:', e);
  }
}

module.exports = { getEntitlements, requireResponseEntitlement, incrementResponseCount };
