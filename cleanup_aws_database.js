const { Pool } = require('pg');
require('dotenv').config({ path: './production.password.env' });

// Database connection configuration
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USERNAME,
  password: process.env.DB_PASSWORD,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
  connectionTimeoutMillis: 10000,
  idleTimeoutMillis: 30000,
});

// Tables to keep for the simplified system
const TABLES_TO_KEEP = [
  'users',
  'requests',
  'responses',
  'user_usage',  // For tracking 3 responses per month
  'notifications',
  'admin_users'
];

// Drop all tables except the ones we want to keep
async function cleanupDatabase() {
  const client = await pool.connect();
  
  try {
    console.log('🔍 Connecting to AWS RDS PostgreSQL database...');
    
    // Get all tables in the database
    const result = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_type = 'BASE TABLE'
      ORDER BY table_name;
    `);
    
    console.log('📋 Current tables in database:');
    result.rows.forEach(row => {
      const keep = TABLES_TO_KEEP.includes(row.table_name) ? '✅ KEEP' : '🗑️  DROP';
      console.log(`  ${row.table_name} - ${keep}`);
    });
    
    // Get tables to drop
    const tablesToDrop = result.rows
      .map(row => row.table_name)
      .filter(tableName => !TABLES_TO_KEEP.includes(tableName));
    
    if (tablesToDrop.length === 0) {
      console.log('✅ No tables need to be dropped!');
      return;
    }
    
    console.log(`\n🗑️  Dropping ${tablesToDrop.length} unrelated tables...`);
    
    // Disable foreign key checks temporarily
    await client.query('SET session_replication_role = replica;');
    
    // Drop each table
    for (const tableName of tablesToDrop) {
      try {
        console.log(`   Dropping table: ${tableName}`);
        await client.query(`DROP TABLE IF EXISTS "${tableName}" CASCADE;`);
        console.log(`   ✅ Dropped: ${tableName}`);
      } catch (error) {
        console.log(`   ❌ Error dropping ${tableName}: ${error.message}`);
      }
    }
    
    // Re-enable foreign key checks
    await client.query('SET session_replication_role = DEFAULT;');
    
    // Show final table list
    const finalResult = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_type = 'BASE TABLE'
      ORDER BY table_name;
    `);
    
    console.log('\n📋 Remaining tables after cleanup:');
    finalResult.rows.forEach(row => {
      console.log(`  ✅ ${row.table_name}`);
    });
    
    console.log('\n🎉 Database cleanup completed successfully!');
    
  } catch (error) {
    console.error('❌ Error during database cleanup:', error.message);
    throw error;
  } finally {
    client.release();
  }
}

