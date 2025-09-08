const express = require('express');
const router = express.Router();
const database = require('../services/database');

// Temporary migration endpoint to add missing columns
router.post('/add-verification-columns', async (req, res) => {
  try {
    console.log('🔧 Adding missing verification timestamp columns...');
    
    const operations = [];
    
    // Add columns to business_verifications table
    try {
      await database.query('ALTER TABLE business_verifications ADD COLUMN phone_verified_at TIMESTAMP');
      operations.push('✅ Added phone_verified_at to business_verifications');
    } catch (e) {
      if (e.code === '42701') {
        operations.push('ℹ️ phone_verified_at already exists in business_verifications');
      } else {
        operations.push(`❌ Error adding phone_verified_at to business_verifications: ${e.message}`);
      }
    }
    
    try {
      await database.query('ALTER TABLE business_verifications ADD COLUMN email_verified_at TIMESTAMP');
      operations.push('✅ Added email_verified_at to business_verifications');
    } catch (e) {
      if (e.code === '42701') {
        operations.push('ℹ️ email_verified_at already exists in business_verifications');
      } else {
        operations.push(`❌ Error adding email_verified_at to business_verifications: ${e.message}`);
      }
    }
    
    // Add columns to driver_verifications table
    try {
      await database.query('ALTER TABLE driver_verifications ADD COLUMN phone_verified_at TIMESTAMP');
      operations.push('✅ Added phone_verified_at to driver_verifications');
    } catch (e) {
      if (e.code === '42701') {
        operations.push('ℹ️ phone_verified_at already exists in driver_verifications');
      } else {
        operations.push(`❌ Error adding phone_verified_at to driver_verifications: ${e.message}`);
      }
    }
    
    try {
      await database.query('ALTER TABLE driver_verifications ADD COLUMN email_verified_at TIMESTAMP');
      operations.push('✅ Added email_verified_at to driver_verifications');
    } catch (e) {
      if (e.code === '42701') {
        operations.push('ℹ️ email_verified_at already exists in driver_verifications');
      } else {
        operations.push(`❌ Error adding email_verified_at to driver_verifications: ${e.message}`);
      }
    }
    
    // Verify columns were added
    const businessCols = await database.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'business_verifications' 
        AND column_name LIKE '%verified%'
      ORDER BY column_name
    `);
    
    const driverCols = await database.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'driver_verifications' 
        AND column_name LIKE '%verified%'
      ORDER BY column_name
    `);
    
    res.json({
      success: true,
      message: 'Database migration completed',
      operations,
      businessVerificationColumns: businessCols.rows,
      driverVerificationColumns: driverCols.rows
    });
    
  } catch (error) {
    console.error('❌ Migration error:', error);
    res.status(500).json({
      success: false,
      message: 'Migration failed',
      error: error.message
    });
  }
});

