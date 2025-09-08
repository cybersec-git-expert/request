const dbService = require('./services/database');

async function createEnhancedBenefitsTable() {
  const client = await dbService.pool.connect();
  
  try {
    console.log('Creating enhanced_business_benefits table...');
    
    // Create the table
    await client.query(`
      CREATE TABLE IF NOT EXISTS enhanced_business_benefits (
        id SERIAL PRIMARY KEY,
        country_id INTEGER NOT NULL,
        business_type_id UUID NOT NULL,
        plan_code VARCHAR(50) NOT NULL,
        plan_name VARCHAR(255) NOT NULL,
        pricing_model VARCHAR(50) NOT NULL,
        features JSONB DEFAULT '{}',
        pricing JSONB DEFAULT '{}',
        is_active BOOLEAN DEFAULT true,
        allowed_response_types JSONB DEFAULT '[]',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(country_id, business_type_id, plan_code)
      );
    `);
    
    console.log('Table created successfully!');
    
    // Add some sample data
    await client.query(`
      INSERT INTO enhanced_business_benefits 
      (country_id, business_type_id, plan_code, plan_name, pricing_model, features, pricing, allowed_response_types)
      SELECT 
        1,
        bt.id,
        'free',
        'Free Plan',
        'response_based',
        '{"responses_per_month": 3, "contact_revealed": false, "can_message_requester": false}',
        '{"monthly_fee": 0}',
        '["quick_quote", "standard"]'
      FROM business_types bt
      WHERE bt.name IN ('Product Seller', 'Delivery', 'Tours', 'Events')
      ON CONFLICT (country_id, business_type_id, plan_code) DO NOTHING;
    `);
    
    await client.query(`
      INSERT INTO enhanced_business_benefits 
      (country_id, business_type_id, plan_code, plan_name, pricing_model, features, pricing, allowed_response_types)
      SELECT 
        1,
        bt.id,
        'pay_per_click',
        'Pay Per Click',
        'pay_per_click',
        '{"cost_per_click": 50, "click_tracking": true}',
        '{"cost_per_click": 50}',
        '["product_listing"]'
      FROM business_types bt
      WHERE bt.name = 'Product Seller'
      ON CONFLICT (country_id, business_type_id, plan_code) DO NOTHING;
    `);
    
    await client.query(`
      INSERT INTO enhanced_business_benefits 
      (country_id, business_type_id, plan_code, plan_name, pricing_model, features, pricing, allowed_response_types)
      SELECT 
        1,
        bt.id,
        'monthly_pricing',
        'Monthly Product Pricing',
        'monthly_subscription',
        '{"product_listing_limit": 100, "featured_products": 5}',
        '{"monthly_fee": 2500}',
        '["product_listing", "featured"]'
      FROM business_types bt
      WHERE bt.name = 'Product Seller'
      ON CONFLICT (country_id, business_type_id, plan_code) DO NOTHING;
    `);
    
    await client.query(`
      INSERT INTO enhanced_business_benefits 
      (country_id, business_type_id, plan_code, plan_name, pricing_model, features, pricing, allowed_response_types)
      SELECT 
        1,
        bt.id,
        'bundle',
        'Bundle: Pricing + Unlimited Responses',
        'bundle',
        '{"product_listing_limit": -1, "responses_per_month": -1, "contact_revealed": true, "priority_support": true}',
        '{"monthly_fee": 5000}',
        '["product_listing", "featured", "quick_quote", "standard", "premium"]'
      FROM business_types bt
      WHERE bt.name = 'Product Seller'
      ON CONFLICT (country_id, business_type_id, plan_code) DO NOTHING;
    `);
    
    console.log('Sample data inserted!');
    
  } catch (error) {
    console.error('Error creating table:', error);
    throw error;
  } finally {
    client.release();
  }
}

// Run the migration
createEnhancedBenefitsTable()
  .then(() => console.log('Migration completed successfully!'))
  .catch(console.error);
