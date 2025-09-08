const { Pool } = require('pg');
const fs = require('fs').promises;
const path = require('path');

// Database configuration
const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'request-lk-db.c8na2aebfrj0.us-east-1.rds.amazonaws.com',
  database: process.env.DB_NAME || 'request_lk_db',
  password: process.env.DB_PASSWORD || 'Eohlj12Gd',
  port: process.env.DB_PORT || 5432,
  ssl: {
    rejectUnauthorized: false
  }
});

async function runGlobalBusinessTypesMigration() {
  try {
    console.log('🔄 Starting global business types migration...');
    
    // Read migration file
    const migrationPath = path.join(__dirname, 'database', 'migrations', 'create_global_business_types.sql');
    const migrationSQL = await fs.readFile(migrationPath, 'utf8');
    
    // Run migration
    await pool.query(migrationSQL);
    console.log('✅ Migration completed successfully');
    
    // Verify results
    console.log('\n📊 Checking migration results...');
    
    const globalTypesCount = await pool.query(`
      SELECT COUNT(*) as count 
      FROM global_business_types
    `);
    
    console.log(`Global business types created: ${globalTypesCount.rows[0].count}`);
    
    const businessTypesWithGlobal = await pool.query(`
      SELECT 
        bt.name,
        bt.country_code,
        gbt.name as global_name
      FROM business_types bt
      LEFT JOIN global_business_types gbt ON bt.global_type_id = gbt.id
      ORDER BY bt.country_code, bt.name
    `);
    
    console.log('\nBusiness types with global references:');
    businessTypesWithGlobal.rows.forEach(row => {
      console.log(`  ${row.country_code}: ${row.name} → ${row.global_name || 'No global reference'}`);
    });
    
    // Sample global business types
    const sampleGlobalTypes = await pool.query(`
      SELECT name, description, icon, display_order
      FROM global_business_types 
      ORDER BY display_order 
      LIMIT 10
    `);
    
    console.log('\nSample global business types:');
    sampleGlobalTypes.rows.forEach(row => {
      console.log(`  ${row.icon} ${row.name} (${row.display_order})`);
    });
    
    console.log('\n🎉 Global business types migration completed successfully!');
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    console.error('💥 Migration failed:', error.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

// Only run if called directly
if (require.main === module) {
  runGlobalBusinessTypesMigration().catch(console.error);
}

module.exports = { runGlobalBusinessTypesMigration };
