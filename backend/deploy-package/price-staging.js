const express = require('express');
const priceStagingService = require('../services/price_staging_service');
const authService = require('../services/auth');

const router = express.Router();

// Stage a price update
router.post('/stage', authService.authMiddleware(), async (req, res) => {
  try {
    const { priceListingId, price, stockQuantity, isAvailable, whatsappNumber, productLink, modelNumber, selectedVariables } = req.body;
    const businessId = req.user.businessId || req.user.uid || req.user.id;

    console.log('DEBUG: Staging request - User:', req.user.id, 'BusinessId:', businessId, 'PriceListingId:', priceListingId);

    if (!priceListingId || !price) {
      return res.status(400).json({
        success: false,
        message: 'Price listing ID and price are required'
      });
    }

    if (price <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Price must be greater than 0'
      });
    }

    const stagedData = {
      price: parseFloat(price),
      stockQuantity: stockQuantity ? parseInt(stockQuantity) : undefined,
      isAvailable: isAvailable !== undefined ? Boolean(isAvailable) : undefined,
      whatsappNumber,
      productLink,
      modelNumber,
      selectedVariables
    };

    const result = await priceStagingService.stagePriceUpdate(businessId, priceListingId, stagedData);

    res.json({
      success: true,
      data: result,
      message: result.message
    });

  } catch (error) {
    console.error('Error staging price:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Error staging price update'
    });
  }
});

// Get all staged prices for a business
router.get('/staged', authService.authMiddleware(), async (req, res) => {
  try {
    const businessId = req.user.businessId || req.user.uid;
    const stagedPrices = await priceStagingService.getBusinessStagedPrices(businessId);

    res.json({
      success: true,
      data: stagedPrices,
      count: stagedPrices.length,
      message: `Found ${stagedPrices.length} staged price updates`
    });

  } catch (error) {
    console.error('Error getting staged prices:', error);
    res.status(500).json({
      success: false,
      message: 'Error retrieving staged prices'
    });
  }
});

// Cancel a staged price update
router.delete('/stage/:priceListingId', authService.authMiddleware(), async (req, res) => {
  try {
    const { priceListingId } = req.params;
    const businessId = req.user.businessId || req.user.uid;

    const result = await priceStagingService.cancelStagedPrice(businessId, priceListingId);

    res.json({
      success: true,
      message: result.message
    });

  } catch (error) {
    console.error('Error cancelling staged price:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Error cancelling staged price'
    });
  }
});

// Get business staging summary
router.get('/summary', authService.authMiddleware(), async (req, res) => {
  try {
    const businessId = req.user.businessId || req.user.uid;
    const summary = await priceStagingService.getBusinessStagingSummary(businessId);

    res.json({
      success: true,
      data: {
        ...summary,
        nextUpdateTime: priceStagingService.getNextUpdateTime(),
        timezone: 'Asia/Colombo'
      },
      message: 'Staging summary retrieved successfully'
    });

  } catch (error) {
    console.error('Error getting staging summary:', error);
    res.status(500).json({
      success: false,
      message: 'Error retrieving staging summary'
    });
  }
});

// Get price update history
router.get('/history', authService.authMiddleware(), async (req, res) => {
  try {
    const businessId = req.user.businessId || req.user.uid;
    const limit = parseInt(req.query.limit) || 50;

    const history = await priceStagingService.getPriceHistory(businessId, limit);

    res.json({
      success: true,
      data: history,
      count: history.length,
      message: 'Price history retrieved successfully'
    });

  } catch (error) {
    console.error('Error getting price history:', error);
    res.status(500).json({
      success: false,
      message: 'Error retrieving price history'
    });
  }
});

// Manual trigger for price application (admin only)
router.post('/apply-now', authService.authMiddleware(), async (req, res) => {
  try {
    // Check if user is admin (you might want to add admin verification here)
    const isAdmin = req.user.role === 'admin' || req.user.isAdmin;
    
    if (!isAdmin) {
      return res.status(403).json({
        success: false,
        message: 'Admin access required'
      });
    }

    const result = await priceStagingService.triggerManualUpdate();

    res.json({
      success: true,
      data: result,
      message: `Manual price update completed. ${result.updatedCount} prices applied.`
    });

  } catch (error) {
    console.error('Error applying staged prices manually:', error);
    res.status(500).json({
      success: false,
      message: 'Error applying staged prices'
    });
  }
});

// Get next scheduled update time
router.get('/next-update', async (req, res) => {
  try {
    const nextUpdate = priceStagingService.getNextUpdateTime();
    
    res.json({
      success: true,
      data: {
        nextUpdateTime: nextUpdate,
        timezone: 'Asia/Colombo',
        updateSchedule: 'Daily at 1:00 AM Sri Lanka Time'
      },
      message: 'Next update time retrieved successfully'
    });

  } catch (error) {
    console.error('Error getting next update time:', error);
    res.status(500).json({
      success: false,
      message: 'Error retrieving next update time'
    });
  }
});

module.exports = router;
