const express = require('express');
const router = express.Router();
const auth = require('../services/auth');
const notif = require('../services/notification-helper');

// List current user's notifications
router.get('/', auth.authMiddleware(), async (req, res) => {
  try {
    let userId = req.user && (req.user.id || req.user.userId);
    if (!userId && req.headers.authorization && req.headers.authorization.startsWith('Bearer ')) {
      try {
        const decoded = auth.verifyToken(req.headers.authorization.substring(7));
        userId = decoded.userId || decoded.id;
      } catch (_) {}
    }
    if (!userId) return res.status(401).json({ success: false, error: 'Unauthorized' });
    const list = await notif.listForUser(userId, { limit: 200, offset: 0 });
    res.json({ success: true, data: list });
  } catch (e) {
    console.error('notifications.list error', e);
    res.status(500).json({ success: false, message: 'Failed to list notifications' });
  }
});

router.post('/mark-all-read', auth.authMiddleware(), async (req, res) => {
  try {
    await notif.markAllAsRead(req.user.id);
    res.json({ success: true });
  } catch (e) {
    console.error('notifications.markAll error', e);
    res.status(500).json({ success: false });
  }
});

router.post('/:id/read', auth.authMiddleware(), async (req, res) => {
  try {
    const updated = await notif.markAsRead(req.params.id);
    res.json({ success: true, data: updated });
  } catch (e) {
    console.error('notifications.read error', e);
    res.status(500).json({ success: false });
  }
});

// Get unread counts (total and by type)
router.get('/counts', auth.authMiddleware(), async (req, res) => {
  try {
    let userId = req.user && (req.user.id || req.user.userId);
    if (!userId && req.headers.authorization && req.headers.authorization.startsWith('Bearer ')) {
      try {
        const decoded = auth.verifyToken(req.headers.authorization.substring(7));
        userId = decoded.userId || decoded.id;
      } catch (_) {}
    }
    if (!userId) return res.status(401).json({ success: false, error: 'Unauthorized' });
    console.log('[notifications.counts] userId', userId);
    const total = await notif.countUnread(userId);
    const messages = await notif.countUnread(userId, { type: 'newMessage' });
    res.json({ success: true, data: { total, messages } });
  } catch (e) {
    console.error('notifications.counts error', e);
    res.status(500).json({ success: false, message: 'Failed to get counts', error: e.message });
  }
});

router.delete('/:id', auth.authMiddleware(), async (req, res) => {
  try {
    const del = await notif.remove(req.params.id);
    res.json({ success: true, data: del });
  } catch (e) {
    console.error('notifications.delete error', e);
    res.status(500).json({ success: false });
  }
});

module.exports = router;
