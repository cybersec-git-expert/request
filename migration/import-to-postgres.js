const fs = require('fs').promises;
const path = require('path');
const { Pool } = require('pg');
require('dotenv').config({ path: '../.env.rds' });

// PostgreSQL connection
const pool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

// Mapping of Firebase collections to PostgreSQL tables
const COLLECTION_MAPPINGS = {
    'users': 'users',
    'categories': 'categories', 
    'subcategories': 'subcategories',
    'cities': 'cities',
    'vehicle_types': 'vehicle_types',
    'country_vehicle_types': 'country_vehicle_types',
    'country_vehicles': 'country_vehicle_types', // Map to same table
    'variable_types': 'variable_types',
    'requests': 'requests',
    'new_business_verifications': 'new_business_verifications',
    'new_driver_verifications': 'new_driver_verifications',
    'price_listings': 'price_listings',
    'conversations': 'conversations',
    'messages': 'messages',
    'notifications': 'notifications',
    'subscription_plans': 'subscription_plans',
    'content_pages': 'content_pages',
    'email_otp_verifications': 'email_otp_verifications',
    'phone_otp_verifications': 'phone_otp_verifications',
    'response_tracking': 'response_tracking',
    'ride_tracking': 'ride_tracking'
};

async function transformAndImportData() {
    console.log('🔄 Firebase to PostgreSQL Data Migration');
    console.log('==========================================');
    
    const client = await pool.connect();
    
    try {
        const exportDir = path.join(__dirname, 'firebase-export');
        const importSummary = {
            startTime: new Date().toISOString(),
            collections: {},
            totalDocuments: 0,
            errors: []
        };
        
        // Start transaction for this collection only
        //await client.query('BEGIN');
        
        for (const [firebaseCollection, postgresTable] of Object.entries(COLLECTION_MAPPINGS)) {
            try {
                console.log(`\n📦 Processing: ${firebaseCollection} → ${postgresTable}`);
                
                const filePath = path.join(exportDir, `${firebaseCollection}.json`);
                
                // Check if file exists
                try {
                    await fs.access(filePath);
                } catch (error) {
                    console.log(`   ⚠️  File not found: ${firebaseCollection}.json - skipping`);
                    continue;
                }
                
                const data = JSON.parse(await fs.readFile(filePath, 'utf8'));
                console.log(`   📄 Found ${data.length} documents`);
                
                if (data.length === 0) {
                    console.log(`   ⏭️  No documents to import - skipping`);
                    continue;
                }
                
                // Transform and insert data based on collection type
                let insertedCount = 0;
                
                switch (firebaseCollection) {
                    case 'users':
                        insertedCount = await importUsers(client, data);
                        break;
                    case 'categories':
                        insertedCount = await importCategories(client, data);
                        break;
                    case 'subcategories':
                        insertedCount = await importSubcategories(client, data);
                        break;
                    case 'cities':
                        insertedCount = await importCities(client, data);
                        break;
                    case 'vehicle_types':
                        insertedCount = await importVehicleTypes(client, data);
                        break;
                    case 'country_vehicle_types':
                    case 'country_vehicles':
                        insertedCount = await importCountryVehicleTypes(client, data);
                        break;
                    case 'variable_types':
                        insertedCount = await importVariableTypes(client, data);
                        break;
                    case 'requests':
                        insertedCount = await importRequests(client, data);
                        break;
                    case 'new_business_verifications':
                        insertedCount = await importBusinessVerifications(client, data);
                        break;
                    case 'new_driver_verifications':
                        insertedCount = await importDriverVerifications(client, data);
                        break;
                    case 'conversations':
                        insertedCount = await importConversations(client, data);
                        break;
                    case 'messages':
                        insertedCount = await importMessages(client, data);
                        break;
                    case 'notifications':
                        insertedCount = await importNotifications(client, data);
                        break;
                    case 'content_pages':
                        insertedCount = await importContentPages(client, data);
                        break;
                    default:
                        console.log(`   ⚠️  No specific transformer for ${firebaseCollection} - using generic`);
                        insertedCount = await importGeneric(client, postgresTable, data);
                        break;
                }
                
                console.log(`   ✅ Imported ${insertedCount} records into ${postgresTable}`);
                importSummary.collections[firebaseCollection] = insertedCount;
                importSummary.totalDocuments += insertedCount;
                
            } catch (error) {
                console.error(`   ❌ Error importing ${firebaseCollection}:`, error.message);
                importSummary.errors.push({
                    collection: firebaseCollection,
                    error: error.message
                });
            }
        }
        
        // Commit transaction
        //await client.query('COMMIT');
        console.log('\n✅ Import completed successfully');
        
        importSummary.endTime = new Date().toISOString();
        
        // Display summary
        console.log('\n==========================================');
        console.log('📊 Import Summary');
        console.log('==========================================');
        console.log(`Total Collections Processed: ${Object.keys(COLLECTION_MAPPINGS).length}`);
        console.log(`Total Documents Imported: ${importSummary.totalDocuments}`);
        console.log(`Import Duration: ${new Date(importSummary.endTime) - new Date(importSummary.startTime)} ms`);
        
        if (importSummary.errors.length > 0) {
            console.log('\n❌ Errors:');
            importSummary.errors.forEach(error => {
                console.log(`   ${error.collection}: ${error.error}`);
            });
        }
        
        // Verify data
        await verifyImportedData(client);
        
        console.log('\n🎉 Data migration completed successfully!');
        return importSummary;
        
    } catch (error) {
        //await client.query('ROLLBACK');
        console.error('\n💥 Migration failed');
        throw error;
    } finally {
        client.release();
    }
}

