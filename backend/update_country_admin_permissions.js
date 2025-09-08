const dbService = require('./services/database');

async function updateCountryAdminPermissions() {
  try {
    // Get current permissions
    const result = await dbService.query('SELECT permissions FROM admin_users WHERE email = $1', ['rimas@request.lk']);
    if (result.rows.length === 0) {
      console.log('User not found');
      return;
    }
    
    const currentPermissions = result.rows[0].permissions || {};
    console.log('Current permissions count:', Object.keys(currentPermissions).length);
    
    // Add missing country-specific permissions
    const updatedPermissions = {
      ...currentPermissions,
      countryProductManagement: true,
      countryCategoryManagement: true,
      countrySubcategoryManagement: true,
      countryBrandManagement: true,
      countryVariableTypeManagement: true,
      contentManagement: true
    };
    
    console.log('Updated permissions count:', Object.keys(updatedPermissions).length);
    
    // Update the user
    await dbService.query(
      'UPDATE admin_users SET permissions = $1 WHERE email = $2',
      [updatedPermissions, 'rimas@request.lk']
    );
    
    console.log('✅ Successfully updated permissions for rimas@request.lk');
    console.log('Added permissions:');
    console.log('- countryProductManagement');
    console.log('- countryCategoryManagement');
    console.log('- countrySubcategoryManagement');
    console.log('- countryBrandManagement');
    console.log('- countryVariableTypeManagement');
    console.log('- contentManagement');
    
  } catch (error) {
    console.error('Error:', error.message);
  }
  process.exit(0);
}

updateCountryAdminPermissions();
