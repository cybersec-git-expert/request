const express = require('express');
const router = express.Router();
const db = require('../services/database');
const auth = require('../services/auth');

async function resolveGateway(countryCode, provider) {
  const where = ['is_active = true'];
  const params = [];
  if (countryCode) { where.push('country_code = $' + (params.length + 1)); params.push(countryCode); }
  if (provider) { where.push('provider = $' + (params.length + 1)); params.push(provider); }
  const q = `SELECT * FROM country_payment_gateways WHERE ${where.join(' AND ')} ORDER BY display_name LIMIT 1`;
  return db.queryOne(q, params);
}

// Create a checkout session for a pending subscription
router.post('/checkout-subscription', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    const { subscription_id, provider } = req.body || {};
    if (!subscription_id) return res.status(400).json({ success:false, error:'subscription_id required' });
    const sub = await db.queryOne(`
      SELECT us.*, sp.duration_days, sp.code, sp.name
      FROM user_subscriptions us
      JOIN subscription_plans_new sp ON sp.id = us.plan_id
      WHERE us.id=$1 AND us.user_id=$2
    `, [subscription_id, userId]);
    if (!sub) return res.status(404).json({ success:false, error:'Subscription not found' });
    if (sub.status !== 'pending_payment') return res.status(400).json({ success:false, error:'Subscription not pending_payment' });

    const gateway = await resolveGateway(sub.country_code, provider);
    if (!gateway) return res.status(400).json({ success:false, error:'No active gateway for country/provider' });

    // Create a transaction row we can map to a provider session/intent
    const tx = await db.queryOne(`
      INSERT INTO subscription_transactions (user_id, country_code, plan_id, subscription_id, purpose, amount, currency, provider, status, metadata)
      VALUES ($1,$2,$3,$4,'subscription',$5,$6,$7,'pending', jsonb_build_object('plan_code',$8))
      RETURNING *
    `, [userId, sub.country_code, sub.plan_id, sub.id, sub.price, sub.currency, gateway.provider, sub.code]);

    // In a real integration, call provider to get a session/url. For now, return details for mobile SDK usage.
    const provider_ref = `sess_${tx.id}`;
    await db.query('UPDATE subscription_transactions SET provider_ref=$1 WHERE id=$2', [provider_ref, tx.id]);

    res.status(201).json({
      success:true,
      data: {
        transaction: { ...tx, provider_ref },
        gateway: { id: gateway.id, provider: gateway.provider, display_name: gateway.display_name, public_config: gateway.public_config },
        // Payment hand-off data for mobile app
        payment: {
          provider: gateway.provider,
          amount: Number(sub.price || 0),
          currency: sub.currency,
          country_code: sub.country_code,
          provider_ref
        }
      }
    });
  } catch (e) {
    console.error('checkout-subscription failed', e);
    res.status(500).json({ success:false, error:'Failed to create checkout' });
  }
});

// Generic webhook for payment providers (simplified)
router.post('/webhook/generic', async (req, res) => {
  try {
    const secret = process.env.WEBHOOK_SECRET;
    if (secret && req.headers['x-webhook-secret'] !== secret) {
      return res.status(401).json({ success:false, error:'unauthorized' });
    }
    const { provider, provider_ref, status, transaction_id, metadata } = req.body || {};
    if (!provider_ref && !transaction_id) return res.status(400).json({ success:false, error:'provider_ref or transaction_id required' });
    const tx = transaction_id
      ? await db.queryOne('SELECT * FROM subscription_transactions WHERE id=$1', [transaction_id])
      : await db.queryOne('SELECT * FROM subscription_transactions WHERE provider_ref=$1', [provider_ref]);
    if (!tx) return res.status(404).json({ success:false, error:'transaction_not_found' });

    // Update transaction status
    const newStatus = (status || '').toLowerCase();
    if (!['paid','failed','pending','refunded'].includes(newStatus)) {
      return res.status(400).json({ success:false, error:'invalid_status' });
    }
    await db.query('UPDATE subscription_transactions SET status=$1, provider=$2, updated_at=NOW() WHERE id=$3', [newStatus, provider || tx.provider, tx.id]);

    // Side effects
    if (newStatus === 'paid') {
      if (tx.purpose === 'subscription' && tx.subscription_id) {
        const sub = await db.queryOne(`
          SELECT us.*, sp.duration_days
          FROM user_subscriptions us
          JOIN subscription_plans_new sp ON sp.id = us.plan_id
          WHERE us.id=$1
        `, [tx.subscription_id]);
        if (sub) {
          const days = Math.max(parseInt(sub.duration_days || 30, 10), 1);
          await db.query(
            'UPDATE user_subscriptions SET status=$1, started_at=NOW(), next_renewal_at=NOW() + ($2 || \n' + "' days')::interval WHERE id=$3",
            ['active', String(days), sub.id]
          );
        }
      } else if (tx.purpose === 'urgent_boost') {
        // if webhook handles urgent boost too, apply it (fallback to requests endpoint already exists)
        const reqId = (tx.metadata && tx.metadata.request_id) || (metadata && metadata.request_id);
        if (reqId) {
          await db.query('UPDATE requests SET is_urgent=true, urgent_until=NOW() + interval \n' + "'30 days', urgent_paid_tx_id=$1 WHERE id=$2", [tx.id, reqId]);
        }
      }
    }

    res.json({ success:true });
  } catch (e) {
    console.error('webhook handler failed', e);
    res.status(500).json({ success:false, error:'webhook_failed' });
  }
});

// List my transactions
router.get('/transactions/me', auth.authMiddleware(), async (req, res) => {
  try {
    const rows = await db.query('SELECT * FROM subscription_transactions WHERE user_id=$1 ORDER BY created_at DESC LIMIT 100', [req.user.id]);
    res.json({ success:true, data: rows.rows });
  } catch (e) {
    console.error('list transactions failed', e);
    res.status(500).json({ success:false, error:'Failed to list transactions' });
  }
});

module.exports = router;
