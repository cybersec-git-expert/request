const dbService = require('./database');

/**
 * Standard permissions for all admin users
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
  vehicleManagement: true,
  countryVehicleTypeManagement: true,
  
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
  countryVehicleTypeManagement: true,
  
  // Content Management
  contentManagement: true,
  countryPageManagement: true,
  
  // Legal & Payment (available for country admins too)
  paymentMethodManagement: true,
  legalDocumentManagement: true,
  
  // SMS Configuration
  smsConfiguration: true
};

/**
 * Permissions only for super admins
 */
const SUPER_ADMIN_ONLY_PERMISSIONS = {
  adminUsersManagement: true
};

/**
 * Get default permissions for a new admin user based on their role
 * @param {string} role - 'super_admin' or 'country_admin'
 * @returns {object} - Complete permissions object
 */
function getDefaultPermissionsForRole(role) {
  let permissions = { ...STANDARD_PERMISSIONS };
  
  if (role === 'super_admin') {
    permissions = { ...permissions, ...SUPER_ADMIN_ONLY_PERMISSIONS };
  }
  
  return permissions;
}

/**
 * Auto-activate data for a new country
 * @param {string} countryCode - Country code (e.g., 'LK', 'US')
 * @param {string} countryName - Country name (e.g., 'Sri Lanka', 'United States')
 * @param {string} adminUserId - ID of admin creating the activation
 * @param {string} adminUserName - Name of admin creating the activation
 */
