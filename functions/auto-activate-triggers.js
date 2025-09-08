/**
 * Cloud Functions for auto-activating new items across all countries
 * These functions trigger when new documents are added to main collections
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Get all enabled countries from the country management system
 */
async function getEnabledCountries() {
  try {
    const countriesSnapshot = await db.collection('countries')
      .where('isEnabled', '==', true)
      .get();
    
    return countriesSnapshot.docs.map(doc => ({
      code: doc.data().code,
      name: doc.data().name
    }));
  } catch (error) {
    console.error('Error getting enabled countries:', error);
    return [];
  }
}

/**
 * Auto-activate a new variable type for all enabled countries
 */
exports.autoActivateNewVariableType = functions.firestore
  .document('variable_types/{variableTypeId}')
  .onCreate(async (snap, context) => {
    const variableTypeId = context.params.variableTypeId;
    const variableTypeData = snap.data();
    
    console.log(`🆕 New variable type created: ${variableTypeData.name} (${variableTypeId})`);
    
    try {
      const enabledCountries = await getEnabledCountries();
      console.log(`📍 Auto-activating for ${enabledCountries.length} enabled countries`);
      
      const batch = db.batch();
      
      for (const country of enabledCountries) {
        // Check if activation already exists
        const existingActivation = await db.collection('country_variable_types')
          .where('country', '==', country.code)
          .where('variableTypeId', '==', variableTypeId)
          .get();
        
        if (existingActivation.empty) {
          const activationRef = db.collection('country_variable_types').doc();
          batch.set(activationRef, {
            country: country.code,
            countryName: country.name,
            variableTypeId: variableTypeId,
            variableTypeName: variableTypeData.name,
            isActive: true, // Auto-activate by default
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: 'system',
            updatedBy: 'system',
            createdByName: 'Auto-Activation',
            updatedByName: 'Auto-Activation'
          });
          
          console.log(`✅ Queued activation for ${country.name} (${country.code})`);
        }
      }
      
      await batch.commit();
      console.log(`🎉 Successfully auto-activated variable type "${variableTypeData.name}" for all enabled countries`);
      
    } catch (error) {
      console.error('Error auto-activating variable type:', error);
    }
  });

/**
 * Auto-activate a new category for all enabled countries
 */
exports.autoActivateNewCategory = functions.firestore
  .document('categories/{categoryId}')
  .onCreate(async (snap, context) => {
    const categoryId = context.params.categoryId;
    const categoryData = snap.data();
    
    console.log(`🆕 New category created: ${categoryData.category} (${categoryId})`);
    
    try {
      const enabledCountries = await getEnabledCountries();
      console.log(`📍 Auto-activating for ${enabledCountries.length} enabled countries`);
      
      const batch = db.batch();
      
      for (const country of enabledCountries) {
        // Check if activation already exists
        const existingActivation = await db.collection('country_categories')
          .where('country', '==', country.code)
          .where('categoryId', '==', categoryId)
          .get();
        
        if (existingActivation.empty) {
          const activationRef = db.collection('country_categories').doc();
          batch.set(activationRef, {
            country: country.code,
            countryName: country.name,
            categoryId: categoryId,
            categoryName: categoryData.category,
            isActive: true, // Auto-activate by default
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: 'system',
            updatedBy: 'system',
            createdByName: 'Auto-Activation',
            updatedByName: 'Auto-Activation'
          });
          
          console.log(`✅ Queued activation for ${country.name} (${country.code})`);
        }
      }
      
      await batch.commit();
      console.log(`🎉 Successfully auto-activated category "${categoryData.category}" for all enabled countries`);
      
    } catch (error) {
      console.error('Error auto-activating category:', error);
    }
  });

/**
 * Auto-activate a new subcategory for all enabled countries
 */
exports.autoActivateNewSubcategory = functions.firestore
  .document('subcategories/{subcategoryId}')
  .onCreate(async (snap, context) => {
    const subcategoryId = context.params.subcategoryId;
    const subcategoryData = snap.data();
    
    console.log(`🆕 New subcategory created: ${subcategoryData.subcategory} (${subcategoryId})`);
    
    try {
      const enabledCountries = await getEnabledCountries();
      console.log(`📍 Auto-activating for ${enabledCountries.length} enabled countries`);
      
      const batch = db.batch();
      
      for (const country of enabledCountries) {
        // Check if activation already exists
        const existingActivation = await db.collection('country_subcategories')
          .where('country', '==', country.code)
          .where('subcategoryId', '==', subcategoryId)
          .get();
        
        if (existingActivation.empty) {
          const activationRef = db.collection('country_subcategories').doc();
          batch.set(activationRef, {
            country: country.code,
            countryName: country.name,
            subcategoryId: subcategoryId,
            subcategoryName: subcategoryData.subcategory,
            isActive: true, // Auto-activate by default
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: 'system',
            updatedBy: 'system',
            createdByName: 'Auto-Activation',
            updatedByName: 'Auto-Activation'
          });
          
          console.log(`✅ Queued activation for ${country.name} (${country.code})`);
        }
      }
      
      await batch.commit();
      console.log(`🎉 Successfully auto-activated subcategory "${subcategoryData.subcategory}" for all enabled countries`);
      
    } catch (error) {
      console.error('Error auto-activating subcategory:', error);
    }
  });

/**
 * Auto-activate a new brand for all enabled countries
 */
