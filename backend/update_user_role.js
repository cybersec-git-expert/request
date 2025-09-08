const database = require('./services/database');

async function updateUserRoleForBusiness() {
  try {
    const userId = '5af58de3-896d-4cc3-bd0b-177054916335';
    
    console.log('🔍 Checking current user role...');
    const userResult = await database.query('SELECT id, email, role FROM users WHERE id = $1', [userId]);
    console.log('👤 Current user:', userResult.rows[0]);
    
    console.log('\n🔍 Checking business verification...');
    const businessResult = await database.query('SELECT status, business_name FROM business_verifications WHERE user_id = $1', [userId]);
    
    if (businessResult.rows.length === 0) {
      console.log('❌ No business verification found');
      process.exit(1);
    }
    
    const business = businessResult.rows[0];
    console.log('🏢 Business verification:', business);
    
    if (business.status === 'pending') {
      console.log('\n🔄 Business is pending approval. Temporarily updating user role to show correct status...');
      
      // For now, just update to show that user has submitted business verification
      // In production, this would be handled by the approval workflow
      const updateResult = await database.query(
        'UPDATE users SET role = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 RETURNING *',
        ['business_pending', userId]
      );
      
      console.log('✅ User role updated to business_pending:', updateResult.rows[0]);
    }
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

updateUserRoleForBusiness();