// Fix missing is_urgent column in requests table
router.post('/fix-urgent-column', async (req, res) => {
  try {
    console.log('🔧 Fixing missing is_urgent columns in requests table...');
    
    const operations = [];
    
    // Check if is_urgent column exists
    const checkResult = await database.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'requests' AND column_name = 'is_urgent'
    `);
    
    if (checkResult.rows.length === 0) {
      console.log('❌ is_urgent column does not exist. Adding it...');
      
      try {
        // Add the urgent columns
        await database.query(`
          BEGIN;
          
          -- Add urgent boost fields to requests
          ALTER TABLE requests
            ADD COLUMN is_urgent BOOLEAN NOT NULL DEFAULT false,
            ADD COLUMN urgent_until TIMESTAMPTZ,
            ADD COLUMN urgent_paid_tx_id UUID;
          
          -- Helpful index for active urgent sorting/filtering
          CREATE INDEX IF NOT EXISTS idx_requests_urgent_active ON requests ((is_urgent AND urgent_until > now()));
          
          COMMIT;
        `);
        
        operations.push('✅ Successfully added is_urgent columns to requests table');
      } catch (e) {
        operations.push(`❌ Error adding is_urgent columns: ${e.message}`);
        throw e;
      }
    } else {
      operations.push('✅ is_urgent column already exists');
    }
    
    // Test the query that was failing
    try {
      const testResult = await database.query(`
        SELECT COUNT(*) as total, 
               COUNT(*) FILTER (WHERE is_urgent = true) as urgent_count 
        FROM requests 
        LIMIT 1
      `);
      operations.push(`📊 Test query successful: ${testResult.rows[0].total} total requests, ${testResult.rows[0].urgent_count} urgent`);
    } catch (e) {
      operations.push(`❌ Test query failed: ${e.message}`);
    }
    
    // Verify columns exist now
    const columnsResult = await database.query(`
      SELECT column_name, data_type, column_default
      FROM information_schema.columns 
      WHERE table_name = 'requests' 
        AND column_name IN ('is_urgent', 'urgent_until', 'urgent_paid_tx_id')
      ORDER BY column_name
    `);
    
    res.json({
      success: true,
      message: 'Urgent column fix completed',
      operations,
      addedColumns: columnsResult.rows
    });
    
  } catch (error) {
    console.error('❌ Urgent column fix error:', error);
    res.status(500).json({
      success: false,
      message: 'Urgent column fix failed',
      error: error.message
    });
  }
});

// Fix permissions for email_otp_verifications table
router.post('/fix-permissions', async (req, res) => {
  try {
    console.log('🔑 Attempting to fix table permissions...');
    
    const operations = [];
    
    // Check current user
    const currentUser = await database.query('SELECT current_user, session_user');
    operations.push(`Current user: ${currentUser.rows[0].current_user}`);
    
    // Check if email_otp_verifications table exists
    const tableExists = await database.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'email_otp_verifications'
      )
    `);
    
    if (!tableExists.rows[0].exists) {
      operations.push('❌ email_otp_verifications table does not exist');
      
      // Try to create the table if it doesn't exist
      try {
        await database.query(`
          CREATE TABLE IF NOT EXISTS email_otp_verifications (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            email VARCHAR(255) NOT NULL,
            otp_code VARCHAR(10) NOT NULL,
            expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
            used BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
            user_id UUID,
            otp_id VARCHAR(100),
            verification_type VARCHAR(50),
            provider_used VARCHAR(50) DEFAULT 'aws_ses'
          )
        `);
        operations.push('✅ Created email_otp_verifications table');
      } catch (createError) {
        operations.push(`❌ Failed to create table: ${createError.message}`);
      }
    } else {
      operations.push('✅ email_otp_verifications table exists');
    }
    
    // Check table owner
    const tableOwner = await database.query(`
      SELECT tableowner 
      FROM pg_tables 
      WHERE schemaname = 'public' 
      AND tablename = 'email_otp_verifications'
    `);
    
    if (tableOwner.rows.length > 0) {
      operations.push(`Table owner: ${tableOwner.rows[0].tableowner}`);
    }
    
    // Check current permissions
    const permissions = await database.query(`
      SELECT 
        grantee, 
        privilege_type
      FROM information_schema.role_table_grants 
      WHERE table_name = 'email_otp_verifications'
    `);
    
    operations.push(`Current permissions: ${JSON.stringify(permissions.rows)}`);
    
    // Test if we can perform operations on the table
    try {
      const testCount = await database.query('SELECT COUNT(*) FROM email_otp_verifications');
      operations.push(`✅ Can read from table (count: ${testCount.rows[0].count})`);
    } catch (readError) {
      operations.push(`❌ Cannot read from table: ${readError.message}`);
    }
    
    try {
      // Test if we can insert (we'll roll this back)
      await database.query('BEGIN');
      await database.query(`
        INSERT INTO email_otp_verifications (email, otp_code, expires_at) 
        VALUES ('test@example.com', '123456', NOW() + INTERVAL '10 minutes')
      `);
      await database.query('ROLLBACK');
      operations.push('✅ Can write to table');
    } catch (writeError) {
      await database.query('ROLLBACK');
      operations.push(`❌ Cannot write to table: ${writeError.message}`);
    }
    
    res.json({
      success: true,
      message: 'Permission check completed',
      operations
    });
    
  } catch (error) {
    console.error('❌ Permission check error:', error);
    res.status(500).json({
      success: false,
      message: 'Permission check failed',
      error: error.message
    });
  }
});

module.exports = router;
