const express = require('express');
const router = express.Router();
const dbService = require('../services/database');
const authService = require('../services/auth');

// Get all country variable types
router.get('/', async (req, res) => {
  try {
    const { country } = req.query;
    console.log('Fetching country variable types...', { country });
        
    let query = `
            SELECT 
                cvt.*
            FROM country_variable_types cvt
        `;
        
    const queryParams = [];
        
    if (country) {
      query += ' WHERE cvt.country_code = $1';
      queryParams.push(country);
    }
        
    query += ' ORDER BY cvt.country_name, cvt.variable_type_name';
        
    const result = await dbService.query(query, queryParams);

    // Add predefined values for common variable types
    const variableTypesWithValues = result.rows.map(row => {
      let possibleValues = [];
      let type = 'select';
      let description = '';

      switch (row.variable_type_name?.toLowerCase()) {
      case 'ram':
        possibleValues = ['4GB', '8GB', '12GB', '16GB', '32GB', '64GB'];
        description = 'Memory capacity';
        break;
      case 'storage_capacity':
        possibleValues = ['64GB', '128GB', '256GB', '512GB', '1TB', '2TB'];
        description = 'Device storage capacity';
        break;
      case 'color':
        possibleValues = ['Black', 'White', 'Silver', 'Gold', 'Blue', 'Red', 'Green', 'Purple', 'Gray'];
        description = 'Product color options';
        break;
      case 'size':
        possibleValues = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
        description = 'Product size';
        break;
      case 'screen_size':
        possibleValues = ['5.5"', '6.1"', '6.4"', '6.7"', '13"', '15"', '17"', '27"', '32"'];
        description = 'Screen or display size';
        break;
      default:
        type = 'text';
        description = `Custom ${row.variable_type_name} value`;
      }

      return {
        id: row.variable_type_id || row.id,
        name: row.variable_type_name,
        type: type,
        required: false,
        possibleValues: possibleValues,
        description: description,
        country_code: row.country_code,
        is_active: row.is_active
      };
    });

    console.log(`Found ${variableTypesWithValues.length} country variable types`);
        
    res.json({
      success: true,
      data: variableTypesWithValues,
      count: variableTypesWithValues.length
    });
  } catch (error) {
    console.error('Error fetching country variable types:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch country variable types'
    });
  }
});

// Get country variable type by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
        
    const result = await dbService.query(`
            SELECT 
                cvt.*
            FROM country_variable_types cvt
            WHERE cvt.id = $1
        `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Country variable type not found'
      });
    }

    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error fetching country variable type:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch country variable type'
    });
  }
});

// Create new country variable type
router.post('/', authService.authMiddleware(), async (req, res) => {
  try {
    const { variable_id, country_code, is_active, custom_settings } = req.body;

    const result = await dbService.query(`
            INSERT INTO country_variable_types (variable_id, country_code, is_active, custom_settings)
            VALUES ($1, $2, $3, $4)
            RETURNING *
        `, [variable_id, country_code, is_active || true, custom_settings || {}]);

    res.status(201).json({
      success: true,
      message: 'Country variable type created successfully',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error creating country variable type:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create country variable type'
    });
  }
});

// Update country variable type
router.put('/:id', authService.authMiddleware(), async (req, res) => {
  try {
    const { id } = req.params;
    const { variable_id, country_code, is_active, custom_settings } = req.body;

    const result = await dbService.query(`
            UPDATE country_variable_types 
            SET variable_id = $1, country_code = $2, is_active = $3, 
                custom_settings = $4, updated_at = CURRENT_TIMESTAMP
            WHERE id = $5
            RETURNING *
        `, [variable_id, country_code, is_active, custom_settings, id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Country variable type not found'
      });
    }

    res.json({
      success: true,
      message: 'Country variable type updated successfully',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error updating country variable type:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update country variable type'
    });
  }
});

// Delete country variable type
router.delete('/:id', authService.authMiddleware(), async (req, res) => {
  try {
    const { id } = req.params;

    const result = await dbService.query(`
            DELETE FROM country_variable_types WHERE id = $1 RETURNING *
        `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Country variable type not found'
      });
    }

    res.json({
      success: true,
      message: 'Country variable type deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting country variable type:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete country variable type'
    });
  }
});

module.exports = router;
