require('dotenv').config();
const admin = require('firebase-admin');
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

// PostgreSQL connection
const pool = new Pool({
  host: process.env.PGHOST,
  port: process.env.PGPORT,
  database: process.env.PGDATABASE,
  user: process.env.PGUSER,
  password: process.env.PGPASSWORD,
  ssl: { rejectUnauthorized: false }
});

// Initialize Firebase Admin
let serviceAccount;
try {
  console.log('Loading Firebase service account...');
  if (process.env.FIREBASE_SERVICE_ACCOUNT_KEY) {
    console.log('Using service account from environment variable');
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);
  } else if (fs.existsSync('./firebase-service-account.json')) {
    console.log('Using firebase-service-account.json');
    serviceAccount = require('./firebase-service-account.json');
  } else if (fs.existsSync('./serviceAccount.json')) {
    console.log('Using serviceAccount.json');
    serviceAccount = require('./serviceAccount.json');
  } else if (fs.existsSync('./request-marketplace-62dc9dd4835f.json')) {
    console.log('Using request-marketplace-62dc9dd4835f.json');
    serviceAccount = require('./request-marketplace-62dc9dd4835f.json');
  } else {
    console.error('Firebase service account key not found!');
    console.error('Please either:');
    console.error('1. Set FIREBASE_SERVICE_ACCOUNT_KEY environment variable with the JSON content');
    console.error('2. Place firebase-service-account.json file in the project root');
    process.exit(1);
  }
  console.log('Service account loaded for project:', serviceAccount.project_id);
} catch (error) {
  console.error('Error loading Firebase service account:', error.message);
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: process.env.FIREBASE_DATABASE_URL // Add this to your .env if needed
  });
}

const db = admin.firestore();

// Helper function to convert Firebase timestamp to Date
function toDate(timestamp) {
  if (!timestamp) return new Date();
  if (timestamp.toDate && typeof timestamp.toDate === 'function') {
    return new Date(timestamp.toDate());
  }
  if (timestamp.seconds) {
    return new Date(timestamp.seconds * 1000);
  }
  if (timestamp instanceof Date) {
    return timestamp;
  }
  return new Date(timestamp);
}

// Migration functions for each collection
async function migrateCategories() {
  console.log('\\n=== Migrating Categories ===');
  try {
    const snapshot = await db.collection('categories').get();
    const categories = [];
    
    snapshot.forEach(doc => {
      const data = doc.data();
      categories.push({
        firebase_id: doc.id,
        name: data.category || data.name || '',
        slug: (data.category || data.name || '').toLowerCase().replace(/[^a-z0-9]/g, '-'),
        type: data.type || 'general',
        is_active: data.isActive !== false,
        metadata: JSON.stringify({
          description: data.description,
          icon: data.icon,
          original_firebase_data: data
        }),
        created_at: toDate(data.createdAt),
        updated_at: toDate(data.updatedAt)
      });
    });

    console.log(`Found ${categories.length} categories in Firebase`);

    for (const category of categories) {
      await pool.query(`
        INSERT INTO categories (firebase_id, name, slug, type, is_active, metadata, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (firebase_id) DO UPDATE SET
          name = EXCLUDED.name,
          slug = EXCLUDED.slug,
          type = EXCLUDED.type,
          is_active = EXCLUDED.is_active,
          metadata = EXCLUDED.metadata,
          updated_at = EXCLUDED.updated_at
      `, [category.firebase_id, category.name, category.slug, category.type, 
        category.is_active, category.metadata, category.created_at, category.updated_at]);
    }

    console.log(`✅ Migrated ${categories.length} categories`);
  } catch (error) {
    console.error('❌ Error migrating categories:', error.message);
  }
}

