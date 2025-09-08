import { initializeApp } from 'firebase/app';
import { getFirestore, doc, getDoc } from 'firebase/firestore';

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

async function testModuleAPI() {
  try {
    console.log('🧪 Testing Module Configuration API...');
    
    // Test getting Sri Lanka modules
    const lkModulesRef = doc(db, 'country_modules', 'LK');
    const lkDoc = await getDoc(lkModulesRef);
    
    if (lkDoc.exists()) {
      const data = lkDoc.data();
      console.log('\n✅ Sri Lanka Module Configuration:');
      console.log('   Country Code:', 'LK');
      console.log('   Modules:', data.modules);
      console.log('   Core Dependencies:', data.coreDependencies);
      console.log('   Last Updated:', data.updatedAt?.toDate());
      
      // Show which modules are enabled
      console.log('\n📱 Enabled Modules for Mobile App:');
      Object.entries(data.modules || {}).forEach(([module, enabled]) => {
        const status = enabled ? '✅ ENABLED' : '❌ DISABLED';
        console.log(`   ${module}: ${status}`);
      });
      
      // Show what the mobile app should display
      const enabledModules = Object.entries(data.modules || {})
        .filter(([module, enabled]) => enabled)
        .map(([module, enabled]) => module);
        
      console.log('\n📲 Mobile App Should Show These Request Types:');
      enabledModules.forEach(module => {
        const moduleNames = {
          item: '🛍️ Item Request - Request for products or items',
          service: '🔧 Service Request - Request for services',
          rent: '📅 Rental Request - Rent vehicles, equipment, or items',
          delivery: '📦 Delivery Request - Request for delivery services',
          ride: '🚗 Ride Request - Request for transportation',
          price: '💰 Price Request - Request price quotes for items or services'
        };
        console.log(`   ${moduleNames[module] || module}`);
      });
      
    } else {
      console.log('❌ No module configuration found for Sri Lanka');
      console.log('💡 This means default modules will be used');
    }
    
  } catch (error) {
    console.error('❌ Error testing module API:', error);
  }
  
  process.exit(0);
}

testModuleAPI();
