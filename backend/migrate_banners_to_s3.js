const { Pool } = require('pg');

// Database configuration
const pool = new Pool({
  host: process.env.DB_HOST || 'requestdb.cq70gkkamvcs.us-east-1.rds.amazonaws.com',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'request',
  user: process.env.DB_USERNAME || 'requestadmindb',
  password: process.env.DB_PASSWORD || 'RequestMarketplace2024!',
  ssl: process.env.DB_SSL !== 'false'
});

async function migrateBannerUrlsToS3() {
  try {
    console.log('🔄 Starting banner URL migration to S3...');
    
    // Get all banners with local storage URLs
    const result = await pool.query(`
      SELECT id, image_url, title 
      FROM banners 
      WHERE image_url LIKE '%/uploads/images/%'
      OR image_url LIKE '%ec2-54-144-9-226%'
      OR image_url LIKE '%localhost%'
    `);
    
    console.log(`📋 Found ${result.rows.length} banners to migrate`);
    
    for (const banner of result.rows) {
      const oldUrl = banner.image_url;
      
      // Extract filename from the old URL
      const filename = oldUrl.split('/').pop();
      
      // Create new S3 URL
      const newS3Url = `https://requestappbucket.s3.amazonaws.com/banners/${filename}`;
      
      // Update the database
      await pool.query(`
        UPDATE banners 
        SET image_url = $1, updated_at = NOW() 
        WHERE id = $2
      `, [newS3Url, banner.id]);
      
      console.log(`✅ Updated banner "${banner.title || banner.id}": ${oldUrl} → ${newS3Url}`);
    }
    
    console.log('🎉 Banner URL migration completed!');
    
    // Show updated banners
    const updatedResult = await pool.query(`
      SELECT id, title, image_url 
      FROM banners 
      WHERE active = true 
      ORDER BY priority DESC 
      LIMIT 5
    `);
    
    console.log('\n📊 Updated banner URLs:');
    updatedResult.rows.forEach(banner => {
      console.log(`- ${banner.title || banner.id}: ${banner.image_url}`);
    });
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
  } finally {
    await pool.end();
  }
}

migrateBannerUrlsToS3();