async function migrateSubcategories() {
  console.log('\\n=== Migrating Subcategories ===');
  try {
    const snapshot = await db.collection('subcategories').get();
    const subcategories = [];
    
    // First get all categories to map Firebase IDs to PostgreSQL UUIDs
    const categoryResult = await pool.query('SELECT id, firebase_id FROM categories');
    const categoryMap = {};
    categoryResult.rows.forEach(row => {
      categoryMap[row.firebase_id] = row.id;
    });
    
    snapshot.forEach(doc => {
      const data = doc.data();
      const categoryId = categoryMap[data.category_id] || null;
      
      subcategories.push({
        firebase_id: doc.id,
        category_id: categoryId,
        name: data.subcategory || data.name || '',
        slug: (data.subcategory || data.name || '').toLowerCase().replace(/[^a-z0-9]/g, '-'),
        is_active: data.isActive !== false,
        metadata: JSON.stringify({
          description: data.description,
          original_firebase_data: data
        }),
        created_at: toDate(data.createdAt),
        updated_at: toDate(data.updatedAt)
      });
    });

    console.log(`Found ${subcategories.length} subcategories in Firebase`);

    for (const subcategory of subcategories) {
      if (subcategory.category_id) { // Only insert if we have a valid category mapping
        await pool.query(`
          INSERT INTO sub_categories (firebase_id, category_id, name, slug, is_active, metadata, created_at, updated_at)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
          ON CONFLICT (firebase_id) DO UPDATE SET
            category_id = EXCLUDED.category_id,
            name = EXCLUDED.name,
            slug = EXCLUDED.slug,
            is_active = EXCLUDED.is_active,
            metadata = EXCLUDED.metadata,
            updated_at = EXCLUDED.updated_at
        `, [subcategory.firebase_id, subcategory.category_id, subcategory.name, subcategory.slug, 
          subcategory.is_active, subcategory.metadata, subcategory.created_at, subcategory.updated_at]);
      } else {
        console.log(`⚠️  Skipping subcategory ${subcategory.name} - no matching category`);
      }
    }

    console.log(`✅ Migrated ${subcategories.filter(s => s.category_id).length} subcategories`);
  } catch (error) {
    console.error('❌ Error migrating subcategories:', error.message);
  }
}

async function migrateBrands() {
  console.log('\\n=== Migrating Brands ===');
  try {
    const snapshot = await db.collection('brands').get();
    const brands = [];
    
    snapshot.forEach(doc => {
      const data = doc.data();
      brands.push({
        firebase_id: doc.id,
        name: data.name || '',
        slug: (data.name || '').toLowerCase().replace(/[^a-z0-9]/g, '-'),
        is_active: data.isActive !== false,
        created_at: toDate(data.createdAt),
        updated_at: toDate(data.updatedAt)
      });
    });

    console.log(`Found ${brands.length} brands in Firebase`);

    for (const brand of brands) {
      await pool.query(`
        INSERT INTO brands (firebase_id, name, slug, is_active, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (firebase_id) DO UPDATE SET
          name = EXCLUDED.name,
          slug = EXCLUDED.slug,
          is_active = EXCLUDED.is_active,
          updated_at = EXCLUDED.updated_at
      `, [brand.firebase_id, brand.name, brand.slug, brand.is_active, brand.created_at, brand.updated_at]);
    }

    console.log(`✅ Migrated ${brands.length} brands`);
  } catch (error) {
    console.error('❌ Error migrating brands:', error.message);
  }
}

async function migrateVehicleTypes() {
  console.log('\\n=== Migrating Vehicle Types ===');
  try {
    const snapshot = await db.collection('vehicle_types').get();
    const vehicleTypes = [];
    
    snapshot.forEach(doc => {
      const data = doc.data();
      vehicleTypes.push({
        firebase_id: doc.id,
        name: data.name || '',
        description: data.description || null,
        icon: data.icon || null,
        capacity: data.capacity || 1,
        is_active: data.isActive !== false,
        created_at: toDate(data.createdAt),
        updated_at: toDate(data.updatedAt)
      });
    });

    console.log(`Found ${vehicleTypes.length} vehicle types in Firebase`);

    for (const vehicleType of vehicleTypes) {
      await pool.query(`
        INSERT INTO vehicle_types (firebase_id, name, description, icon, capacity, is_active, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (firebase_id) DO UPDATE SET
          name = EXCLUDED.name,
          description = EXCLUDED.description,
          icon = EXCLUDED.icon,
          capacity = EXCLUDED.capacity,
          is_active = EXCLUDED.is_active,
          updated_at = EXCLUDED.updated_at
      `, [vehicleType.firebase_id, vehicleType.name, vehicleType.description, vehicleType.icon, 
        vehicleType.capacity, vehicleType.is_active, vehicleType.created_at, vehicleType.updated_at]);
    }

    console.log(`✅ Migrated ${vehicleTypes.length} vehicle types`);
  } catch (error) {
    console.error('❌ Error migrating vehicle types:', error.message);
  }
}