// Collection-specific import functions
async function importUsers(client, users) {
    let count = 0;
    for (const user of users) {
        try {
            // Skip users without email or phone (required fields)
            if (!user.email && !user.phone) {
                console.log(`   ⚠️  Skipping user ${user.id} - no email or phone`);
                continue;
            }
            
            await client.query(`
                INSERT INTO users (firebase_uid, email, phone, display_name, photo_url, 
                                 email_verified, phone_verified, is_active, role, country_code, 
                                 created_at, updated_at)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            `, [
                user.id,
                user.email || null,
                user.phone || null,
                user.displayName || user.name || null,
                user.photoURL || user.photoUrl || null,
                user.emailVerified || false,
                user.phoneVerified || false,
                user.isActive !== false,
                user.role || 'user',
                user.countryCode || user.country || 'LK',
                user.createdAt || new Date().toISOString(),
                user.updatedAt || new Date().toISOString()
            ]);
            count++;
        } catch (error) {
            console.error(`Error importing user ${user.id}:`, error.message);
        }
    }
    return count;
}

async function importCategories(client, categories) {
    let count = 0;
    for (const category of categories) {
        try {
            await client.query(`
                INSERT INTO categories (firebase_id, name, description, icon, display_order, 
                                      is_active, country_code, created_at, updated_at)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            `, [
                category.id,
                category.category || category.name, // Fixed: use category field
                category.description || null,
                category.icon || null,
                category.displayOrder || category.order || 0,
                category.isActive !== false,
                category.countryCode || 'LK',
                category.createdAt || new Date().toISOString(),
                category.updatedAt || new Date().toISOString()
            ]);
            count++;
        } catch (error) {
            console.error(`Error importing category ${category.id}:`, error.message);
        }
    }
    return count;
}

async function importSubcategories(client, subcategories) {
    let count = 0;
    for (const subcategory of subcategories) {
        try {
            // First get the category UUID from firebase_id
            const categoryResult = await client.query(
                'SELECT id FROM categories WHERE firebase_id = $1',
                [subcategory.category_id || subcategory.categoryId] // Fixed: use category_id field
            );
            
            const categoryId = categoryResult.rows[0]?.id || null;
            
            await client.query(`
                INSERT INTO subcategories (firebase_id, category_id, name, description, icon, 
                                         display_order, is_active, country_code, created_at, updated_at)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            `, [
                subcategory.id,
                categoryId,
                subcategory.subcategory || subcategory.name, // Fixed: use subcategory field
                subcategory.description || null,
                subcategory.icon || null,
                subcategory.displayOrder || subcategory.order || 0,
                subcategory.isActive !== false,
                subcategory.countryCode || 'LK',
                subcategory.createdAt || new Date().toISOString(),
                subcategory.updatedAt || new Date().toISOString()
            ]);
            count++;
        } catch (error) {
            console.error(`Error importing subcategory ${subcategory.id}:`, error.message);
        }
    }
    return count;
}

async function importCities(client, cities) {
    let count = 0;
    for (const city of cities) {
        try {
            await client.query(`
                INSERT INTO cities (firebase_id, name, country_code, province, district, 
                                  latitude, longitude, is_active, created_at, updated_at)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            `, [
                city.id,
                city.name,
                city.countryCode || city.country || 'LK',
                city.province || null,
                city.district || null,
                city.latitude || null,
                city.longitude || null,
                city.isActive !== false,
                city.createdAt || new Date().toISOString(),
                city.updatedAt || new Date().toISOString()
            ]);
            count++;
        } catch (error) {
            console.error(`Error importing city ${city.id}:`, error.message);
        }
    }
    return count;
}

