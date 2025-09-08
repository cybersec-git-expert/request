import { db } from './src/firebase/config.js';
import { collection, getDocs } from 'firebase/firestore';

async function debugAdminUsers() {
  try {
    console.log('🔍 Checking admin_users in Firestore...');
    const adminUsersRef = collection(db, 'admin_users');
    const snapshot = await getDocs(adminUsersRef);
    
    console.log(`\n📊 Found ${snapshot.size} admin users in Firestore:`);
    console.log('='.repeat(50));
    
    if (snapshot.empty) {
      console.log('No admin users found in Firestore');
    } else {
      snapshot.forEach((doc) => {
        const data = doc.data();
        console.log(`📋 ID: ${doc.id}`);
        console.log(`   Name: ${data.displayName || data.name || 'N/A'}`);
        console.log(`   Email: ${data.email || 'N/A'}`);
        console.log(`   Role: ${data.role || 'N/A'}`);
        console.log(`   Country: ${data.country || 'N/A'}`);
        console.log(`   Active: ${data.isActive !== undefined ? data.isActive : 'N/A'}`);
        console.log(`   UID: ${data.uid || 'N/A'}`);
        console.log(`   Created: ${data.createdAt?.toDate?.() || data.createdAt || 'N/A'}`);
        console.log('   ---');
      });
    }
    
    console.log('\n💡 If you see duplicate or incomplete records, you may need to clean them up.');
    console.log('💡 Try using a completely different email address that has never been used.');
    console.log('💡 Common test emails: test1@example.com, admin2@test.com, etc.');
    
  } catch (error) {
    console.error('❌ Error checking admin users:', error);
  }
  
  process.exit(0);
}

debugAdminUsers();
