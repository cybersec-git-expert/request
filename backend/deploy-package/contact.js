const express = require('express');
const router = express.Router();
const auth = require('../services/auth');
const phone = require('../services/phone-helper');

// GET /api/contact/phone?userId=...&context=personal|business|driver
router.get('/phone', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.query.userId || req.user.id || req.user.userId;
    const context = req.query.context || 'personal';
    if (!userId) return res.status(400).json({ success: false, error: 'userId required' });
    const best = await phone.selectContactPhone(userId, context);
    res.json({ success: true, data: best });
  } catch (e) {
    console.error('contact.phone error', e);
    res.status(500).json({ success: false, error: 'Failed to resolve contact phone' });
  }
});

module.exports = router;
