const express = require('express');
const router = express.Router();
const dbService = require('../services/database');
const authService = require('../services/auth');

// Get all country categories
router.get('/', async (req, res) => {
  try {
    const { country } = req.query;
    console.log('Fetching country categories...', { country });
        
    let query = `
            SELECT 
                cc.*,
                c.name as category_name,
                co.name as country_name
            FROM country_categories cc
            LEFT JOIN categories c ON cc.category_id = c.id
            LEFT JOIN countries co ON cc.country_code = co.code
        `;
        
    const queryParams = [];
        
    if (country) {
      query += ' WHERE cc.country_code = $1';
      queryParams.push(country);
    }
        
    query += ' ORDER BY co.name, c.name';
        
    const result = await dbService.query(query, queryParams);

    console.log(`Found ${result.rows.length} country categories`);
        
    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length
    });
  } catch (error) {
    console.error('Error fetching country categories:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch country categories'
    });
  }
});

// Get country category by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
        
    const result = await dbService.query(`
            SELECT 
                cc.*,
                c.name as category_name,
                co.name as country_name
            FROM country_categories cc
            LEFT JOIN categories c ON cc.category_id = c.id
            LEFT JOIN countries co ON cc.country_code = co.code
            WHERE cc.id = $1
        `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Country category not found'
      });
    }

    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error fetching country category:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch country category'
    });
  }
});

// Create new country category
router.post('/', authService.authMiddleware(), async (req, res) => {
  try {
    // Handle both frontend camelCase and backend snake_case field names
    const { 
      category_id, 
      categoryId, 
      country_code, 
      country,
      is_active, 
      isActive, 
      custom_settings,
      categoryName,
      countryName
    } = req.body;

    // Use the provided field or fall back to alternative naming
    const categoryIdValue = category_id || categoryId;
    const countryCodeValue = country_code || country;
    const isActiveValue = is_active !== undefined ? is_active : (isActive !== undefined ? isActive : true);

    const result = await dbService.query(`
            INSERT INTO country_categories (category_id, country_code, is_active)
            VALUES ($1, $2, $3)
            RETURNING *
        `, [categoryIdValue, countryCodeValue, isActiveValue]);

    res.status(201).json({
      success: true,
      message: 'Country category created successfully',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error creating country category:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create country category'
    });
  }
});

// Update country category
router.put('/:id', authService.authMiddleware(), async (req, res) => {
  try {
    const { id } = req.params;
    // Handle both frontend camelCase and backend snake_case field names
    const { 
      category_id, 
      categoryId, 
      country_code, 
      country,
      is_active, 
      isActive, 
      custom_settings,
      categoryName,
      countryName
    } = req.body;

    // Use the provided field or fall back to alternative naming
    const categoryIdValue = category_id || categoryId;
    const countryCodeValue = country_code || country;
    const isActiveValue = is_active !== undefined ? is_active : isActive;

    const result = await dbService.query(`
            UPDATE country_categories 
            SET category_id = $1, country_code = $2, is_active = $3, 
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $4
            RETURNING *
        `, [categoryIdValue, countryCodeValue, isActiveValue, id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Country category not found'
      });
    }

    res.json({
      success: true,
      message: 'Country category updated successfully',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error updating country category:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update country category'
    });
  }
});

// Delete country category
router.delete('/:id', authService.authMiddleware(), async (req, res) => {
  try {
    const { id } = req.params;

    const result = await dbService.query(`
            DELETE FROM country_categories WHERE id = $1 RETURNING *
        `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Country category not found'
      });
    }

    res.json({
      success: true,
      message: 'Country category deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting country category:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete country category'
    });
  }
});

module.exports = router;
