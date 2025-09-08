const database = require('./services/database');

async function populateUserEmails() {
  try {
    console.log('🔄 Populating user_email_addresses table...');
    
    // Insert existing user emails into the new table
    const insertResult = await database.query(`
      INSERT INTO user_email_addresses (user_id, email_address, is_verified, is_primary, purpose, email_type, verified_at, verification_method)
      SELECT 
        id as user_id,
        email as email_address,
        email_verified as is_verified,
        true as is_primary,
        'registration' as purpose,
        'personal' as email_type,
        CASE WHEN email_verified THEN created_at ELSE NULL END as verified_at,
        CASE WHEN email_verified THEN 'registration' ELSE NULL END as verification_method
      FROM users 
      WHERE email IS NOT NULL AND email != ''
      ON CONFLICT (user_id, email_address) DO NOTHING
      RETURNING user_id, email_address, is_verified
    `);
    
    console.log(`✅ Populated ${insertResult.rows.length} user emails`);
    insertResult.rows.forEach((row, index) => {
      console.log(`${index + 1}. ${row.email_address} (verified: ${row.is_verified})`);
    });
    
    // Update business_verifications table to add email verification columns
    console.log('\n🔄 Adding email verification columns to business_verifications...');
    
    const alterBusinessResult = await database.query(`
      ALTER TABLE business_verifications 
      ADD COLUMN IF NOT EXISTS email_verification_source VARCHAR(50),
      ADD COLUMN IF NOT EXISTS email_verification_method VARCHAR(50)
    `);
    
    console.log('✅ Business verifications table updated');
    
    // Update driver_verifications table to add email verification columns
    console.log('\n🔄 Adding email verification columns to driver_verifications...');
    
    const alterDriverResult = await database.query(`
      ALTER TABLE driver_verifications 
      ADD COLUMN IF NOT EXISTS email_verification_source VARCHAR(50),
      ADD COLUMN IF NOT EXISTS email_verification_method VARCHAR(50)
    `);
    
    console.log('✅ Driver verifications table updated');
    
    console.log('\n🎉 Unified email system setup completed!');
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
  
  process.exit(0);
}

populateUserEmails();
