#!/usr/bin/env node
/**
 * Production Migration: Add modules column to country_business_types table
 * Run this on the production server to add the missing modules column
 */

const db = require('./backend/services/database');

async function addModulesColumn() {
  try {
    console.log('🔍 Checking if modules column exists...');
    
    // Check if modules column already exists
    const columnCheck = await db.pool.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'country_business_types' 
      AND column_name = 'modules'
    `);
    
    if (columnCheck.rows.length > 0) {
      console.log('✅ Modules column already exists, no migration needed');
      return;
    }
    
    console.log('➕ Adding modules column to country_business_types table...');
    
    // Add the modules column
    await db.pool.query(`
      ALTER TABLE country_business_types 
      ADD COLUMN modules JSONB DEFAULT '[]'::jsonb
    `);
    
    console.log('✅ Successfully added modules column');
    
    // Initialize modules for existing business types based on their names
    console.log('🔧 Initializing modules for existing business types...');
    
    const moduleMapping = {
      'Product Seller': ['item', 'service', 'rent', 'price'],
      'Delivery': ['item', 'service', 'rent', 'delivery'],
      'Ride': ['ride'],
      'Tours': ['tours'],
      'Events': ['events'],
      'Construction': ['construction'],
      'Education': ['education'],
      'Hiring': ['hiring'],
      'Other': ['other'],
      'Item': ['item'],
      'Rent': ['rent']
    };
    
    for (const [typeName, modules] of Object.entries(moduleMapping)) {
      await db.pool.query(`
        UPDATE country_business_types 
        SET modules = $1 
        WHERE name = $2 AND modules = '[]'::jsonb
      `, [JSON.stringify(modules), typeName]);
      
      console.log(`📝 Updated ${typeName} business type with modules:`, modules);
    }
    
    console.log('✅ Migration completed successfully');
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    await db.pool.end();
  }
}

// Run the migration
addModulesColumn()
  .then(() => {
    console.log('🎉 Migration script completed');
    process.exit(0);
  })
  .catch((error) => {
    console.error('💥 Migration script failed:', error);
    process.exit(1);
  });
