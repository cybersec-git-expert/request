const db = require('./services/database.js');

(async () => {
  try {
    const userId = 'ee9776a6-afde-4256-9374-aab0c24e4a70'; // Rimas Mohamed
    const carVehicleTypeId = 'b04c3142-91e0-49f1-b7dc-b22714bd32bf'; // Car
    
    console.log('Creating verifications for Rimas Mohamed...');
    
    // Check if driver verification already exists
    const existingDriver = await db.query('SELECT id FROM driver_verifications WHERE user_id = $1', [userId]);
    if (existingDriver.rows.length === 0) {
      console.log('Creating driver verification (Car)...');
      await db.query(`
        INSERT INTO driver_verifications (
          user_id, first_name, last_name, full_name, email, 
          vehicle_type_id, vehicle_type_name, status, 
          is_verified, created_at, updated_at
        ) VALUES (
          $1, 'Rimas', 'Mohamed', 'Rimas Mohamed', 'cyber.sec.expert@outlook.com',
          $2, 'Car', 'approved',
          true, NOW(), NOW()
        )
      `, [userId, carVehicleTypeId]);
      console.log('✅ Driver verification created');
    } else {
      console.log('Driver verification already exists');
    }
    
    // Check if business verification already exists  
    const existingBusiness = await db.query('SELECT id FROM business_verifications WHERE user_id = $1', [userId]);
    if (existingBusiness.rows.length === 0) {
      console.log('Creating business verification (Delivery Service)...');
      await db.query(`
        INSERT INTO business_verifications (
          user_id, business_name, business_email, business_category,
          business_description, status, is_verified, 
          created_at, updated_at
        ) VALUES (
          $1, 'Rimas Delivery Service', 'cyber.sec.expert@outlook.com', 'Delivery Service',
          'Fast and reliable delivery service', 'approved', true,
          NOW(), NOW()
        )
      `, [userId]);
      console.log('✅ Business verification created');
    } else {
      console.log('Business verification already exists');
    }
    
    console.log('\n=== VERIFICATION CHECK ===');
    const driverCheck = await db.query('SELECT status, vehicle_type_name FROM driver_verifications WHERE user_id = $1', [userId]);
    const businessCheck = await db.query('SELECT status, business_category FROM business_verifications WHERE user_id = $1', [userId]);
    
    console.log('Driver verification:', driverCheck.rows);
    console.log('Business verification:', businessCheck.rows);
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
})();
