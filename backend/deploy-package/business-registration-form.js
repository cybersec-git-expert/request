const express = require('express');
const router = express.Router();
const database = require('../services/database');

// Helper: does country_business_types exist?
async function hasCountryBusinessTypesTable() {
  try {
    const r = await database.query(`
      SELECT 1 FROM information_schema.tables
      WHERE table_schema='public' AND table_name='country_business_types'
    `);
    return r.rows.length > 0;
  } catch {
    return false;
  }
}

// Get business registration form data
router.get('/form-data', async (req, res) => {
  try {
    const { country_code = 'LK' } = req.query;

    // 1) Business types (country-aware; fallback to legacy if needed)
    let businessTypesRows = [];
    if (await hasCountryBusinessTypesTable()) {
      const q = `
    SELECT id, name, description, icon, display_order, global_business_type_id
        FROM country_business_types
        WHERE country_code = $1 AND is_active = true
        ORDER BY display_order, name
      `;
      const r = await database.query(q, [country_code]);
      businessTypesRows = r.rows;
    } else {
      // Legacy: per-country rows in business_types
      const q = `
    SELECT id, name, description, icon, display_order, id as global_business_type_id
        FROM business_types
        WHERE country_code = $1 AND is_active = true
        ORDER BY display_order, name
      `;
      const r = await database.query(q, [country_code]);
      businessTypesRows = r.rows;
    }

    // 2) Only item-type subcategories available for this country via country_subcategories
    const itemCountrySubsQ = `
      SELECT 
        cs.id                       AS country_subcategory_id,
        sc.id                       AS subcategory_id,
        sc.name                     AS subcategory_name,
        sc.slug,
        sc.category_id,
        c.name                      AS category_name,
        c.type                      AS category_type
      FROM country_subcategories cs
      JOIN sub_categories sc ON cs.subcategory_id = sc.id AND sc.is_active = true
      JOIN categories c ON sc.category_id = c.id AND c.is_active = true
      WHERE cs.country_code = $1 AND cs.is_active = true AND c.type = 'item'
      ORDER BY c.name, sc.name
    `;
    const itemSubs = await database.query(itemCountrySubsQ, [country_code]);

    // Group by category for convenient UI rendering
    const byCategoryMap = new Map();
    for (const row of itemSubs.rows) {
      if (!byCategoryMap.has(row.category_id)) {
        byCategoryMap.set(row.category_id, {
          category_id: row.category_id,
          category_name: row.category_name,
          subcategories: []
        });
      }
      byCategoryMap.get(row.category_id).subcategories.push({
        country_subcategory_id: row.country_subcategory_id,
        id: row.subcategory_id,
        name: row.subcategory_name,
        slug: row.slug
      });
    }
    const itemSubcategoriesByCategory = Array.from(byCategoryMap.values());

    res.json({
      success: true,
      data: {
        businessTypes: businessTypesRows,
        // New: item-only subcategories available in this country (for multi-select)
        itemSubcategories: itemSubs.rows,
        itemSubcategoriesByCategory
      }
    });
  } catch (error) {
    console.error('Error fetching business registration form data:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching form data',
      error: error.message
    });
  }
});

// Get categories hierarchy for multi-select
router.get('/categories-hierarchy', async (req, res) => {
  try {
    const { country_code = 'LK' } = req.query;

    const query = `
      SELECT 
        c.id as category_id,
        c.name as category_name,
        c.type as category_type,
        sc.id as subcategory_id,
        sc.name as subcategory_name
      FROM categories c
      LEFT JOIN sub_categories sc ON c.id = sc.category_id AND sc.is_active = true
      WHERE c.is_active = true
      ORDER BY c.name, sc.name
    `;

    const result = await database.query(query, []);

    // Build hierarchy
    const hierarchy = {};
    
    result.rows.forEach(row => {
      if (!hierarchy[row.category_id]) {
        hierarchy[row.category_id] = {
          id: row.category_id,
          name: row.category_name,
          type: row.category_type,
          subcategories: []
        };
      }

      if (row.subcategory_id) {
        hierarchy[row.category_id].subcategories.push({
          id: row.subcategory_id,
          name: row.subcategory_name
        });
      }
    });

    const categoriesArray = Object.values(hierarchy).sort((a, b) => a.name.localeCompare(b.name));

    res.json({
      success: true,
      data: categoriesArray
    });
  } catch (error) {
    console.error('Error fetching categories hierarchy:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching categories',
      error: error.message
    });
  }
});

// Get business type details by ID
router.get('/business-type/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const query = `
      SELECT id, name, description, icon, country_code
      FROM business_types 
      WHERE id = $1 AND is_active = true
    `;

    const result = await database.queryOne(query, [id]);

    if (!result) {
      return res.status(404).json({
        success: false,
        message: 'Business type not found'
      });
    }

    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    console.error('Error fetching business type:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching business type',
      error: error.message
    });
  }
});

module.exports = router;
