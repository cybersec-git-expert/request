const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const pool = new Pool({
  host: 'requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com',
  port: 5432,
  database: 'request',
  user: 'requestadmindb',
  password: 'RequestMarketplace2024!',
  ssl: {
    rejectUnauthorized: false
  }
});

async function runMigration() {
  try {
    console.log('🔄 Running price listings enhancement migration...');
    
    const migrationPath = path.join(__dirname, 'database', 'migrations', '016_enhance_price_listings.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf8');
    
    await pool.query(migrationSQL);
    
    console.log('✅ Migration completed successfully!');
    
    // Test the new structure
    console.log('\n🔍 Testing price_listings table structure...');
    const result = await pool.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns 
      WHERE table_name = 'price_listings' 
      ORDER BY ordinal_position;
    `);
    
    console.log('Price listings table columns:');
    result.rows.forEach(row => {
      console.log(`  - ${row.column_name}: ${row.data_type} ${row.is_nullable === 'NO' ? 'NOT NULL' : ''}`);
    });
    
    console.log('\n🔍 Testing business_products table structure...');
    const businessProductsResult = await pool.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns 
      WHERE table_name = 'business_products' 
      ORDER BY ordinal_position;
    `);
    
    console.log('Business products table columns:');
    businessProductsResult.rows.forEach(row => {
      console.log(`  - ${row.column_name}: ${row.data_type} ${row.is_nullable === 'NO' ? 'NOT NULL' : ''}`);
    });
    
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    console.error(error);
  } finally {
    await pool.end();
  }
}

runMigration();
