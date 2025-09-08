import { collection, addDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../src/firebase/config.js';

async function createSampleCategories() {
  try {
    console.log('🏗️ Creating sample categories and subcategories...');

    // Sample categories
    const categories = [
      {
        name: 'Electronics',
        description: 'Electronic devices and gadgets',
        applicableFor: 'Item',
        isActive: true,
        createdAt: serverTimestamp(),
        createdBy: 'system'
      },
      {
        name: 'Fashion',
        description: 'Clothing, shoes, and accessories',
        applicableFor: 'Item',
        isActive: true,
        createdAt: serverTimestamp(),
        createdBy: 'system'
      },
      {
        name: 'Home & Garden',
        description: 'Home improvement and garden supplies',
        applicableFor: 'Item',
        isActive: true,
        createdAt: serverTimestamp(),
        createdBy: 'system'
      },
      {
        name: 'Sports & Recreation',
        description: 'Sports equipment and recreational items',
        applicableFor: 'Item',
        isActive: true,
        createdAt: serverTimestamp(),
        createdBy: 'system'
      },
      {
        name: 'Professional Services',
        description: 'Professional and business services',
        applicableFor: 'Service',
        isActive: true,
        createdAt: serverTimestamp(),
        createdBy: 'system'
      }
    ];

    const categoryIds = {};
    
    for (const category of categories) {
      const docRef = await addDoc(collection(db, 'categories'), category);
      categoryIds[category.name] = docRef.id;
      console.log(`✅ Created category: ${category.name}`);
    }

    // Sample subcategories
    const subcategories = [
      {
        name: 'Smartphones',
        description: 'Mobile phones and smartphones',
        categoryId: categoryIds['Electronics'],
        isActive: true,
        createdAt: serverTimestamp(),
        createdBy: 'system'
      },
      {
        name: 'Laptops',
        description: 'Laptops and notebooks',
        categoryId: categoryIds['Electronics'],
        isActive: true,
        createdAt: serverTimestamp(),
        createdBy: 'system'
      },
      {
        name: 'Headphones',
        description: 'Audio headphones and earbuds',
        categoryId: categoryIds['Electronics'],
        isActive: true,
        createdAt: serverTimestamp(),
        createdBy: 'system'
      },
      {
        name: "Men's Clothing",
        description: 'Clothing for men',
        categoryId: categoryIds['Fashion'],
        isActive: true,
        createdAt: serverTimestamp(),
        createdBy: 'system'
      },
      {
        name: "Women's Clothing",
        description: 'Clothing for women',
        categoryId: categoryIds['Fashion'],
        isActive: true,
        createdAt: serverTimestamp(),
        createdBy: 'system'
      },
      {
        name: 'Footwear',
        description: 'Shoes and sandals',
        categoryId: categoryIds['Fashion'],
        isActive: true,
        createdAt: serverTimestamp(),
        createdBy: 'system'
      }
    ];

    for (const subcategory of subcategories) {
      await addDoc(collection(db, 'subcategories'), subcategory);
      console.log(`✅ Created subcategory: ${subcategory.name}`);
    }

    console.log('');
    console.log('🎉 Sample categories and subcategories created successfully!');
    console.log('📋 Categories created:', Object.keys(categoryIds).length);
    console.log('📋 Subcategories created:', subcategories.length);
    console.log('');
    console.log('🌐 Now refresh your admin panel to see the categories!');
    
  } catch (error) {
    console.error('❌ Error creating sample categories:', error);
  }
}

createSampleCategories();
