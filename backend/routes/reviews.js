const express = require('express');
const router = express.Router();
const db = require('../services/database');
const auth = require('../services/auth');
const notif = require('../services/notification-helper');

// Ensure reviews table exists (idempotent)
async function ensureReviewsTable() {
  await db.query(`
    CREATE TABLE IF NOT EXISTS reviews (
      id SERIAL PRIMARY KEY,
      request_id UUID NOT NULL,
      response_id UUID,
      reviewer_id VARCHAR(255) NOT NULL, -- requester (owner of the request)
      reviewee_id VARCHAR(255) NOT NULL, -- responder (owner of accepted response)
      rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
      comment TEXT,
      country_code VARCHAR(10),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT uq_review_per_request UNIQUE (request_id, reviewer_id, reviewee_id)
    );
  `);
  // Helpful indexes
  await db.query(`CREATE INDEX IF NOT EXISTS idx_reviews_reviewee ON reviews(reviewee_id);`);
  await db.query(`CREATE INDEX IF NOT EXISTS idx_reviews_request ON reviews(request_id);`);
}

ensureReviewsTable().catch(e => console.error('Failed to ensure reviews table:', e.message));

// Create a review (request owner reviews accepted responder after completion)
router.post('/', auth.authMiddleware(), async (req, res) => {
  try {
    const { request_id, rating, comment } = req.body || {};
    const reviewerId = req.user.id || req.user.userId;
    if (!request_id || !rating) {
      return res.status(400).json({ success: false, message: 'request_id and rating are required' });
    }
    const rate = parseInt(rating, 10);
    if (!(rate >= 1 && rate <= 5)) {
      return res.status(400).json({ success: false, message: 'rating must be 1-5' });
    }

    // Fetch request and accepted response
    const reqRow = await db.queryOne(`
      SELECT r.id, r.user_id, r.accepted_response_id, r.status, r.country_code,
             ar.user_id AS responder_id
      FROM requests r
      LEFT JOIN responses ar ON r.accepted_response_id = ar.id
      WHERE r.id = $1
    `, [request_id]);
    if (!reqRow) return res.status(404).json({ success: false, message: 'Request not found' });
    if (reqRow.user_id !== reviewerId) {
      return res.status(403).json({ success: false, message: 'Only the request owner can review' });
    }
    if (!reqRow.accepted_response_id || !reqRow.responder_id) {
      return res.status(400).json({ success: false, message: 'No accepted response to review' });
    }
    // Require request to be completed before review
    if ((reqRow.status || '').toLowerCase() !== 'completed') {
      return res.status(400).json({ success: false, message: 'You can review only after the request is completed' });
    }

    // Prevent duplicate reviews for same pair on this request
    const existing = await db.queryOne(
      'SELECT id FROM reviews WHERE request_id=$1 AND reviewer_id=$2::text AND reviewee_id=$3::text',
      [request_id, reviewerId, reqRow.responder_id]
    );
    if (existing) {
      return res.status(400).json({ success: false, message: 'You already reviewed this responder for this request' });
    }

    const inserted = await db.queryOne(`
      INSERT INTO reviews (request_id, response_id, reviewer_id, reviewee_id, rating, comment, country_code)
      VALUES ($1,$2,$3::text,$4::text,$5,$6,$7)
      RETURNING *
    `, [request_id, reqRow.accepted_response_id, reviewerId, reqRow.responder_id, rate, comment || null, reqRow.country_code || null]);

    // Best-effort: notify the responder that they received a review
    try {
      await notif.createNotification({
        recipientId: reqRow.responder_id,
        senderId: reviewerId,
        type: 'review.received',
        title: 'You received a review',
        message: `You were rated ${rate}/5` + (comment && String(comment).trim() ? `: "${String(comment).trim().slice(0, 140)}"` : ''),
        data: {
          request_id,
          response_id: reqRow.accepted_response_id,
          review_id: inserted.id,
          rating: rate,
          country_code: reqRow.country_code || null,
        },
      });
    } catch (notifyError) {
      console.warn('reviews.create: failed to send notification (non-fatal):', notifyError.message);
    }

    return res.status(201).json({ success: true, message: 'Review submitted', data: inserted });
  } catch (error) {
    console.error('Error creating review:', error);
    res.status(500).json({ success: false, message: 'Error creating review', error: error.message });
  }
});

// Public: list reviews for a user (as reviewee)
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { page = 1, limit = 20 } = req.query;
    const p = Math.max(parseInt(page) || 1, 1);
    const lim = Math.min(parseInt(limit) || 20, 100);
    const offset = (p - 1) * lim;

    const rows = await db.query(`
      SELECT rv.*, u.display_name AS reviewer_name, u.photo_url AS reviewer_photo
      FROM reviews rv
      LEFT JOIN users u ON u.id::text = rv.reviewer_id
      WHERE rv.reviewee_id = $1::text
      ORDER BY rv.created_at DESC
      LIMIT $2 OFFSET $3
    `, [userId, lim, offset]);

    const countRow = await db.queryOne('SELECT COUNT(*)::int AS total FROM reviews WHERE reviewee_id = $1::text', [userId]);

    res.json({
      success: true,
      data: {
        reviews: rows.rows,
        pagination: { page: p, limit: lim, total: countRow.total, totalPages: Math.ceil((countRow.total || 0)/lim) }
      }
    });
  } catch (error) {
    console.error('Error listing reviews:', error);
    res.status(500).json({ success: false, message: 'Error listing reviews', error: error.message });
  }
});

// Public: aggregated stats for a user
router.get('/stats/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const stats = await db.queryOne(`
      SELECT 
        COALESCE(AVG(rating), 0)::numeric(10,2) AS average_rating,
        COUNT(*)::int AS review_count
      FROM reviews WHERE reviewee_id = $1::text
    `, [userId]);
    res.json({ success: true, data: stats });
  } catch (error) {
    console.error('Error fetching review stats:', error);
    res.status(500).json({ success: false, message: 'Error fetching review stats', error: error.message });
  }
});

// Auth: fetch current user's review (if any) for a specific request
router.get('/request/:requestId/mine', auth.authMiddleware(), async (req, res) => {
  try {
    const { requestId } = req.params;
    const reviewerId = req.user.id || req.user.userId;
    const row = await db.queryOne(
      `SELECT * FROM reviews WHERE request_id = $1 AND reviewer_id = $2::text LIMIT 1`,
      [requestId, reviewerId]
    );
    return res.json({ success: true, data: row || null });
  } catch (error) {
    console.error('Error fetching my review for request:', error);
    res.status(500).json({ success: false, message: 'Error fetching review', error: error.message });
  }
});

module.exports = router;
