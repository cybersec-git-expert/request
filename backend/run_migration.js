const { Pool } = require('pg');
const fs = require('fs');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config({ path: '.env.rds' });

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USERNAME,
  password: process.env.DB_PASSWORD,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false
});

async function runMigration() {
  try {
    console.log('🔗 Connecting to RDS database...');
    console.log('Host:', process.env.DB_HOST);
    console.log('Database:', process.env.DB_NAME);
    console.log('User:', process.env.DB_USERNAME);
    
    // Test connection
    await pool.query('SELECT 1');
    console.log('✅ Connected successfully');
    
    // Run migration
    const sql = fs.readFileSync('./database/migrations/create_promo_codes_system.sql', 'utf8');
    console.log('🚀 Running promo codes migration...');
    
    await pool.query(sql);
    console.log('✅ Promo codes migration completed successfully');
    
    // Verify tables were created
    const tablesResult = await pool.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name IN ('promo_codes', 'promo_code_redemptions') 
      ORDER BY table_name
    `);
    
    console.log('📋 Created tables:', tablesResult.rows.map(r => r.table_name));
    
    // Check sample data
    const sampleResult = await pool.query('SELECT code, name FROM promo_codes LIMIT 3');
    console.log('🎯 Sample promo codes:', sampleResult.rows);
    
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    if (error.message.includes('already exists')) {
      console.log('ℹ️  Tables might already exist, checking...');
      try {
        const existingResult = await pool.query('SELECT code, name FROM promo_codes LIMIT 3');
        console.log('✅ Existing promo codes found:', existingResult.rows);
      } catch (e) {
        console.log('❌ Tables do not exist yet');
      }
    }
  } finally {
    await pool.end();
  }
}

runMigration();