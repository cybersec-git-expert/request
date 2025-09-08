// Script to add contentManagement permission to admin users
import { collection, getDocs, updateDoc, doc } from 'firebase/firestore';
import { db } from './src/firebase/config.js';

async function addContentManagementPermission() {
  console.log('🔧 Adding contentManagement permission to admin users...');
  console.log('======================================================');
  
  try {
    const adminQuery = collection(db, 'admin_users');
    const snapshot = await getDocs(adminQuery);
    
    console.log(`📊 Found ${snapshot.size} admin users`);
    
    for (const adminDoc of snapshot.docs) {
      const data = adminDoc.data();
      const currentPermissions = data.permissions || {};
      
      // Add contentManagement permission based on role
      const updatedPermissions = {
        ...currentPermissions,
        contentManagement: true // Both super admin and country admin get this permission
      };
      
      await updateDoc(doc(db, 'admin_users', adminDoc.id), {
        permissions: updatedPermissions
      });
      
      console.log(`✅ Updated permissions for: ${data.email} (${data.country || 'Global'})`);
      console.log(`   Role: ${data.role}`);
      console.log(`   Added: contentManagement = true`);
      console.log('   ---');
    }
    
    console.log('🎉 Content management permissions added successfully!');
    
    // Now check the updated permissions
    console.log('\n📋 Updated Permission Structure:');
    const updatedSnapshot = await getDocs(adminQuery);
    updatedSnapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      console.log(`${index + 1}. ${data.email} (${data.country || 'Global'})`);
      console.log(`   contentManagement: ${data.permissions?.contentManagement}`);
    });
    
  } catch (error) {
    console.error('❌ Error adding permissions:', error);
  }
}

// Run the script
addContentManagementPermission();
