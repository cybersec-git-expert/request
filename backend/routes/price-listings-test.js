const express = require('express');
const router = express.Router();

// Simple test route
router.get('/test', (req, res) => {
  res.json({ success: true, message: 'Price listings route is working!' });
});

// GET /api/price-listings/search - Search products for price comparison
router.get('/search', async (req, res) => {
  try {
    const { q: query, country = 'LK', limit = 10 } = req.query;

    if (!query || query.trim().length < 2) {
      return res.json({
        success: true,
        data: [],
        message: 'Query too short'
      });
    }

    // For now, return empty results until we fix any issues
    res.json({
      success: true,
      data: [],
      message: 'Search endpoint working - returning empty results for now'
    });

  } catch (error) {
    console.error('Error searching products:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error searching products', 
      error: error.message 
    });
  }
});

module.exports = router;