async function migrateSubscriptionPlans() {
  console.log('\\n=== Migrating Subscription Plans ===');
  try {
    const snapshot = await db.collection('subscription_plans').get();
    const plans = [];
    
    snapshot.forEach(doc => {
      const data = doc.data();
      plans.push({
        firebase_id: doc.id,
        code: data.code || doc.id,
        name: data.name || '',
        type: data.type || 'business',
        plan_type: data.planType || 'monthly',
        description: data.description || null,
        price: parseFloat(data.price) || 0,
        currency: data.currency || 'LKR',
        duration_days: data.durationDays || (data.planType === 'yearly' ? 365 : 30),
        features: JSON.stringify(data.features || []),
        limitations: JSON.stringify(data.limitations || {}),
        countries: data.countries || null,
        pricing_by_country: data.pricingByCountry ? JSON.stringify(data.pricingByCountry) : null,
        is_active: data.isActive !== false,
        is_default_plan: data.isDefault || false,
        requires_country_pricing: !!data.pricingByCountry,
        created_at: toDate(data.createdAt),
        updated_at: toDate(data.updatedAt)
      });
    });

    console.log(`Found ${plans.length} subscription plans in Firebase`);

    for (const plan of plans) {
      await pool.query(`
        INSERT INTO subscription_plans_new (firebase_id, code, name, type, plan_type, description, price, currency, duration_days, features, limitations, countries, pricing_by_country, is_active, is_default_plan, requires_country_pricing, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
        ON CONFLICT (firebase_id) DO UPDATE SET
          code = EXCLUDED.code,
          name = EXCLUDED.name,
          type = EXCLUDED.type,
          plan_type = EXCLUDED.plan_type,
          description = EXCLUDED.description,
          price = EXCLUDED.price,
          currency = EXCLUDED.currency,
          duration_days = EXCLUDED.duration_days,
          features = EXCLUDED.features,
          limitations = EXCLUDED.limitations,
          countries = EXCLUDED.countries,
          pricing_by_country = EXCLUDED.pricing_by_country,
          is_active = EXCLUDED.is_active,
          is_default_plan = EXCLUDED.is_default_plan,
          requires_country_pricing = EXCLUDED.requires_country_pricing,
          updated_at = EXCLUDED.updated_at
      `, [plan.firebase_id, plan.code, plan.name, plan.type, plan.plan_type, plan.description, 
        plan.price, plan.currency, plan.duration_days, plan.features, plan.limitations, 
        plan.countries, plan.pricing_by_country, plan.is_active, plan.is_default_plan, 
        plan.requires_country_pricing, plan.created_at, plan.updated_at]);
    }

    console.log(`✅ Migrated ${plans.length} subscription plans`);
  } catch (error) {
    console.error('❌ Error migrating subscription plans:', error.message);
  }
}

async function migrateMasterProducts() {
  console.log('\\n=== Migrating Master Products ===');
  try {
    const snapshot = await db.collection('master_products').get();
    const products = [];
    
    // Get brand mappings
    const brandResult = await pool.query('SELECT id, firebase_id FROM brands');
    const brandMap = {};
    brandResult.rows.forEach(row => {
      brandMap[row.firebase_id] = row.id;
    });
    
    snapshot.forEach(doc => {
      const data = doc.data();
      const brandId = brandMap[data.brand] || null;
      
      products.push({
        firebase_id: doc.id,
        brand_id: brandId,
        name: data.name || '',
        slug: (data.name || '').toLowerCase().replace(/[^a-z0-9]/g, '-'),
        base_unit: data.baseUnit || null,
        is_active: data.isActive !== false,
        created_at: toDate(data.createdAt),
        updated_at: toDate(data.updatedAt)
      });
    });

    console.log(`Found ${products.length} master products in Firebase`);

    for (const product of products) {
      await pool.query(`
        INSERT INTO master_products (firebase_id, brand_id, name, slug, base_unit, is_active, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (firebase_id) DO UPDATE SET
          brand_id = EXCLUDED.brand_id,
          name = EXCLUDED.name,
          slug = EXCLUDED.slug,
          base_unit = EXCLUDED.base_unit,
          is_active = EXCLUDED.is_active,
          updated_at = EXCLUDED.updated_at
      `, [product.firebase_id, product.brand_id, product.name, product.slug, 
        product.base_unit, product.is_active, product.created_at, product.updated_at]);
    }

    console.log(`✅ Migrated ${products.length} master products`);
  } catch (error) {
    console.error('❌ Error migrating master products:', error.message);
  }
}

