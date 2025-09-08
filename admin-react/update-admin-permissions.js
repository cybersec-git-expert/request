import { initializeApp } from 'firebase/app';
import { getFirestore, doc, updateDoc, getDocs, collection, query, where } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyCtuD42SzwxKmSY5p-x5olFex2U_S9YrMk",
  authDomain: "request-marketplace.firebaseapp.com",
  projectId: "request-marketplace",
  storageBucket: "request-marketplace.firebasestorage.app",
  messagingSenderId: "355474518888",
  appId: "1:355474518888:web:7b3a7f6f7d7a8b0d8e8f9f"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function updateAdminPermissions() {
  try {
    console.log('🔧 Updating admin user permissions...');
    
    // Get all admin users
    const adminQuery = query(collection(db, 'admin_users'));
    const adminSnapshot = await getDocs(adminQuery);
    
    if (adminSnapshot.empty) {
      console.log('❌ No admin users found');
      return;
    }
    
    console.log(`📋 Found ${adminSnapshot.docs.length} admin users`);
    
    for (const adminDoc of adminSnapshot.docs) {
      const adminData = adminDoc.data();
      const adminId = adminDoc.id;
      
      console.log(`\n👤 Processing: ${adminData.displayName || adminData.email}`);
      console.log(`   Role: ${adminData.role}`);
      console.log(`   Current permissions:`, adminData.permissions);
      
      // Prepare updated permissions
      const updatedPermissions = {
        paymentMethods: adminData.permissions?.paymentMethods !== undefined ? adminData.permissions.paymentMethods : true,
        legalDocuments: adminData.permissions?.legalDocuments !== undefined ? adminData.permissions.legalDocuments : true,
        businessManagement: adminData.permissions?.businessManagement !== undefined ? adminData.permissions.businessManagement : true,
        driverManagement: adminData.permissions?.driverManagement !== undefined ? adminData.permissions.driverManagement : true,
        // Add the new permission - give it to super admins by default, not to country admins
        adminUsersManagement: adminData.role === 'super_admin'
      };
      
      console.log(`   New permissions:`, updatedPermissions);
      
      // Update the document
      await updateDoc(doc(db, 'admin_users', adminId), {
        permissions: updatedPermissions
      });
      
      console.log(`   ✅ Updated successfully`);
    }
    
    console.log('\n🎉 All admin users updated with new permissions!');
    
  } catch (error) {
    console.error('❌ Error updating admin permissions:', error);
  }
  
  process.exit(0);
}

updateAdminPermissions();
