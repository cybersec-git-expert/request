const fs = require('fs');
const path = require('path');
const database = require('./services/database');

async function runMigrations() {
  try {
    console.log('🚀 Starting subscription system migrations...');
    
    // Migration 1: Fix UUID mapping issue
    console.log('1. Fixing business type mappings UUID issue...');
    const fixMappingSQL = `
      DROP TABLE IF EXISTS business_type_plan_allowed_request_types CASCADE;
      DROP TABLE IF EXISTS business_type_plan_mappings CASCADE;

      CREATE TABLE IF NOT EXISTS business_type_plan_mappings (
        id SERIAL PRIMARY KEY,
        country_code VARCHAR(10) NOT NULL,
        business_type_id UUID NOT NULL REFERENCES business_types(id) ON DELETE CASCADE,
        plan_id INTEGER NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
        is_active BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
        UNIQUE(country_code, business_type_id, plan_id)
      );

      CREATE OR REPLACE FUNCTION trg_update_business_type_plan_mappings_updated_at()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.updated_at = NOW();
        RETURN NEW;
      END; $$ LANGUAGE plpgsql;

      DROP TRIGGER IF EXISTS trg_business_type_plan_mappings_updated_at ON business_type_plan_mappings;
      CREATE TRIGGER trg_business_type_plan_mappings_updated_at
      BEFORE UPDATE ON business_type_plan_mappings
      FOR EACH ROW EXECUTE FUNCTION trg_update_business_type_plan_mappings_updated_at();

      CREATE TABLE IF NOT EXISTS business_type_plan_allowed_request_types (
        id SERIAL PRIMARY KEY,
        mapping_id INTEGER NOT NULL REFERENCES business_type_plan_mappings(id) ON DELETE CASCADE,
        request_type VARCHAR(50) NOT NULL,
        is_active BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMP NOT NULL DEFAULT NOW(),
        UNIQUE(mapping_id, request_type)
      );
    `;
    await database.query(fixMappingSQL);
    console.log('✅ Fixed UUID mapping issue');

    // Migration 2: Create 4 subscription plans
    console.log('2. Creating 4 subscription plans...');
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

    // Migration 3: Set LK pricing
    console.log('3. Setting LK pricing...');
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
    console.log('4. Verifying plans...');
    const verifyPlans = await database.query(`SELECT code, name, plan_type, status FROM subscription_plans WHERE code LIKE 'pro_%'`);
    console.table(verifyPlans.rows);

    console.log('5. Verifying LK pricing...');
    const verifyPricing = await database.query(`
      SELECT sp.code, sp.name, scs.currency, scs.price, scs.ppc_price 
      FROM subscription_plans sp 
      JOIN subscription_country_settings scs ON sp.id = scs.plan_id 
      WHERE scs.country_code = 'LK'
    `);
    console.table(verifyPricing.rows);

    console.log('🎉 Subscription system migration completed successfully!');
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    process.exit(0);
  }
}

runMigrations().catch(console.error);
