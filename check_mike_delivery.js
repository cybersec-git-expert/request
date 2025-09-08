const { Pool } = require('pg');

const pool = new Pool({
  host: 'requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com',
  port: 5432,
  database: 'request',
  user: 'requestadmindb',
  password: 'RequestMarketplace2024!',
  ssl: {
    rejectUnauthorized: false
  }
});

async function checkMikeDeliveryStatus() {
  try {
    const userId = '5af58de3-896d-4cc3-bd0b-177054916335'; // Mike's user ID from logs
    
    console.log('🔍 Checking Mike\'s delivery business status...\n');
    
    // Check user info
    const userResult = await pool.query('SELECT * FROM users WHERE id = $1', [userId]);
    if (userResult.rows.length === 0) {
      console.log('❌ User not found!');
      return;
    }
    
    const user = userResult.rows[0];
    console.log(`👤 User: ${user.display_name} (${user.email})`);
    console.log(`📱 Phone verified: ${user.phone_verified ? 'Yes' : 'No'}`);
    console.log(`📧 Email verified: ${user.email_verified ? 'Yes' : 'No'}\n`);
    
    // Check business registration
    const businessResult = await pool.query(`
      SELECT * FROM business_verifications 
      WHERE user_id = $1
    `, [userId]);
    
    if (businessResult.rows.length === 0) {
      console.log('❌ No business registration found!');
      console.log('💡 Solution: You need to register as a business first');
      console.log('   Go to: Profile > Business Registration');
      console.log('   Choose category: "Delivery Service"');
      return;
    }
    
    const business = businessResult.rows[0];
    console.log('🏢 Business Registration Found:');
    console.log(`   Name: ${business.business_name || 'No name'}`);
    console.log(`   Category: ${business.business_category || 'No category'}`);
    console.log(`   Status: ${business.status || 'No status'}`);
    console.log(`   Verified: ${business.is_verified ? 'Yes' : 'No'}`);
    console.log(`   Created: ${business.created_at}`);
    
    // Check if delivery capable
    const category = business.business_category?.toLowerCase() || '';
    const isDeliveryCapable = category.includes('delivery') || 
                             category.includes('logistics') || 
                             category.includes('courier');
    
    console.log(`\n🚚 Can Handle Delivery Requests: ${isDeliveryCapable ? '✅ YES' : '❌ NO'}`);
    
    if (!isDeliveryCapable) {
      console.log('\n💡 To fix delivery response issue:');
      console.log('   1. Your business category needs to contain "delivery", "logistics", or "courier"');
      console.log(`   2. Current category: "${business.business_category}"`);
      console.log('   3. Recommended: Change to "Delivery Service"');
    }
    
    if (business.status !== 'approved') {
      console.log('\n⏳ Business Status Issue:');
      console.log(`   Status: ${business.status}`);
      console.log('   Your business registration needs to be approved first');
    }
    
    // Check if we can auto-fix this
    if (business.status === 'approved' && !isDeliveryCapable) {
      console.log('\n🔧 Auto-fix available!');
      console.log('   Updating business category to "Delivery Service"...');
      
      await pool.query(`
        UPDATE business_verifications 
        SET business_category = 'Delivery Service',
            updated_at = NOW()
        WHERE user_id = $1
      `, [userId]);
      
      console.log('✅ Fixed! Your business category is now "Delivery Service"');
      console.log('   You should now be able to respond to delivery requests');
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

checkMikeDeliveryStatus();