exports.autoActivateNewBrand = functions.firestore
  .document('brands/{brandId}')
  .onCreate(async (snap, context) => {
    const brandId = context.params.brandId;
    const brandData = snap.data();
    
    console.log(`🆕 New brand created: ${brandData.name} (${brandId})`);
    
    try {
      const enabledCountries = await getEnabledCountries();
      console.log(`📍 Auto-activating for ${enabledCountries.length} enabled countries`);
      
      const batch = db.batch();
      
      for (const country of enabledCountries) {
        // Check if activation already exists
        const existingActivation = await db.collection('country_brands')
          .where('country', '==', country.code)
          .where('brandId', '==', brandId)
          .get();
        
        if (existingActivation.empty) {
          const activationRef = db.collection('country_brands').doc();
          batch.set(activationRef, {
            country: country.code,
            countryName: country.name,
            brandId: brandId,
            brandName: brandData.name,
            isActive: true, // Auto-activate by default
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: 'system',
            updatedBy: 'system',
            createdByName: 'Auto-Activation',
            updatedByName: 'Auto-Activation'
          });
          
          console.log(`✅ Queued activation for ${country.name} (${country.code})`);
        }
      }
      
      await batch.commit();
      console.log(`🎉 Successfully auto-activated brand "${brandData.name}" for all enabled countries`);
      
    } catch (error) {
      console.error('Error auto-activating brand:', error);
    }
  });

/**
 * Auto-activate a new product for all enabled countries
 */
exports.autoActivateNewProduct = functions.firestore
  .document('products/{productId}')
  .onCreate(async (snap, context) => {
    const productId = context.params.productId;
    const productData = snap.data();
    
    console.log(`🆕 New product created: ${productData.name} (${productId})`);
    
    try {
      const enabledCountries = await getEnabledCountries();
      console.log(`📍 Auto-activating for ${enabledCountries.length} enabled countries`);
      
      const batch = db.batch();
      
      for (const country of enabledCountries) {
        // Check if activation already exists
        const existingActivation = await db.collection('country_products')
          .where('country', '==', country.code)
          .where('productId', '==', productId)
          .get();
        
        if (existingActivation.empty) {
          const activationRef = db.collection('country_products').doc();
          batch.set(activationRef, {
            country: country.code,
            countryName: country.name,
            productId: productId,
            productName: productData.name,
            isActive: true, // Auto-activate by default
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: 'system',
            updatedBy: 'system',
            createdByName: 'Auto-Activation',
            updatedByName: 'Auto-Activation'
          });
          
          console.log(`✅ Queued activation for ${country.name} (${country.code})`);
        }
      }
      
      await batch.commit();
      console.log(`🎉 Successfully auto-activated product "${productData.name}" for all enabled countries`);
      
    } catch (error) {
      console.error('Error auto-activating product:', error);
    }
  });

/**
 * Auto-activate a new vehicle type for all enabled countries
 */
exports.autoActivateNewVehicleType = functions.firestore
  .document('vehicle_types/{vehicleTypeId}')
  .onCreate(async (snap, context) => {
    const vehicleTypeId = context.params.vehicleTypeId;
    const vehicleTypeData = snap.data();
    
    console.log(`🆕 New vehicle type created: ${vehicleTypeData.name} (${vehicleTypeId})`);
    
    try {
      const enabledCountries = await getEnabledCountries();
      console.log(`📍 Auto-activating for ${enabledCountries.length} enabled countries`);
      
      const batch = db.batch();
      
      for (const country of enabledCountries) {
        // Check if activation already exists
        const existingActivation = await db.collection('country_vehicle_types')
          .where('country', '==', country.code)
          .where('vehicleTypeId', '==', vehicleTypeId)
          .get();
        
        if (existingActivation.empty) {
          const activationRef = db.collection('country_vehicle_types').doc();
          batch.set(activationRef, {
            country: country.code,
            countryName: country.name,
            vehicleTypeId: vehicleTypeId,
            vehicleTypeName: vehicleTypeData.name,
            isActive: true, // Auto-activate by default
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: 'system',
            updatedBy: 'system',
            createdByName: 'Auto-Activation',
            updatedByName: 'Auto-Activation'
          });
          
          console.log(`✅ Queued activation for ${country.name} (${country.code})`);
        }
      }
      
      await batch.commit();
      console.log(`🎉 Successfully auto-activated vehicle type "${vehicleTypeData.name}" for all enabled countries`);
      
    } catch (error) {
      console.error('Error auto-activating vehicle type:', error);
    }
  });

/**
 * Auto-activate all existing data when a new country is enabled
 * This triggers when a country's isEnabled field is set to true
 */
exports.autoActivateForNewCountry = functions.firestore
  .document('countries/{countryId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    // Check if country was just enabled
    if (!beforeData.isEnabled && afterData.isEnabled) {
      const countryCode = afterData.code;
      const countryName = afterData.name;
      
      console.log(`🌍 Country enabled: ${countryName} (${countryCode})`);
      console.log(`🚀 Auto-activating all existing data for ${countryName}`);
      
      try {
        // Import the auto-activation function
        const { autoActivateCountryData } = require('./auto_activate_country_data');
        
        // Run the comprehensive auto-activation
        await autoActivateCountryData(countryCode, countryName, 'system', 'Auto-Activation');
        
        console.log(`🎉 Successfully auto-activated all data for ${countryName}`);
        
      } catch (error) {
        console.error(`❌ Error auto-activating data for ${countryName}:`, error);
      }
    }
  });
