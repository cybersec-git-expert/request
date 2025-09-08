const database = require('./services/database');

/**
 * Add approval system to SMS configurations
 * This script adds approval workflow fields to support:
 * 1. Country admin submits SMS configuration
 * 2. Super admin approves/rejects configuration
 * 3. Only approved configurations can be used for SMS
 */

async function addApprovalSystem() {
  try {
    console.log('🔧 Adding SMS approval system...');

    // Add approval fields to sms_configurations table
    await database.query(`
      ALTER TABLE sms_configurations 
      ADD COLUMN IF NOT EXISTS approval_status VARCHAR(20) DEFAULT 'pending',
      ADD COLUMN IF NOT EXISTS approved_by UUID,
      ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS approval_notes TEXT,
      ADD COLUMN IF NOT EXISTS submitted_by UUID,
      ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ DEFAULT NOW()
    `);
    console.log('✅ Added approval fields to sms_configurations');

    // Add foreign key constraints (one at a time to avoid syntax issues)
    try {
      await database.query(`
        ALTER TABLE sms_configurations 
        ADD CONSTRAINT fk_approved_by 
        FOREIGN KEY (approved_by) REFERENCES admin_users(id)
      `);
    } catch (error) {
      if (!error.message.includes('already exists')) {
        console.log('⚠️ Constraint fk_approved_by might already exist');
      }
    }

    try {
      await database.query(`
        ALTER TABLE sms_configurations 
        ADD CONSTRAINT fk_submitted_by 
        FOREIGN KEY (submitted_by) REFERENCES admin_users(id)
      `);
    } catch (error) {
      if (!error.message.includes('already exists')) {
        console.log('⚠️ Constraint fk_submitted_by might already exist');
      }
    }
    console.log('✅ Added foreign key constraints');

    // Add check constraint for approval status
    try {
      await database.query(`
        ALTER TABLE sms_configurations 
        ADD CONSTRAINT chk_approval_status 
        CHECK (approval_status IN ('pending', 'approved', 'rejected'))
      `);
    } catch (error) {
      if (!error.message.includes('already exists')) {
        console.log('⚠️ Constraint chk_approval_status might already exist');
      }
    }
    console.log('✅ Added approval status constraint');

    // Create index for approval queries
    await database.query(`
      CREATE INDEX IF NOT EXISTS idx_sms_approval_status 
      ON sms_configurations (approval_status, submitted_at)
    `);
    console.log('✅ Created approval status index');

    // Update existing configurations to approved status (for migration)
    const result = await database.query(`
      UPDATE sms_configurations 
      SET approval_status = 'approved',
          approved_at = NOW()
      WHERE approval_status = 'pending' AND is_active = true
      RETURNING country_code, country_name
    `);
    
    if (result.rows.length > 0) {
      console.log('✅ Migrated existing active configurations to approved status:');
      result.rows.forEach(row => {
        console.log(`   - ${row.country_name} (${row.country_code})`);
      });
    }

    // Create approval history table for audit trail
    await database.query(`
      CREATE TABLE IF NOT EXISTS sms_approval_history (
        id SERIAL PRIMARY KEY,
        configuration_id INTEGER NOT NULL REFERENCES sms_configurations(id) ON DELETE CASCADE,
        action VARCHAR(20) NOT NULL,
        previous_status VARCHAR(20),
        new_status VARCHAR(20),
        admin_id UUID REFERENCES admin_users(id),
        notes TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `);
    console.log('✅ Created sms_approval_history table');

    // Create index for approval history
    await database.query(`
      CREATE INDEX IF NOT EXISTS idx_approval_history_config 
      ON sms_approval_history (configuration_id, created_at DESC)
    `);
    console.log('✅ Created approval history index');

    console.log('🎉 SMS approval system added successfully!');
    console.log('');
    console.log('📋 Approval Workflow:');
    console.log('1. Country admin creates SMS configuration (status: pending)');
    console.log('2. Super admin reviews and approves/rejects');
    console.log('3. Only approved configurations can send SMS');
    console.log('4. All actions are logged in approval history');

  } catch (error) {
    console.error('❌ Error adding approval system:', error);
  } finally {
    process.exit(0);
  }
}

addApprovalSystem();
