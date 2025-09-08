const { Pool } = require('pg');

const pool = new Pool({
  host: 'requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com',
  port: 5432,
  database: 'request',
  user: 'requestadmindb',
  password: 'RequestMarketplace2024!',
  ssl: {
    rejectUnauthorized: false
  }
});

async function createPriceListingsTable() {
  try {
    console.log('🔄 Creating price_listings table...');
    
    const createTableSQL = `
      -- Create price_listings table for business pricing
      CREATE TABLE IF NOT EXISTS price_listings (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          business_id UUID NOT NULL, -- references users.id (business owner)
          master_product_id UUID NOT NULL REFERENCES master_products(id) ON DELETE CASCADE,
          category_id UUID REFERENCES categories(id),
          subcategory_id UUID REFERENCES sub_categories(id),
          title VARCHAR(500) NOT NULL,
          description TEXT,
          price DECIMAL(10, 2) NOT NULL,
          currency VARCHAR(3) DEFAULT 'LKR',
          unit VARCHAR(100),
          delivery_charge DECIMAL(10, 2) DEFAULT 0,
          images JSONB DEFAULT '[]',
          website VARCHAR(255),
          whatsapp VARCHAR(20),
          city_id UUID REFERENCES cities(id),
          country_code VARCHAR(3) DEFAULT 'LK',
          is_active BOOLEAN DEFAULT TRUE,
          view_count INTEGER DEFAULT 0,
          contact_count INTEGER DEFAULT 0,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
          
          -- Ensure business can only have one listing per product
          UNIQUE(business_id, master_product_id)
      );
      
      -- Create indexes for better performance
      CREATE INDEX IF NOT EXISTS idx_price_listings_business ON price_listings(business_id);
      CREATE INDEX IF NOT EXISTS idx_price_listings_master_product ON price_listings(master_product_id);
      CREATE INDEX IF NOT EXISTS idx_price_listings_country_active ON price_listings(country_code, is_active);
      CREATE INDEX IF NOT EXISTS idx_price_listings_price ON price_listings(price);
      CREATE INDEX IF NOT EXISTS idx_price_listings_category ON price_listings(category_id);
      CREATE INDEX IF NOT EXISTS idx_price_listings_city ON price_listings(city_id);
      
      -- Create trigger for updated_at
      CREATE OR REPLACE FUNCTION update_price_listings_updated_at()
      RETURNS TRIGGER AS $$
      BEGIN
          NEW.updated_at = NOW();
          RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      DROP TRIGGER IF EXISTS update_price_listings_updated_at ON price_listings;
      CREATE TRIGGER update_price_listings_updated_at
          BEFORE UPDATE ON price_listings
          FOR EACH ROW
          EXECUTE FUNCTION update_price_listings_updated_at();
    `;
    
    await pool.query(createTableSQL);
    
    console.log('✅ Price listings table created successfully!');
    
    // Test the table structure
    console.log('\n🔍 Testing price_listings table structure...');
    const result = await pool.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns 
      WHERE table_name = 'price_listings' 
      ORDER BY ordinal_position;
    `);
    
    console.log('Price listings table columns:');
    result.rows.forEach(row => {
      console.log(`  - ${row.column_name}: ${row.data_type} ${row.is_nullable === 'NO' ? 'NOT NULL' : ''}`);
    });
    
    // Check constraints
    console.log('\n🔍 Checking constraints...');
    const constraintResult = await pool.query(`
      SELECT constraint_name, constraint_type
      FROM information_schema.table_constraints 
      WHERE table_name = 'price_listings';
    `);
    
    console.log('Constraints:');
    constraintResult.rows.forEach(row => {
      console.log(`  - ${row.constraint_name}: ${row.constraint_type}`);
    });
    
  } catch (error) {
    console.error('❌ Error creating price_listings table:', error.message);
    console.error(error);
  } finally {
    await pool.end();
  }
}

createPriceListingsTable();
