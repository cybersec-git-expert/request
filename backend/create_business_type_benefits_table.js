const { Pool } = require('pg');
const dbService = require('./services/database');

async function createBusinessTypeBenefitsTable() {
  const client = await dbService.pool.connect();
  
  try {
    console.log('Creating business_type_benefits table...');
    
    // Create the table to store business type benefits configuration
    await client.query(`
      CREATE TABLE IF NOT EXISTS business_type_benefits (
        id SERIAL PRIMARY KEY,
        country_id INTEGER NOT NULL,
        business_type_id INTEGER NOT NULL,
        plan_type VARCHAR(20) NOT NULL CHECK (plan_type IN ('free', 'paid')),
        responses_per_month INTEGER DEFAULT 3,
        contact_revealed BOOLEAN DEFAULT false,
        can_message_requester BOOLEAN DEFAULT false,
        respond_button_enabled BOOLEAN DEFAULT true,
        instant_notifications BOOLEAN DEFAULT false,
        priority_in_search BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_by INTEGER,
        updated_by INTEGER,
        UNIQUE(country_id, business_type_id, plan_type),
        FOREIGN KEY (country_id) REFERENCES countries(id) ON DELETE CASCADE,
        FOREIGN KEY (business_type_id) REFERENCES business_types(id) ON DELETE CASCADE
      );
    `);

    console.log('Creating indexes for better performance...');
    
    // Create indexes for better query performance
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_business_type_benefits_country_type 
      ON business_type_benefits(country_id, business_type_id);
    `);
    
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_business_type_benefits_plan_type 
      ON business_type_benefits(plan_type);
    `);

    console.log('Inserting default business type benefits...');
    
    // Insert default benefits configuration for each country and business type
    // This will be the baseline that country admins can modify
    await client.query(`
      INSERT INTO business_type_benefits 
      (country_id, business_type_id, plan_type, responses_per_month, contact_revealed, can_message_requester, respond_button_enabled, instant_notifications, priority_in_search)
      SELECT 
        c.id as country_id,
        bt.id as business_type_id,
        'free' as plan_type,
        3 as responses_per_month,
        false as contact_revealed,
        false as can_message_requester,
        true as respond_button_enabled,
        false as instant_notifications,
        false as priority_in_search
      FROM countries c
      CROSS JOIN business_types bt
      ON CONFLICT (country_id, business_type_id, plan_type) DO NOTHING;
    `);

    await client.query(`
      INSERT INTO business_type_benefits 
      (country_id, business_type_id, plan_type, responses_per_month, contact_revealed, can_message_requester, respond_button_enabled, instant_notifications, priority_in_search)
      SELECT 
        c.id as country_id,
        bt.id as business_type_id,
        'paid' as plan_type,
        -1 as responses_per_month,  -- -1 means unlimited
        true as contact_revealed,
        true as can_message_requester,
        true as respond_button_enabled,
        true as instant_notifications,
        true as priority_in_search
      FROM countries c
      CROSS JOIN business_types bt
      ON CONFLICT (country_id, business_type_id, plan_type) DO NOTHING;
    `);

    console.log('Creating admin management functions...');
    
    // Create a function for country admins to update business type benefits
    await client.query(`
      CREATE OR REPLACE FUNCTION update_business_type_benefits(
        p_country_id INTEGER,
        p_business_type_id INTEGER,
        p_plan_type VARCHAR(20),
        p_responses_per_month INTEGER DEFAULT NULL,
        p_contact_revealed BOOLEAN DEFAULT NULL,
        p_can_message_requester BOOLEAN DEFAULT NULL,
        p_respond_button_enabled BOOLEAN DEFAULT NULL,
        p_instant_notifications BOOLEAN DEFAULT NULL,
        p_priority_in_search BOOLEAN DEFAULT NULL,
        p_admin_user_id INTEGER DEFAULT NULL
      )
      RETURNS JSON AS $$
      DECLARE
        update_count INTEGER;
      BEGIN
        UPDATE business_type_benefits 
        SET 
          responses_per_month = COALESCE(p_responses_per_month, responses_per_month),
          contact_revealed = COALESCE(p_contact_revealed, contact_revealed),
          can_message_requester = COALESCE(p_can_message_requester, can_message_requester),
          respond_button_enabled = COALESCE(p_respond_button_enabled, respond_button_enabled),
          instant_notifications = COALESCE(p_instant_notifications, instant_notifications),
          priority_in_search = COALESCE(p_priority_in_search, priority_in_search),
          updated_at = CURRENT_TIMESTAMP,
          updated_by = p_admin_user_id
        WHERE 
          country_id = p_country_id 
          AND business_type_id = p_business_type_id 
          AND plan_type = p_plan_type;
        
        GET DIAGNOSTICS update_count = ROW_COUNT;
        
        IF update_count = 0 THEN
          RETURN json_build_object('success', false, 'message', 'No matching record found to update');
        END IF;
        
        RETURN json_build_object('success', true, 'message', 'Business type benefits updated successfully');
      END;
      $$ LANGUAGE plpgsql;
    `);

    // Create a function to get business type benefits for a specific country
    await client.query(`
      CREATE OR REPLACE FUNCTION get_business_type_benefits(p_country_id INTEGER)
      RETURNS TABLE(
        business_type_id INTEGER,
        business_type_name VARCHAR,
        free_responses_per_month INTEGER,
        free_contact_revealed BOOLEAN,
        free_can_message_requester BOOLEAN,
        free_respond_button_enabled BOOLEAN,
        free_instant_notifications BOOLEAN,
        free_priority_in_search BOOLEAN,
        paid_responses_per_month INTEGER,
        paid_contact_revealed BOOLEAN,
        paid_can_message_requester BOOLEAN,
        paid_respond_button_enabled BOOLEAN,
        paid_instant_notifications BOOLEAN,
        paid_priority_in_search BOOLEAN
      ) AS $$
      BEGIN
        RETURN QUERY
        SELECT 
          bt.id as business_type_id,
          bt.name as business_type_name,
          free_plan.responses_per_month as free_responses_per_month,
          free_plan.contact_revealed as free_contact_revealed,
          free_plan.can_message_requester as free_can_message_requester,
          free_plan.respond_button_enabled as free_respond_button_enabled,
          free_plan.instant_notifications as free_instant_notifications,
          free_plan.priority_in_search as free_priority_in_search,
          paid_plan.responses_per_month as paid_responses_per_month,
          paid_plan.contact_revealed as paid_contact_revealed,
          paid_plan.can_message_requester as paid_can_message_requester,
          paid_plan.respond_button_enabled as paid_respond_button_enabled,
          paid_plan.instant_notifications as paid_instant_notifications,
          paid_plan.priority_in_search as paid_priority_in_search
        FROM business_types bt
        LEFT JOIN business_type_benefits free_plan ON (
          bt.id = free_plan.business_type_id 
          AND free_plan.country_id = p_country_id 
          AND free_plan.plan_type = 'free'
        )
        LEFT JOIN business_type_benefits paid_plan ON (
          bt.id = paid_plan.business_type_id 
          AND paid_plan.country_id = p_country_id 
          AND paid_plan.plan_type = 'paid'
        )
        ORDER BY bt.name;
      END;
      $$ LANGUAGE plpgsql;
    `);

    console.log('Business type benefits table and functions created successfully!');
    console.log('');
    console.log('Usage Examples:');
    console.log('1. Get benefits for country ID 1:');
    console.log('   SELECT * FROM get_business_type_benefits(1);');
    console.log('');
    console.log('2. Update benefits for a business type (country admin only):');
    console.log('   SELECT update_business_type_benefits(1, 1, \'free\', 5, null, null, null, null, null, 123);');
    console.log('');
    console.log('3. View all benefits:');
    console.log('   SELECT * FROM business_type_benefits ORDER BY country_id, business_type_id, plan_type;');

  } catch (error) {
    console.error('Error creating business type benefits table:', error);
    throw error;
  } finally {
    client.release();
  }
}

// Execute the function
if (require.main === module) {
  createBusinessTypeBenefitsTable()
    .then(() => {
      console.log('Setup completed successfully!');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Setup failed:', error);
      process.exit(1);
    });
}

module.exports = { createBusinessTypeBenefitsTable };
