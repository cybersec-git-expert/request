const express = require('express');
const router = express.Router();
const dbService = require('../services/database');

// Helper to resolve a country identifier (numeric id or code) to numeric id
async function resolveCountryId(client, countryIdOrCode) {
  if (!countryIdOrCode) return null;
  const asNumber = parseInt(countryIdOrCode, 10);
  if (!Number.isNaN(asNumber)) return asNumber;
  // Try resolve by country code columns
  const { rows } = await client.query(
    `SELECT id FROM countries WHERE LOWER(code) = LOWER($1) OR LOWER(country_code) = LOWER($1) LIMIT 1`,
    [String(countryIdOrCode)]
  );
  return rows[0]?.id || null;
}

/**
 * GET /api/business-type-benefits/:countryId
 * Get business type benefits configuration for a specific country (id or code)
 */
router.get('/:countryId', async (req, res) => {
  try {
    const { countryId } = req.params;
    const client = await dbService.pool.connect();
    
    try {
      const resolvedId = await resolveCountryId(client, countryId);
      if (!resolvedId) {
        return res.status(400).json({ error: 'Valid country ID or code is required' });
      }
      // Get business type benefits for the specified country
      const result = await client.query(
        'SELECT * FROM get_business_type_benefits($1)',
        [resolvedId]
      );
      
      // Transform the data into a more Flutter-friendly format
      const benefits = {};
      
      result.rows.forEach(row => {
        benefits[row.business_type_name] = {
          businessTypeId: row.business_type_id,
          businessTypeName: row.business_type_name,
          freePlan: {
            responsesPerMonth: row.free_responses_per_month || 3,
            contactRevealed: row.free_contact_revealed || false,
            canMessageRequester: row.free_can_message_requester || false,
            respondButtonEnabled: row.free_respond_button_enabled !== false, // default true
            instantNotifications: row.free_instant_notifications || false,
            priorityInSearch: row.free_priority_in_search || false
          },
          paidPlan: {
            responsesPerMonth: row.paid_responses_per_month || -1, // -1 = unlimited
            contactRevealed: row.paid_contact_revealed !== false, // default true
            canMessageRequester: row.paid_can_message_requester !== false, // default true
            respondButtonEnabled: row.paid_respond_button_enabled !== false, // default true
            instantNotifications: row.paid_instant_notifications !== false, // default true
            priorityInSearch: row.paid_priority_in_search !== false // default true
          }
        };
      });

      res.json({
        success: true,
  countryId: resolvedId,
        businessTypeBenefits: benefits,
        timestamp: new Date().toISOString()
      });

    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Error fetching business type benefits:', error);
    res.status(500).json({
      error: 'Failed to fetch business type benefits',
      details: error.message
    });
  }
});

/**
 * PUT /api/business-type-benefits/:countryId/:businessTypeId/:planType
 * Update business type benefits (admin only)
 */
router.put('/:countryId/:businessTypeId/:planType', async (req, res) => {
  try {
    const { countryId, businessTypeId, planType } = req.params;
    const {
      responsesPerMonth,
      contactRevealed,
      canMessageRequester,
      respondButtonEnabled,
      instantNotifications,
      priorityInSearch
    } = req.body;

    // Validate parameters
    const client = await dbService.pool.connect();
    const resolvedId = await resolveCountryId(client, countryId);
    if (!resolvedId) {
      client.release();
      return res.status(400).json({ error: 'Valid country ID or code is required' });
    }

    if (!businessTypeId || isNaN(parseInt(businessTypeId, 10))) {
      return res.status(400).json({ error: 'Valid business type ID is required' });
    }
    
    if (!['free', 'paid'].includes(planType)) {
      return res.status(400).json({ error: 'Plan type must be either "free" or "paid"' });
    }

    // TODO: Add admin authentication middleware
    // For now, we'll accept updates but in production this should be protected
    const adminUserId = req.user?.id || null; // Assuming auth middleware sets req.user

    try {
      // Update business type benefits using the stored function
      const result = await client.query(
        'SELECT update_business_type_benefits($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)',
        [
          resolvedId,
          parseInt(businessTypeId, 10),
          planType,
          responsesPerMonth !== undefined ? parseInt(responsesPerMonth) : null,
          contactRevealed !== undefined ? Boolean(contactRevealed) : null,
          canMessageRequester !== undefined ? Boolean(canMessageRequester) : null,
          respondButtonEnabled !== undefined ? Boolean(respondButtonEnabled) : null,
          instantNotifications !== undefined ? Boolean(instantNotifications) : null,
          priorityInSearch !== undefined ? Boolean(priorityInSearch) : null,
          adminUserId
        ]
      );

      const updateResult = result.rows[0].update_business_type_benefits;
      
      if (updateResult.success) {
        res.json({
          success: true,
          message: 'Business type benefits updated successfully',
          timestamp: new Date().toISOString()
        });
      } else {
        res.status(400).json({
          success: false,
          error: updateResult.message || 'Failed to update business type benefits'
        });
      }

    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Error updating business type benefits:', error);
    res.status(500).json({
      error: 'Failed to update business type benefits',
      details: error.message
    });
  }
});

/**
 * GET /api/business-type-benefits/admin/:countryId
 * Get all business type benefits for admin management (includes metadata). Accepts id or code.
 */
router.get('/admin/:countryId', async (req, res) => {
  try {
    const { countryId } = req.params;

    // TODO: Add admin authentication middleware
    // For now, we'll allow access but in production this should be protected

    const client = await dbService.pool.connect();
    
    try {
      const resolvedId = await resolveCountryId(client, countryId);
      if (!resolvedId) {
        client.release();
        return res.status(400).json({ error: 'Valid country ID or code is required' });
      }
      // Get detailed business type benefits including metadata
      const result = await client.query(`
        SELECT 
          btb.*,
          bt.name as business_type_name,
          c.name as country_name
        FROM business_type_benefits btb
        JOIN business_types bt ON btb.business_type_id = bt.id
        JOIN countries c ON btb.country_id = c.id
        /* Handle mixed integer/uuid user id types by casting to text for join */
        LEFT JOIN users creator ON CAST(btb.created_by AS TEXT) = CAST(creator.id AS TEXT)
        LEFT JOIN users updater ON CAST(btb.updated_by AS TEXT) = CAST(updater.id AS TEXT)
        WHERE btb.country_id = $1
        ORDER BY bt.name, btb.plan_type
      `, [resolvedId]);

      res.json({
        success: true,
        countryId: resolvedId,
        benefits: result.rows,
        timestamp: new Date().toISOString()
      });

    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Error fetching admin business type benefits:', error);
    res.status(500).json({
      error: 'Failed to fetch admin business type benefits',
      details: error.message
    });
  }
});

module.exports = router;
