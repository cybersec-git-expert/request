const database = require('./services/database');

async function createSMSSystem() {
  try {
    console.log('🚀 Creating SMS system tables...');

    // 1. Create SMS configurations table
    await database.query(`
      CREATE TABLE IF NOT EXISTS sms_configurations (
        id SERIAL PRIMARY KEY,
        country_code VARCHAR(2) NOT NULL UNIQUE,
        country_name VARCHAR(100) NOT NULL,
        active_provider VARCHAR(20) NOT NULL,
        is_active BOOLEAN DEFAULT true,
        
        twilio_config JSONB,
        aws_config JSONB,
        vonage_config JSONB,
        local_config JSONB,
        
        total_sms_sent INTEGER DEFAULT 0,
        total_cost DECIMAL(10,4) DEFAULT 0,
        cost_per_sms DECIMAL(6,4) DEFAULT 0,
        
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        created_by VARCHAR(255)
      )
    `);
    console.log('✅ Created sms_configurations table');

    // 2. Enhanced OTP verifications table
    await database.query('DROP TABLE IF EXISTS phone_otp_verifications');
    await database.query(`
      CREATE TABLE phone_otp_verifications (
        id SERIAL PRIMARY KEY,
        otp_id VARCHAR(50) UNIQUE NOT NULL,
        phone VARCHAR(20) NOT NULL,
        otp VARCHAR(6) NOT NULL,
        country_code VARCHAR(2) NOT NULL,
        provider_used VARCHAR(20),
        
        verified BOOLEAN DEFAULT FALSE,
        attempts INTEGER DEFAULT 0,
        max_attempts INTEGER DEFAULT 3,
        
        created_at TIMESTAMPTZ DEFAULT NOW(),
        expires_at TIMESTAMPTZ NOT NULL,
        verified_at TIMESTAMPTZ
      )
    `);
    console.log('✅ Created phone_otp_verifications table');

    // 3. Create indexes for phone_otp_verifications
    await database.query(`
      CREATE INDEX IF NOT EXISTS idx_phone_otp_active 
      ON phone_otp_verifications (phone, verified, expires_at)
    `);
    await database.query(`
      CREATE INDEX IF NOT EXISTS idx_otp_id 
      ON phone_otp_verifications (otp_id)
    `);
    await database.query(`
      CREATE INDEX IF NOT EXISTS idx_phone_created 
      ON phone_otp_verifications (phone, created_at)
    `);
    console.log('✅ Created indexes for phone_otp_verifications');

    // 4. SMS Analytics table
    await database.query(`
      CREATE TABLE IF NOT EXISTS sms_analytics (
        id SERIAL PRIMARY KEY,
        country_code VARCHAR(2) NOT NULL,
        provider VARCHAR(20) NOT NULL,
        cost DECIMAL(6,4) DEFAULT 0,
        success BOOLEAN DEFAULT true,
        error_message TEXT,
        
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `);
    console.log('✅ Created sms_analytics table');

    // 5. Create indexes for sms_analytics
    await database.query(`
      CREATE INDEX IF NOT EXISTS idx_analytics_country_month 
      ON sms_analytics (country_code, year, month)
    `);
    await database.query(`
      CREATE INDEX IF NOT EXISTS idx_analytics_provider 
      ON sms_analytics (provider, created_at)
    `);
    console.log('✅ Created indexes for sms_analytics');

    // 6. User phone numbers table
    await database.query(`
      CREATE TABLE IF NOT EXISTS user_phone_numbers (
        id SERIAL PRIMARY KEY,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        phone_number VARCHAR(20) NOT NULL,
        country_code VARCHAR(2),
        
        is_verified BOOLEAN DEFAULT FALSE,
        is_primary BOOLEAN DEFAULT FALSE,
        verified_at TIMESTAMPTZ,
        
        label VARCHAR(50),
        purpose VARCHAR(100),
        
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        
        UNIQUE(user_id, phone_number)
      )
    `);
    console.log('✅ Created user_phone_numbers table');

    // 7. Create indexes for user_phone_numbers
    await database.query(`
      CREATE INDEX IF NOT EXISTS idx_user_phones 
      ON user_phone_numbers (user_id)
    `);
    await database.query(`
      CREATE INDEX IF NOT EXISTS idx_phone_lookup 
      ON user_phone_numbers (phone_number)
    `);
    await database.query(`
      CREATE INDEX IF NOT EXISTS idx_primary_phone 
      ON user_phone_numbers (user_id, is_primary)
    `);
    console.log('✅ Created indexes for user_phone_numbers');

    // 8. Update users table
    await database.query(`
      ALTER TABLE users 
      ADD COLUMN IF NOT EXISTS primary_phone_id INTEGER REFERENCES user_phone_numbers(id)
    `);
    await database.query(`
      ALTER TABLE users 
      ADD COLUMN IF NOT EXISTS phone_verification_enabled BOOLEAN DEFAULT TRUE
    `);
    console.log('✅ Updated users table');

    // 9. Insert default SMS configurations
    const countries = [
      { code: 'LK', name: 'Sri Lanka', phone: '+94700000000' },
      { code: 'IN', name: 'India', phone: '+911234567890' },
      { code: 'US', name: 'United States', phone: '+1234567890' },
      { code: 'UK', name: 'United Kingdom', phone: '+441234567890' },
      { code: 'AE', name: 'United Arab Emirates', phone: '+971501234567' }
    ];

    for (const country of countries) {
      await database.query(`
        INSERT INTO sms_configurations (country_code, country_name, active_provider, twilio_config, is_active) 
        VALUES ($1, $2, 'twilio', $3, false)
        ON CONFLICT (country_code) DO NOTHING
      `, [
        country.code, 
        country.name, 
        JSON.stringify({
          accountSid: '', 
          authToken: '', 
          fromNumber: country.phone
        })
      ]);
    }
    console.log('✅ Inserted default SMS configurations');

    // 10. Test the tables
    console.log('\n📊 Testing table creation...');
    
    const tables = [
      'sms_configurations',
      'phone_otp_verifications', 
      'sms_analytics',
      'user_phone_numbers'
    ];
    
    for (const table of tables) {
      try {
        const result = await database.query(`SELECT COUNT(*) FROM ${table}`);
        console.log(`✅ Table ${table}: ${result.rows[0].count} rows`);
      } catch (error) {
        console.log(`❌ Table ${table}: ${error.message}`);
      }
    }

    console.log('\n🎉 SMS system setup completed successfully!');

  } catch (error) {
    console.error('❌ SMS system setup failed:', error);
  }
}

createSMSSystem();
