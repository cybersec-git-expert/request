const database = require('./services/database');

async function runSimpleMigration() {
  try {
    console.log('🚀 Starting simple subscription plans migration...');
    
    // Migration 1: Create 4 subscription plans
    console.log('1. Creating 4 subscription plans...');
    await database.query(`DELETE FROM subscription_plans WHERE code IN ('pro_responder', 'pro_driver', 'pro_seller_monthly', 'pro_seller_ppc')`);
    
    const plans = [
      ['pro_responder', 'Pro Responder', 'Unlimited responses for general businesses - Monthly Rs 5000', 'unlimited', null, 'active'],
      ['pro_driver', 'Pro Driver', 'Unlimited responses for drivers (ride + common requests) - Monthly Rs 7500', 'unlimited', null, 'active'],
      ['pro_seller_monthly', 'Pro Seller Monthly', 'Unlimited responses + price comparison access - Monthly Rs 4500', 'unlimited', null, 'active'],
      ['pro_seller_ppc', 'Pro Seller PPC', 'Pay per click for price comparison - Rs 100 per click', 'ppc', 3, 'active']
    ];

    for (const plan of plans) {
      await database.query(
        `INSERT INTO subscription_plans (code, name, description, plan_type, default_responses_per_month, status) VALUES ($1, $2, $3, $4, $5, $6)`,
        plan
      );
    }
    console.log('✅ Created 4 subscription plans');

    // Migration 2: Set LK pricing
    console.log('2. Setting LK pricing...');
    await database.query(`DELETE FROM subscription_country_settings WHERE country_code = 'LK'`);
    
    const plansResult = await database.query(`SELECT id, code FROM subscription_plans WHERE code IN ('pro_responder', 'pro_driver', 'pro_seller_monthly', 'pro_seller_ppc')`);
    const plansMap = {};
    plansResult.rows.forEach(row => {
      plansMap[row.code] = row.id;
    });

    const pricing = [
      [plansMap.pro_responder, 'LK', 'LKR', 5000.00, null, null, true],
      [plansMap.pro_driver, 'LK', 'LKR', 7500.00, null, null, true],
      [plansMap.pro_seller_monthly, 'LK', 'LKR', 4500.00, null, null, true],
      [plansMap.pro_seller_ppc, 'LK', 'LKR', null, 3, 100.00, true]
    ];

    for (const price of pricing) {
      await database.query(
        `INSERT INTO subscription_country_settings (plan_id, country_code, currency, price, responses_per_month, ppc_price, is_active) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        price
      );
    }
    console.log('✅ Set LK pricing');

    // Verification
    console.log('3. Verifying plans...');
    const verifyPlans = await database.query(`SELECT code, name, plan_type, status FROM subscription_plans WHERE code LIKE 'pro_%'`);
    console.table(verifyPlans.rows);

    console.log('4. Verifying LK pricing...');
    const verifyPricing = await database.query(`
      SELECT sp.code, sp.name, scs.currency, scs.price, scs.ppc_price 
      FROM subscription_plans sp 
      JOIN subscription_country_settings scs ON sp.id = scs.plan_id 
      WHERE scs.country_code = 'LK'
    `);
    console.table(verifyPricing.rows);

    console.log('🎉 Subscription plans migration completed successfully!');
    console.log('🔧 The original UUID error in the admin should now be fixed.');
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    process.exit(0);
  }
}

runSimpleMigration().catch(console.error);
