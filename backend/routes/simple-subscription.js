const express = require('express');
const router = express.Router();
const db = require('../services/database');
const auth = require('../services/auth');

// Get user's subscription status and remaining responses
router.get('/status', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    
    // Get or create user subscription with country-specific details
    let subscription = await db.queryOne(`
      SELECT 
        us.*,
        ssp.name as plan_name,
        ssp.features,
        COALESCE(scp.response_limit, 3) as response_limit,
        COALESCE(scp.price, 0) as price,
        COALESCE(scp.currency, 'USD') as currency
      FROM user_simple_subscriptions us
      JOIN simple_subscription_plans ssp ON us.plan_code = ssp.code
      LEFT JOIN simple_subscription_country_pricing scp ON ssp.code = scp.plan_code 
        AND scp.country_code = $2 AND scp.is_active = true
      WHERE us.user_id = $1
    `, [userId, req.user.country_code || 'LK']);
    
    if (!subscription) {
      // Create default free subscription
      await db.query(`
        INSERT INTO user_simple_subscriptions (user_id, plan_code)
        VALUES ($1, 'free')
      `, [userId]);
      
      subscription = await db.queryOne(`
        SELECT 
          us.*,
          ssp.name as plan_name,
          ssp.features,
          COALESCE(scp.response_limit, 3) as response_limit,
          COALESCE(scp.price, 0) as price,
          COALESCE(scp.currency, 'USD') as currency
        FROM user_simple_subscriptions us
        JOIN simple_subscription_plans ssp ON us.plan_code = ssp.code
        LEFT JOIN simple_subscription_country_pricing scp ON ssp.code = scp.plan_code 
          AND scp.country_code = $2 AND scp.is_active = true
        WHERE us.user_id = $1
      `, [userId, req.user.country_code || 'LK']);
    }
    
    // Check if month has changed and reset if needed
    const now = new Date();
    const currentMonth = now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0');
    const resetMonth = subscription.month_reset_date ? 
      new Date(subscription.month_reset_date).getFullYear() + '-' + 
      String(new Date(subscription.month_reset_date).getMonth() + 1).padStart(2, '0') : 
      currentMonth;
    
    if (currentMonth !== resetMonth) {
      await db.query(`
        UPDATE user_simple_subscriptions 
        SET responses_used_this_month = 0, 
            month_reset_date = CURRENT_DATE,
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = $1
      `, [userId]);
      subscription.responses_used_this_month = 0;
    }
    
    const responseLimit = subscription.response_limit === -1 ? null : subscription.response_limit;
    const responsesUsed = subscription.responses_used_this_month || 0;
    const responsesRemaining = responseLimit ? Math.max(0, responseLimit - responsesUsed) : null;
    const canRespond = responseLimit === null || responsesUsed < responseLimit;
    
    // Check subscription status and expiry
    let isActive = true;
    let daysRemaining = null;
    let renewalRequired = false;
    
    if (subscription.subscription_end_date) {
      const endDate = new Date(subscription.subscription_end_date);
      isActive = endDate > now || (subscription.grace_period_end && new Date(subscription.grace_period_end) > now);
      daysRemaining = Math.ceil((endDate - now) / (1000 * 60 * 60 * 24));
      renewalRequired = daysRemaining <= 7 && daysRemaining > 0;
    }
    
    res.json({
      success: true,
      subscription: {
        plan_code: subscription.plan_code,
        plan_name: subscription.plan_name,
        status: subscription.status,
        payment_status: subscription.payment_status,
        subscription_start_date: subscription.subscription_start_date,
        subscription_end_date: subscription.subscription_end_date,
        days_remaining: daysRemaining,
        is_active: isActive,
        renewal_required: renewalRequired,
        auto_renew: subscription.auto_renew,
        grace_period_end: subscription.grace_period_end,
        responses_used: responsesUsed,
        responses_limit: responseLimit,
        responses_remaining: responsesRemaining,
        can_respond: canRespond && isActive,
        is_verified_business: subscription.is_verified_business,
        features: subscription.features || []
      }
    });
  } catch (error) {
    console.error('Get subscription status error:', error);
    res.status(500).json({ success: false, error: 'Failed to get subscription status' });
  }
});

