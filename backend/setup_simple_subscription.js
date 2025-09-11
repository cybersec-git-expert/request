const { Client } = require('pg');

// Simple database setup script for simple subscription system
async function setupSimpleSubscription() {
  const client = new Client({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'request_db',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD,
  });

  try {
    await client.connect();
    console.log('✅ Connected to database');

    // Create simple subscription plans table
    await client.query(`
      CREATE TABLE IF NOT EXISTS simple_subscription_plans (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        code VARCHAR(50) UNIQUE NOT NULL,
        name VARCHAR(100) NOT NULL,
        description TEXT,
        price DECIMAL(10,2) DEFAULT 0,
        currency VARCHAR(3) DEFAULT 'USD',
        response_limit INTEGER DEFAULT 3,
        features JSONB DEFAULT '[]',
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('✅ Created simple_subscription_plans table');

    // Insert default plans
    await client.query(`
      INSERT INTO simple_subscription_plans (code, name, description, price, currency, response_limit, features) VALUES
      ('free', 'Free Plan', 'Free plan with 3 responses per month', 0, 'USD', 3, '["Browse all requests", "Respond to 3 requests per month", "Basic profile"]'),
      ('premium', 'Premium Plan', 'Unlimited responses and premium features', 9.99, 'USD', -1, '["Browse all requests", "Unlimited responses per month", "Priority support", "Verified business badge", "Advanced analytics"]')
      ON CONFLICT (code) DO NOTHING
    `);
    console.log('✅ Inserted default subscription plans');

    // Create user subscriptions table
    await client.query(`
      CREATE TABLE IF NOT EXISTS user_simple_subscriptions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL,
        plan_code VARCHAR(50) NOT NULL DEFAULT 'free',
        responses_used_this_month INTEGER DEFAULT 0,
        month_reset_date DATE DEFAULT CURRENT_DATE,
        is_verified_business BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT fk_plan_code FOREIGN KEY (plan_code) REFERENCES simple_subscription_plans(code)
      )
    `);
    console.log('✅ Created user_simple_subscriptions table');

    // Create unique index
    await client.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_user_simple_subscriptions_user_id 
      ON user_simple_subscriptions(user_id)
    `);
    console.log('✅ Created unique index for user subscriptions');

    // Create function to reset monthly usage
    await client.query(`
      CREATE OR REPLACE FUNCTION reset_monthly_usage()
      RETURNS void AS $$
      BEGIN
        UPDATE user_simple_subscriptions 
        SET responses_used_this_month = 0,
            month_reset_date = CURRENT_DATE,
            updated_at = CURRENT_TIMESTAMP
        WHERE month_reset_date < DATE_TRUNC('month', CURRENT_DATE);
      END;
      $$ LANGUAGE plpgsql
    `);
    console.log('✅ Created reset_monthly_usage function');

    // Check if users table exists before creating trigger
    const usersTableExists = await client.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'users'
      )
    `);

    if (usersTableExists.rows[0].exists) {
      // Create trigger function
      await client.query(`
        CREATE OR REPLACE FUNCTION create_default_subscription()
        RETURNS TRIGGER AS $$
        BEGIN
          INSERT INTO user_simple_subscriptions (user_id, plan_code)
          VALUES (NEW.id, 'free')
          ON CONFLICT (user_id) DO NOTHING;
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
      `);

      // Drop and recreate trigger
      await client.query(`DROP TRIGGER IF EXISTS trigger_create_default_subscription ON users`);
      await client.query(`
        CREATE TRIGGER trigger_create_default_subscription
          AFTER INSERT ON users
          FOR EACH ROW
          EXECUTE FUNCTION create_default_subscription()
      `);
      console.log('✅ Created default subscription trigger');
    } else {
      console.log('⚠️ Users table not found, skipping trigger creation');
    }

    console.log('🎉 Simple subscription system setup completed successfully!');

  } catch (error) {
    console.error('❌ Database setup failed:', error);
    process.exit(1);
  } finally {
    await client.end();
  }
}

// Run the setup
setupSimpleSubscription();
