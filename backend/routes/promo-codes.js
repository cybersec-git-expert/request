const express = require('express');
const router = express.Router();
const db = require('../services/database');
const { authenticateToken } = require('../middleware/auth');
const { body, validationResult, param } = require('express-validator');

/**
 * @api {post} /api/promo-codes/validate Validate Promo Code
 * @apiDescription Check if a promo code is valid and what benefits it offers
 * @apiGroup PromoCode
 * @apiHeader {String} Authorization Bearer token
 * 
 * @apiParam {String} code Promo code to validate
 * 
 * @apiSuccess {Boolean} success Operation status
 * @apiSuccess {Boolean} valid Whether the code is valid
 * @apiSuccess {Object} promo Promo code details (if valid)
 * @apiSuccess {String} promo.name Promo code name
 * @apiSuccess {String} promo.description Promo code description
 * @apiSuccess {String} promo.benefit_type Type of benefit (free_plan, discount, extension)
 * @apiSuccess {Number} promo.benefit_duration_days Duration of benefit in days
 * @apiSuccess {String} promo.benefit_plan_code Plan code that will be granted
 * @apiSuccess {Boolean} user_can_use Whether current user can use this code
 */
router.post('/validate', 
  authenticateToken,
  [
    body('code').trim().isLength({ min: 1, max: 50 }).withMessage('Promo code is required')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          errors: errors.array()
        });
      }

      const { code } = req.body;
      const userId = req.user.id;

      // Get promo code details
      const promoQuery = `
        SELECT 
          id, code, name, description, benefit_type, benefit_duration_days, 
          benefit_plan_code, discount_percentage, max_uses, max_uses_per_user, 
          current_uses, valid_from, valid_until, is_active
        FROM promo_codes 
        WHERE code = $1 AND is_active = true
      `;
      
      const promoResult = await db.query(promoQuery, [code.toUpperCase()]);
      
      if (promoResult.rows.length === 0) {
        return res.json({
          success: true,
          valid: false,
          message: 'Invalid promo code'
        });
      }

      const promo = promoResult.rows[0];

      // Check if user can use this promo code
      const canUseQuery = `SELECT can_user_use_promo_code($1, $2) as can_use`;
      const canUseResult = await db.query(canUseQuery, [promo.id, userId]);
      const userCanUse = canUseResult.rows[0].can_use;

      // Get user's usage count for this promo
      const usageQuery = `
        SELECT COUNT(*) as usage_count 
        FROM promo_code_redemptions 
        WHERE promo_code_id = $1 AND user_id = $2
      `;
      const usageResult = await db.query(usageQuery, [promo.id, userId]);
      const userUsageCount = parseInt(usageResult.rows[0].usage_count);

      let message = '';
      if (!userCanUse) {
        if (promo.valid_from > new Date()) {
          message = 'This promo code is not yet active';
        } else if (promo.valid_until && promo.valid_until < new Date()) {
          message = 'This promo code has expired';
        } else if (promo.max_uses && promo.current_uses >= promo.max_uses) {
          message = 'This promo code has reached its usage limit';
        } else if (promo.max_uses_per_user && userUsageCount >= promo.max_uses_per_user) {
          message = 'You have already used this promo code the maximum number of times';
        } else {
          message = 'You cannot use this promo code';
        }
      } else {
        if (promo.benefit_type === 'free_plan') {
          message = `Get ${promo.benefit_duration_days} days of ${promo.benefit_plan_code} access for free!`;
        } else if (promo.benefit_type === 'discount') {
          message = `Get ${promo.discount_percentage}% off your next subscription!`;
        }
      }

      res.json({
        success: true,
        valid: true,
        user_can_use: userCanUse,
        message,
        promo: {
          name: promo.name,
          description: promo.description,
          benefit_type: promo.benefit_type,
          benefit_duration_days: promo.benefit_duration_days,
          benefit_plan_code: promo.benefit_plan_code,
          discount_percentage: promo.discount_percentage,
          user_usage_count: userUsageCount,
          max_uses_per_user: promo.max_uses_per_user,
          valid_until: promo.valid_until
        }
      });

    } catch (error) {
      console.error('Error validating promo code:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to validate promo code'
      });
    }
  }
);

/**
 * @api {post} /api/promo-codes/redeem Redeem Promo Code
 * @apiDescription Redeem a promo code and apply its benefits to the user
 * @apiGroup PromoCode
 * @apiHeader {String} Authorization Bearer token
 * 
 * @apiParam {String} code Promo code to redeem
 * 
 * @apiSuccess {Boolean} success Operation status
 * @apiSuccess {String} redemption_id Unique redemption ID
 * @apiSuccess {String} benefit_plan Plan granted by the promo
 * @apiSuccess {String} benefit_end_date When the promo benefit expires
 * @apiSuccess {String} message Success message
 */