// Check if user can respond to a request
router.get('/can-respond', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    
    const subscription = await db.queryOne(`
      SELECT 
        us.*,
        COALESCE(scp.response_limit, 3) as response_limit
      FROM user_simple_subscriptions us
      JOIN simple_subscription_plans ssp ON us.plan_code = ssp.code
      LEFT JOIN simple_subscription_country_pricing scp ON ssp.code = scp.plan_code 
        AND scp.country_code = $2 AND scp.is_active = true
      WHERE us.user_id = $1
    `, [userId, req.user.country_code || 'LK']);
    
    if (!subscription) {
      return res.json({
        can_respond: false,
        reason: 'no_subscription',
        message: 'Please set up your subscription'
      });
    }
    
    // Unlimited plan
    if (subscription.response_limit === -1) {
      return res.json({
        can_respond: true,
        reason: 'unlimited_plan',
        responses_remaining: null
      });
    }
    
    // Check limit
    const responsesUsed = subscription.responses_used_this_month || 0;
    const canRespond = responsesUsed < subscription.response_limit;
    const responsesRemaining = Math.max(0, subscription.response_limit - responsesUsed);
    
    res.json({
      can_respond: canRespond,
      reason: canRespond ? 'within_limit' : 'limit_exceeded',
      responses_used: responsesUsed,
      responses_limit: subscription.response_limit,
      responses_remaining: responsesRemaining,
      message: canRespond ? 
        `${responsesRemaining} responses remaining this month` :
        'Monthly response limit reached. Upgrade to premium for unlimited responses.'
    });
  } catch (error) {
    console.error('Check can respond error:', error);
    res.status(500).json({ success: false, error: 'Failed to check response eligibility' });
  }
});

// Record a response (increment usage counter)
router.post('/record-response', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    const { request_id } = req.body;
    
    // Check if user can respond
    const subscription = await db.queryOne(`
      SELECT 
        us.*,
        COALESCE(scp.response_limit, 3) as response_limit
      FROM user_simple_subscriptions us
      JOIN simple_subscription_plans ssp ON us.plan_code = ssp.code
      LEFT JOIN simple_subscription_country_pricing scp ON ssp.code = scp.plan_code 
        AND scp.country_code = $2 AND scp.is_active = true
      WHERE us.user_id = $1
    `, [userId, req.user.country_code || 'LK']);
    
    if (!subscription) {
      return res.status(400).json({ success: false, error: 'No subscription found' });
    }
    
    // Skip increment for unlimited plans
    if (subscription.response_limit === -1) {
      return res.json({
        success: true,
        message: 'Response recorded (unlimited plan)',
        responses_remaining: null
      });
    }
    
    // Check if within limit
    const responsesUsed = subscription.responses_used_this_month || 0;
    if (responsesUsed >= subscription.response_limit) {
      return res.status(403).json({
        success: false,
        error: 'Response limit exceeded',
        upgrade_required: true
      });
    }
    
    // Increment usage
    await db.query(`
      UPDATE user_simple_subscriptions 
      SET responses_used_this_month = responses_used_this_month + 1,
          updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $1
    `, [userId]);
    
    const newUsed = responsesUsed + 1;
    const responsesRemaining = Math.max(0, subscription.response_limit - newUsed);
    
    res.json({
      success: true,
      message: 'Response recorded successfully',
      responses_used: newUsed,
      responses_limit: subscription.response_limit,
      responses_remaining: responsesRemaining
    });
  } catch (error) {
    console.error('Record response error:', error);
    res.status(500).json({ success: false, error: 'Failed to record response' });
  }
});

// Get available subscription plans
router.get('/plans', async (req, res) => {
  try {
    const { country } = req.query;
    
    let plans;
    
    if (country) {
      // Get plan templates with country-specific pricing (only approved/active ones)
      plans = await db.query(`
        SELECT 
          ssp.code,
          ssp.name,
          ssp.description,
          ssp.features,
          scp.price,
          scp.currency,
          scp.response_limit,
          scp.is_active as country_pricing_active,
          scp.created_at as pricing_created_at
        FROM simple_subscription_plans ssp
        INNER JOIN simple_subscription_country_pricing scp 
          ON ssp.code = scp.plan_code 
        WHERE scp.country_code = $1 
          AND scp.is_active = true
          AND ssp.is_active = true 
        ORDER BY scp.price ASC
      `, [country]);
      
      // If no country-specific plans found, return template info with a note
      if (plans.rows.length === 0) {
        plans = await db.query(`
          SELECT 
            code,
            name,
            description,
            features,
            NULL as price,
            'USD' as currency,
            NULL as response_limit,
            false as country_pricing_active,
            created_at as pricing_created_at,
            'No pricing available for this country' as note
          FROM simple_subscription_plans 
          WHERE is_active = true 
          ORDER BY name ASC
        `);
      }
    } else {
      // Get plan templates without pricing (fallback for no country specified)
      plans = await db.query(`
        SELECT 
          code,
          name,
          description,
          features,
          NULL as price,
          'USD' as currency,
          3 as response_limit,
          false as country_pricing_active,
          created_at as pricing_created_at
        FROM simple_subscription_plans 
        WHERE is_active = true 
        ORDER BY name ASC
      `);
    }
    
    res.json({
      success: true,
      plans: plans.rows
    });
  } catch (error) {
    console.error('Get plans error:', error);
    res.status(500).json({ success: false, error: 'Failed to get plans' });
  }
});

