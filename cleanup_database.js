const { Client } = require('pg');
require('dotenv').config({ path: './production.password.env' });

// Tables to keep for the simplified system
const TABLES_TO_KEEP = [
    'users',
    'requests', 
    'responses',
    'user_response_count', // For tracking monthly limits
    'categories',
    'countries',
    'sms_config',
    'email_config'
];

// Tables to definitely remove (ride/vehicle/subscription related)
const TABLES_TO_REMOVE = [
    'vehicles',
    'vehicle_types', 
    'ride_requests',
    'ride_responses',
    'rides',
    'drivers',
    'driver_registrations',
    'driver_verifications',
    'subscriptions',
    'subscription_plans',
    'user_subscriptions',
    'membership_plans',
    'user_memberships',
    'enhanced_business_benefits',
    'business_benefits',
    'entitlements',
    'user_entitlements',
    'benefits',
    'permissions',
    'user_permissions',
    'roles',
    'user_roles',
    'modules',
    'country_modules',
    'entity_activations',
    'brands',
    'products',
    'custom_product_variables'
];

async function listAllTables() {
    const client = new Client({
        host: process.env.DB_HOST,
        port: process.env.DB_PORT,
        database: process.env.DB_NAME,
        user: process.env.DB_USERNAME,
        password: process.env.DB_PASSWORD,
        ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false
    });

    try {
        await client.connect();
        console.log('Connected to PostgreSQL database');

        // Get all table names
        const result = await client.query(`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_type = 'BASE TABLE'
            ORDER BY table_name;
        `);

        console.log('\n=== ALL TABLES IN DATABASE ===');
        const allTables = result.rows.map(row => row.table_name);
        allTables.forEach(table => console.log(table));

        console.log('\n=== TABLES TO KEEP ===');
        const tablesToKeep = allTables.filter(table => TABLES_TO_KEEP.includes(table));
        tablesToKeep.forEach(table => console.log(`✓ ${table}`));

        console.log('\n=== TABLES TO REMOVE ===');
        const tablesToRemove = allTables.filter(table => TABLES_TO_REMOVE.includes(table));
        tablesToRemove.forEach(table => console.log(`✗ ${table}`));

        console.log('\n=== UNKNOWN TABLES (REVIEW NEEDED) ===');
        const unknownTables = allTables.filter(table => 
            !TABLES_TO_KEEP.includes(table) && !TABLES_TO_REMOVE.includes(table)
        );
        unknownTables.forEach(table => console.log(`? ${table}`));

        await client.end();
        return { allTables, tablesToKeep, tablesToRemove, unknownTables };

    } catch (error) {
        console.error('Database connection error:', error);
        if (client) await client.end();
        throw error;
    }
}

async function removeTables(tablesToDrop) {
    const client = new Client({
        host: process.env.DB_HOST,
        port: process.env.DB_PORT,
        database: process.env.DB_NAME,
        user: process.env.DB_USERNAME,
        password: process.env.DB_PASSWORD,
        ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false
    });

    try {
        await client.connect();
        console.log('\n=== STARTING TABLE REMOVAL ===');

        for (const table of tablesToDrop) {
            try {
                console.log(`Dropping table: ${table}`);
                await client.query(`DROP TABLE IF EXISTS ${table} CASCADE;`);
                console.log(`✓ Dropped: ${table}`);
            } catch (error) {
                console.error(`✗ Failed to drop ${table}:`, error.message);
            }
        }

        await client.end();
        console.log('\n=== TABLE REMOVAL COMPLETE ===');

    } catch (error) {
        console.error('Database connection error:', error);
        if (client) await client.end();
        throw error;
    }
}

// Main execution
async function main() {
    try {
        console.log('🔍 Analyzing database tables...');
        const { allTables, tablesToKeep, tablesToRemove, unknownTables } = await listAllTables();

        console.log('\n📊 SUMMARY:');
        console.log(`Total tables: ${allTables.length}`);
        console.log(`To keep: ${tablesToKeep.length}`);
        console.log(`To remove: ${tablesToRemove.length}`);
        console.log(`Unknown: ${unknownTables.length}`);

        if (process.argv.includes('--execute')) {
            console.log('\n⚠️  EXECUTING TABLE REMOVAL...');
            await removeTables(tablesToRemove);
        } else {
            console.log('\n💡 Run with --execute flag to actually remove tables');
            console.log('   node cleanup_database.js --execute');
        }

    } catch (error) {
        console.error('Script failed:', error);
        process.exit(1);
    }
}

if (require.main === module) {
    main();
}

module.exports = { listAllTables, removeTables };
