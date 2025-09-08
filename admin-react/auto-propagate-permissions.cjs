const { initializeApp } = require('firebase/app');
const { getFirestore, collection, getDocs, doc, updateDoc } = require('firebase/firestore');

const firebaseConfig = {
  projectId: 'request-marketplace'
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

/**
 * Standard permissions that should be available to all admin types
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
  vehicleManagement: true, // Now available for all admin types
  
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
  countryVehicleTypeManagement: true, // NEW: Country-specific vehicle types
  
  // Content Management
  contentManagement: true,
  countryPageManagement: true,
  
  // Legal & Payment (available for country admins too)
  paymentMethodManagement: true,
  legalDocumentManagement: true
};

/**
 * Permissions only for super admins
 */
const SUPER_ADMIN_ONLY_PERMISSIONS = {
  adminUsersManagement: true
};

/**
 * Auto-propagate permissions to all existing admin users
 */
async function propagatePermissions() {
  console.log('🔄 Auto-propagating permissions to all admin users...\n');
  
  try {
    const adminSnapshot = await getDocs(collection(db, 'admin_users'));
    console.log(`📊 Found ${adminSnapshot.docs.length} admin users\n`);
    
    for (const adminDoc of adminSnapshot.docs) {
      const data = adminDoc.data();
      const currentPermissions = data.permissions || {};
      const role = data.role;
      
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
      
      // Update the document
      await updateDoc(doc(db, 'admin_users', adminDoc.id), {
        permissions: updatedPermissions,
        lastPermissionUpdate: new Date()
      });
      
      console.log(`✅ Updated: ${data.email} (${role})`);
      if (newPermissions.length > 0) {
        console.log(`   📝 Added new permissions: ${newPermissions.join(', ')}`);
      } else {
        console.log(`   ℹ️  No new permissions to add`);
      }
      console.log('');
    }
    
    console.log('🎉 Permission propagation complete!');
    console.log('\n📋 Summary of standard permissions:');
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
    console.error('❌ Error propagating permissions:', error);
  }
}

// Run if called directly
if (require.main === module) {
  propagatePermissions().then(() => process.exit(0));
}

module.exports = { propagatePermissions, STANDARD_PERMISSIONS, SUPER_ADMIN_ONLY_PERMISSIONS };
