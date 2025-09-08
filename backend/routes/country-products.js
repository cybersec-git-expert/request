const express = require('express');
const router = express.Router();
const database = require('../services/database');
const auth = require('../services/auth');

// Get all products for a country (similar to vehicle-types pattern)
router.get('/', async (req, res) => {
  try {
    const countryCode = (req.query.country || 'LK').toUpperCase();
    const includeInactive = req.query.includeInactive === 'true';

    const result = await database.query(`
      SELECT 
        mp.id,
        mp.name,
        mp.slug,
        mp.brand_id,
        mp.base_unit,
        mp.is_active,
        mp.created_at,
        mp.updated_at,
        cp.is_active AS country_specific_active,
        COALESCE(cp.is_active, mp.is_active) AS country_enabled,
        cp.id AS country_product_id
      FROM master_products mp
      LEFT JOIN country_products cp 
        ON mp.id = cp.product_id 
       AND cp.country_code = $1
      WHERE ($2 OR mp.is_active = true)
      ORDER BY mp.name
    `, [countryCode, includeInactive]);

    // Adapt to frontend expected camelCase keys
    const data = result.rows.map(r => ({
      id: r.id,
      name: r.name,
      description: r.description,
      imageUrl: r.image_url,
      isActive: r.is_active,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
      countryEnabled: r.country_enabled,
      countrySpecificActive: r.country_specific_active,
      countryProductId: r.country_product_id
    }));

    res.json({ success: true, data });
  } catch (error) {
    console.error('Error fetching products:', error);
    res.status(500).json({ success: false, message: 'Error fetching products', error: error.message });
  }
});

// Toggle product status for a specific country (country admin only)
router.post('/:id/toggle-country', auth.authMiddleware(), async (req, res) => {
  try {
    const productId = req.params.id;
    const { isActive } = req.body;
    
    // Get user's country
    const countryCode = (req.user.country_code || req.user.country || 'LK').toUpperCase();
    
    // Check if product exists
    const product = await database.queryOne('SELECT * FROM master_products WHERE id = $1', [productId]);
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found' });
    }
    
    // Upsert country_products record
    const result = await database.query(`
      INSERT INTO country_products (product_id, country_code, is_active)
      VALUES ($1, $2, $3)
      ON CONFLICT (product_id, country_code)
      DO UPDATE SET is_active = EXCLUDED.is_active, updated_at = CURRENT_TIMESTAMP
      RETURNING *
    `, [productId, countryCode, isActive]);
    
    res.json({ 
      success: true, 
      message: `Product ${isActive ? 'enabled' : 'disabled'} for ${countryCode}`,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error toggling product for country:', error);
    res.status(500).json({ success: false, message: 'Error updating product status', error: error.message });
  }
});

// Create new country product
router.post('/', auth.authMiddleware(), async (req, res) => {
  try {
    // Handle both frontend camelCase and backend snake_case field names
    const { 
      master_product_id, 
      productId, 
      country_code, 
      country,
      is_active, 
      isActive, 
      custom_data,
      productName,
      countryName
    } = req.body;

    // Use the provided field or fall back to alternative naming
    const productIdValue = master_product_id || productId;
    const countryCodeValue = country_code || country;
    const isActiveValue = is_active !== undefined ? is_active : (isActive !== undefined ? isActive : true);

    const result = await database.query(`
            INSERT INTO country_products (product_id, country_code, is_active)
            VALUES ($1, $2, $3)
            RETURNING *
        `, [productIdValue, countryCodeValue, isActiveValue]);

    res.status(201).json({
      success: true,
      message: 'Country product created successfully',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error creating country product:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create country product'
    });
  }
});

// Update country product
router.put('/:id', auth.authMiddleware(), async (req, res) => {
  try {
    const { id } = req.params;
    // Handle both frontend camelCase and backend snake_case field names
    const { 
      master_product_id, 
      productId, 
      country_code, 
      country,
      is_active, 
      isActive, 
      custom_data,
      productName,
      countryName
    } = req.body;

    // Use the provided field or fall back to alternative naming
    const productIdValue = master_product_id || productId;
    const countryCodeValue = country_code || country;
    const isActiveValue = is_active !== undefined ? is_active : isActive;

    const result = await database.query(`
            UPDATE country_products 
            SET product_id = $1, country_code = $2, is_active = $3, 
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $4
            RETURNING *
        `, [productIdValue, countryCodeValue, isActiveValue, id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Country product not found'
      });
    }

    res.json({
      success: true,
      message: 'Country product updated successfully',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error updating country product:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update country product'
    });
  }
});

// Delete country product
router.delete('/:id', auth.authMiddleware(), async (req, res) => {
  try {
    const { id } = req.params;

    const result = await database.query(`
            DELETE FROM country_products WHERE id = $1 RETURNING *
        `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Country product not found'
      });
    }

    res.json({
      success: true,
      message: 'Country product deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting country product:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete country product'
    });
  }
});

module.exports = router;
