require('dotenv').config();
const admin = require('firebase-admin');
const { Pool } = require('pg');
const fs = require('fs');

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
  if (fs.existsSync('./serviceAccount.json')) {
    serviceAccount = require('./serviceAccount.json');
  } else {
    console.error('Firebase service account not found!');
    process.exit(1);
  }
} catch (error) {
  console.error('Error loading Firebase service account:', error.message);
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

// Helper function to convert Firebase timestamp to Date
function toDate(timestamp) {
  if (!timestamp) return null;
  if (timestamp._seconds) {
    return new Date(timestamp._seconds * 1000);
  }
  if (timestamp.seconds) {
    return new Date(timestamp.seconds * 1000);
  }
  if (timestamp instanceof Date) {
    return timestamp;
  }
  if (typeof timestamp === 'string') {
    return new Date(timestamp);
  }
  return null;
}

// Generate UUID v4
function generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// 1. Migrate admin_users (update existing with Firebase data)
async function migrateAdminUsers() {
  console.log('🔄 Migrating admin_users...');
  
  try {
    const snapshot = await db.collection('admin_users').get();
    console.log(`Found ${snapshot.size} admin users in Firebase`);
    
    let migrated = 0;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      // Check if admin user exists with this firebase_id
      const existingUser = await pool.query(
        'SELECT id FROM admin_users WHERE firebase_id = $1',
        [doc.id]
      );
      
      if (existingUser.rows.length > 0) {
        // Update existing user
        await pool.query(`
          UPDATE admin_users SET 
            email = COALESCE($2, email),
            name = COALESCE($3, name),
            role = COALESCE($4, role),
            is_active = COALESCE($5, is_active),
            permissions = COALESCE($6, permissions),
            updated_at = $7
          WHERE firebase_id = $1
        `, [
          doc.id,
          data.email,
          data.name || data.displayName,
          data.role,
          data.isActive !== undefined ? data.isActive : true,
          data.permissions ? JSON.stringify(data.permissions) : null,
          toDate(data.updatedAt) || new Date()
        ]);
      } else {
        // Insert new user
        await pool.query(`
          INSERT INTO admin_users (
            id, firebase_id, email, name, role, is_active, 
            permissions, created_at, updated_at
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        `, [
          generateUUID(),
          doc.id,
          data.email,
          data.name || data.displayName,
          data.role,
          data.isActive !== undefined ? data.isActive : true,
          data.permissions ? JSON.stringify(data.permissions) : null,
          toDate(data.createdAt) || new Date(),
          toDate(data.updatedAt) || new Date()
        ]);
      }
      
      migrated++;
    }
    
    console.log(`✅ Migrated ${migrated} admin users`);
    
  } catch (error) {
    console.error('❌ Error migrating admin_users:', error);
  }
}

// 2. Migrate app_countries
async function migrateAppCountries() {
  console.log('🔄 Migrating app_countries...');
  
  try {
    const snapshot = await db.collection('app_countries').get();
    console.log(`Found ${snapshot.size} app countries in Firebase`);
    
    let migrated = 0;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      await pool.query(`
        INSERT INTO app_countries (
          id, firebase_id, code, name, flag, phone_code, 
          is_enabled, coming_soon_message, created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        ON CONFLICT (firebase_id) DO UPDATE SET
          code = EXCLUDED.code,
          name = EXCLUDED.name,
          flag = EXCLUDED.flag,
          phone_code = EXCLUDED.phone_code,
          is_enabled = EXCLUDED.is_enabled,
          coming_soon_message = EXCLUDED.coming_soon_message,
          updated_at = EXCLUDED.updated_at
      `, [
        generateUUID(),
        doc.id,
        data.code,
        data.name,
        data.flag,
        data.phoneCode,
        data.isActive !== undefined ? data.isActive : true,
        data.comingSoonMessage,
        toDate(data.createdAt) || new Date(),
        toDate(data.updatedAt) || new Date()
      ]);
      
      migrated++;
    }
    
    console.log(`✅ Migrated ${migrated} app countries`);
    
  } catch (error) {
    console.error('❌ Error migrating app_countries:', error);
  }
}

