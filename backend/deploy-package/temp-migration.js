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

module.exports = router;
