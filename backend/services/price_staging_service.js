const database = require('./database');
const cron = require('node-cron');

class PriceStagingService {
  constructor() {
    this.scheduleDailyUpdate();
  }

  /**
   * Schedule daily price update at 1 AM
   */
  scheduleDailyUpdate() {
    // Schedule for 1:00 AM every day (cron format: minute hour day month dayofweek)
    cron.schedule('0 1 * * *', async () => {
      console.log('🕐 Starting daily price update at 1 AM...');
      try {
        const result = await this.applyAllStagedPrices();
        console.log(`✅ Daily price update completed. Updated ${result.updatedCount} prices.`);
      } catch (error) {
        console.error('❌ Error during daily price update:', error);
      }
    }, {
      scheduled: true,
      timezone: 'Asia/Colombo' // Sri Lanka timezone
    });

    console.log('📅 Daily price update scheduler initialized for 1:00 AM Sri Lanka time');
  }

  /**
   * Stage a price update for a business
   */
  async stagePriceUpdate(businessId, priceListingId, stagedData) {
    try {
      console.log('DEBUG: stagePriceUpdate called with:', { businessId, priceListingId, stagedData });
      
      // First check if the price listing belongs to this business
      const checkSql = `
        SELECT pl.*, mp.name as product_name
        FROM price_listings pl
        JOIN master_products mp ON mp.id = pl.master_product_id
        WHERE pl.id = $1 AND pl.business_id = $2
      `;
      console.log('DEBUG: Executing query with params:', [priceListingId, businessId]);
      const listingResult = await database.query(checkSql, [priceListingId, businessId]);
      console.log('DEBUG: Query result rows:', listingResult.rows.length);
      
      if (listingResult.rows.length === 0) {
        // Let's also check what business_id the price listing actually has
        const debugSql = `
          SELECT pl.business_id, pl.id, mp.name as product_name
          FROM price_listings pl
          JOIN master_products mp ON mp.id = pl.master_product_id
          WHERE pl.id = $1
        `;
        const debugResult = await database.query(debugSql, [priceListingId]);
        console.log('DEBUG: Price listing exists with business_id:', debugResult.rows);
        
        throw new Error('Price listing not found or does not belong to this business');
      }

      const listing = listingResult.rows[0];

      // Insert or update staging record
      const stagingSql = `
        INSERT INTO price_staging (
          business_id, 
          price_listing_id, 
          master_product_id,
          staged_price,
          currency,
          staged_stock_quantity,
          staged_is_available,
          staged_whatsapp_number,
          staged_product_link,
          staged_model_number,
          staged_selected_variables
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        ON CONFLICT (price_listing_id) 
        DO UPDATE SET
          staged_price = EXCLUDED.staged_price,
          staged_stock_quantity = EXCLUDED.staged_stock_quantity,
          staged_is_available = EXCLUDED.staged_is_available,
          staged_whatsapp_number = EXCLUDED.staged_whatsapp_number,
          staged_product_link = EXCLUDED.staged_product_link,
          staged_model_number = EXCLUDED.staged_model_number,
          staged_selected_variables = EXCLUDED.staged_selected_variables,
          updated_at = CURRENT_TIMESTAMP,
          is_processed = false
        RETURNING *
      `;

      const stagingResult = await database.query(stagingSql, [
        businessId,
        priceListingId,
        listing.master_product_id,
        stagedData.price || listing.price,
        stagedData.currency || listing.currency || 'LKR',
        stagedData.stockQuantity || listing.stock_quantity || 1,
        stagedData.isAvailable !== undefined ? stagedData.isAvailable : listing.is_available,
        stagedData.whatsappNumber || listing.whatsapp_number,
        stagedData.productLink || listing.product_link,
        stagedData.modelNumber || listing.model_number,
        stagedData.selectedVariables || listing.selected_variables || {}
      ]);

      // Record the staging action in history
      await this.recordPriceHistory(
        priceListingId,
        businessId,
        listing.price,
        stagedData.price,
        'staged',
        'user'
      );

      return {
        success: true,
        staged: stagingResult.rows[0],
        message: 'Price staged successfully. Will be applied at next daily update (1 AM).'
      };
    } catch (error) {
      console.error('Error staging price update:', error);
      throw error;
    }
  }