// 3. Migrate subcategories (to sub_categories table)
async function migrateSubcategories() {
  console.log('🔄 Migrating subcategories to sub_categories...');
  
  try {
    const snapshot = await db.collection('subcategories').get();
    console.log(`Found ${snapshot.size} subcategories in Firebase`);
    
    let migrated = 0;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      // Find the category UUID from firebase_id
      let categoryId = null;
      if (data.category_id) {
        const categoryResult = await pool.query(
          'SELECT id FROM categories WHERE firebase_id = $1',
          [data.category_id]
        );
        if (categoryResult.rows.length > 0) {
          categoryId = categoryResult.rows[0].id;
        }
      }
      
      // Generate slug from name
      const slug = data.subcategory ? data.subcategory.toLowerCase().replace(/\s+/g, '-') : null;
      
      await pool.query(`
        INSERT INTO sub_categories (
          id, firebase_id, name, slug, category_id, 
          is_active, metadata, created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ON CONFLICT (firebase_id) DO UPDATE SET
          name = EXCLUDED.name,
          slug = EXCLUDED.slug,
          category_id = EXCLUDED.category_id,
          is_active = EXCLUDED.is_active,
          metadata = EXCLUDED.metadata,
          updated_at = EXCLUDED.updated_at
      `, [
        generateUUID(),
        doc.id,
        data.subcategory,
        slug,
        categoryId,
        data.isActive !== undefined ? data.isActive : true,
        data.description ? JSON.stringify({description: data.description}) : null,
        toDate(data.createdAt) || new Date(),
        toDate(data.updatedAt) || new Date()
      ]);
      
      migrated++;
    }
    
    console.log(`✅ Migrated ${migrated} subcategories`);
    
  } catch (error) {
    console.error('❌ Error migrating subcategories:', error);
  }
}

// 4. Migrate subscription_plans (to subscription_plans_new table)
async function migrateSubscriptionPlans() {
  console.log('🔄 Migrating subscription_plans to subscription_plans_new...');
  
  try {
    const snapshot = await db.collection('subscription_plans').get();
    console.log(`Found ${snapshot.size} subscription plans in Firebase`);
    
    let migrated = 0;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      // Generate a code from name
      const code = data.name ? data.name.toLowerCase().replace(/\s+/g, '_') : doc.id;
      
      await pool.query(`
        INSERT INTO subscription_plans_new (
          id, firebase_id, code, name, type, plan_type, description, 
          price, currency, duration_days, features, limitations, 
          is_active, is_default_plan, requires_country_pricing,
          created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
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
          is_active = EXCLUDED.is_active,
          updated_at = EXCLUDED.updated_at
      `, [
        generateUUID(),
        doc.id,
        code,
        data.name,
        data.type || 'basic',
        data.planType || 'subscription',
        data.description,
        data.price || 0,
        data.currency || 'USD',
        data.durationDays || 30,
        data.features ? JSON.stringify(data.features) : JSON.stringify([]),
        data.limitations ? JSON.stringify(data.limitations) : JSON.stringify([]),
        data.isActive !== undefined ? data.isActive : true,
        false, // is_default_plan
        false, // requires_country_pricing
        toDate(data.createdAt) || new Date(),
        toDate(data.updatedAt) || new Date()
      ]);
      
      migrated++;
    }
    
    console.log(`✅ Migrated ${migrated} subscription plans`);
    
  } catch (error) {
    console.error('❌ Error migrating subscription_plans:', error);
  }
}

