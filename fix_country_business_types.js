const db = require('./services/database');

async function fixCountryBusinessTypes() {
  try {
    console.log('🔧 Fixing country business types...');
    
    // 1. Update modules for all business types with empty modules
    console.log('📊 Updating modules for business types...');
    
    const moduleUpdates = [
      // Existing ones with global_business_type_id
      { name: 'Product Seller', modules: ['item', 'service', 'rent', 'price'] },
      { name: 'Delivery', modules: ['item', 'service', 'rent', 'delivery'] },
      
      // New ones without global_business_type_id
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
      
      const result = await db.pool.query(`
        UPDATE country_business_types 
        SET modules = $1, updated_at = NOW()
        WHERE name = $2 AND country_code = 'LK'
      `, [JSON.stringify(update.modules), update.name]);
      
      console.log(`  ✅ Updated ${result.rowCount} row(s) for ${update.name}`);
    }
    
    // 2. Create missing global business type references
    console.log('\n🔗 Creating missing global business type references...');
    
    // Check which global business types exist
    const globalTypes = await db.pool.query('SELECT id, name FROM business_types ORDER BY id');
    console.log('Existing global business types:');
    globalTypes.rows.forEach(gt => console.log(`  - ${gt.id}: ${gt.name}`));
    
    // Map names to create missing global references
    const globalMappings = [
      { name: 'Tours', globalId: 7 },
      { name: 'Events', globalId: 8 },
      { name: 'Construction', globalId: 9 },
      { name: 'Education', globalId: 10 },
      { name: 'Hiring', globalId: 11 },
      { name: 'Other', globalId: 12 },
      // New ones that don't exist in global table yet
      { name: 'Rent', globalId: null },
      { name: 'Ride', globalId: null },
      { name: 'Item', globalId: null }
    ];
    
    for (const mapping of globalMappings) {
      if (mapping.globalId) {
        console.log(`Linking ${mapping.name} to global business type ${mapping.globalId}`);
        
        const result = await db.pool.query(`
          UPDATE country_business_types 
          SET global_business_type_id = $1, updated_at = NOW()
          WHERE name = $2 AND country_code = 'LK' AND global_business_type_id IS NULL
        `, [mapping.globalId, mapping.name]);
        
        console.log(`  ✅ Updated ${result.rowCount} row(s) for ${mapping.name}`);
      } else {
        console.log(`⚠️  ${mapping.name} has no global business type reference (this is okay)`);
      }
    }
    
    // 3. Show final state
    console.log('\n📋 Final business types state:');
    const final = await db.pool.query(`
      SELECT name, global_business_type_id, modules 
      FROM country_business_types 
      WHERE country_code = 'LK' 
      ORDER BY display_order
    `);
    
    final.rows.forEach(bt => {
      console.log(`  - ${bt.name}: global=${bt.global_business_type_id || 'null'}, modules=${JSON.stringify(bt.modules)}`);
    });
    
    console.log('\n✅ Country business types fixed successfully!');
    console.log('\n💡 Now subscription mapping should work correctly.');
    
  } catch (error) {
    console.error('❌ Error fixing country business types:', error);
  } finally {
    await db.pool.end();
  }
}

// Run the fix
fixCountryBusinessTypes();
