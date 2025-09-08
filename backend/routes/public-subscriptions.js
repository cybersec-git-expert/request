const express = require('express');
const router = express.Router();
const database = require('../services/database');

// Public: list available plans for a country
router.get('/plans/available', async (req, res) => {
  try {
    const country = (req.query.country || 'LK').toUpperCase();
    const { rows } = await database.query(`
      SELECT 
        sp.code,
        sp.name,
        sp.description,
        sp.plan_type,
        sp.default_responses_per_month,
        scs.currency,
        scs.price,
        scs.ppc_price,
        scs.responses_per_month,
        COALESCE(scs.is_active, TRUE) as is_active
      FROM subscription_plans sp
      LEFT JOIN subscription_country_settings scs ON sp.id = scs.plan_id AND scs.country_code = $1
      WHERE sp.status = 'active' AND (scs.is_active = true OR scs.is_active IS NULL)
      ORDER BY 
        CASE sp.plan_type 
          WHEN 'unlimited' THEN 1 
          WHEN 'ppc' THEN 2 
          ELSE 3 
        END,
        scs.price ASC NULLS LAST
    `, [country]);
    res.json(rows);
  } catch (err) {
    console.error('GET /public/subscriptions/plans/available error', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

module.exports = router;
