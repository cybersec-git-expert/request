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

async function checkDeliveryBusinessStatus() {
  try {
    console.log('🔍 Checking delivery business status...\n');
    
    // Get all business verifications with user info
    const result = await pool.query(`
      SELECT 
        bv.id,
        bv.user_id,
        u.display_name,
        u.email,
        bv.business_name,
        bv.business_category,
        bv.status,
        bv.is_verified,
        bv.created_at
      FROM business_verifications bv
      JOIN users u ON bv.user_id = u.id
      ORDER BY bv.created_at DESC
    `);
    
    console.log(`📊 Found ${result.rows.length} business registrations:\n`);
    
    result.rows.forEach((business, index) => {
      const isDeliveryCapable = business.business_category && 
        (business.business_category.toLowerCase().includes('delivery') ||
         business.business_category.toLowerCase().includes('logistics') ||
         business.business_category.toLowerCase().includes('courier'));
      
      console.log(`${index + 1}. ${business.business_name || 'No Name'}`);
      console.log(`   User: ${business.display_name} (${business.email})`);
      console.log(`   Category: ${business.business_category || 'No category'}`);
      console.log(`   Status: ${business.status || 'No status'}`);
      console.log(`   Verified: ${business.is_verified ? 'Yes' : 'No'}`);
      console.log(`   Can Handle Delivery: ${isDeliveryCapable ? '✅ YES' : '❌ NO'}`);
      console.log(`   User ID: ${business.user_id}`);
      console.log('   ' + '-'.repeat(50));
    });
    
    // Check for common issues
    const pendingBusinesses = result.rows.filter(b => b.status === 'pending');
    const approvedBusinesses = result.rows.filter(b => b.status === 'approved');
    const deliveryBusinesses = result.rows.filter(b => {
      const category = b.business_category?.toLowerCase() || '';
      return category.includes('delivery') || category.includes('logistics') || category.includes('courier');
    });
    
    console.log('\n📈 Summary:');
    console.log(`Total businesses: ${result.rows.length}`);
    console.log(`Pending approval: ${pendingBusinesses.length}`);
    console.log(`Approved: ${approvedBusinesses.length}`);
    console.log(`Delivery capable: ${deliveryBusinesses.length}`);
    
    if (pendingBusinesses.length > 0) {
      console.log('\n⏳ Pending businesses that need approval:');
      pendingBusinesses.forEach(b => {
        console.log(`   - ${b.business_name} (${b.display_name})`);
      });
    }
    
    if (approvedBusinesses.length > 0 && deliveryBusinesses.length === 0) {
      console.log('\n⚠️  Warning: You have approved businesses but none are set up for delivery!');
      console.log('   Make sure your business category includes "Delivery Service", "Logistics", or "Courier"');
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    await pool.end();
  }
}

checkDeliveryBusinessStatus();
