#!/usr/bin/env node
/**
 * Schema Audit Tool
 * Compares legacy Firestore collection concepts to current PostgreSQL tables/columns.
 * Outputs JSON summary with status per collection: mapped | partial | pending | merged | deprecated.
 */

const { Client } = require('pg');
// Load environment variables (try common filenames)
try {
  const dotenv = require('dotenv');
  // Attempt priority-specific files first if they exist
  const fs = require('fs');
  const candidateFiles = [
    process.env.ENV_FILE,
    '.env.local',
    '.env.development',
    '.env.rds',
    '.env'
  ].filter(Boolean);
  for (const file of candidateFiles) {
    if (fs.existsSync(file)) {
      dotenv.config({ path: file });
      break; // stop at first existing file
    }
  }
} catch (e) {
  // dotenv optional; ignore if missing
}

// Mapping of Firestore collections (or conceptual groupings) to Postgres tables
// status meanings:
//  mapped: has a dedicated table with equivalent columns
//  merged: data merged into another table (name in target.note)
//  partial: some columns/entities implemented; gaps listed
//  pending: not implemented yet
//  deprecated: intentionally dropped
const collectionMappings = [
  { collection: 'users', table: 'users', status: 'mapped' },
  { collection: 'admin_users', table: 'users.permissions (JSONB)', status: 'merged', note: 'admin metadata consolidated into users + permissions JSONB + role column' },
  { collection: 'roles', table: 'roles (enum/role column)', status: 'merged', note: 'Normalized into role column + permissions JSONB' },
  { collection: 'categories', table: 'categories', status: 'mapped' },
  { collection: 'subcategories', table: 'subcategories', status: 'mapped' },
  { collection: 'requests', table: 'requests', status: 'mapped' },
  { collection: 'request_items', table: 'request_items', status: 'mapped' },
  { collection: 'businesses', table: 'businesses', status: 'mapped' },
  { collection: 'business_users', table: 'business_users', status: 'mapped' },
  { collection: 'vehicles', table: 'vehicles', status: 'mapped' },
  { collection: 'vehicle_types', table: 'vehicle_types', status: 'mapped' },
  { collection: 'vehicle_drivers', table: 'vehicle_drivers', status: 'mapped' },
  { collection: 'drivers', table: 'drivers', status: 'mapped' },
  { collection: 'countries', table: 'countries', status: 'mapped' },
  { collection: 'country_modules', table: 'country_modules', status: 'mapped' },
  { collection: 'cities', table: 'cities', status: 'mapped' },
  { collection: 'content_pages', table: 'content_pages', status: 'pending' },
  { collection: 'brands', table: 'brands', status: 'mapped' },
  { collection: 'products', table: 'master_products', status: 'mapped', note: 'master product catalog' },
  { collection: 'business_products', table: 'business_products', status: 'pending' },
  { collection: 'product_variables', table: 'custom_product_variables', status: 'mapped' },
  { collection: 'country_category_activations', table: 'entity_activations', status: 'merged', note: 'Generic entity activation by entity_type=category' },
  { collection: 'country_subcategory_activations', table: 'entity_activations', status: 'merged', note: 'Generic entity activation by entity_type=subcategory' },
  { collection: 'vehicle_type_activations', table: 'entity_activations', status: 'merged', note: 'Generic entity activation by entity_type=vehicle_type' },
  { collection: 'brand_activations', table: 'entity_activations', status: 'merged', note: 'entity_type=brand' },
  { collection: 'product_activations', table: 'entity_activations', status: 'merged', note: 'entity_type=product' },
  { collection: 'verification_audit_log', table: 'verification_audit_log', status: 'mapped' },
  { collection: 'rate_limits', table: 'rate_limits', status: 'mapped' },
  { collection: 'promo_codes', table: 'promo_codes', status: 'pending' },
  { collection: 'promo_code_redemptions', table: 'promo_code_redemptions', status: 'pending' },
  { collection: 'phone_verification', table: 'phone_verifications', status: 'pending' },
  { collection: 'email_verification', table: 'email_verifications', status: 'pending' },
  { collection: 'conversations', table: 'conversations', status: 'pending' },
  { collection: 'conversation_messages', table: 'conversation_messages', status: 'pending' },
  { collection: 'response_tracking', table: 'response_tracking', status: 'pending' },
  { collection: 'notifications', table: 'notifications', status: 'pending' },
  { collection: 'notification_preferences', table: 'notification_preferences', status: 'pending' },
  { collection: 'analytics_events', table: 'analytics_events', status: 'pending' },
  { collection: 'file_uploads', table: 'files', status: 'pending', note: 'Would replace Firebase Storage references' }
];

