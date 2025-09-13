const cron = require('node-cron');
const db = require('../services/database');

class SubscriptionExpirationService {
    constructor() {
        this.isInitialized = false;
        this.gracePeriodDays = 7;
    }

    /**
     * Initialize the subscription expiration checking cron job
     * Runs daily at 2:00 AM to check for expired subscriptions
     */
    initialize() {
        if (this.isInitialized) {
            console.log('Subscription expiration service already initialized');
            return;
        }

        // Run daily at 2:00 AM
        cron.schedule('0 2 * * *', () => {
            this.checkExpiredSubscriptions();
        });

        // Also run once on startup (with 30 second delay to allow server to fully start)
        setTimeout(() => {
            this.checkExpiredSubscriptions();
        }, 30000);

        this.isInitialized = true;
        console.log('Subscription expiration service initialized - will run daily at 2:00 AM');
    }

    /**
     * Main method to check and handle expired subscriptions
     */
    async checkExpiredSubscriptions() {
        console.log('Starting subscription expiration check...');
        
        try {
            const results = {
                processedCount: 0,
                gracePeriodStarted: 0,
                downgradedToFree: 0,
                gracePeriodExpired: 0,
                errors: []
            };

            // Step 1: Handle newly expired paid subscriptions
            await this.handleNewlyExpiredSubscriptions(results);

            // Step 2: Handle expired grace periods
            await this.handleExpiredGracePeriods(results);

            // Step 3: Send renewal notifications
            await this.sendRenewalNotifications(results);

            console.log('Subscription expiration check completed:', results);
            
            // Log to database for audit trail
            await this.logExpirationCheckResult(results);

        } catch (error) {
            console.error('Error in subscription expiration check:', error);
            await this.logExpirationCheckResult({ error: error.message });
        }
    }

    /**
     * Handle subscriptions that just expired
     */
    async handleNewlyExpiredSubscriptions(results) {
        const expiredSubscriptions = await db.query(`
            SELECT * FROM user_simple_subscriptions 
            WHERE subscription_end_date <= CURRENT_TIMESTAMP 
            AND status = 'active'
            AND plan_code != 'Free'
            AND plan_code IS NOT NULL
        `);

        console.log(`Found ${expiredSubscriptions.rows.length} newly expired subscriptions`);

        for (const subscription of expiredSubscriptions.rows) {
            try {
                if (subscription.auto_renew) {
                    await this.startGracePeriod(subscription);
                    results.gracePeriodStarted++;
                } else {
                    await this.downgradeToFree(subscription, 'subscription_expired');
                    results.downgradedToFree++;
                }
                results.processedCount++;
            } catch (error) {
                console.error(`Error processing subscription ${subscription.id}:`, error);
                results.errors.push({
                    subscriptionId: subscription.id,
                    userId: subscription.user_id,
                    error: error.message
                });
            }
        }
    }

    /**
     * Handle grace periods that have expired
     */
    async handleExpiredGracePeriods(results) {
        const expiredGracePeriods = await db.query(`
            SELECT * FROM user_simple_subscriptions 
            WHERE grace_period_end <= CURRENT_TIMESTAMP 
            AND status = 'grace_period'
        `);

        console.log(`Found ${expiredGracePeriods.rows.length} expired grace periods`);

        for (const subscription of expiredGracePeriods.rows) {
            try {
                await this.downgradeToFree(subscription, 'grace_period_expired');
                results.gracePeriodExpired++;
                results.processedCount++;
            } catch (error) {
                console.error(`Error processing grace period expiration for subscription ${subscription.id}:`, error);
                results.errors.push({
                    subscriptionId: subscription.id,
                    userId: subscription.user_id,
                    error: error.message
                });
            }
        }
    }

    /**
     * Start grace period for auto-renew subscriptions
     */
    async startGracePeriod(subscription) {
        const gracePeriodEnd = new Date(Date.now() + (this.gracePeriodDays * 24 * 60 * 60 * 1000));

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

        console.log(`Started grace period for subscription ${subscription.id} until ${gracePeriodEnd}`);

        // TODO: Send grace period notification email/SMS
        await this.sendGracePeriodNotification(subscription, gracePeriodEnd);
    }