async function autoActivateCountryData(countryCode, countryName, adminUserId, adminUserName) {
  console.log(`🔄 Auto-activating data for country: ${countryName} (${countryCode})`);
  
  try {
    // Define the collections and their table mappings
    const collections = [
      { 
        name: 'variables', 
        activationTable: 'country_variable_types', 
        nameField: 'key', 
        idField: 'variable_type_id', 
        nameColumn: 'variable_type_name',
        hasCountryName: true,
        hasItemName: true
      },
      { 
        name: 'categories', 
        activationTable: 'country_categories', 
        nameField: 'name', 
        idField: 'category_id', 
        nameColumn: 'category_name',
        hasCountryName: true,
        hasItemName: true
      },
      { 
        name: 'sub_categories', 
        activationTable: 'country_subcategories', 
        nameField: 'name', 
        idField: 'subcategory_id', 
        nameColumn: 'subcategory_name',
        hasCountryName: false,
        hasItemName: false
      },
      { 
        name: 'brands', 
        activationTable: 'country_brands', 
        nameField: 'name', 
        idField: 'brand_id', 
        nameColumn: 'brand_name',
        hasCountryName: false,
        hasItemName: false
      },
      { 
        name: 'master_products', 
        activationTable: 'country_products', 
        nameField: 'name', 
        idField: 'product_id', 
        nameColumn: 'product_name',
        hasCountryName: true,
        hasItemName: true
      },
      { 
        name: 'vehicle_types', 
        activationTable: 'country_vehicle_types', 
        nameField: 'name', 
        idField: 'vehicle_type_id', 
        nameColumn: 'vehicle_type_name',
        hasCountryName: true,
        hasItemName: true
      }
    ];
    
    for (const collection of collections) {
      console.log(`   📋 Processing ${collection.name}...`);
      
      let items;
      // Special handling for variables table which stores name in JSON
      if (collection.name === 'variables') {
        items = await dbService.query(`SELECT id, key, value FROM ${collection.name} WHERE is_active = true`);
      } else {
        items = await dbService.query(`SELECT id, ${collection.nameField} FROM ${collection.name} WHERE is_active = true`);
      }
      
      let activatedCount = 0;
      let skippedCount = 0;
      
      for (const item of items.rows) {
        // Check if activation already exists
        const existing = await dbService.query(
          `SELECT id FROM ${collection.activationTable} WHERE country_code = $1 AND ${collection.idField} = $2`,
          [countryCode, item.id]
        );
        
        if (existing.rows.length === 0) {
          let displayName;
          
          // Special handling for variables table
          if (collection.name === 'variables') {
            try {
              const valueJson = JSON.parse(item.value);
              displayName = valueJson.name || item.key;
            } catch (e) {
              displayName = item.key;
            }
          } else {
            displayName = item[collection.nameField];
          }
          
          // Create activation record with appropriate columns
          let insertQuery, values;
          
          if (collection.hasCountryName && collection.hasItemName) {
            // Full structure with country_name and item_name
            insertQuery = `INSERT INTO ${collection.activationTable} (
              country_code, 
              country_name, 
              ${collection.idField}, 
              ${collection.nameColumn}, 
              is_active, 
              created_at, 
              updated_at, 
              updated_by
            ) VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, $6)`;
            values = [countryCode, countryName, item.id, displayName, true, adminUserId];
          } else {
            // Basic structure without name columns
            insertQuery = `INSERT INTO ${collection.activationTable} (
              country_code, 
              ${collection.idField}, 
              is_active, 
              created_at, 
              updated_at
            ) VALUES ($1, $2, $3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)`;
            values = [countryCode, item.id, true];
          }
          
          await dbService.query(insertQuery, values);
          activatedCount++;
        } else {
          skippedCount++;
        }
      }
      
      console.log(`   ✅ ${collection.name}: ${activatedCount} activated, ${skippedCount} already existed`);
    }
    
    // Seed country business types from global templates if country_business_types exists
    try {
      console.log('   📋 Processing business types...');
      // Check table existence first
      const tbl = await dbService.query(`
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema='public' AND table_name='country_business_types'
      `);
      if (tbl.rows.length === 0) {
        console.warn('   ⚠️ Skipping business types seeding: country_business_types table not found');
      } else {
        const globalTypes = await dbService.query('SELECT id, name, description, icon, display_order, is_active FROM business_types WHERE is_active = true');

        // If no global types exist, seed from a safe built-in default list
        let typesToSeed = globalTypes.rows;
        if (!typesToSeed || typesToSeed.length === 0) {
          console.warn('   ⚠️ No active rows found in business_types. Seeding from built-in defaults.');
          typesToSeed = [
            { id: null, name: 'Product Seller', description: 'Businesses that sell physical products (electronics, food, clothing, etc.)', icon: '🛍️', display_order: 1, is_active: true },
            { id: null, name: 'Service Provider', description: 'Businesses that provide services (repairs, consultations, etc.)', icon: '🔧', display_order: 2, is_active: true },
            { id: null, name: 'Rental Business', description: 'Businesses that rent out items (vehicles, equipment, etc.)', icon: '🏠', display_order: 3, is_active: true },
            { id: null, name: 'Restaurant/Food', description: 'Restaurants, cafes, food delivery businesses', icon: '🍽️', display_order: 4, is_active: true },
            { id: null, name: 'Delivery Service', description: 'Courier, logistics, and delivery companies', icon: '🚚', display_order: 5, is_active: true },
            { id: null, name: 'Other Business', description: 'Businesses that don\'t fit into other categories', icon: '🏢', display_order: 6, is_active: true }
          ];
        }

        // Validate admin id for FK (nullable if not a UUID)
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
        const createdBySafe = uuidRegex.test(adminUserId || '') ? adminUserId : null;
        let btActivated = 0, btSkipped = 0;
        for (const t of typesToSeed) {
          const exists = await dbService.query(
            'SELECT id FROM country_business_types WHERE country_code = $1 AND (global_business_type_id = $2 OR name = $3)',
            [countryCode, t.id, t.name]
          );
          if (exists.rows.length === 0) {
            await dbService.query(
              `INSERT INTO country_business_types (name, description, icon, is_active, display_order, country_code, global_business_type_id, created_by, updated_by, created_at, updated_at)
               VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$8,NOW(),NOW())`,
              [t.name, t.description || null, t.icon || null, true, t.display_order || 0, countryCode, t.id, createdBySafe]
            );
            btActivated++;
          } else {
            btSkipped++;
          }
        }
        console.log(`   ✅ business_types: ${btActivated} activated, ${btSkipped} already existed`);
      }
    } catch (btErr) {
      console.error('   ❌ Error seeding country business types (continuing):', btErr.message);
    }

    console.log(`🎉 Auto-activation completed for ${countryName}!`);
    
  } catch (error) {
    console.error(`❌ Error during auto-activation for ${countryName}:`, error);
    throw error;
  }
}

module.exports = {
  getDefaultPermissionsForRole,
  autoActivateCountryData,
  STANDARD_PERMISSIONS,
  SUPER_ADMIN_ONLY_PERMISSIONS
};
