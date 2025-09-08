const database = require('./services/database');

async function migrateEmailOtpTable() {
  try {
    console.log('🔄 Migrating email_otp_verifications table...');
    
    // Check current structure
    const structureResult = await database.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'email_otp_verifications' 
      ORDER BY ordinal_position
    `);
    
    console.log('Current columns:', structureResult.rows.map(r => r.column_name));
    
    // Add missing columns
    const columnsToAdd = [
      'id UUID DEFAULT gen_random_uuid()',
      'otp_id VARCHAR(100) UNIQUE',
      'user_id UUID REFERENCES users(id) ON DELETE CASCADE',
      'verification_type VARCHAR(50)',
      'provider_used VARCHAR(50) DEFAULT \'aws_ses\''
    ];
    
    for (const column of columnsToAdd) {
      const columnName = column.split(' ')[0];
      
      // Check if column exists
      const hasColumn = structureResult.rows.some(r => r.column_name === columnName);
      
      if (!hasColumn) {
        console.log(`➕ Adding column: ${columnName}`);
        await database.query(`ALTER TABLE email_otp_verifications ADD COLUMN ${column}`);
      } else {
        console.log(`✅ Column already exists: ${columnName}`);
      }
    }
    
    // Create indexes
    const indexes = [
      'CREATE INDEX IF NOT EXISTS idx_email_otp ON email_otp_verifications (email, otp)',
      'CREATE INDEX IF NOT EXISTS idx_otp_id ON email_otp_verifications (otp_id)',
      'CREATE INDEX IF NOT EXISTS idx_email_verified_otp ON email_otp_verifications (email, verified)'
    ];
    
    for (const indexSql of indexes) {
      console.log('📊 Creating index...');
      await database.query(indexSql);
    }
    
    console.log('🎉 Email OTP table migration completed!');
    
  } catch (error) {
    console.error('❌ Migration error:', error);
  }
  
  process.exit(0);
}

migrateEmailOtpTable();