// Expected core columns for key tables (subset). Using simple arrays; script will compare to live DB.
const expectedColumns = {
  users: ['id', 'email', 'password_hash', 'role', 'permissions', 'created_at'],
  categories: ['id', 'name', 'status', 'created_at'],
  subcategories: ['id', 'category_id', 'name', 'status', 'created_at'],
  requests: ['id', 'user_id', 'status', 'country_code', 'city_id', 'created_at'],
  request_items: ['id', 'request_id', 'product_id', 'quantity'],
  businesses: ['id', 'name', 'country_code', 'status'],
  vehicles: ['id', 'business_id', 'vehicle_type_id', 'status'],
  vehicle_types: ['id', 'name', 'status'],
  country_modules: ['id', 'country_code', 'module_key', 'config', 'updated_at'],
  brands: ['id', 'name', 'status'],
  master_products: ['id', 'brand_id', 'name', 'status'],
  entity_activations: ['id', 'entity_type', 'entity_id', 'country_code', 'is_active'],
  custom_product_variables: ['id', 'product_id', 'variable_name', 'variable_value'],
  rate_limits: ['id', 'key', 'limit', 'window_seconds', 'created_at'],
  verification_audit_log: ['id', 'user_id', 'channel', 'status', 'created_at']
};

async function fetchTableColumns(client, table) {
  const res = await client.query(
    'SELECT column_name FROM information_schema.columns WHERE table_name = $1 ORDER BY ordinal_position',
    [table]
  );
  return res.rows.map(r => r.column_name);
}

async function main() {
  let client = null;
  let dbConnected = false;
  try {
    client = new Client({
      connectionString: process.env.DATABASE_URL || undefined,
      host: process.env.PGHOST,
      port: process.env.PGPORT ? Number(process.env.PGPORT) : undefined,
      user: process.env.PGUSER,
      password: process.env.PGPASSWORD,
      database: process.env.PGDATABASE,
    });
    await client.connect();
    dbConnected = true;
  } catch (err) {
    console.error('Warning: DB connection failed, continuing without live column verification:', err.message);
  }

  const results = [];

  for (const mapping of collectionMappings) {
    const entry = { ...mapping };
    const tableName = (mapping.table || '').split(' ')[0]; // take first token (handles notes)
    if (dbConnected && expectedColumns[tableName]) {
      try {
        const dbCols = await fetchTableColumns(client, tableName);
        entry.dbColumns = dbCols;
        const expected = expectedColumns[tableName];
        entry.expectedColumns = expected;
        entry.missingColumns = expected.filter(c => !dbCols.includes(c));
        entry.extraColumns = dbCols.filter(c => !expected.includes(c));
        if (entry.missingColumns.length === 0 && entry.status === 'mapped') {
          entry.columnStatus = 'complete';
        } else if (entry.status === 'mapped') {
          entry.columnStatus = 'incomplete';
        }
      } catch (err) {
        entry.error = `Unable to fetch columns: ${err.message}`;
      }
    } else if (expectedColumns[tableName]) {
      entry.expectedColumns = expectedColumns[tableName];
      entry.columnStatus = 'unknown';
    }
    results.push(entry);
  }
  if (dbConnected && client) {
    await client.end();
  }

  const summary = {
    generated_at: new Date().toISOString(),
    totals: {
      mapped: results.filter(r => r.status === 'mapped').length,
      merged: results.filter(r => r.status === 'merged').length,
      partial: results.filter(r => r.status === 'partial').length,
      pending: results.filter(r => r.status === 'pending').length,
      deprecated: results.filter(r => r.status === 'deprecated').length,
    },
    db_connected: dbConnected,
    results
  };

  console.log(JSON.stringify(summary, null, 2));
}

main().catch(err => {
  console.error('Schema audit failed', err);
  process.exit(1);
});
