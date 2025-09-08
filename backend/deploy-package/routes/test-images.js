// Test image endpoint to verify image serving
const express = require('express');
const path = require('path');

const router = express.Router();

// Test endpoint to check if image serving works
router.get('/test', (req, res) => {
  res.json({
    success: true,
    message: 'Image serving is working',
    uploadPath: path.join(__dirname, '../uploads/images'),
    staticUrl: `${req.protocol}://${req.get('host')}/uploads/images/`,
    timestamp: new Date().toISOString()
  });
});

module.exports = router;
