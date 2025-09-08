const { Pool } = require('pg');
const dbService = require('./services/database');

async function createEnhancedBusinessTypeBenefitsSystem() {
  const client = await dbService.pool.connect();
  
  try {
    console.log('Creating enhanced business type benefits system...');
    
    // Create business type benefit plans table (supports multiple plan types per business type)
    await client.query(`
      CREATE TABLE IF NOT EXISTS business_type_benefit_plans (
        id SERIAL PRIMARY KEY,
        country_id INTEGER NOT NULL,
        business_type_id INTEGER NOT NULL,
        plan_code VARCHAR(50) NOT NULL, -- 'free', 'basic', 'premium', 'pay_per_click', 'monthly_pricing', 'bundle'
        plan_name VARCHAR(100) NOT NULL,
        plan_description TEXT,
        plan_type VARCHAR(20) NOT NULL CHECK (plan_type IN ('response_based', 'pricing_based', 'hybrid')),
        is_active BOOLEAN DEFAULT true,
        sort_order INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_by INTEGER,
        updated_by INTEGER,
        UNIQUE(country_id, business_type_id, plan_code),
        FOREIGN KEY (country_id) REFERENCES countries(id) ON DELETE CASCADE,
        FOREIGN KEY (business_type_id) REFERENCES business_types(id) ON DELETE CASCADE
      );
    `);

    // Create benefits configuration table (flexible JSON structure)
    await client.query(`
      CREATE TABLE IF NOT EXISTS business_type_benefit_configs (
        id SERIAL PRIMARY KEY,
        plan_id INTEGER NOT NULL,
        config_key VARCHAR(100) NOT NULL, -- 'responses', 'pricing', 'features', 'limits'
        config_data JSONB NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (plan_id) REFERENCES business_type_benefit_plans(id) ON DELETE CASCADE,
        UNIQUE(plan_id, config_key)
      );
    `);

    // Create allowed business types mapping (which business types can respond to which request types)
    await client.query(`
      CREATE TABLE IF NOT EXISTS business_type_allowed_responses (
        id SERIAL PRIMARY KEY,
        plan_id INTEGER NOT NULL,
        can_respond_to_business_type_id INTEGER NOT NULL,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (plan_id) REFERENCES business_type_benefit_plans(id) ON DELETE CASCADE,
        FOREIGN KEY (can_respond_to_business_type_id) REFERENCES business_types(id) ON DELETE CASCADE,
        UNIQUE(plan_id, can_respond_to_business_type_id)
      );
    `);

    console.log('Creating indexes...');
    
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_benefit_plans_country_business_type 
      ON business_type_benefit_plans(country_id, business_type_id);
    `);
    
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_benefit_configs_plan_key 
      ON business_type_benefit_configs(plan_id, config_key);
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_allowed_responses_plan 
      ON business_type_allowed_responses(plan_id);
    `);

    console.log('Inserting default benefit plans...');
    
    // Get all countries and business types
    const countries = await client.query('SELECT id FROM countries ORDER BY id');
    const businessTypes = await client.query('SELECT id, name FROM business_types ORDER BY id');

    for (const country of countries.rows) {
      for (const businessType of businessTypes.rows) {
        const countryId = country.id;
        const businessTypeId = businessType.id;
        const businessTypeName = businessType.name.toLowerCase();

        if (businessTypeName === 'product seller') {
          // Product Seller - Pricing-based plans
          
          // Plan 1: Pay Per Click
          const payPerClickPlan = await client.query(`
            INSERT INTO business_type_benefit_plans 
            (country_id, business_type_id, plan_code, plan_name, plan_description, plan_type, sort_order)
            VALUES ($1, $2, 'pay_per_click', 'Pay Per Click', 'Pay only when customers click on your products', 'pricing_based', 1)
            ON CONFLICT (country_id, business_type_id, plan_code) DO UPDATE SET
            plan_name = EXCLUDED.plan_name, plan_description = EXCLUDED.plan_description
            RETURNING id
          `, [countryId, businessTypeId]);

          await client.query(`
            INSERT INTO business_type_benefit_configs (plan_id, config_key, config_data)
            VALUES ($1, 'pricing', $2)
            ON CONFLICT (plan_id, config_key) DO UPDATE SET config_data = EXCLUDED.config_data
          `, [payPerClickPlan.rows[0].id, JSON.stringify({
            model: 'per_click',
            price_per_click: 0.50,
            currency: 'USD',
            min_budget: 10.00,
            responses_included: 0
          })]);

          await client.query(`
            INSERT INTO business_type_benefit_configs (plan_id, config_key, config_data)
            VALUES ($1, 'features', $2)
            ON CONFLICT (plan_id, config_key) DO UPDATE SET config_data = EXCLUDED.config_data
          `, [payPerClickPlan.rows[0].id, JSON.stringify({
            product_listings: true,
            basic_analytics: true,
            customer_contact: false,
            priority_placement: false,
            unlimited_products: true
          })]);

          // Plan 2: Monthly Product Pricing
          const monthlyPlan = await client.query(`
            INSERT INTO business_type_benefit_plans 
            (country_id, business_type_id, plan_code, plan_name, plan_description, plan_type, sort_order)
            VALUES ($1, $2, 'monthly_pricing', 'Monthly Product Pricing', 'Fixed monthly fee for product listings', 'pricing_based', 2)
            ON CONFLICT (country_id, business_type_id, plan_code) DO UPDATE SET
            plan_name = EXCLUDED.plan_name, plan_description = EXCLUDED.plan_description
            RETURNING id
          `, [countryId, businessTypeId]);

          await client.query(`
            INSERT INTO business_type_benefit_configs (plan_id, config_key, config_data)
            VALUES ($1, 'pricing', $2)
            ON CONFLICT (plan_id, config_key) DO UPDATE SET config_data = EXCLUDED.config_data
          `, [monthlyPlan.rows[0].id, JSON.stringify({
            model: 'monthly_subscription',
            monthly_fee: 29.99,
            currency: 'USD',
            max_products: 100,
            responses_included: 0
          })]);

          await client.query(`
            INSERT INTO business_type_benefit_configs (plan_id, config_key, config_data)
            VALUES ($1, 'features', $2)
            ON CONFLICT (plan_id, config_key) DO UPDATE SET config_data = EXCLUDED.config_data
          `, [monthlyPlan.rows[0].id, JSON.stringify({
            product_listings: true,
            advanced_analytics: true,
            customer_contact: true,
            priority_placement: true,
            unlimited_products: false,
            max_products: 100
          })]);

          // Plan 3: Bundle (Product Pricing + Unlimited Responses)
          const bundlePlan = await client.query(`
            INSERT INTO business_type_benefit_plans 
            (country_id, business_type_id, plan_code, plan_name, plan_description, plan_type, sort_order)
            VALUES ($1, $2, 'bundle_unlimited', 'Bundle: Pricing + Unlimited Responses', 'Product pricing with unlimited response capabilities', 'hybrid', 3)
            ON CONFLICT (country_id, business_type_id, plan_code) DO UPDATE SET
            plan_name = EXCLUDED.plan_name, plan_description = EXCLUDED.plan_description
            RETURNING id
          `, [countryId, businessTypeId]);

          await client.query(`
            INSERT INTO business_type_benefit_configs (plan_id, config_key, config_data)
            VALUES ($1, 'pricing', $2)
            ON CONFLICT (plan_id, config_key) DO UPDATE SET config_data = EXCLUDED.config_data
          `, [bundlePlan.rows[0].id, JSON.stringify({
            model: 'bundle',
            monthly_fee: 49.99,
            currency: 'USD',
            max_products: 500,
            responses_included: -1 // unlimited
          })]);

          await client.query(`
            INSERT INTO business_type_benefit_configs (plan_id, config_key, config_data)
            VALUES ($1, 'responses', $2)
            ON CONFLICT (plan_id, config_key) DO UPDATE SET config_data = EXCLUDED.config_data
          `, [bundlePlan.rows[0].id, JSON.stringify({
            responses_per_month: -1, // unlimited
            contact_revealed: true,
            can_message_requester: true,
            respond_button_enabled: true,
            instant_notifications: true,
            priority_in_search: true
          })]);

          await client.query(`
            INSERT INTO business_type_benefit_configs (plan_id, config_key, config_data)
            VALUES ($1, 'features', $2)
            ON CONFLICT (plan_id, config_key) DO UPDATE SET config_data = EXCLUDED.config_data
          `, [bundlePlan.rows[0].id, JSON.stringify({
            product_listings: true,
            advanced_analytics: true,
            customer_contact: true,
            priority_placement: true,
            unlimited_products: false,
            max_products: 500,
            can_respond_to_requests: true
          })]);

        } else {
          // Other business types (Driver, Tour, Construction, etc.) - Response-based plans
          
          // Free Plan
          const freePlan = await client.query(`
            INSERT INTO business_type_benefit_plans 
            (country_id, business_type_id, plan_code, plan_name, plan_description, plan_type, sort_order)
            VALUES ($1, $2, 'free', 'Free Plan', 'Basic features with limited responses', 'response_based', 1)
            ON CONFLICT (country_id, business_type_id, plan_code) DO UPDATE SET
            plan_name = EXCLUDED.plan_name, plan_description = EXCLUDED.plan_description
            RETURNING id
          `, [countryId, businessTypeId]);

          await client.query(`
            INSERT INTO business_type_benefit_configs (plan_id, config_key, config_data)
            VALUES ($1, 'responses', $2)
            ON CONFLICT (plan_id, config_key) DO UPDATE SET config_data = EXCLUDED.config_data
          `, [freePlan.rows[0].id, JSON.stringify({
            responses_per_month: 3,
            contact_revealed: false,
            can_message_requester: false,
            respond_button_enabled: true,
            instant_notifications: false,
            priority_in_search: false
          })]);

          await client.query(`
            INSERT INTO business_type_benefit_configs (plan_id, config_key, config_data)
            VALUES ($1, 'features', $2)
            ON CONFLICT (plan_id, config_key) DO UPDATE SET config_data = EXCLUDED.config_data
          `, [freePlan.rows[0].id, JSON.stringify({
            basic_profile: true,
            limited_visibility: true,
            basic_support: true
          })]);

          // Premium Plan
          const premiumPlan = await client.query(`
            INSERT INTO business_type_benefit_plans 
            (country_id, business_type_id, plan_code, plan_name, plan_description, plan_type, sort_order)
            VALUES ($1, $2, 'premium', 'Premium Plan', 'Unlimited responses with premium features', 'response_based', 2)
            ON CONFLICT (country_id, business_type_id, plan_code) DO UPDATE SET
            plan_name = EXCLUDED.plan_name, plan_description = EXCLUDED.plan_description
            RETURNING id
          `, [countryId, businessTypeId]);

          await client.query(`
            INSERT INTO business_type_benefit_configs (plan_id, config_key, config_data)
            VALUES ($1, 'responses', $2)
            ON CONFLICT (plan_id, config_key) DO UPDATE SET config_data = EXCLUDED.config_data
          `, [premiumPlan.rows[0].id, JSON.stringify({
            responses_per_month: -1, // unlimited
            contact_revealed: true,
            can_message_requester: true,
            respond_button_enabled: true,
            instant_notifications: true,
            priority_in_search: true
          })]);

          await client.query(`
            INSERT INTO business_type_benefit_configs (plan_id, config_key, config_data)
            VALUES ($1, 'features', $2)
            ON CONFLICT (plan_id, config_key) DO UPDATE SET config_data = EXCLUDED.config_data
          `, [premiumPlan.rows[0].id, JSON.stringify({
            enhanced_profile: true,
            priority_visibility: true,
            premium_support: true,
            analytics_dashboard: true
          })]);

          // Set up default allowed response types (can respond to their own type and related types)
          await client.query(`
            INSERT INTO business_type_allowed_responses (plan_id, can_respond_to_business_type_id)
            VALUES ($1, $2)
            ON CONFLICT (plan_id, can_respond_to_business_type_id) DO NOTHING
          `, [freePlan.rows[0].id, businessTypeId]);

          await client.query(`
            INSERT INTO business_type_allowed_responses (plan_id, can_respond_to_business_type_id)
            VALUES ($1, $2)
            ON CONFLICT (plan_id, can_respond_to_business_type_id) DO NOTHING
          `, [premiumPlan.rows[0].id, businessTypeId]);
        }
      }
    }

    console.log('Creating management functions...');

    // Function to get all benefit plans for a business type in a country
    await client.query(`
      CREATE OR REPLACE FUNCTION get_business_type_benefit_plans(p_country_id INTEGER, p_business_type_id INTEGER)
      RETURNS TABLE(
        plan_id INTEGER,
        plan_code VARCHAR,
        plan_name VARCHAR,
        plan_description TEXT,
        plan_type VARCHAR,
        is_active BOOLEAN,
        sort_order INTEGER,
        config_data JSONB,
        allowed_response_types INTEGER[]
      ) AS $$
      BEGIN
        RETURN QUERY
        SELECT 
          bp.id,
          bp.plan_code,
          bp.plan_name,
          bp.plan_description,
          bp.plan_type,
          bp.is_active,
          bp.sort_order,
          COALESCE(
            jsonb_object_agg(bc.config_key, bc.config_data) FILTER (WHERE bc.config_key IS NOT NULL),
            '{}'::jsonb
          ) as config_data,
          COALESCE(
            array_agg(DISTINCT bar.can_respond_to_business_type_id) FILTER (WHERE bar.can_respond_to_business_type_id IS NOT NULL),
            ARRAY[]::integer[]
          ) as allowed_response_types
        FROM business_type_benefit_plans bp
        LEFT JOIN business_type_benefit_configs bc ON bp.id = bc.plan_id
        LEFT JOIN business_type_allowed_responses bar ON bp.id = bar.plan_id AND bar.is_active = true
        WHERE bp.country_id = p_country_id 
          AND bp.business_type_id = p_business_type_id
          AND bp.is_active = true
        GROUP BY bp.id, bp.plan_code, bp.plan_name, bp.plan_description, bp.plan_type, bp.is_active, bp.sort_order
        ORDER BY bp.sort_order, bp.plan_name;
      END;
      $$ LANGUAGE plpgsql;
    `);

    // Function to update benefit plan configuration
    await client.query(`
      CREATE OR REPLACE FUNCTION update_benefit_plan_config(
        p_plan_id INTEGER,
        p_config_key VARCHAR,
        p_config_data JSONB,
        p_admin_user_id INTEGER DEFAULT NULL
      )
      RETURNS JSON AS $$
      BEGIN
        INSERT INTO business_type_benefit_configs (plan_id, config_key, config_data)
        VALUES (p_plan_id, p_config_key, p_config_data)
        ON CONFLICT (plan_id, config_key) 
        DO UPDATE SET 
          config_data = EXCLUDED.config_data,
          updated_at = CURRENT_TIMESTAMP;
        
        RETURN json_build_object('success', true, 'message', 'Configuration updated successfully');
      EXCEPTION WHEN OTHERS THEN
        RETURN json_build_object('success', false, 'message', SQLERRM);
      END;
      $$ LANGUAGE plpgsql;
    `);

    console.log('Enhanced business type benefits system created successfully!');
    
  } catch (error) {
    console.error('Error creating enhanced business type benefits system:', error);
    throw error;
  } finally {
    client.release();
  }
}

// Run the migration
if (require.main === module) {
  createEnhancedBusinessTypeBenefitsSystem()
    .then(() => {
      console.log('Migration completed successfully!');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Migration failed:', error);
      process.exit(1);
    });
}

module.exports = { createEnhancedBusinessTypeBenefitsSystem };
