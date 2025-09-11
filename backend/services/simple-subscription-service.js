const dbService = require('./database');

class SimpleSubscriptionService {
    constructor() {
        this.FREE_RESPONSES_PER_MONTH = 3;
    }

    /**
     * Get current month in YYYY-MM format
     */
    getCurrentMonth() {
        const now = new Date();
        return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    }

    /**
     * Get user's usage for current month
     */
    async getUserUsage(userId) {
        try {
            const currentMonth = this.getCurrentMonth();
            
            const result = await dbService.query(`
                SELECT responses_used 
                FROM user_usage 
                WHERE user_id = $1 AND month_year = $2
            `, [userId, currentMonth]);

            if (result.rows.length === 0) {
                // Create new record for this user/month
                await dbService.query(`
                    INSERT INTO user_usage (user_id, month_year, responses_used)
                    VALUES ($1, $2, 0)
                    ON CONFLICT (user_id, month_year) DO NOTHING
                `, [userId, currentMonth]);
                return 0;
            }

            return result.rows[0].responses_used;
        } catch (error) {
            console.error('Error getting user usage:', error);
            throw error;
        }
    }

    /**
     * Check if user can make a response
     */
    async canUserRespond(userId) {
        try {
            const currentUsage = await this.getUserUsage(userId);
            return currentUsage < this.FREE_RESPONSES_PER_MONTH;
        } catch (error) {
            console.error('Error checking user response limit:', error);
            return false;
        }
    }

    /**
     * Increment user's response count
     */
    async incrementUserUsage(userId) {
        try {
            const currentMonth = this.getCurrentMonth();
            
            await dbService.query(`
                INSERT INTO user_usage (user_id, month_year, responses_used)
                VALUES ($1, $2, 1)
                ON CONFLICT (user_id, month_year) 
                DO UPDATE SET 
                    responses_used = user_usage.responses_used + 1,
                    updated_at = CURRENT_TIMESTAMP
            `, [userId, currentMonth]);

            return true;
        } catch (error) {
            console.error('Error incrementing user usage:', error);
            throw error;
        }
    }

    /**
     * Get user's subscription status
     */
    async getUserSubscriptionStatus(userId) {
        try {
            const currentUsage = await this.getUserUsage(userId);
            const remainingResponses = Math.max(0, this.FREE_RESPONSES_PER_MONTH - currentUsage);
            
            return {
                plan: 'free',
                responsesUsed: currentUsage,
                responsesLimit: this.FREE_RESPONSES_PER_MONTH,
                remainingResponses: remainingResponses,
                canRespond: remainingResponses > 0,
                currentMonth: this.getCurrentMonth()
            };
        } catch (error) {
            console.error('Error getting subscription status:', error);
            throw error;
        }
    }

    /**
     * Reset all users' usage for new month (can be run via cron)
     */
    async resetMonthlyUsage() {
        try {
            const currentMonth = this.getCurrentMonth();
            console.log(`🔄 Resetting usage for month: ${currentMonth}`);
            
            // This will be handled automatically by our month-based tracking
            // But we can clean up old records (older than 6 months)
            const sixMonthsAgo = new Date();
            sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);
            const cleanupMonth = `${sixMonthsAgo.getFullYear()}-${String(sixMonthsAgo.getMonth() + 1).padStart(2, '0')}`;
            
            await dbService.query(`
                DELETE FROM user_usage 
                WHERE month_year < $1
            `, [cleanupMonth]);
            
            console.log(`✅ Cleaned up usage records older than ${cleanupMonth}`);
            return true;
        } catch (error) {
            console.error('Error resetting monthly usage:', error);
            throw error;
        }
    }
}

module.exports = new SimpleSubscriptionService();
