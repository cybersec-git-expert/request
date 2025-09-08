const db = require('./services/database');

(async () => {
  try {
    console.log('🔧 Adding country-specific override columns to country_products...');
    
    // Add columns for country-specific overrides
    await db.query(`
      ALTER TABLE country_products 
      ADD COLUMN IF NOT EXISTS custom_images TEXT[],
      ADD COLUMN IF NOT EXISTS custom_category_id UUID REFERENCES categories(id),
      ADD COLUMN IF NOT EXISTS custom_subcategory_id UUID REFERENCES sub_categories(id),
      ADD COLUMN IF NOT EXISTS custom_description TEXT,
      ADD COLUMN IF NOT EXISTS custom_keywords TEXT[],
      ADD COLUMN IF NOT EXISTS override_master BOOLEAN DEFAULT FALSE
    `);
    
    console.log('✅ Successfully added override columns');
    
    // Add an index for better performance
    await db.query(`
      CREATE INDEX IF NOT EXISTS idx_country_products_master_product 
      ON country_products(product_id, country_code)
    `);
    
    console.log('✅ Added performance index');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    process.exit();
  }
})();
