const dbService = require('../backend/services/database');

/**
 * Standard permissions for all admin users
 */
const STANDARD_PERMISSIONS = {
  // Request Management
  requestManagement: true,
  responseManagement: true,
  priceListingManagement: true,
  
  // Business Management
  productManagement: true,
  businessManagement: true,
  driverVerification: true,
  
  // Vehicle Management
  vehicleManagement: true,
  countryVehicleTypeManagement: true,
  
  // City Management
  cityManagement: true,
  
  // User & Module Management
  userManagement: true,
  subscriptionManagement: true,
  promoCodeManagement: true,
  moduleManagement: true,
  
  // Product Catalog Management
  categoryManagement: true,
  subcategoryManagement: true,
  brandManagement: true,
  variableTypeManagement: true,
  
  // Country-specific Management (for country admins)
  countryProductManagement: true,
  countryCategoryManagement: true,
  countrySubcategoryManagement: true,
  countryBrandManagement: true,
  countryVariableTypeManagement: true,
  countryVehicleTypeManagement: true,
  
  // Content Management
  contentManagement: true,
  countryPageManagement: true,
  
  // Legal & Payment (available for country admins too)
  paymentMethodManagement: true,
  legalDocumentManagement: true,
  
  // SMS Configuration
  smsConfiguration: true
};

/**
 * Permissions only for super admins
 */
const SUPER_ADMIN_ONLY_PERMISSIONS = {
  adminUsersManagement: true
};

/**
 * Auto-propagate permissions to all existing admin users in PostgreSQL
 */
async function propagatePermissions() {
  console.log('🔄 Auto-propagating permissions to all admin users in PostgreSQL...\n');
  
  try {
    const result = await dbService.query('SELECT id, email, role, permissions FROM admin_users ORDER BY created_at');
    console.log(`📊 Found ${result.rows.length} admin users\n`);
    
    for (const adminUser of result.rows) {
      const currentPermissions = adminUser.permissions || {};
      const role = adminUser.role;
      
      // Start with standard permissions
      let updatedPermissions = { ...currentPermissions, ...STANDARD_PERMISSIONS };
      
      // Add super admin only permissions for super admins
      if (role === 'super_admin') {
        updatedPermissions = { ...updatedPermissions, ...SUPER_ADMIN_ONLY_PERMISSIONS };
      }
      
      // Find new permissions that were added
      const newPermissions = [];
      for (const [permission, value] of Object.entries(updatedPermissions)) {
        if (currentPermissions[permission] === undefined) {
          newPermissions.push(permission);
        }
      }
      
      if (newPermissions.length > 0) {
        // Update the user with new permissions
        await dbService.query(
          'UPDATE admin_users SET permissions = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
          [updatedPermissions, adminUser.id]
        );
        
        console.log(`✅ Updated: ${adminUser.email} (${role})`);
        console.log(`   📝 Added new permissions: ${newPermissions.join(', ')}\n`);
      } else {
        console.log(`✅ Updated: ${adminUser.email} (${role})`);
        console.log(`   ℹ️  No new permissions to add\n`);
      }
    }
    
    console.log('🎉 Permission propagation complete!\n');
    
    console.log('📋 Summary of standard permissions:');
    console.log('=====================================');
    Object.keys(STANDARD_PERMISSIONS).forEach(permission => {
      console.log(`✓ ${permission}`);
    });
    
    console.log('\n👑 Super Admin only permissions:');
    console.log('==================================');
    Object.keys(SUPER_ADMIN_ONLY_PERMISSIONS).forEach(permission => {
      console.log(`✓ ${permission}`);
    });
    
  } catch (error) {
    console.error('❌ Error during permission propagation:', error);
    throw error;
  }
}

// Run if called directly
if (require.main === module) {
  propagatePermissions()
    .then(() => {
      console.log('\n✅ Script completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('\n❌ Script failed:', error);
      process.exit(1);
    });
}

module.exports = { 
  propagatePermissions, 
  STANDARD_PERMISSIONS, 
  SUPER_ADMIN_ONLY_PERMISSIONS 
};