// Subscribe to a plan
router.post('/subscribe', auth.authMiddleware(), async (req, res) => {
    try {
        const { planCode } = req.body;
        const userId = req.user.id;

        if (!planCode) {
            return res.status(400).json({
                success: false,
                error: 'Plan code is required'
            });
        }

        // Get plan details with country-specific pricing
        const countryCode = req.user.country_code || 'LK';
        const planQuery = `
            SELECT 
                ssp.*,
                sscp.price,
                sscp.currency,
                sscp.response_limit
            FROM simple_subscription_plans ssp
            LEFT JOIN simple_subscription_country_pricing sscp ON ssp.code = sscp.plan_code 
                AND sscp.country_code = $2
            WHERE ssp.code = $1 AND ssp.is_active = true
        `;
        
        const planResult = await db.query(planQuery, [planCode, countryCode]);
        
        if (planResult.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'Plan not found'
            });
        }

        const plan = planResult.rows[0];
        const price = parseFloat(plan.price) || 0;

        // For free plans, activate immediately
        if (price === 0) {
            const subscriptionStart = new Date();
            const subscriptionEnd = new Date(subscriptionStart.getTime() + (30 * 24 * 60 * 60 * 1000)); // 30 days

            const insertQuery = `
                INSERT INTO user_simple_subscriptions 
                (user_id, plan_code, plan_name, status, subscription_start_date, subscription_end_date, payment_status, created_at, updated_at)
                VALUES ($1, $2, $3, 'active', $4, $5, 'completed', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                ON CONFLICT (user_id) 
                DO UPDATE SET 
                    plan_code = EXCLUDED.plan_code,
                    plan_name = EXCLUDED.plan_name,
                    status = EXCLUDED.status,
                    subscription_start_date = EXCLUDED.subscription_start_date,
                    subscription_end_date = EXCLUDED.subscription_end_date,
                    payment_status = EXCLUDED.payment_status,
                    updated_at = CURRENT_TIMESTAMP
                RETURNING *
            `;

            const subscriptionResult = await db.query(insertQuery, [
                userId, planCode, plan.name, subscriptionStart, subscriptionEnd
            ]);

            return res.json({
                success: true,
                message: 'Successfully subscribed to free plan',
                subscription: subscriptionResult.rows[0]
            });
        }

        // For paid plans, create pending subscription and redirect to payment
        const pendingSubscription = await db.query(`
            INSERT INTO user_simple_subscriptions 
            (user_id, plan_code, plan_name, status, payment_status, created_at, updated_at)
            VALUES ($1, $2, $3, 'pending', 'pending', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON CONFLICT (user_id) 
            DO UPDATE SET 
                plan_code = EXCLUDED.plan_code,
                plan_name = EXCLUDED.plan_name,
                status = EXCLUDED.status,
                payment_status = EXCLUDED.payment_status,
                updated_at = CURRENT_TIMESTAMP
            RETURNING *
        `, [userId, planCode, plan.name]);

        res.json({
            success: true,
            requiresPayment: true,
            subscription: pendingSubscription.rows[0],
            plan: {
                code: planCode,
                name: plan.name,
                price: price,
                currency: plan.currency || 'LKR'
            },
            message: 'Subscription created. Payment required to activate.'
        });

    } catch (error) {
        console.error('Subscription error:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to process subscription'
        });
    }
});// Mark user as verified business (admin only)
router.post('/verify-business', auth.authMiddleware(), auth.roleMiddleware(['admin', 'super_admin']), async (req, res) => {
  try {
    const { user_id } = req.body;
    
    if (!user_id) {
      return res.status(400).json({ success: false, error: 'User ID is required' });
    }
    
    await db.query(`
      UPDATE user_simple_subscriptions 
      SET is_verified_business = true,
          updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $1
    `, [user_id]);
    
    res.json({
      success: true,
      message: 'User verified as business successfully'
    });
  } catch (error) {
    console.error('Verify business error:', error);
    res.status(500).json({ success: false, error: 'Failed to verify business' });
  }
});

