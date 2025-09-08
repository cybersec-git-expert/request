const db = require('./services/database');

async function addTestPhoneNumber() {
  try {
    const userId = '5af58de3-896d-4cc3-bd0b-177054916335';
    const phoneNumber = '+94725742238';
    
    console.log('Adding test phone number to user_phone_numbers table...');
    
    // Insert the phone number as verified
    const insertQuery = `
      INSERT INTO user_phone_numbers (user_id, phone_number, country_code, is_verified, is_primary, purpose, verified_at, created_at, updated_at)
      VALUES ($1, $2, $3, true, true, 'business_verification', NOW(), NOW(), NOW())
      ON CONFLICT (user_id, phone_number) 
      DO UPDATE SET is_verified = true, verified_at = NOW(), updated_at = NOW()
      RETURNING *
    `;
    
    const result = await db.query(insertQuery, [userId, phoneNumber, 'LK']);
    console.log('Added/Updated phone number:', result.rows[0]);
    
    // Check the table
    const checkQuery = 'SELECT * FROM user_phone_numbers WHERE user_id = $1';
    const checkResult = await db.query(checkQuery, [userId]);
    console.log('All phone numbers for user:', checkResult.rows);
    
  } catch (error) {
    console.error('Error:', error);
  }
  process.exit(0);
}

addTestPhoneNumber();