// 5. Migrate variable_types (to variables table)  
async function migrateVariableTypes() {
  console.log('🔄 Migrating variable_types to variables...');
  
  try {
    const snapshot = await db.collection('variable_types').get();
    console.log(`Found ${snapshot.size} variable types in Firebase`);
    
    let migrated = 0;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      // Create a key from name
      const key = data.name ? data.name.toLowerCase().replace(/\s+/g, '_') : doc.id;
      
      await pool.query(`
        INSERT INTO variables (
          id, firebase_id, key, value, type, description, 
          is_active, created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ON CONFLICT (firebase_id) DO UPDATE SET
          key = EXCLUDED.key,
          value = EXCLUDED.value,
          type = EXCLUDED.type,
          description = EXCLUDED.description,
          is_active = EXCLUDED.is_active,
          updated_at = EXCLUDED.updated_at
      `, [
        generateUUID(),
        doc.id,
        key,
        JSON.stringify({
          name: data.name,
          options: data.options,
          isRequired: data.isRequired,
          defaultValue: data.defaultValue,
          validationRules: data.validationRules
        }),
        data.type || 'string',
        data.description,
        data.isActive !== undefined ? data.isActive : true,
        toDate(data.createdAt) || new Date(),
        toDate(data.updatedAt) || new Date()
      ]);
      
      migrated++;
    }
    
    console.log(`✅ Migrated ${migrated} variable types`);
    
  } catch (error) {
    console.error('❌ Error migrating variable_types:', error);
  }
}

// 6. Migrate cities
async function migrateCities() {
  console.log('🔄 Migrating cities...');
  
  try {
    const snapshot = await db.collection('cities').get();
    console.log(`Found ${snapshot.size} cities in Firebase`);
    
    let migrated = 0;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      await pool.query(`
        INSERT INTO cities (
          id, firebase_id, name, country_code, is_active, 
          population, coordinates, created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ON CONFLICT (firebase_id) DO UPDATE SET
          name = EXCLUDED.name,
          country_code = EXCLUDED.country_code,
          is_active = EXCLUDED.is_active,
          population = EXCLUDED.population,
          coordinates = EXCLUDED.coordinates,
          updated_at = EXCLUDED.updated_at
      `, [
        generateUUID(),
        doc.id,
        data.name,
        data.countryCode,
        data.isActive !== undefined ? data.isActive : true,
        data.population,
        data.coordinates ? JSON.stringify(data.coordinates) : null,
        toDate(data.createdAt) || new Date(),
        toDate(data.updatedAt) || new Date()
      ]);
      
      migrated++;
    }
    
    console.log(`✅ Migrated ${migrated} cities`);
    
  } catch (error) {
    console.error('❌ Error migrating cities:', error);
  }
}

// 7. Migrate business_products
async function migrateBusinessProducts() {
  console.log('🔄 Migrating business_products...');
  
  try {
    const snapshot = await db.collection('business_products').get();
    console.log(`Found ${snapshot.size} business products in Firebase`);
    
    let migrated = 0;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      await pool.query(`
        INSERT INTO business_products (
          id, firebase_id, submitted_by, delivery_info, click_count, 
          original_price, business_whatsapp, created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ON CONFLICT (firebase_id) DO UPDATE SET
          submitted_by = EXCLUDED.submitted_by,
          delivery_info = EXCLUDED.delivery_info,
          click_count = EXCLUDED.click_count,
          original_price = EXCLUDED.original_price,
          business_whatsapp = EXCLUDED.business_whatsapp,
          updated_at = EXCLUDED.updated_at
      `, [
        generateUUID(),
        doc.id,
        data.submittedBy,
        data.deliveryInfo,
        data.clickCount || 0,
        data.originalPrice,
        data.businessWhatsapp,
        toDate(data.createdAt) || new Date(),
        toDate(data.updatedAt) || new Date()
      ]);
      
      migrated++;
    }
    
    console.log(`✅ Migrated ${migrated} business products`);
    
  } catch (error) {
    console.error('❌ Error migrating business_products:', error);
  }
}

// Main migration function
async function runFixedFirebaseMigration() {
  console.log('🚀 Starting fixed Firebase to PostgreSQL migration...\n');
  
  try {
    // Test database connection
    await pool.query('SELECT NOW()');
    console.log('✅ Database connection successful\n');
    
    // Run all migrations
    await migrateAdminUsers();
    await migrateAppCountries();
    await migrateSubcategories();
    await migrateSubscriptionPlans();
    await migrateVariableTypes();
    await migrateCities();
    await migrateBusinessProducts();
    
    console.log('\n🎉 Fixed Firebase migration finished!');
    
  } catch (error) {
    console.error('💥 Migration failed:', error);
  } finally {
    await pool.end();
  }
}

runFixedFirebaseMigration();
