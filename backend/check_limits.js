const db = require('./services/database');

async function checkLimits() {
  try {
    const result = await db.query(`SELECT plan_code, country_code, response_limit FROM subscription_country_pricing WHERE country_code = 'LK'`);
    console.log('Current response limits for LK:', result.rows);
    process.exit(0);
  } catch (error) {
    console.error('Query failed:', error.message);
    process.exit(1);
  }
}

checkLimits();
