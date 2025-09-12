const db = require('./services/database');

async function testPlansQuery() {
  try {
    console.log('Testing plans query for LK...');
    
    const result = await db.query(`
      SELECT 
        ssp.code,
        ssp.name,
        ssp.description,
        ssp.features,
        scp.price,
        scp.currency,
        scp.response_limit,
        scp.is_active as country_pricing_active,
        scp.created_at as pricing_created_at
      FROM simple_subscription_plans ssp
      INNER JOIN subscription_country_pricing scp 
        ON ssp.code = scp.plan_code 
      WHERE scp.country_code = $1 
        AND scp.is_active = true
        AND ssp.is_active = true 
      ORDER BY scp.price ASC
    `, ['LK']);
    
    console.log('Query successful!');
    console.log('Results:', JSON.stringify(result.rows, null, 2));
    process.exit(0);
  } catch (error) {
    console.error('Query failed:', error);
    process.exit(1);
  }
}

testPlansQuery();