router.post('/redeem',
  authenticateToken,
  [
    body('code').trim().isLength({ min: 1, max: 50 }).withMessage('Promo code is required')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          errors: errors.array()
        });
      }

      const { code } = req.body;
      const userId = req.user.id;
      const ipAddress = req.ip;
      const userAgent = req.get('User-Agent');

      // Use the database function to redeem the promo code
      const redeemQuery = `SELECT redeem_promo_code($1, $2, $3, $4) as result`;
      const redeemResult = await db.query(redeemQuery, [
        code.toUpperCase(), 
        userId, 
        ipAddress, 
        userAgent
      ]);

      const result = redeemResult.rows[0].result;

      if (result.success) {
        // Log successful redemption
        console.log(`User ${userId} successfully redeemed promo code: ${code}`);
        
        res.json(result);
      } else {
        res.status(400).json(result);
      }

    } catch (error) {
      console.error('Error redeeming promo code:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to redeem promo code'
      });
    }
  }
);

/**
 * @api {get} /api/promo-codes/my-redemptions Get User's Promo Redemptions
 * @apiDescription Get list of promo codes redeemed by the current user
 * @apiGroup PromoCode
 * @apiHeader {String} Authorization Bearer token
 * 
 * @apiSuccess {Boolean} success Operation status
 * @apiSuccess {Array} redemptions List of user's promo redemptions
 */
router.get('/my-redemptions', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    const query = `
      SELECT 
        pcr.id,
        pcr.redeemed_at,
        pcr.benefit_start_date,
        pcr.benefit_end_date,
        pcr.granted_plan_code,
        pcr.status,
        pc.code,
        pc.name,
        pc.description,
        pc.benefit_type,
        pc.benefit_duration_days
      FROM promo_code_redemptions pcr
      JOIN promo_codes pc ON pcr.promo_code_id = pc.id
      WHERE pcr.user_id = $1
      ORDER BY pcr.redeemed_at DESC
    `;

    const result = await db.query(query, [userId]);

    res.json({
      success: true,
      redemptions: result.rows.map(row => ({
        id: row.id,
        code: row.code,
        name: row.name,
        description: row.description,
        benefit_type: row.benefit_type,
        benefit_duration_days: row.benefit_duration_days,
        granted_plan_code: row.granted_plan_code,
        status: row.status,
        redeemed_at: row.redeemed_at,
        benefit_start_date: row.benefit_start_date,
        benefit_end_date: row.benefit_end_date,
        is_active: row.status === 'active' && new Date(row.benefit_end_date) > new Date(),
        days_remaining: row.status === 'active' 
          ? Math.max(0, Math.ceil((new Date(row.benefit_end_date) - new Date()) / (1000 * 60 * 60 * 24)))
          : 0
      }))
    });

  } catch (error) {
    console.error('Error getting user redemptions:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get redemptions'
    });
  }
});

/**
 * @api {get} /api/promo-codes/check-active Check Active Promo Benefits
 * @apiDescription Check if user has any active promo benefits
 * @apiGroup PromoCode
 * @apiHeader {String} Authorization Bearer token
 * 
 * @apiSuccess {Boolean} success Operation status
 * @apiSuccess {Boolean} has_active_promo Whether user has active promo benefits
 * @apiSuccess {Object} active_promo Details of active promo (if any)
 */
router.get('/check-active', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    const query = `
      SELECT 
        pcr.id,
        pcr.benefit_end_date,
        pcr.granted_plan_code,
        pc.code,
        pc.name
      FROM promo_code_redemptions pcr
      JOIN promo_codes pc ON pcr.promo_code_id = pc.id
      WHERE pcr.user_id = $1 
        AND pcr.status = 'active' 
        AND pcr.benefit_end_date > CURRENT_TIMESTAMP
      ORDER BY pcr.benefit_end_date DESC
      LIMIT 1
    `;

    const result = await db.query(query, [userId]);

    if (result.rows.length > 0) {
      const activePromo = result.rows[0];
      const daysRemaining = Math.ceil((new Date(activePromo.benefit_end_date) - new Date()) / (1000 * 60 * 60 * 24));

      res.json({
        success: true,
        has_active_promo: true,
        active_promo: {
          id: activePromo.id,
          code: activePromo.code,
          name: activePromo.name,
          granted_plan_code: activePromo.granted_plan_code,
          benefit_end_date: activePromo.benefit_end_date,
          days_remaining: daysRemaining
        }
      });
    } else {
      res.json({
        success: true,
        has_active_promo: false
      });
    }

  } catch (error) {
    console.error('Error checking active promo:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to check active promo'
    });
  }
});

module.exports = router;
