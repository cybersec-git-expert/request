const database = require('./services/database');

async function checkTableStructure() {
  try {
    console.log('Checking business_types table structure...');
    const result = await database.query(`
      SELECT column_name, data_type, udt_name 
      FROM information_schema.columns 
      WHERE table_name = 'business_types' AND column_name = 'id'
      ORDER BY ordinal_position
    `);
    console.log('business_types.id column:', result.rows);

    console.log('Checking existing business_type_plan_mappings...');
    const existing = await database.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'business_type_plan_mappings'
      )
    `);
    console.log('business_type_plan_mappings exists:', existing.rows[0].exists);

    if (existing.rows[0].exists) {
      const structure = await database.query(`
        SELECT column_name, data_type, udt_name 
        FROM information_schema.columns 
        WHERE table_name = 'business_type_plan_mappings'
        ORDER BY ordinal_position
      `);
      console.log('Current business_type_plan_mappings structure:');
      console.table(structure.rows);
    }

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

checkTableStructure();
