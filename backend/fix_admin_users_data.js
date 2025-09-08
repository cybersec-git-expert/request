const dbService = require('./services/database');

async function fixAdminUsersData() {
  try {
    console.log('🔧 Fixing admin_users table data...');
        
    // Update records with missing timestamps
    const result = await dbService.query(`
            UPDATE admin_users 
            SET 
                created_at = COALESCE(created_at, CURRENT_TIMESTAMP),
                updated_at = COALESCE(updated_at, CURRENT_TIMESTAMP)
            WHERE created_at IS NULL OR updated_at IS NULL
            RETURNING id, email, name, created_at, updated_at
        `);
        
    if (result.rows.length > 0) {
      console.log(`✅ Updated ${result.rows.length} admin user records:`);
      result.rows.forEach(row => {
        console.log(`   - ${row.email} (${row.name}): created_at=${row.created_at}, updated_at=${row.updated_at}`);
      });
    } else {
      console.log('ℹ️ No records needed updating');
    }
        
    // Show current state
    console.log('\n📊 Current admin_users data:');
    const allUsers = await dbService.query('SELECT id, email, name, role, country_code, is_active, created_at, updated_at FROM admin_users ORDER BY created_at');
    allUsers.rows.forEach(row => {
      console.log(`   - ${row.email} (${row.name}) - ${row.role} - ${row.country_code || 'No Country'} - Active: ${row.is_active}`);
      console.log(`     Created: ${row.created_at}, Updated: ${row.updated_at}`);
    });
        
    await dbService.close();
        
  } catch (error) {
    console.error('❌ Error fixing admin users data:', error);
    process.exit(1);
  }
}

fixAdminUsersData();
