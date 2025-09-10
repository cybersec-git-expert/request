#!/usr/bin/env node

// Simple script to run the usage_monthly table migration
// Usage: node run_migration.js

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

async function runMigration() {
  const pool = new Pool();
  
  try {
    console.log('🗃️  Connecting to database...');
    
    const sqlFile = path.join(__dirname, 'migrations', 'create_usage_monthly.sql');
    const sql = fs.readFileSync(sqlFile, 'utf8');
    
    console.log('📝 Running migration: create_usage_monthly.sql');
    
    const client = await pool.connect();
    try {
      await client.query(sql);
      console.log('✅ Migration completed successfully!');
      
      // Test that the table exists
      const result = await client.query(`
        SELECT column_name, data_type, is_nullable 
        FROM information_schema.columns 
        WHERE table_name = 'usage_monthly' 
        ORDER BY ordinal_position
      `);
      
      console.log('📋 Table structure:');
      result.rows.forEach(row => {
        console.log(`  - ${row.column_name}: ${row.data_type} ${row.is_nullable === 'NO' ? '(NOT NULL)' : ''}`);
      });
      
    } finally {
      client.release();
    }
    
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    console.error('Full error:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  runMigration();
}

module.exports = { runMigration };
