const { Pool } = require('pg');
const dotenv = require('dotenv');
const fs = require('fs');
const path = require('path');

// Load the same .env configuration as the server
const envCandidates = [
  path.join(process.cwd(), '.env.rds'),
  path.join(__dirname, '..', '.env.rds'),
  path.join(__dirname, '..', '..', '.env.rds'),
];
let loadedEnvPath = null;
for (const p of envCandidates) {
  if (fs.existsSync(p)) {
    dotenv.config({ path: p });
    loadedEnvPath = p;
    break;
  }
}

console.log(`Environment loaded from: ${loadedEnvPath || 'none found'}`);
console.log(`DB Config: ${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`);

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'request_marketplace',
  user: process.env.DB_USERNAME || 'postgres',
  password: process.env.DB_PASSWORD || 'admin123'
});

async function addMissingColumns() {
  try {
    console.log('🔍 Connecting to database...');
    
    // Test connection
    await pool.query('SELECT NOW()');
    console.log('✅ Database connected successfully');
    
    console.log('🔧 Adding missing columns...');
    
    // Add columns to business_verifications table
    try {
      await pool.query('ALTER TABLE business_verifications ADD COLUMN phone_verified_at TIMESTAMP');
      console.log('✅ Added phone_verified_at to business_verifications');
    } catch (e) {
      if (e.code === '42701') {
        console.log('ℹ️ phone_verified_at already exists in business_verifications');
      } else {
        console.error('❌ Error adding phone_verified_at to business_verifications:', e.message);
      }
    }
    
    try {
      await pool.query('ALTER TABLE business_verifications ADD COLUMN email_verified_at TIMESTAMP');
      console.log('✅ Added email_verified_at to business_verifications');
    } catch (e) {
      if (e.code === '42701') {
        console.log('ℹ️ email_verified_at already exists in business_verifications');
      } else {
        console.error('❌ Error adding email_verified_at to business_verifications:', e.message);
      }
    }
    
    // Add columns to driver_verifications table
    try {
      await pool.query('ALTER TABLE driver_verifications ADD COLUMN phone_verified_at TIMESTAMP');
      console.log('✅ Added phone_verified_at to driver_verifications');
    } catch (e) {
      if (e.code === '42701') {
        console.log('ℹ️ phone_verified_at already exists in driver_verifications');
      } else {
        console.error('❌ Error adding phone_verified_at to driver_verifications:', e.message);
      }
    }
    
    try {
      await pool.query('ALTER TABLE driver_verifications ADD COLUMN email_verified_at TIMESTAMP');
      console.log('✅ Added email_verified_at to driver_verifications');
    } catch (e) {
      if (e.code === '42701') {
        console.log('ℹ️ email_verified_at already exists in driver_verifications');
      } else {
        console.error('❌ Error adding email_verified_at to driver_verifications:', e.message);
      }
    }
    
    // Verify columns were added
    console.log('\n📋 Checking business_verifications columns:');
    const businessCols = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'business_verifications' 
        AND column_name LIKE '%verified%'
      ORDER BY column_name
    `);
    businessCols.rows.forEach(row => {
      console.log(`  - ${row.column_name}: ${row.data_type}`);
    });
    
    console.log('\n📋 Checking driver_verifications columns:');
    const driverCols = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'driver_verifications' 
        AND column_name LIKE '%verified%'
      ORDER BY column_name
    `);
    driverCols.rows.forEach(row => {
      console.log(`  - ${row.column_name}: ${row.data_type}`);
    });
    
    console.log('\n🎉 Database schema update completed successfully!');
    
  } catch (error) {
    console.error('❌ Database error:', error.message);
    console.error('Full error:', error);
  } finally {
    await pool.end();
  }
}

addMissingColumns();
