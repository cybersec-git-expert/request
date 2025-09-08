const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'request_db',
  password: process.env.DB_PASSWORD || 'your_password',
  port: process.env.DB_PORT || 5432,
});

async function createEnhancedBusinessBenefitsTable() {
  const client = await pool.connect();
  
  try {
    console.log('Creating enhanced_business_benefits table...');
    
    // Create the table
    await client.query(`
      CREATE TABLE IF NOT EXISTS enhanced_business_benefits (
        id SERIAL PRIMARY KEY,
        country_id INTEGER,
        business_type_id UUID REFERENCES business_types(id),
        plan_code VARCHAR(50) UNIQUE NOT NULL,
        plan_name VARCHAR(255) NOT NULL,
        pricing_model VARCHAR(50) NOT NULL CHECK (pricing_model IN ('response_based', 'pay_per_click', 'monthly_subscription', 'bundle')),
        features JSONB DEFAULT '{}',
        pricing JSONB DEFAULT '{}',
        allowed_response_types JSONB DEFAULT '[]',
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    
    console.log('Table created successfully!');
    
    // Get country and business type data first
    console.log('Getting country and business type data...');
    const countryResult = await client.query("SELECT id FROM countries WHERE country_code = 'LK' LIMIT 1");
    const businessTypesResult = await client.query("SELECT id, name FROM business_types ORDER BY name");
    
    if (countryResult.rows.length === 0) {
      console.log('No country found with code LK, using country_id = 1');
    }
    
    const countryId = countryResult.rows.length > 0 ? countryResult.rows[0].id : 1;
    console.log('Using country_id:', countryId);
    console.log('Available business types:', businessTypesResult.rows);
    
    // Insert sample data for each business type
    for (const businessType of businessTypesResult.rows) {
      const businessTypeId = businessType.id;
      const businessTypeName = businessType.name.toLowerCase();
      
      console.log(`Creating plans for business type: ${businessType.name} (${businessTypeId})`);
      
      if (businessTypeName.includes('product') || businessTypeName.includes('seller')) {
        // Product Seller - pay per click, monthly, bundle
        const productSellerPlans = [
          {
            plan_code: `product_pay_per_click_${businessTypeId.replace(/-/g, '_')}`,
            plan_name: 'Pay Per Click Plan',
            pricing_model: 'pay_per_click',
            features: JSON.stringify({
              click_tracking: true,
              analytics_dashboard: true,
              product_showcase: true,
              customer_messaging: true
            }),
            pricing: JSON.stringify({
              cost_per_click: 0.50,
              minimum_budget: 50.00,
              currency: 'LKR'
            })
          },
          {
            plan_code: `product_monthly_${businessTypeId.replace(/-/g, '_')}`,
            plan_name: 'Monthly Subscription Plan',
            pricing_model: 'monthly_subscription',
            features: JSON.stringify({
              unlimited_products: true,
              priority_listing: true,
              advanced_analytics: true,
              customer_support: true,
              promotion_tools: true
            }),
            pricing: JSON.stringify({
              monthly_fee: 2500.00,
              setup_fee: 500.00,
              currency: 'LKR'
            })
          },
          {
            plan_code: `product_bundle_${businessTypeId.replace(/-/g, '_')}`,
            plan_name: 'Bundle Offer Plan',
            pricing_model: 'bundle',
            features: JSON.stringify({
              clicks_included: 1000,
              monthly_promotion: true,
              featured_listing: true,
              analytics_reports: true,
              customer_messaging: true
            }),
            pricing: JSON.stringify({
              bundle_price: 1500.00,
              clicks_included: 1000,
              additional_click_cost: 0.40,
              currency: 'LKR'
            })
          }
        ];
        
        for (const plan of productSellerPlans) {
          await client.query(`
            INSERT INTO enhanced_business_benefits 
            (country_id, business_type_id, plan_code, plan_name, pricing_model, features, pricing, allowed_response_types)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            ON CONFLICT (plan_code) DO NOTHING
          `, [
            countryId,
            businessTypeId,
            plan.plan_code,
            plan.plan_name,
            plan.pricing_model,
            plan.features,
            plan.pricing,
            JSON.stringify([])
          ]);
        }
      } else {
        // Other business types - response based
        await client.query(`
          INSERT INTO enhanced_business_benefits 
          (country_id, business_type_id, plan_code, plan_name, pricing_model, features, pricing, allowed_response_types)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
          ON CONFLICT (plan_code) DO NOTHING
        `, [
          countryId,
          businessTypeId,
          `${businessTypeName.replace(/\s+/g, '_')}_response_basic_${businessTypeId.replace(/-/g, '_')}`,
          `${businessType.name} Basic Response Plan`,
          'response_based',
          JSON.stringify({
            response_limit: 50,
            basic_analytics: true,
            customer_messaging: true
          }),
          JSON.stringify({
            cost_per_response: 25.00,
            monthly_minimum: 500.00,
            currency: 'LKR'
          }),
          JSON.stringify(['call', 'message', 'email'])
        ]);
      }
    }
    
    console.log('Sample data inserted successfully!');
    
    // Show what was created
    const result = await client.query(`
      SELECT ebs.*, bt.name as business_type_name, c.country_name 
      FROM enhanced_business_benefits ebs
      LEFT JOIN business_types bt ON ebs.business_type_id = bt.id
      LEFT JOIN countries c ON ebs.country_id = c.id
      ORDER BY bt.name, ebs.plan_name
    `);
    
    console.log('Created enhanced business benefits:');
    console.table(result.rows);
    
  } catch (error) {
    console.error('Error creating enhanced business benefits table:', error);
    throw error;
  } finally {
    client.release();
  }
}

if (require.main === module) {
  createEnhancedBusinessBenefitsTable()
    .then(() => {
      console.log('Enhanced business benefits migration completed successfully!');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Migration failed:', error);
      process.exit(1);
    });
}

module.exports = { createEnhancedBusinessBenefitsTable };
