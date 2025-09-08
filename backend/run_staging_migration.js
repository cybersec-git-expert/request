const fs = require('fs');
const path = require('path');
const database = require('./services/database');

async function runMigration() {
  try {
    console.log('🚀 Running Price Staging System Migration...');
    
    // Read the migration file
    const migrationPath = path.join(__dirname, 'migrations', 'add_price_staging_system.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf8');
    
    // Execute the migration
    await database.query(migrationSQL);
    
    console.log('✅ Price staging system migration completed successfully!');
    console.log('📊 Created tables:');
    console.log('   - price_staging');
    console.log('   - price_update_history');
    console.log('🕐 Daily price update scheduler is now active (1:00 AM Sri Lanka time)');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

runMigration();
