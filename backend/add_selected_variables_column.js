const { Client } = require('pg');
const database = require('./services/database');

// Use the existing database service instead of creating a new client
const client = database;

async function addSelectedVariablesColumn() {
  try {
    console.log('Adding selected_variables column to price_listings table...');

    // Add selected_variables column to price_listings table
    const addColumnQuery = `
      ALTER TABLE price_listings 
      ADD COLUMN IF NOT EXISTS selected_variables JSONB DEFAULT '{}';
    `;

    console.log('Adding selected_variables column...');
    await client.query(addColumnQuery);
    console.log('✅ selected_variables column added successfully');

    // Add an index for better performance on selected_variables queries
    const addIndexQuery = `
      CREATE INDEX IF NOT EXISTS idx_price_listings_selected_variables 
      ON price_listings USING GIN (selected_variables);
    `;

    console.log('Adding GIN index for selected_variables...');
    await client.query(addIndexQuery);
    console.log('✅ GIN index added successfully');

    // Check the updated table structure
    const checkColumnsQuery = `
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'price_listings' 
      ORDER BY ordinal_position;
    `;

    const result = await client.query(checkColumnsQuery);
    console.log('\n📋 Updated price_listings table structure:');
    result.rows.forEach(row => {
      console.log(`  - ${row.column_name} (${row.data_type})`);
    });

  } catch (error) {
    console.error('❌ Error adding selected_variables column:', error);
  }
}

addSelectedVariablesColumn();