// Generate SQL script without database connection (based on common tables)
function generateStaticCleanupSQL() {
  console.log('📝 Generating static SQL cleanup script...');
  
  // Common tables that are typically created and should be dropped
  const COMMON_UNRELATED_TABLES = [
    'subscriptions',
    'subscription_plans',
    'subscription_benefits',
    'user_subscriptions',
    'enhanced_business_benefits',
    'business_benefits',
    'membership_plans',
    'user_memberships',
    'vehicle_types',
    'vehicle_categories',
    'ride_requests',
    'ride_responses',
    'rides',
    'drivers',
    'vehicles',
    'driver_vehicles',
    'delivery_requests',
    'delivery_responses',
    'deliveries',
    'delivery_status',
    'payment_methods',
    'payments',
    'transactions',
    'user_payment_methods',
    'business_verifications',
    'business_types',
    'business_categories',
    'hutch_config',
    'hutch_mobile_config',
    'hutch_sms_config',
    'sms_config',
    'otp_verifications',
    'phone_verifications',
    'email_verifications',
    'user_entitlements',
    'entitlements',
    'permissions',
    'roles',
    'user_roles',
    'role_permissions',
    'api_keys',
    'sessions',
    'refresh_tokens',
    'password_resets',
    'email_templates',
    'notification_templates',
    'push_notifications',
    'user_preferences',
    'app_settings',
    'system_config',
    'audit_logs',
    'error_logs',
    'usage_stats',
    'analytics_events',
    'feedback',
    'reviews',
    'ratings',
    'reports',
    'disputes',
    'support_tickets',
    'categories',
    'subcategories',
    'tags',
    'locations',
    'addresses',
    'regions',
    'countries',
    'cities',
    'areas'
  ];
  
  let sqlScript = `-- AWS RDS PostgreSQL Database Cleanup Script
-- Generated on: ${new Date().toISOString()}
-- This script will remove all unrelated tables for simplified system

-- First, check what tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Disable foreign key checks
SET session_replication_role = replica;

`;

  COMMON_UNRELATED_TABLES.forEach(tableName => {
    sqlScript += `-- Drop table: ${tableName}\n`;
    sqlScript += `DROP TABLE IF EXISTS "${tableName}" CASCADE;\n\n`;
  });
  
  sqlScript += `-- Re-enable foreign key checks
SET session_replication_role = DEFAULT;

-- Show remaining tables after cleanup
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Create basic tables needed for simplified system
CREATE TABLE IF NOT EXISTS user_usage (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    month_year VARCHAR(7) NOT NULL, -- Format: YYYY-MM
    responses_used INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, month_year)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_usage_user_month ON user_usage(user_id, month_year);
CREATE INDEX IF NOT EXISTS idx_requests_created_at ON requests(created_at);
CREATE INDEX IF NOT EXISTS idx_responses_request_id ON responses(request_id);
`;

  // Write SQL script to file
  const fs = require('fs');
  fs.writeFileSync('./database_cleanup.sql', sqlScript);
  
  console.log('✅ SQL script generated: database_cleanup.sql');
  console.log(`📊 Script will attempt to drop ${COMMON_UNRELATED_TABLES.length} common unrelated tables`);
  console.log('📝 You can review and edit the script before running it on AWS RDS');
  
  return true;
}

// Alternative: Generate SQL script for manual execution
async function generateCleanupSQL() {
  const client = await pool.connect();
  
  try {
    console.log('📝 Generating SQL cleanup script...');
    
    // Get all tables
    const result = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_type = 'BASE TABLE'
      ORDER BY table_name;
    `);
    
    const tablesToDrop = result.rows
      .map(row => row.table_name)
      .filter(tableName => !TABLES_TO_KEEP.includes(tableName));
    
    let sqlScript = `-- AWS RDS PostgreSQL Database Cleanup Script
-- Generated on: ${new Date().toISOString()}
-- This script will remove all unrelated tables

-- Disable foreign key checks
SET session_replication_role = replica;

`;

    tablesToDrop.forEach(tableName => {
      sqlScript += `-- Drop table: ${tableName}\n`;
      sqlScript += `DROP TABLE IF EXISTS "${tableName}" CASCADE;\n\n`;
    });
    
    sqlScript += `-- Re-enable foreign key checks
SET session_replication_role = DEFAULT;

-- Show remaining tables
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_type = 'BASE TABLE'
ORDER BY table_name;
`;

    // Write SQL script to file
    const fs = require('fs');
    fs.writeFileSync('./database_cleanup.sql', sqlScript);
    
    console.log('✅ SQL script generated: database_cleanup.sql');
    console.log(`📊 Script will drop ${tablesToDrop.length} tables`);
    
  } catch (error) {
    console.error('❌ Error generating SQL script:', error.message);
    throw error;
  } finally {
    client.release();
  }
}

// Main execution
async function main() {
  try {
    console.log('🚀 AWS RDS Database Cleanup Tool');
    console.log('==================================\n');
    
    const args = process.argv.slice(2);
    
    if (args.includes('--sql-only')) {
      await generateCleanupSQL();
    } else if (args.includes('--static-sql')) {
      generateStaticCleanupSQL();
    } else if (args.includes('--execute')) {
      await cleanupDatabase();
    } else {
      console.log('Options:');
      console.log('  --static-sql  Generate SQL script without DB connection (safe)');
      console.log('  --sql-only    Generate SQL script from live DB (requires connection)');
      console.log('  --execute     Execute cleanup directly');
      console.log('\nRecommended: Start with --static-sql to generate cleanup script');
    }
    
  } catch (error) {
    console.error('💥 Fatal error:', error.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  main();
}

module.exports = { cleanupDatabase, generateCleanupSQL };