  /**
   * Get all staged prices for a business
   */
  async getBusinessStagedPrices(businessId) {
    try {
      const sql = `
        SELECT 
          ps.*,
          pl.price as current_price,
          pl.currency as current_currency,
          pl.stock_quantity as current_stock_quantity,
          pl.is_available as current_is_available,
          mp.name as product_name,
          mp.images as product_images
        FROM price_staging ps
        JOIN price_listings pl ON pl.id = ps.price_listing_id
        JOIN master_products mp ON mp.id = ps.master_product_id
        WHERE ps.business_id = $1 AND ps.is_processed = false
        ORDER BY ps.updated_at DESC
      `;

      const result = await database.query(sql, [businessId]);
      return result.rows;
    } catch (error) {
      console.error('Error getting staged prices:', error);
      throw error;
    }
  }

  /**
   * Cancel a staged price update
   */
  async cancelStagedPrice(businessId, priceListingId) {
    try {
      const sql = `
        DELETE FROM price_staging 
        WHERE business_id = $1 AND price_listing_id = $2 AND is_processed = false
        RETURNING *
      `;

      const result = await database.query(sql, [businessId, priceListingId]);
      
      if (result.rows.length === 0) {
        throw new Error('No staged price found to cancel');
      }

      return {
        success: true,
        message: 'Staged price cancelled successfully'
      };
    } catch (error) {
      console.error('Error cancelling staged price:', error);
      throw error;
    }
  }

  /**
   * Apply all staged prices (called by scheduler or manually)
   */
  async applyAllStagedPrices() {
    try {
      // Call the database function to apply staged prices
      const result = await database.query('SELECT apply_staged_prices() as updated_count');
      const updatedCount = result.rows[0].updated_count;

      return {
        success: true,
        updatedCount,
        appliedAt: new Date().toISOString(),
        message: `Applied ${updatedCount} staged price updates`
      };
    } catch (error) {
      console.error('Error applying staged prices:', error);
      throw error;
    }
  }

  /**
   * Get business staging summary
   */
  async getBusinessStagingSummary(businessId) {
    try {
      const result = await database.query(
        'SELECT * FROM get_business_staging_summary($1)',
        [businessId]
      );

      return result.rows[0] || {
        total_staged: 0,
        total_value: 0,
        last_update: null
      };
    } catch (error) {
      console.error('Error getting staging summary:', error);
      throw error;
    }
  }

  /**
   * Get price update history for a business
   */
  async getPriceHistory(businessId, limit = 50) {
    try {
      const sql = `
        SELECT 
          puh.*,
          pl.title as product_name,
          mp.name as master_product_name
        FROM price_update_history puh
        JOIN price_listings pl ON pl.id = puh.price_listing_id
        JOIN master_products mp ON mp.id = pl.master_product_id
        WHERE puh.business_id = $1
        ORDER BY puh.applied_at DESC
        LIMIT $2
      `;

      const result = await database.query(sql, [businessId, limit]);
      return result.rows;
    } catch (error) {
      console.error('Error getting price history:', error);
      throw error;
    }
  }

  /**
   * Record price change in history
   */
  async recordPriceHistory(priceListingId, businessId, oldPrice, newPrice, changeType, appliedBy) {
    try {
      const priceChangePercentage = oldPrice > 0 
        ? ((newPrice - oldPrice) / oldPrice * 100).toFixed(2)
        : 0;

      const sql = `
        INSERT INTO price_update_history (
          price_listing_id,
          business_id,
          old_price,
          new_price,
          price_change_percentage,
          change_type,
          applied_by
        ) VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING *
      `;

      const result = await database.query(sql, [
        priceListingId,
        businessId,
        oldPrice,
        newPrice,
        priceChangePercentage,
        changeType,
        appliedBy
      ]);

      return result.rows[0];
    } catch (error) {
      console.error('Error recording price history:', error);
      throw error;
    }
  }

  /**
   * Manual trigger for price application (for testing or emergency updates)
   */
  async triggerManualUpdate() {
    console.log('🔧 Manual price update triggered...');
    return await this.applyAllStagedPrices();
  }

  /**
   * Get next scheduled update time
   */
  getNextUpdateTime() {
    const now = new Date();
    const tomorrow = new Date(now);
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(1, 0, 0, 0); // 1:00 AM

    return tomorrow;
  }
}

module.exports = new PriceStagingService();
