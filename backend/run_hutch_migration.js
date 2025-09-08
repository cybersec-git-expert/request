const database = require('./services/database');
const fs = require('fs');

async function runMigration() {
  try {
    console.log('🚀 Running Hutch Mobile configuration migration...');
    
    const sql = fs.readFileSync('./migrations/add_hutch_mobile_config.sql', 'utf8');
    await database.query(sql);
    
    console.log('✅ Migration completed successfully!');
    console.log('📱 Hutch Mobile SMS provider support added');
    
    // Verify the column was added
    const result = await database.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'sms_configurations' 
      AND column_name = 'hutch_mobile_config'
    `);
    
    if (result.rows.length > 0) {
      console.log('✅ hutch_mobile_config column confirmed in database');
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

runMigration();