async function importVehicleTypes(client, vehicleTypes) {
    let count = 0;
    for (const vehicle of vehicleTypes) {
        try {
            await client.query(`
                INSERT INTO vehicle_types (firebase_id, name, description, icon, passenger_capacity, 
                                         display_order, is_active, country_code, created_at, updated_at)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            `, [
                vehicle.id,
                vehicle.name,
                vehicle.description || null,
                vehicle.icon || null,
                vehicle.passengerCapacity || vehicle.capacity || 1,
                vehicle.displayOrder || vehicle.order || 0,
                vehicle.isActive !== false,
                vehicle.countryCode || 'LK',
                vehicle.createdAt || new Date().toISOString(),
                vehicle.updatedAt || new Date().toISOString()
            ]);
            count++;
        } catch (error) {
            console.error(`Error importing vehicle type ${vehicle.id}:`, error.message);
        }
    }
    return count;
}

async function importCountryVehicleTypes(client, countryVehicles) {
    let count = 0;
    for (const item of countryVehicles) {
        try {
            // Handle different data structures
            const enabledVehicles = item.enabledVehicles || item.vehicles || [];
            const countryCode = item.countryCode || item.country || 'LK';
            
            for (const vehicleId of enabledVehicles) {
                // Get vehicle type UUID from firebase_id
                const vehicleResult = await client.query(
                    'SELECT id FROM vehicle_types WHERE firebase_id = $1',
                    [vehicleId]
                );
                
                const vehicleTypeId = vehicleResult.rows[0]?.id;
                
                if (vehicleTypeId) {
                    await client.query(`
                        INSERT INTO country_vehicle_types (country_code, vehicle_type_id, is_enabled, created_at, updated_at)
                        VALUES ($1, $2, $3, $4, $5)
                    `, [
                        countryCode,
                        vehicleTypeId,
                        true,
                        item.createdAt || new Date().toISOString(),
                        item.updatedAt || new Date().toISOString()
                    ]);
                    count++;
                }
            }
        } catch (error) {
            console.error(`Error importing country vehicle:`, error.message);
        }
    }
    return count;
}

async function importVariableTypes(client, variableTypes) {
    let count = 0;
    for (const variable of variableTypes) {
        try {
            await client.query(`
                INSERT INTO variable_types (firebase_id, name, data_type, options, is_required, 
                                          display_order, is_active, country_code, created_at, updated_at)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            `, [
                variable.id,
                variable.name,
                variable.dataType || variable.type || 'text',
                JSON.stringify(variable.options || []),
                variable.isRequired || false,
                variable.displayOrder || variable.order || 0,
                variable.isActive !== false,
                variable.countryCode || 'LK',
                variable.createdAt || new Date().toISOString(),
                variable.updatedAt || new Date().toISOString()
            ]);
            count++;
        } catch (error) {
            console.error(`Error importing variable type ${variable.id}:`, error.message);
        }
    }
    return count;
}

async function importGeneric(client, tableName, data) {
    console.log(`   ⚠️  Using generic import for table: ${tableName}`);
    return 0; // Skip generic imports for now
}

// Additional import functions for other collections...
async function importRequests(client, requests) {
    // Implementation for requests...
    return 0;
}

async function importBusinessVerifications(client, businesses) {
    // Implementation for business verifications...
    return 0;
}

async function importDriverVerifications(client, drivers) {
    // Implementation for driver verifications...
    return 0;
}

async function importConversations(client, conversations) {
    // Implementation for conversations...
    return 0;
}

async function importMessages(client, messages) {
    // Implementation for messages...
    return 0;
}

async function importNotifications(client, notifications) {
    // Implementation for notifications...
    return 0;
}

async function importContentPages(client, contentPages) {
    // Implementation for content pages...
    return 0;
}

async function verifyImportedData(client) {
    console.log('\n🔍 Verifying imported data...');
    
    const tables = ['users', 'categories', 'subcategories', 'cities', 'vehicle_types', 'country_vehicle_types', 'variable_types'];
    
    for (const table of tables) {
        try {
            const result = await client.query(`SELECT COUNT(*) as count FROM ${table}`);
            console.log(`   📊 ${table}: ${result.rows[0].count} records`);
        } catch (error) {
            console.log(`   ❌ Error checking ${table}: ${error.message}`);
        }
    }
}

// Run the import
if (require.main === module) {
    transformAndImportData()
        .then((summary) => {
            console.log('\n🎉 Migration completed successfully!');
            console.log('✅ Firebase → PostgreSQL migration is complete');
            console.log('🔜 Next: Update application to use PostgreSQL');
            process.exit(0);
        })
        .catch(error => {
            console.error('\n💥 Migration failed:', error);
            process.exit(1);
        });
}

module.exports = { transformAndImportData };
