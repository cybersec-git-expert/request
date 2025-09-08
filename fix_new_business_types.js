const db = require('./backend/services/database');

async function fixNewBusinessTypes() {
  try {
    console.log('🔧 Fixing new business types...');
    
    // 1. Add modules column if it doesn't exist
    console.log('📊 Adding modules column if missing...');
    await db.pool.query(`
      ALTER TABLE country_business_types 
      ADD COLUMN IF NOT EXISTS modules JSONB DEFAULT '[]'
    `);
    
    // 2. Update business types that have null or empty modules
    console.log('🔄 Updating business types with default modules...');
    
    const businessTypesQuery = `
      SELECT id, name, modules 
      FROM country_business_types 
      WHERE modules IS NULL OR modules = '[]'::jsonb
    `;
    
    const result = await db.pool.query(businessTypesQuery);
    console.log(`Found ${result.rows.length} business types needing module updates`);
    
    // Default module mappings based on business type names
    const defaultModuleMappings = {
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
      'Rent': ['rent'],
      'Service': ['service']
    };
    
    // Update each business type with appropriate modules
    for (const businessType of result.rows) {
      const modules = defaultModuleMappings[businessType.name] || ['other'];
      
      console.log(`Updating ${businessType.name} with modules:`, modules);
      
      await db.pool.query(`
        UPDATE country_business_types 
        SET modules = $1, updated_at = NOW()
        WHERE id = $2
      `, [JSON.stringify(modules), businessType.id]);
    }
    
    // 3. Check for any business types that might have UUID issues
    console.log('🔍 Checking business type ID formats...');
    
    const allBusinessTypes = await db.pool.query(`
      SELECT id, name, firebase_id, global_business_type_id 
      FROM country_business_types 
      ORDER BY created_at DESC 
      LIMIT 10
    `);
    
    console.log('Recent business types:');
    allBusinessTypes.rows.forEach(bt => {
      console.log(`- ID: ${bt.id}, Name: ${bt.name}, Firebase: ${bt.firebase_id}, Global: ${bt.global_business_type_id}`);
    });
    
    console.log('✅ Business types fixed successfully!');
    
  } catch (error) {
    console.error('❌ Error fixing business types:', error);
  } finally {
    await db.pool.end();
  }
}

// Run the fix
fixNewBusinessTypes();
