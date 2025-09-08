const dbService = require('./services/database');

async function checkUser() {
  try {
    const result = await dbService.query('SELECT email, role, country_code, permissions FROM admin_users WHERE email = $1', ['admin@india.request.com']);
    const user = result.rows[0];
    console.log('📧 Email:', user.email);
    console.log('🌍 Country:', user.country_code);
    console.log('🔑 Total Permissions:', Object.keys(user.permissions).length);
    console.log('✅ Key Permissions:');
    console.log('   - requestManagement:', !!user.permissions.requestManagement);
    console.log('   - countryProductManagement:', !!user.permissions.countryProductManagement);
    console.log('   - countryCategoryManagement:', !!user.permissions.countryCategoryManagement);
    console.log('   - businessManagement:', !!user.permissions.businessManagement);
    console.log('   - adminUsersManagement:', !!user.permissions.adminUsersManagement);
  } catch (error) {
    console.error('Error:', error.message);
  }
  process.exit(0);
}

checkUser();
