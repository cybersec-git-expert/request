const express = require('express');
const router = express.Router();
const database = require('../services/database');
const auth = require('../services/auth');

// Adapter to provide camelCase fields for frontend consistency
function adaptCity(row){
  if(!row) return row;
  return {
    ...row,
    countryCode: row.country_code,
    isActive: row.is_active,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

// Get all (or by country) cities
router.get('/', async (req, res) => {
  try {
    const countryParam = req.query.country;
    const all = req.query.all === '1' || req.query.all === 'true';
    let result;
    if (all || !countryParam) {
      // If no country specified, keep previous behavior defaulting to LK unless all=1 explicitly requested
      if (all) {
        result = await database.query('SELECT * FROM cities ORDER BY name');
      } else {
        result = await database.query('SELECT * FROM cities WHERE country_code = $1 ORDER BY name',[ (countryParam || 'LK').toUpperCase() ]);
      }
    } else {
      result = await database.query('SELECT * FROM cities WHERE country_code = $1 ORDER BY name',[ countryParam.toUpperCase() ]);
    }
    res.json({ success:true, data: result.rows.map(adaptCity) });
  } catch (error) {
    console.error('Error fetching cities:', error);
    res.status(500).json({ success:false, message:'Error fetching cities', error: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error' });
  }
});

// Get city by ID
router.get('/:id', async (req, res) => {
  try {
    const cityId = req.params.id;
    
    const city = await database.queryOne(
      'SELECT * FROM cities WHERE id = $1',
      [cityId]
    );

    if (!city) {
      return res.status(404).json({
        success: false,
        message: 'City not found'
      });
    }

    res.json({ success:true, data: adaptCity(city) });
  } catch (error) {
    console.error('Error fetching city:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching city',
      error: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
    });
  }
});

// Admin routes (require authentication and admin role)

// Create new city (admin only)
router.post('/', auth.authMiddleware(), async (req, res) => {
  try {
    const { name, country_code, countryCode, is_active = true } = req.body;
    const cc = (country_code || countryCode || '').toUpperCase();
    if (!name || !cc) {
      return res.status(400).json({ success:false, message:'Name and countryCode are required' });
    }
    const city = await database.queryOne(
      `INSERT INTO cities (name, country_code, is_active, created_at, updated_at)
       VALUES ($1,$2,$3,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)
       RETURNING *`,
      [name, cc, is_active]
    );
    res.status(201).json({ success:true, message:'City created successfully', data: adaptCity(city) });
  } catch (error) {
    console.error('Error creating city:', error);
    
    if (error.code === '23505') { // Unique constraint violation
      return res.status(409).json({
        success: false,
        message: 'City with this name already exists in this country'
      });
    }

    res.status(500).json({
      success: false,
      message: 'Error creating city',
      error: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
    });
  }
});

// Update city (admin only)
router.put('/:id', auth.authMiddleware(), async (req, res) => {
  try {
    const cityId = req.params.id;
    const { name, country_code, countryCode, is_active } = req.body;
    const cc = country_code || countryCode;

    // Build dynamic update query
    const updates = [];
    const values = [];
    let paramCounter = 1;

    if (name !== undefined) {
      updates.push(`name = $${paramCounter++}`);
      values.push(name);
    }
    if (cc !== undefined) {
      updates.push(`country_code = $${paramCounter++}`);
      values.push((cc || '').toUpperCase());
    }
    if (is_active !== undefined) {
      updates.push(`is_active = $${paramCounter++}`);
      values.push(is_active);
    }

    if (updates.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No valid fields to update'
      });
    }

    updates.push('updated_at = CURRENT_TIMESTAMP');
    values.push(cityId);

    const query = `
      UPDATE cities 
      SET ${updates.join(', ')}
      WHERE id = $${paramCounter}
      RETURNING *
    `;

    const city = await database.queryOne(query, values);

    if (!city) {
      return res.status(404).json({
        success: false,
        message: 'City not found'
      });
    }

    res.json({ success:true, message:'City updated successfully', data: adaptCity(city) });
  } catch (error) {
    console.error('Error updating city:', error);
    
    if (error.code === '23505') { // Unique constraint violation
      return res.status(409).json({
        success: false,
        message: 'City with this name already exists in this country'
      });
    }

    res.status(500).json({
      success: false,
      message: 'Error updating city',
      error: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
    });
  }
});

// Delete city (admin only)
router.delete('/:id', auth.authMiddleware(), async (req, res) => {
  try {
    const cityId = req.params.id;

    const city = await database.queryOne(
      'DELETE FROM cities WHERE id = $1 RETURNING *',
      [cityId]
    );

    if (!city) {
      return res.status(404).json({
        success: false,
        message: 'City not found'
      });
    }

    res.json({ success:true, message:'City deleted successfully', data: adaptCity(city) });
  } catch (error) {
    console.error('Error deleting city:', error);
    
    if (error.code === '23503') { // Foreign key constraint violation
      return res.status(409).json({
        success: false,
        message: 'Cannot delete city: it is referenced by other records'
      });
    }

    res.status(500).json({
      success: false,
      message: 'Error deleting city',
      error: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
    });
  }
});

// Public endpoint for cities by country (no authentication required)
router.get('/public/:countryCode', async (req, res) => {
  try {
    const countryCode = req.params.countryCode.toUpperCase();
    
    console.log(`🌍 Public cities endpoint called for country: ${countryCode}`);
    
    const result = await database.query(
      'SELECT * FROM cities WHERE country_code = $1 AND is_active = true ORDER BY name',
      [countryCode]
    );
    
    const cities = result.rows.map(adaptCity);
    console.log(`📍 Found ${cities.length} active cities for ${countryCode}:`, cities.map(c => c.name).join(', '));
    
    res.json({ 
      success: true, 
      data: cities,
      count: cities.length,
      countryCode: countryCode
    });
  } catch (error) {
    console.error('Error fetching public cities:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching cities', 
      error: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error' 
    });
  }
});

module.exports = router;
