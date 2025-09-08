const { Pool } = require('pg');
const fs = require('fs').promises;
const path = require('path');

// Load environment variables
require('dotenv').config({ path: '.env.rds' });

async function runBusinessTypeMigration() {
  const pool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false
  });

  try {
    console.log('🔄 Starting business type migration...');
    
    // Read migration file
    const migrationPath = path.join(__dirname, 'database', 'migrations', 'create_business_types_system.sql');
    const migrationSQL = await fs.readFile(migrationPath, 'utf8');
    
    // Run migration
    await pool.query(migrationSQL);
    console.log('✅ Migration completed successfully');
    
    // Verify results
    console.log('\n📊 Checking migration results...');
    
    const typeDistribution = await pool.query(`
      SELECT business_type, COUNT(*) as count 
      FROM business_verifications 
      GROUP BY business_type 
      ORDER BY count DESC
    `);
    
    console.log('Business type distribution:');
    typeDistribution.rows.forEach(row => {
      console.log(`  ${row.business_type}: ${row.count}`);
    });
    
    // Check sample data
    const sampleData = await pool.query(`
      SELECT business_name, business_category, business_type, categories
      FROM business_verifications 
      ORDER BY created_at DESC 
      LIMIT 5
    `);
    
    console.log('\nSample converted data:');
    sampleData.rows.forEach(row => {
      console.log(`  ${row.business_name}:`);
      console.log(`    Old category: ${row.business_category}`);
      console.log(`    New type: ${row.business_type}`);
      console.log(`    Categories: ${JSON.stringify(row.categories)}`);
    });
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    await pool.end();
  }
}

// Run if called directly
if (require.main === module) {
  runBusinessTypeMigration()
    .then(() => {
      console.log('\n🎉 Migration completed successfully!');
      process.exit(0);
    })
    .catch(error => {
      console.error('\n💥 Migration failed:', error);
      process.exit(1);
    });
}

module.exports = { runBusinessTypeMigration };
