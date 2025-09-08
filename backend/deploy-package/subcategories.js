const express = require('express');
const router = express.Router();
const dbService = require('../services/database');

// Get all subcategories
router.get('/', async (req, res) => {
  try {
    const { includeInactive = 'false' } = req.query;
    const whereActive = includeInactive === 'true' ? '' : 'WHERE sc.is_active = true';
    const result = await dbService.query(`
            SELECT sc.*, c.name as category_name
            FROM sub_categories sc
            LEFT JOIN categories c ON sc.category_id = c.id
            ${whereActive}
            ORDER BY c.name, sc.name
        `);
    const enriched = result.rows.map(r => ({
      ...r,
      description: r.metadata?.description || r.description || null
    }));
    res.json({ success: true, data: enriched, count: enriched.length });
  } catch (error) {
    console.error('Error fetching subcategories:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch subcategories' });
  }
});

// Get subcategories by category ID
router.get('/category/:categoryId', async (req, res) => {
  try {
    const { categoryId } = req.params;
        
    const result = await dbService.query(`
            SELECT * FROM sub_categories 
            WHERE category_id = $1 AND is_active = true
            ORDER BY name
        `, [categoryId]);

    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length
    });
  } catch (error) {
    console.error('Error fetching subcategories by category:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch subcategories'
    });
  }
});

// Create new subcategory (Super Admin only)
router.post('/', async (req, res) => {
  try {
    const { category_id, name, slug, metadata, description } = req.body;
    const user = req.user || { role: 'super_admin' };
    if (user.role !== 'super_admin') return res.status(403).json({ success: false, error: 'Only super admins can create subcategories' });
    if (!category_id || !name) return res.status(400).json({ success: false, error: 'category_id and name required' });
    const meta = metadata || (description ? { description } : null);
    const ins = await dbService.query(`
            INSERT INTO sub_categories (category_id, name, slug, metadata, is_active, created_at, updated_at)
            VALUES ($1,$2,$3,$4,true,NOW(),NOW()) RETURNING *
        `, [category_id, name, slug || name.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/(^-|-$)/g,''), meta]);
    const row = ins.rows[0];
    res.status(201).json({ success: true, data: { ...row, description: row.metadata?.description || null }, message: 'Subcategory created successfully' });
  } catch (error) {
    console.error('Error creating subcategory:', error);
    res.status(500).json({ success: false, error: 'Failed to create subcategory' });
  }
});

// Update subcategory (Super Admin only)
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { category_id, name, slug, metadata, description, is_active } = req.body;
    const user = req.user || { role: 'super_admin' };
    if (user.role !== 'super_admin') return res.status(403).json({ success: false, error: 'Only super admins can update subcategories' });

    const existing = await dbService.findById('sub_categories', id);
    if (!existing) return res.status(404).json({ success: false, error: 'Subcategory not found' });

    const update = {};
    if (category_id !== undefined) update.category_id = category_id;
    if (name !== undefined) update.name = name;
    if (slug !== undefined) update.slug = slug;
    // Merge description into metadata
    if (description !== undefined || metadata !== undefined) {
      const metaBase = existing.metadata && typeof existing.metadata === 'object' ? { ...existing.metadata } : {};
      if (description !== undefined) {
        if (description === null || description === '') delete metaBase.description; else metaBase.description = description;
      }
      if (metadata && typeof metadata === 'object') Object.assign(metaBase, metadata);
      update.metadata = Object.keys(metaBase).length ? metaBase : null;
    }
    if (is_active !== undefined) update.is_active = is_active;
    if (name && slug === undefined) {
      update.slug = name.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/(^-|-$)/g,'');
    }
    if (!Object.keys(update).length) return res.json({ success: true, message: 'No changes applied', data: { ...existing, description: existing.metadata?.description || null } });
    const result = await dbService.update('sub_categories', id, update);
    res.json({ success: true, data: { ...result, description: result.metadata?.description || null }, message: 'Subcategory updated successfully' });
  } catch (error) {
    console.error('Error updating subcategory:', error);
    res.status(500).json({ success: false, error: 'Failed to update subcategory' });
  }
});

// Delete subcategory (Super Admin only)
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const user = req.user || { role: 'super_admin' }; // Default for testing
        
    // Check if user is super admin
    if (user.role !== 'super_admin') {
      return res.status(403).json({
        success: false,
        error: 'Only super admins can delete subcategories'
      });
    }

    // Soft delete by setting is_active to false
    const result = await dbService.query(`
            UPDATE sub_categories 
            SET is_active = false, updated_at = NOW()
            WHERE id = $1
            RETURNING *
        `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Subcategory not found'
      });
    }

    res.json({
      success: true,
      message: 'Subcategory deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting subcategory:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete subcategory'
    });
  }
});

module.exports = router;