async function migrateVariableTypes() {
  console.log('\\n=== Migrating Variable Types ===');
  try {
    const snapshot = await db.collection('variable_types').get();
    const variables = [];
    
    snapshot.forEach(doc => {
      const data = doc.data();
      variables.push({
        firebase_id: doc.id,
        key: data.name || doc.id,
        value: JSON.stringify(data.options || data.value || []),
        type: data.type || 'select',
        description: data.description || null,
        is_active: data.isRequired !== false,
        created_at: toDate(data.createdAt),
        updated_at: toDate(data.updatedAt)
      });
    });

    console.log(`Found ${variables.length} variable types in Firebase`);

    for (const variable of variables) {
      await pool.query(`
        INSERT INTO global_variables (firebase_id, key, value, type, description, is_active, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (firebase_id) DO UPDATE SET
          key = EXCLUDED.key,
          value = EXCLUDED.value,
          type = EXCLUDED.type,
          description = EXCLUDED.description,
          is_active = EXCLUDED.is_active,
          updated_at = EXCLUDED.updated_at
      `, [variable.firebase_id, variable.key, variable.value, variable.type, 
        variable.description, variable.is_active, variable.created_at, variable.updated_at]);
    }

    console.log(`✅ Migrated ${variables.length} variable types`);
  } catch (error) {
    console.error('❌ Error migrating variable types:', error.message);
  }
}

// Main migration function
async function main() {
  try {
    console.log('🚀 Starting Firebase to PostgreSQL migration...');
    console.log('Database:', process.env.PGDATABASE);
    
    // Test database connection
    await pool.query('SELECT 1');
    console.log('✅ PostgreSQL connection successful');

    // Run migrations in order (categories first, then subcategories that depend on them)
    await migrateCategories();
    await migrateSubcategories();
    await migrateBrands();
    await migrateVehicleTypes();
    await migrateSubscriptionPlans();
    await migrateMasterProducts();
    await migrateVariableTypes();

    console.log('\\n🎉 Migration completed successfully!');
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
  } finally {
    await pool.end();
    process.exit(0);
  }
}

// Run specific collection if provided as argument
const collectionArg = process.argv[2];
if (collectionArg) {
  const migrations = {
    categories: migrateCategories,
    subcategories: migrateSubcategories,
    brands: migrateBrands,
    'vehicle-types': migrateVehicleTypes,
    'subscription-plans': migrateSubscriptionPlans,
    'master-products': migrateMasterProducts,
    'variable-types': migrateVariableTypes
  };

  if (migrations[collectionArg]) {
    console.log(`🚀 Starting migration for: ${collectionArg}`);
    pool.query('SELECT 1')
      .then(() => {
        console.log('✅ PostgreSQL connection successful');
        return migrations[collectionArg]();
      })
      .then(() => {
        console.log(`🎉 Migration for ${collectionArg} completed!`);
      })
      .catch(error => {
        console.error(`❌ Migration for ${collectionArg} failed:`, error.message);
      })
      .finally(() => {
        pool.end();
        process.exit(0);
      });
  } else {
    console.error(`Unknown collection: ${collectionArg}`);
    console.error('Available collections: categories, subcategories, brands, vehicle-types, subscription-plans, master-products, variable-types');
    process.exit(1);
  }
} else {
  main();
}
