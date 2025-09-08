const express = require('express');
const router = express.Router();
const auth = require('../services/auth');
const database = require('../services/database');
const BusinessNotificationService = require('../services/business-notification-service');

// Get business types and available categories for selection
router.get('/business-types', async (req, res) => {
  try {
    const businessTypes = [
      { value: 'product_selling', label: 'Product Selling', description: 'Sell physical products to customers' },
      { value: 'delivery_service', label: 'Delivery Service', description: 'Provide delivery and logistics services' },
      { value: 'both', label: 'Both', description: 'Both product selling and delivery services' }
    ];

    // Get available categories from the categories table
    const categoriesQuery = `
      SELECT id, name, description, icon
      FROM categories 
      WHERE is_active = true 
      ORDER BY display_order, name
    `;
    
    const categoriesResult = await database.query(categoriesQuery);

    res.json({
      success: true,
      data: {
        businessTypes,
        categories: categoriesResult.rows
      }
    });
  } catch (error) {
    console.error('Error fetching business types and categories:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching business configuration',
      error: error.message
    });
  }
});

// Get business access rights for current user
router.get('/access-rights', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    const accessRights = await BusinessNotificationService.getBusinessAccessRights(userId);

    res.json({
      success: true,
      data: accessRights
    });
  } catch (error) {
    console.error('Error fetching business access rights:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching access rights',
      error: error.message
    });
  }
});

// Update business categories
router.put('/categories', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    const { categories } = req.body;

    if (!Array.isArray(categories)) {
      return res.status(400).json({
        success: false,
        message: 'Categories must be an array'
      });
    }

    // Validate that all category IDs exist
    if (categories.length > 0) {
      const validationQuery = `
        SELECT id FROM categories 
        WHERE id = ANY($1) AND is_active = true
      `;
      
      const validationResult = await database.query(validationQuery, [categories]);
      
      if (validationResult.rows.length !== categories.length) {
        return res.status(400).json({
          success: false,
          message: 'One or more invalid category IDs provided'
        });
      }
    }

    const result = await BusinessNotificationService.updateBusinessCategories(userId, categories);

    res.json({
      success: true,
      message: 'Business categories updated successfully',
      data: { categories: result.categories }
    });
  } catch (error) {
    console.error('Error updating business categories:', error);
    res.status(500).json({
      success: false,
      message: 'Error updating categories',
      error: error.message
    });
  }
});

// Check if business can respond to a specific request
router.get('/can-respond/:requestId', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    const { requestId } = req.params;

    // Get request details
    const requestQuery = `
      SELECT request_type, category_id, subcategory_id
      FROM requests 
      WHERE id = $1
    `;
    
    const requestResult = await database.query(requestQuery, [requestId]);
    
    if (requestResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Request not found'
      });
    }

    const request = requestResult.rows[0];
    const canRespond = await BusinessNotificationService.canBusinessRespondToRequest(
      userId, 
      request.request_type, 
      request.category_id
    );

    res.json({
      success: true,
      data: {
        canRespond: canRespond.canRespond,
        reason: canRespond.reason,
        requestType: request.request_type,
        categoryId: request.category_id
      }
    });
  } catch (error) {
    console.error('Error checking response eligibility:', error);
    res.status(500).json({
      success: false,
      message: 'Error checking response eligibility',
      error: error.message
    });
  }
});

// Get businesses to notify for a request (admin only)
router.get('/notify/:requestId', auth.authMiddleware(), async (req, res) => {
  try {
    // Check if user is admin
    if (req.user.role !== 'admin' && req.user.role !== 'super_admin') {
      return res.status(403).json({
        success: false,
        message: 'Admin access required'
      });
    }

    const { requestId } = req.params;

    // Get request details
    const requestQuery = `
      SELECT request_type, category_id, subcategory_id, country_code
      FROM requests 
      WHERE id = $1
    `;
    
    const requestResult = await database.query(requestQuery, [requestId]);
    
    if (requestResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Request not found'
      });
    }

    const request = requestResult.rows[0];
    const businesses = await BusinessNotificationService.getBusinessesToNotify(
      requestId,
      request.category_id,
      request.subcategory_id,
      request.request_type,
      request.country_code
    );

    res.json({
      success: true,
      data: {
        requestId,
        requestType: request.request_type,
        categoryId: request.category_id,
        subcategoryId: request.subcategory_id,
        countryCode: request.country_code,
        businesses,
        notificationCount: businesses.length
      }
    });
  } catch (error) {
    console.error('Error finding businesses to notify:', error);
    res.status(500).json({
      success: false,
      message: 'Error finding businesses to notify',
      error: error.message
    });
  }
});

module.exports = router;
