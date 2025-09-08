const fs = require('fs');
const path = require('path');
const database = require('./services/database');

async function runMigration() {
  try {
    console.log('🚀 Running SMS system migration...');
    
    // Read the migration file
    const migrationPath = path.join(__dirname, 'migrations', 'create_sms_system.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf8');
    
    // Split by semicolons to execute each statement separately
    const statements = migrationSQL
      .split(';')
      .map(stmt => stmt.trim())
      .filter(stmt => stmt.length > 0 && !stmt.startsWith('--'));
    
    console.log(`📄 Found ${statements.length} SQL statements to execute`);
    
    for (let i = 0; i < statements.length; i++) {
      const statement = statements[i];
      if (statement.trim()) {
        try {
          console.log(`⚡ Executing statement ${i + 1}/${statements.length}...`);
          await database.query(statement);
        } catch (error) {
          // Some statements might fail if they already exist, that's okay
          if (error.message.includes('already exists') || error.message.includes('relation') && error.message.includes('already exists')) {
            console.log(`⚠️  Statement ${i + 1} skipped (already exists)`);
          } else {
            console.error(`❌ Error in statement ${i + 1}:`, error.message);
            console.log('Statement:', statement.substring(0, 100) + '...');
          }
        }
      }
    }
    
    console.log('✅ SMS system migration completed!');
    
    // Test the tables
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
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
  }
}

runMigration();
