const express = require('express');
const db = require('../services/database');
const auth = require('../services/auth');

const router = express.Router();

// Sync master product changes to country products
router.post('/sync-master-product/:masterProductId', auth.authMiddleware(), auth.requirePermission('productManagement'), async (req, res) => {
  try {
    const { masterProductId } = req.params;
    const { syncFields = ['name', 'category', 'images'] } = req.body;

    // Get the updated master product
    const masterProduct = await db.findById('master_products', masterProductId);
    if (!masterProduct) {
      return res.status(404).json({ success: false, error: 'Master product not found' });
    }

    // Get all country products that reference this master product
    const countryProducts = await db.findMany('country_products', { product_id: masterProductId });

    const updatePromises = [];
    
    for (const countryProduct of countryProducts) {
      const updates = {};
      
      // Sync name if requested
      if (syncFields.includes('name')) {
        updates.product_name = masterProduct.name;
      }
      
      // Note: We don't sync category/images to country_products table since it doesn't have those columns
      // But we can trigger updates to related tables like price_listings
      
      if (Object.keys(updates).length > 0) {
        // Note: updated_at is automatically handled by DatabaseService.update()
        updatePromises.push(
          db.update('country_products', countryProduct.id, updates)
        );
      }
    }

    // Update price listings that reference this master product
    if (syncFields.includes('category') || syncFields.includes('images')) {
      const priceListingUpdates = {};
      
      if (syncFields.includes('category')) {
        priceListingUpdates.category_id = masterProduct.category_id;
        priceListingUpdates.subcategory_id = masterProduct.subcategory_id;
      }
      
      // For images, we'll create a trigger or handle separately since price_listings.images is JSONB
      // and might contain business-specific images mixed with master product images
      
      if (Object.keys(priceListingUpdates).length > 0) {
        updatePromises.push(
          db.query(`
            UPDATE price_listings 
            SET category_id = COALESCE($2, category_id),
                subcategory_id = COALESCE($3, subcategory_id),
                updated_at = NOW()
            WHERE master_product_id = $1
          `, [masterProductId, priceListingUpdates.category_id, priceListingUpdates.subcategory_id])
        );
      }
    }

    await Promise.all(updatePromises);

    res.json({
      success: true,
      message: `Synced master product changes to ${countryProducts.length} country products`,
      synced: {
        countryProducts: countryProducts.length,
        fields: syncFields
      }
    });

  } catch (error) {
    console.error('Error syncing master product:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get country-specific product variations
router.get('/country-variations/:masterProductId', auth.authMiddleware(), async (req, res) => {
  try {
    const { masterProductId } = req.params;
    
    const variations = await db.query(`
      SELECT 
        cp.*,
        mp.name as master_name,
        mp.images as master_images,
        mp.category_id as master_category_id,
        mp.subcategory_id as master_subcategory_id
      FROM country_products cp
      JOIN master_products mp ON cp.product_id = mp.id
      WHERE cp.product_id = $1
      ORDER BY cp.country_code
    `, [masterProductId]);

    res.json({
      success: true,
      data: variations.rows
    });

  } catch (error) {
    console.error('Error fetching country variations:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Add country-specific overrides
router.post('/country-override', auth.authMiddleware(), auth.requirePermission('productManagement'), async (req, res) => {
  try {
    const {
      masterProductId,
      countryCode,
      customImages,
      customCategoryId,
      customSubcategoryId,
      isActive = true
    } = req.body;

    // Check if master product exists
    const masterProduct = await db.findById('master_products', masterProductId);
    if (!masterProduct) {
      return res.status(404).json({ success: false, error: 'Master product not found' });
    }

    // Create or update country-specific override
    // Note: This would require extending the country_products table with override fields
    const result = await db.query(`
      INSERT INTO country_products (
        product_id, 
        country_code, 
        product_name,
        is_active
      ) VALUES ($1, $2, $3, $4)
      ON CONFLICT (product_id, country_code)
      DO UPDATE SET 
        product_name = EXCLUDED.product_name,
        is_active = EXCLUDED.is_active,
        updated_at = NOW()
      RETURNING *
    `, [masterProductId, countryCode, masterProduct.name, isActive]);

    res.json({
      success: true,
      message: 'Country override created/updated',
      data: result.rows[0]
    });

  } catch (error) {
    console.error('Error creating country override:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
