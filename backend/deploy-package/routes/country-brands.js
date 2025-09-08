const express = require('express');
const router = express.Router();
const dbService = require('../services/database');
const authService = require('../services/auth');

// Get all country brands
router.get('/', async (req, res) => {
  try {
    const { country } = req.query;
    console.log('Fetching country brands...', { country });
        
    let query = `
            SELECT 
                cb.*,
                b.name as brand_name,
                b.slug as brand_slug,
                co.name as country_name
            FROM country_brands cb
            LEFT JOIN brands b ON cb.brand_id = b.id
            LEFT JOIN countries co ON cb.country_code = co.code
        `;
        
    const queryParams = [];
        
    if (country) {
      query += ' WHERE cb.country_code = $1';
      queryParams.push(country);
    }
        
    query += ' ORDER BY co.name, b.name';
        
    const result = await dbService.query(query, queryParams);

    console.log(`Found ${result.rows.length} country brands`);
        
    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length
    });
  } catch (error) {
    console.error('Error fetching country brands:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch country brands'
    });
  }
});

// Get country brand by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
        
    const result = await dbService.query(`
            SELECT 
                cb.*,
                b.name as brand_name,
                b.slug as brand_slug,
                co.name as country_name
            FROM country_brands cb
            LEFT JOIN brands b ON cb.brand_id = b.id
            LEFT JOIN countries co ON cb.country_code = co.code
            WHERE cb.id = $1
        `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Country brand not found'
      });
    }

    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error fetching country brand:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch country brand'
    });
  }
});

// Create new country brand
router.post('/', authService.authMiddleware(), async (req, res) => {
  try {
    // Handle both frontend camelCase and backend snake_case field names
    const { 
      brand_id, 
      brandId, 
      country_code, 
      country,
      is_active, 
      isActive, 
      custom_settings,
      brandName,
      countryName
    } = req.body;

    // Use the provided field or fall back to alternative naming
    const brandIdValue = brand_id || brandId;
    const countryCodeValue = country_code || country;
    const isActiveValue = is_active !== undefined ? is_active : (isActive !== undefined ? isActive : true);

    const result = await dbService.query(`
            INSERT INTO country_brands (brand_id, country_code, is_active)
            VALUES ($1, $2, $3)
            RETURNING *
        `, [brandIdValue, countryCodeValue, isActiveValue]);

    res.status(201).json({
      success: true,
      message: 'Country brand created successfully',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error creating country brand:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create country brand'
    });
  }
});

// Update country brand
router.put('/:id', authService.authMiddleware(), async (req, res) => {
  try {
    const { id } = req.params;
    // Handle both frontend camelCase and backend snake_case field names
    const { 
      brand_id, 
      brandId, 
      country_code, 
      country,
      is_active, 
      isActive, 
      custom_settings,
      brandName,
      countryName
    } = req.body;

    // Use the provided field or fall back to alternative naming
    const brandIdValue = brand_id || brandId;
    const countryCodeValue = country_code || country;
    const isActiveValue = is_active !== undefined ? is_active : isActive;

    const result = await dbService.query(`
            UPDATE country_brands 
            SET brand_id = $1, country_code = $2, is_active = $3, 
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $4
            RETURNING *
        `, [brandIdValue, countryCodeValue, isActiveValue, id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Country brand not found'
      });
    }

    res.json({
      success: true,
      message: 'Country brand updated successfully',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error updating country brand:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update country brand'
    });
  }
});

// Delete country brand
router.delete('/:id', authService.authMiddleware(), async (req, res) => {
  try {
    const { id } = req.params;

    const result = await dbService.query(`
            DELETE FROM country_brands WHERE id = $1 RETURNING *
        `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Country brand not found'
      });
    }

    res.json({
      success: true,
      message: 'Country brand deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting country brand:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete country brand'
    });
  }
});

module.exports = router;
