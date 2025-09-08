const express = require('express');
const router = express.Router();

// Minimal stub to satisfy require in server.js during hotfix
router.get('/', (req, res) => {
  res.json({ success: true, message: 'Promo codes API (stub)', timestamp: new Date().toISOString() });
});

module.exports = router;
