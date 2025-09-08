// entitlements.js - User subscription entitlements service

const dbService = require('./database');

class EntitlementsService {
  
  /**
   * Check if user can see contact details in responses
   * @param {string} userId - User UUID
   * @returns {Promise<boolean>}
   */
  async canSeeContactDetails(userId) {
    try {
      // Get user's active subscription
      const subscription = await this.getUserActiveSubscription(userId);
      
      if (!subscription) {
        // Free user - check if they've used their 3 responses
        const responseCount = await this.getUserResponseCount(userId);
        return responseCount < 3;
      }
      
      // Subscribed user - always can see contacts
      return true;
    } catch (error) {
      console.error('Error checking contact details entitlement:', error);
      return false;
    }
  }

  /**
   * Check if user can send messages
   * @param {string} userId - User UUID
   * @returns {Promise<boolean>}
   */
  async canSendMessages(userId) {
    try {
      // Same logic as contact details
      return await this.canSeeContactDetails(userId);
    } catch (error) {
      console.error('Error checking messaging entitlement:', error);
      return false;
    }
  }

  /**
   * Check if user can respond to requests
   * @param {string} userId - User UUID
   * @returns {Promise<boolean>}
   */
  async canRespond(userId) {
    try {
      const subscription = await this.getUserActiveSubscription(userId);
      
      if (!subscription) {
        // Free user - check response limit
        const responseCount = await this.getUserResponseCount(userId);
        return responseCount < 3;
      }
      
      // Subscribed user - check plan limits
      const plan = await this.getSubscriptionPlan(subscription.plan_id);
      if (!plan.response_limit) return true; // Unlimited
      
      const responseCount = await this.getUserResponseCount(userId);
      return responseCount < plan.response_limit;
    } catch (error) {
      console.error('Error checking response entitlement:', error);
      return false;
    }
  }

  /**
   * Check if user should receive notifications for a request type
   * @param {string} userId - User UUID  
   * @param {string} requestType - Type of request (ride, delivery, tour, etc.)
   * @returns {Promise<boolean>}
   */
  async shouldReceiveNotifications(userId, requestType) {
    try {
      const subscription = await this.getUserActiveSubscription(userId);
      if (!subscription) return false; // Free users don't get notifications
      
      const plan = await this.getSubscriptionPlan(subscription.plan_id);
      const userProfile = await this.getUserProfile(userId);
      
      // Check if plan covers this request type
      if (plan.response_type === 'all') return true;
      if (plan.response_type === requestType) return true;
      
      // For business users, check if it matches their business type
      if (userProfile.business_type && requestType === userProfile.business_type) {
        return true;
      }
      
      // Common requests that anyone can respond to
  const commonRequests = ['item', 'service', 'rent', 'tour', 'event', 'construction', 'education', 'hiring', 'job', 'other'];
      if (commonRequests.includes(requestType)) {
        return plan.response_type === 'other' || plan.response_type === 'all';
      }
      
      return false;
    } catch (error) {
      console.error('Error checking notification entitlement:', error);
      return false;
    }
  }

  /**
   * Get user's active subscription
   * @param {string} userId - User UUID
   * @returns {Promise<Object|null>}
   */
  async getUserActiveSubscription(userId) {
    try {
      const query = `
        SELECT urs.*, urp.response_type, urp.response_limit, urp.features
        FROM user_response_subscriptions urs
        JOIN user_response_plans urp ON urs.plan_id = urp.id
        WHERE urs.user_id = $1 AND urs.is_active = true AND urs.expires_at > NOW()
        ORDER BY urs.created_at DESC
        LIMIT 1
      `;
      
      const result = await dbService.query(query, [userId]);
      return result.rows[0] || null;
    } catch (error) {
      console.error('Error getting user subscription:', error);
      return null;
    }
  }

  /**
   * Get user's response count for current month
   * @param {string} userId - User UUID
   * @returns {Promise<number>}
   */
  async getUserResponseCount(userId) {
    try {
      const query = `
        SELECT COUNT(*) as count
        FROM responses 
        WHERE user_id = $1 
        AND created_at >= date_trunc('month', CURRENT_DATE)
        AND created_at < date_trunc('month', CURRENT_DATE) + interval '1 month'
      `;
      
      const result = await dbService.query(query, [userId]);
      return parseInt(result.rows[0]?.count || 0);
    } catch (error) {
      console.error('Error getting user response count:', error);
      return 0;
    }
  }

  /**
   * Get subscription plan details
   * @param {string} planId - Plan UUID
   * @returns {Promise<Object|null>}
   */
  async getSubscriptionPlan(planId) {
    try {
      const query = `SELECT * FROM user_response_plans WHERE id = $1`;
      const result = await dbService.query(query, [planId]);
      return result.rows[0] || null;
    } catch (error) {
      console.error('Error getting subscription plan:', error);
      return null;
    }
  }

  /**
   * Get user profile with business type
   * @param {string} userId - User UUID
   * @returns {Promise<Object|null>}
   */
  async getUserProfile(userId) {
    try {
      const query = `
        SELECT u.*, bv.business_type 
        FROM users u
        LEFT JOIN business_verifications bv ON u.id = bv.user_id
        WHERE u.id = $1
      `;
      
      const result = await dbService.query(query, [userId]);
      return result.rows[0] || null;
    } catch (error) {
      console.error('Error getting user profile:', error);
      return null;
    }
  }

  /**
   * Get entitlements summary for a user
   * @param {string} userId - User UUID
   * @returns {Promise<Object>}
   */
  async getUserEntitlements(userId) {
    try {
      const [canSeeContacts, canMessage, canRespond, subscription] = await Promise.all([
        this.canSeeContactDetails(userId),
        this.canSendMessages(userId),
        this.canRespond(userId),
        this.getUserActiveSubscription(userId)
      ]);

      const responseCount = await this.getUserResponseCount(userId);
      
      return {
        canSeeContactDetails: canSeeContacts,
        canSendMessages: canMessage,
        canRespond: canRespond,
        responseCount,
        remainingResponses: subscription ? 'unlimited' : Math.max(0, 3 - responseCount),
        subscriptionType: subscription ? subscription.response_type : 'free',
        planName: subscription ? subscription.name : 'Free Plan'
      };
    } catch (error) {
      console.error('Error getting user entitlements:', error);
      return {
        canSeeContactDetails: false,
        canSendMessages: false,
        canRespond: false,
        responseCount: 0,
        remainingResponses: 0,
        subscriptionType: 'free',
        planName: 'Free Plan'
      };
    }
  }
}

module.exports = new EntitlementsService();
