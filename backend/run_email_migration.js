const fs = require('fs');
const path = require('path');
const database = require('./services/database');

async function runEmailSystemMigration() {
  try {
    console.log('🔄 Running unified email system migration...');
    
    const sqlPath = path.join(__dirname, 'migrations', 'create_unified_email_system.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    
    // Split SQL into individual statements
    const statements = sql.split(';').filter(stmt => stmt.trim().length > 0);
    
    for (let i = 0; i < statements.length; i++) {
      const statement = statements[i].trim();
      if (statement) {
        console.log(`📝 Executing statement ${i + 1}/${statements.length}...`);
        await database.query(statement);
        console.log(`✅ Statement ${i + 1} completed`);
      }
    }
    
    console.log('🎉 Unified email system migration completed successfully!');
    
    // Verify the migration
    console.log('\n🔍 Verifying migration...');
    
    const userEmailsResult = await database.query('SELECT COUNT(*) FROM user_email_addresses');
    console.log(`📧 user_email_addresses table: ${userEmailsResult.rows[0].count} records`);
    
    const emailOtpResult = await database.query('SELECT COUNT(*) FROM email_otp_verifications');
    console.log(`🔑 email_otp_verifications table: ${emailOtpResult.rows[0].count} records`);
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
  }
  
  process.exit(0);
}

runEmailSystemMigration();