    /**
     * Downgrade subscription to free plan
     */
    async downgradeToFree(subscription, reason) {
        const newEndDate = new Date(Date.now() + (30 * 24 * 60 * 60 * 1000)); // 30 days from now

        await db.query(`
            UPDATE user_simple_subscriptions 
            SET 
                plan_code = 'Free',
                plan_name = 'Free Plan',
                status = 'active',
                payment_status = 'completed',
                subscription_start_date = CURRENT_TIMESTAMP,
                subscription_end_date = $1,
                grace_period_end = NULL,
                auto_renew = false,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $2
        `, [newEndDate, subscription.id]);

        // Reset response count for new free period
        await db.query(`
            UPDATE user_simple_subscriptions 
            SET responses_used_this_month = 0,
                month_reset_date = DATE_TRUNC('month', CURRENT_TIMESTAMP) + INTERVAL '1 month'
            WHERE id = $1
        `, [subscription.id]);

        console.log(`Downgraded subscription ${subscription.id} to free plan (reason: ${reason})`);

        // TODO: Send downgrade notification
        await this.sendDowngradeNotification(subscription, reason);
    }

    /**
     * Send renewal notifications for subscriptions expiring soon
     */
    async sendRenewalNotifications(results) {
        // Get subscriptions expiring in 7 days
        const renewalWarnings = await db.query(`
            SELECT * FROM user_simple_subscriptions 
            WHERE subscription_end_date BETWEEN CURRENT_TIMESTAMP AND CURRENT_TIMESTAMP + INTERVAL '7 days'
            AND status = 'active'
            AND plan_code != 'Free'
            AND plan_code IS NOT NULL
        `);

        for (const subscription of renewalWarnings.rows) {
            const daysRemaining = Math.ceil(
                (new Date(subscription.subscription_end_date) - new Date()) / (1000 * 60 * 60 * 24)
            );

            // Send notifications at 7, 3, and 1 day marks
            if ([7, 3, 1].includes(daysRemaining)) {
                await this.sendRenewalReminder(subscription, daysRemaining);
            }
        }
    }

    /**
     * Send grace period notification
     */
    async sendGracePeriodNotification(subscription, gracePeriodEnd) {
        // TODO: Implement email/SMS notification
        console.log(`Grace period notification for user ${subscription.user_id}: ${this.gracePeriodDays} days to renew`);
    }

    /**
     * Send downgrade notification
     */
    async sendDowngradeNotification(subscription, reason) {
        // TODO: Implement email/SMS notification
        console.log(`Downgrade notification for user ${subscription.user_id}: ${reason}`);
    }

    /**
     * Send renewal reminder
     */
    async sendRenewalReminder(subscription, daysRemaining) {
        // TODO: Implement email/SMS notification
        console.log(`Renewal reminder for user ${subscription.user_id}: ${daysRemaining} days remaining`);
    }

    /**
     * Log expiration check results for audit trail
     */
    async logExpirationCheckResult(results) {
        try {
            await db.query(`
                INSERT INTO subscription_expiration_logs 
                (check_timestamp, processed_count, grace_period_started, downgraded_to_free, 
                 grace_period_expired, errors, created_at)
                VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP)
            `, [
                new Date(),
                results.processedCount || 0,
                results.gracePeriodStarted || 0,
                results.downgradedToFree || 0,
                results.gracePeriodExpired || 0,
                JSON.stringify(results.errors || [])
            ]);
        } catch (error) {
            // If logging table doesn't exist, create it
            if (error.code === '42P01') {
                await this.createLogTable();
                // Retry logging
                await this.logExpirationCheckResult(results);
            } else {
                console.error('Error logging expiration check result:', error);
            }
        }
    }

    /**
     * Create the logging table if it doesn't exist
     */
    async createLogTable() {
        await db.query(`
            CREATE TABLE IF NOT EXISTS subscription_expiration_logs (
                id SERIAL PRIMARY KEY,
                check_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
                processed_count INTEGER DEFAULT 0,
                grace_period_started INTEGER DEFAULT 0,
                downgraded_to_free INTEGER DEFAULT 0,
                grace_period_expired INTEGER DEFAULT 0,
                errors JSONB DEFAULT '[]'::jsonb,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            )
        `);
        console.log('Created subscription_expiration_logs table');
    }

    /**
     * Manual trigger for testing (remove in production)
     */
    async triggerManualCheck() {
        console.log('Manual subscription expiration check triggered');
        await this.checkExpiredSubscriptions();
    }
}

module.exports = new SubscriptionExpirationService();