const database = require('./services/database');

async function fixApprovalColumns() {
  try {
    console.log('🔧 Fixing approval column types...');
    
    // Drop existing columns and recreate with correct types
    await database.query(`
      ALTER TABLE sms_configurations 
      DROP COLUMN IF EXISTS approved_by,
      DROP COLUMN IF EXISTS submitted_by
    `);
    console.log('✅ Dropped existing integer columns');
    
    // Add UUID columns
    await database.query(`
      ALTER TABLE sms_configurations 
      ADD COLUMN approved_by UUID,
      ADD COLUMN submitted_by UUID
    `);
    console.log('✅ Added UUID columns');
    
    // Add foreign key constraints
    await database.query(`
      ALTER TABLE sms_configurations 
      ADD CONSTRAINT fk_approved_by 
      FOREIGN KEY (approved_by) REFERENCES admin_users(id)
    `);
    
    await database.query(`
      ALTER TABLE sms_configurations 
      ADD CONSTRAINT fk_submitted_by 
      FOREIGN KEY (submitted_by) REFERENCES admin_users(id)
    `);
    console.log('✅ Added foreign key constraints');
    
    console.log('🎉 Approval columns fixed successfully!');
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

fixApprovalColumns();
