const db = require('../services/database');

/**
 * Subscription Lifecycle Management
 * This script should be run daily via cron job to:
 * 1. Check for expired subscriptions
 * 2. Handle renewal attempts
 * 3. Set grace periods
 * 4. Downgrade to free plans when necessary
 */

async function manageSubscriptionLifecycle() {
    console.log('🔄 Starting subscription lifecycle management...');
    
    try {
        // 1. Find subscriptions that expired today
        const expiredSubscriptions = await db.query(`
            SELECT * FROM user_simple_subscriptions 
            WHERE DATE(subscription_end_date) = CURRENT_DATE
            AND status = 'active'
            AND plan_code != 'Free'
        `);

        console.log(`📋 Found ${expiredSubscriptions.rows.length} subscriptions expiring today`);

        for (const subscription of expiredSubscriptions.rows) {
            if (subscription.auto_renew) {
                // Set grace period for auto-renew subscriptions
                const gracePeriodEnd = new Date(Date.now() + (7 * 24 * 60 * 60 * 1000)); // 7 days
                
                await db.query(`
                    UPDATE user_simple_subscriptions 
                    SET 
                        status = 'grace_period',
                        grace_period_end = $1,
                        last_payment_attempt = CURRENT_TIMESTAMP,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = $2
                `, [gracePeriodEnd, subscription.id]);

                console.log(`⏳ Set grace period for user ${subscription.user_id} until ${gracePeriodEnd}`);
            } else {
                // Immediately downgrade non-auto-renew subscriptions
                await downgradeToFree(subscription);
                console.log(`⬇️  Downgraded user ${subscription.user_id} to Free plan (no auto-renew)`);
            }
        }

        // 2. Handle expired grace periods
        const expiredGracePeriods = await db.query(`
            SELECT * FROM user_simple_subscriptions 
            WHERE DATE(grace_period_end) = CURRENT_DATE
            AND status = 'grace_period'
        `);

        console.log(`⚠️  Found ${expiredGracePeriods.rows.length} grace periods expiring today`);

        for (const subscription of expiredGracePeriods.rows) {
            await downgradeToFree(subscription);
            console.log(`⬇️  Downgraded user ${subscription.user_id} to Free plan (grace period expired)`);
        }

        // 3. Send renewal reminders (7 days, 3 days, 1 day before expiry)
        const upcomingRenewals = await db.query(`
            SELECT * FROM user_simple_subscriptions 
            WHERE subscription_end_date IS NOT NULL
            AND status = 'active'
            AND plan_code != 'Free'
            AND (
                DATE(subscription_end_date) = CURRENT_DATE + INTERVAL '7 days' OR
                DATE(subscription_end_date) = CURRENT_DATE + INTERVAL '3 days' OR
                DATE(subscription_end_date) = CURRENT_DATE + INTERVAL '1 day'
            )
        `);

        console.log(`📧 Found ${upcomingRenewals.rows.length} subscriptions requiring renewal reminders`);

        for (const subscription of upcomingRenewals.rows) {
            const daysRemaining = Math.ceil((new Date(subscription.subscription_end_date) - new Date()) / (1000 * 60 * 60 * 24));
            
            // TODO: Send email/notification to user about upcoming renewal
            console.log(`📬 Would send renewal reminder to user ${subscription.user_id} (${daysRemaining} days remaining)`);
            
            // Update reminder sent flag (you might want to add this column)
            await db.query(`
                UPDATE user_simple_subscriptions 
                SET updated_at = CURRENT_TIMESTAMP
                WHERE id = $1
            `, [subscription.id]);
        }

        // 4. Cleanup old usage data (optional - keep last 6 months)
        const sixMonthsAgo = new Date();
        sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);
        const cleanupMonth = sixMonthsAgo.getFullYear() + String(sixMonthsAgo.getMonth() + 1).padStart(2, '0');

        const cleanupResult = await db.query(`
            DELETE FROM usage_monthly 
            WHERE year_month < $1
        `, [cleanupMonth]);

        if (cleanupResult.rowCount > 0) {
            console.log(`🧹 Cleaned up ${cleanupResult.rowCount} old usage records`);
        }

        console.log('✅ Subscription lifecycle management completed successfully');

    } catch (error) {
        console.error('❌ Error in subscription lifecycle management:', error);
        throw error;
    }
}

async function downgradeToFree(subscription) {
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
            payment_id = NULL,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = $1
    `, [subscription.id]);
}

// Run if called directly
if (require.main === module) {
    manageSubscriptionLifecycle()
        .then(() => {
            console.log('Script completed successfully');
            process.exit(0);
        })
        .catch((error) => {
            console.error('Script failed:', error);
            process.exit(1);
        });
}

module.exports = { manageSubscriptionLifecycle };
