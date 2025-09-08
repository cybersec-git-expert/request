const database = require('./services/database');

async function createUserSubscriptionTables() {
  try {
    console.log('🚀 Creating user subscription tracking tables...');
    
    // User subscriptions table
    const createUserSubscriptions = `
      CREATE TABLE IF NOT EXISTS user_subscriptions (
        id SERIAL PRIMARY KEY,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        plan_code VARCHAR(50) NOT NULL,
        registration_type VARCHAR(20) DEFAULT 'general',
        subscription_status VARCHAR(20) DEFAULT 'active',
        current_month_responses INTEGER DEFAULT 0,
        responses_limit INTEGER DEFAULT 3,
        last_reset_date DATE DEFAULT CURRENT_DATE,
        subscription_start_date TIMESTAMP DEFAULT NOW(),
        subscription_end_date TIMESTAMP,
        payment_status VARCHAR(20) DEFAULT 'free',
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(user_id)
      );
    `;
    
    await database.query(createUserSubscriptions);
    console.log('✅ Created user_subscriptions table');
    
    // User response tracking table  
    const createUserResponses = `
      CREATE TABLE IF NOT EXISTS user_responses (
        id SERIAL PRIMARY KEY,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        request_id UUID,
        response_text TEXT,
        contact_revealed BOOLEAN DEFAULT true,
        response_month DATE DEFAULT date_trunc('month', CURRENT_DATE),
        created_at TIMESTAMP DEFAULT NOW()
      );
    `;
    
    await database.query(createUserResponses);
    console.log('✅ Created user_responses table');
    
    // Create indexes for performance
    await database.query('CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id ON user_subscriptions(user_id);');
    await database.query('CREATE INDEX IF NOT EXISTS idx_user_responses_user_month ON user_responses(user_id, response_month);');
    
    console.log('✅ Created indexes');
    
    // Insert default free subscriptions for existing users
    const insertDefaultSubscriptions = `
      INSERT INTO user_subscriptions (user_id, plan_code, registration_type, subscription_status, responses_limit)
      SELECT id, 'free', 'general', 'active', 3
      FROM users 
      WHERE id NOT IN (SELECT user_id FROM user_subscriptions)
      ON CONFLICT (user_id) DO NOTHING;
    `;
    
    const result = await database.query(insertDefaultSubscriptions);
    console.log(`✅ Added default free subscriptions for ${result.rowCount} existing users`);
    
    console.log('🎉 User subscription tracking system created successfully!');
    
  } catch (error) {
    console.error('❌ Failed to create user subscription tables:', error);
    throw error;
  } finally {
    process.exit(0);
  }
}

createUserSubscriptionTables().catch(console.error);
