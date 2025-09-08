const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');

// Load env similar to services/database.js
const envCandidates = [
  path.join(process.cwd(), '.env.rds'),
  path.join(__dirname, '.env.rds'),
  path.join(__dirname, '..', '.env.rds'),
];
for (const p of envCandidates) {
  if (fs.existsSync(p)) { dotenv.config({ path: p }); break; }
}

// Database configuration
// Use the same env var names as services/database.js
const dbConfig = {
  user: process.env.DB_USERNAME || process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: parseInt(process.env.DB_PORT || '5432', 10),
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : (process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false)
};

const pool = new Pool(dbConfig);

async function runBusinessTypesRestructuring() {
  const client = await pool.connect();
  
  try {
    console.log('🔄 Starting business types restructuring migration...');
    
    // Read the SQL migration file
    const sqlFilePath = path.join(__dirname, 'database', 'migrations', 'restructure_business_types_system.sql');
    const migrationSQL = fs.readFileSync(sqlFilePath, 'utf8');
    
    // Begin transaction
    await client.query('BEGIN');
    
    // Execute the migration
    await client.query(migrationSQL);
    
    // Commit the transaction
    await client.query('COMMIT');
    
    console.log('✅ Business types restructuring completed successfully!');
    console.log('📋 Summary:');
    console.log('   - business_types table is now for global types (super admin managed)');
    console.log('   - country_business_types table created for country-specific types');
    console.log('   - Existing data preserved in country_business_types');
    console.log('   - Default global business types inserted');
    console.log('   - business_verification table updated with country_business_type_id');
    
  } catch (error) {
    // Rollback on error
    await client.query('ROLLBACK');
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    client.release();
  }
}

// Run the migration
if (require.main === module) {
  runBusinessTypesRestructuring()
    .then(() => {
      console.log('🎉 Migration completed successfully!');
      process.exit(0);
    })
    .catch((error) => {
      console.error('💥 Migration failed:', error.message);
      process.exit(1);
    });
}

module.exports = { runBusinessTypesRestructuring };