// Confirm payment and activate subscription
router.post('/confirm-payment', auth.authMiddleware(), async (req, res) => {
    try {
        const { paymentId, transactionId } = req.body;
        const userId = req.user.id;

        if (!paymentId) {
            return res.status(400).json({
                success: false,
                error: 'Payment ID is required'
            });
        }

        // Get pending subscription
        const subscription = await db.query(`
            SELECT * FROM user_simple_subscriptions 
            WHERE user_id = $1 AND payment_status = 'pending'
        `, [userId]);

        if (subscription.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'No pending subscription found'
            });
        }

        // Activate subscription with 30-day period
        const subscriptionStart = new Date();
        const subscriptionEnd = new Date(subscriptionStart.getTime() + (30 * 24 * 60 * 60 * 1000)); // 30 days

        const updateQuery = `
            UPDATE user_simple_subscriptions 
            SET 
                status = 'active',
                payment_status = 'completed',
                payment_id = $1,
                subscription_start_date = $2,
                subscription_end_date = $3,
                updated_at = CURRENT_TIMESTAMP
            WHERE user_id = $4
            RETURNING *
        `;

        const updatedSubscription = await db.query(updateQuery, [
            paymentId, subscriptionStart, subscriptionEnd, userId
        ]);

        res.json({
            success: true,
            message: 'Subscription activated successfully',
            subscription: updatedSubscription.rows[0]
        });

    } catch (error) {
        console.error('Payment confirmation error:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to confirm payment'
        });
    }
});

// Check for expired subscriptions and handle renewals
router.post('/check-renewals', auth.authMiddleware(), async (req, res) => {
    try {
        // This endpoint would be called by a cron job or scheduler
        const expiredSubscriptions = await db.query(`
            SELECT * FROM user_simple_subscriptions 
            WHERE subscription_end_date < CURRENT_TIMESTAMP 
            AND status = 'active'
            AND plan_code != 'Free'
        `);

        const results = [];

        for (const subscription of expiredSubscriptions.rows) {
            if (subscription.auto_renew) {
                // Try to charge the user again
                // For now, we'll set a grace period
                const gracePeriodEnd = new Date(Date.now() + (7 * 24 * 60 * 60 * 1000)); // 7 days grace

                await db.query(`
                    UPDATE user_simple_subscriptions 
                    SET 
                        status = 'grace_period',
                        grace_period_end = $1,
                        payment_failure_count = payment_failure_count + 1,
                        last_payment_attempt = CURRENT_TIMESTAMP,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = $2
                `, [gracePeriodEnd, subscription.id]);

                results.push({
                    userId: subscription.user_id,
                    action: 'grace_period_started',
                    gracePeriodEnd
                });
            } else {
                // Downgrade to free plan
                await db.query(`
                    UPDATE user_simple_subscriptions 
                    SET 
                        plan_code = 'Free',
                        plan_name = 'Free Plan',
                        status = 'active',
                        payment_status = 'completed',
                        subscription_start_date = CURRENT_TIMESTAMP,
                        subscription_end_date = CURRENT_TIMESTAMP + INTERVAL '30 days',
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = $1
                `, [subscription.id]);

                results.push({
                    userId: subscription.user_id,
                    action: 'downgraded_to_free'
                });
            }
        }

        // Handle expired grace periods
        const expiredGracePeriods = await db.query(`
            SELECT * FROM user_simple_subscriptions 
            WHERE grace_period_end < CURRENT_TIMESTAMP 
            AND status = 'grace_period'
        `);

        for (const subscription of expiredGracePeriods.rows) {
            // Downgrade to free plan after grace period
            await db.query(`
                UPDATE user_simple_subscriptions 
                SET 
                    plan_code = 'Free',
                    plan_name = 'Free Plan',
                    status = 'active',
                    payment_status = 'completed',
                    subscription_start_date = CURRENT_TIMESTAMP,
                    subscription_end_date = CURRENT_TIMESTAMP + INTERVAL '30 days',
                    grace_period_end = NULL,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = $1
            `, [subscription.id]);

            results.push({
                userId: subscription.user_id,
                action: 'downgraded_after_grace_period'
            });
        }

        res.json({
            success: true,
            message: `Processed ${results.length} subscription renewals`,
            results
        });

    } catch (error) {
        console.error('Renewal check error:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to check renewals'
        });
    }
});

module.exports = router;
