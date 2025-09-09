// Minimal entitlefunction ym(date = new Date()) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  return `${y}${m}`; // 202509
}resolver and middleware
// Uses proper database configuration from environment variables

const { Pool } = require("pg");

// Use proper database configuration from environment variables
const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USERNAME,
  password: process.env.DB_PASSWORD,
  ssl: process.env.DB_SSL === "true" ? { rejectUnauthorized: false } : false,
  max: parseInt(process.env.DB_MAX_CONNECTIONS) || 20,
  idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT) || 30000,
  connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT) || 60000
});

function ym(date = new Date()) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  return ${y}; // 202509
}

async function getEntitlements(userId, role, now = new Date()) {
  const client = await pool.connect();
  try {
    const yearMonth = ym(now);
    const audience = role === "business" ? "business" : "normal";

    // Subscriptions removed: always assume no active subscription
    const subscription = null;
    
    // Check if usage_monthly table exists, if not, assume 0 responses
    let responseCount = 0;
    try {
      const usageRes = await client.query(
        "SELECT response_count FROM usage_monthly WHERE user_id =  AND year_month = ",
        [userId, yearMonth]
      );
      responseCount = usageRes.rows[0]?.response_count || 0;
    } catch (err) {
      // If usage_monthly table doesnt exist, count actual responses from responses table
      try {
        const countRes = await client.query(
          "SELECT COUNT(*) as count FROM responses WHERE user_id =  AND EXTRACT(year FROM created_at) =  AND EXTRACT(month FROM created_at) = ",
          [userId, now.getFullYear(), now.getMonth() + 1]
        );
        responseCount = parseInt(countRes.rows[0]?.count) || 0;
      } catch (err2) {
        console.warn("Could not count responses:", err2.message);
        responseCount = 0;
      }
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
      subscription: null,
      canRespond: canMessage, // Same as canMessage for simplicity
      remainingResponses: Math.max(0, freeLimit - responseCount)
    };
  } finally {
    client.release();
  }
}

module.exports = { getEntitlements };
