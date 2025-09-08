#!/bin/bash

# Script to fix country business types on AWS production server

echo "🔧 Fixing country business types on AWS production server..."

# Create a temporary Node.js script on the server
cat > /tmp/fix_production_business_types.js << 'EOF'
const { Pool } = require('pg');

// Use the production database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false
  }
});

async function fixProductionBusinessTypes() {
  try {
    console.log('🔧 Fixing production country business types...');
    
    // 1. Add modules column if it doesn't exist
    console.log('📊 Adding modules column if missing...');
    await pool.query(`
      ALTER TABLE country_business_types 
      ADD COLUMN IF NOT EXISTS modules JSONB DEFAULT '[]'
    `);
    
    // 2. Update modules for all business types with empty modules
    console.log('🔄 Updating business types with default modules...');
    
    const moduleUpdates = [
      { name: 'Product Seller', modules: ['item', 'service', 'rent', 'price'] },
      { name: 'Delivery', modules: ['item', 'service', 'rent', 'delivery'] },
      { name: 'Tours', modules: ['tours'] },
      { name: 'Events', modules: ['events'] },
      { name: 'Construction', modules: ['construction'] },
      { name: 'Education', modules: ['education'] },
      { name: 'Hiring', modules: ['hiring'] },
      { name: 'Other', modules: ['other'] },
      { name: 'Rent', modules: ['rent'] },
      { name: 'Ride', modules: ['ride'] },
      { name: 'Item', modules: ['item'] }
    ];
    
    for (const update of moduleUpdates) {
      console.log(`Updating ${update.name} with modules: ${update.modules.join(', ')}`);
      
      const result = await pool.query(`
        UPDATE country_business_types 
        SET modules = $1, updated_at = NOW()
        WHERE name = $2 AND country_code = 'LK' AND (modules IS NULL OR modules = '[]'::jsonb)
      `, [JSON.stringify(update.modules), update.name]);
      
      console.log(`  ✅ Updated ${result.rowCount} row(s) for ${update.name}`);
    }
    
    // 3. Link to global business types where they exist
    console.log('\n🔗 Linking to global business types...');
    
    const globalMappings = [
      { name: 'Tours', globalId: 7 },
      { name: 'Events', globalId: 8 },
      { name: 'Construction', globalId: 9 },
      { name: 'Education', globalId: 10 },
      { name: 'Hiring', globalId: 11 },
      { name: 'Other', globalId: 12 }
    ];
    
    for (const mapping of globalMappings) {
      console.log(`Linking ${mapping.name} to global business type ${mapping.globalId}`);
      
      const result = await pool.query(`
        UPDATE country_business_types 
        SET global_business_type_id = $1, updated_at = NOW()
        WHERE name = $2 AND country_code = 'LK' AND global_business_type_id IS NULL
      `, [mapping.globalId, mapping.name]);
      
      console.log(`  ✅ Updated ${result.rowCount} row(s) for ${mapping.name}`);
    }
    
    // 4. Show final state
    console.log('\n📋 Final business types state:');
    const final = await pool.query(`
      SELECT name, global_business_type_id, modules 
      FROM country_business_types 
      WHERE country_code = 'LK' 
      ORDER BY display_order
    `);
    
    final.rows.forEach(bt => {
      console.log(`  - ${bt.name}: global=${bt.global_business_type_id || 'null'}, modules=${JSON.stringify(bt.modules)}`);
    });
    
    console.log('\n✅ Production business types fixed successfully!');
    console.log('💡 Subscription mapping should now work correctly.');
    
  } catch (error) {
    console.error('❌ Error fixing production business types:', error);
  } finally {
    await pool.end();
  }
}

fixProductionBusinessTypes();
EOF

# Run the fix script on the production server
echo "🚀 Running the fix script..."
cd /var/www/request-backend
sudo -u www-data NODE_ENV=production node /tmp/fix_production_business_types.js

# Clean up
rm /tmp/fix_production_business_types.js

echo "✅ Production fix completed!"
