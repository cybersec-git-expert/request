import { collection, getDocs, limit } from 'firebase/firestore';
import { db } from '../src/firebase/config.js';

async function debugCollections() {
  console.log('🔍 Debugging Collections Data...\n');

  const collectionsToCheck = [
    'categories',
    'subcategories', 
    'custom_product_variables'
  ];

  for (const collectionName of collectionsToCheck) {
    try {
      console.log(`\n📋 Checking ${collectionName}:`);
      console.log('-'.repeat(50));
      
      const snapshot = await getDocs(collection(db, collectionName));
      console.log(`📊 Total documents: ${snapshot.size}`);
      
      if (snapshot.size > 0) {
        console.log('\n🔍 Sample documents:');
        let count = 0;
        snapshot.forEach(doc => {
          if (count < 3) { // Show first 3 documents
            const data = doc.data();
            console.log(`\nDocument ID: ${doc.id}`);
            console.log('Fields:', Object.keys(data));
            console.log('Sample data:', {
              name: data.name,
              description: data.description,
              status: data.status,
              isActive: data.isActive,
              country: data.country,
              type: data.type,
              label: data.label,
              createdAt: data.createdAt ? 'Has timestamp' : 'No timestamp'
            });
            count++;
          }
        });
      } else {
        console.log('❌ No documents found in this collection');
      }
      
    } catch (error) {
      console.error(`❌ Error checking ${collectionName}:`, error.message);
    }
  }
  
  console.log('\n✅ Collection debugging complete!');
}

debugCollections();
