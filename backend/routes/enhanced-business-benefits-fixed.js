const express = require('express');
const router = express.Router();
const dbService = require('../services/database');

// Helper to resolve a country identifier (numeric id or code) to numeric id
async function resolveCountryId(client, countryIdOrCode) {
  if (!countryIdOrCode) return null;
  const asNumber = parseInt(countryIdOrCode, 10);
  if (!Number.isNaN(asNumber)) return asNumber;
  const { rows } = await client.query(
    `SELECT id FROM countries WHERE LOWER(code) = LOWER($1) LIMIT 1`,
    [String(countryIdOrCode)]
  );
  return rows[0]?.id || null;
}

/**
 * GET /api/enhanced-business-benefits/:countryId
 * Get all benefit plans for all business types in a country
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

      // Get all business types
      const businessTypesResult = await client.query(
        'SELECT id, name FROM business_types ORDER BY name'
      );

      const benefits = {};
      
      for (const businessType of businessTypesResult.rows) {
        // Get plans for this business type (fallback to default if no custom plans)
        const plansResult = await client.query(
          `SELECT * FROM enhanced_business_benefits 
           WHERE country_id = $1 AND business_type_id = $2 
           ORDER BY plan_code`,
          [resolvedId, businessType.id]
        );

        // If no custom plans, return empty array for now
        const plans = plansResult.rows.map(plan => ({
          planId: plan.id,
          planCode: plan.plan_code,
          planName: plan.plan_name,
          pricingModel: plan.pricing_model,
          features: plan.features || {},
          pricing: plan.pricing || {},
          isActive: plan.is_active
        }));

        benefits[businessType.name] = {
          businessTypeId: businessType.id,
          businessTypeName: businessType.name,
          plans: plans
        };
      }

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
    console.error('Error fetching enhanced business type benefits:', error);
    res.status(500).json({
      error: 'Failed to fetch business type benefits',
      details: error.message
    });
  }
});

/**
 * GET /api/enhanced-business-benefits/:countryId/:businessType
 * Get benefit plans for a specific business type in a country
 */
router.get('/:countryId/:businessType', async (req, res) => {
  try {
    const { countryId, businessType } = req.params;
    const client = await dbService.pool.connect();
    
    try {
      const resolvedId = await resolveCountryId(client, countryId);
      if (!resolvedId) {
        return res.status(400).json({ error: 'Valid country ID or code is required' });
      }

      // Get business type ID
      const businessTypeResult = await client.query(
        'SELECT id, name FROM business_types WHERE LOWER(name) = LOWER($1)',
        [businessType]
      );

      if (businessTypeResult.rows.length === 0) {
        return res.status(404).json({ error: 'Business type not found' });
      }

      const businessTypeData = businessTypeResult.rows[0];

      // Get plans for this business type
      const plansResult = await client.query(
        `SELECT * FROM enhanced_business_benefits 
         WHERE country_id = $1 AND business_type_id = $2 
         ORDER BY plan_code`,
        [resolvedId, businessTypeData.id]
      );

      const plans = plansResult.rows.map(plan => ({
        planId: plan.id,
        planCode: plan.plan_code,
        planName: plan.plan_name,
        pricingModel: plan.pricing_model,
        features: plan.features || {},
        pricing: plan.pricing || {},
        isActive: plan.is_active
      }));

      res.json({
        success: true,
        countryId: resolvedId,
        businessTypeId: businessTypeData.id,
        businessTypeName: businessTypeData.name,
        plans: plans,
        timestamp: new Date().toISOString()
      });

    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Error fetching business type plans:', error);
    res.status(500).json({
      error: 'Failed to fetch business type plans',
      details: error.message
    });
  }
});

/**
 * GET /api/enhanced-business-benefits/admin/:countryId
 * Get all benefit plans for admin management
 */
router.get('/admin/:countryId', async (req, res) => {
  try {
    const { countryId } = req.params;
    const client = await dbService.pool.connect();
    
    try {
      const resolvedId = await resolveCountryId(client, countryId);
      if (!resolvedId) {
        return res.status(400).json({ error: 'Valid country ID or code is required' });
      }

      // Get detailed business type benefits including metadata
      const result = await client.query(`
        SELECT 
          ebb.*,
          bt.name as business_type_name,
          c.name as country_name
        FROM enhanced_business_benefits ebb
        JOIN business_types bt ON ebb.business_type_id = bt.id
        JOIN countries c ON ebb.country_id = c.id
        WHERE ebb.country_id = $1
        ORDER BY bt.name, ebb.plan_code
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
    console.error('Error fetching admin enhanced business type benefits:', error);
    res.status(500).json({
      error: 'Failed to fetch business type benefits',
      details: error.message
    });
  }
});

/**
 * POST /api/enhanced-business-benefits/:countryId/:businessTypeId
 * Create a new benefit plan
 */
router.post('/:countryId/:businessTypeId', async (req, res) => {
  try {
    const { countryId, businessTypeId } = req.params;
    const {
      planCode,
      planName,
      pricingModel,
      features,
      pricing,
      isActive,
      allowedResponseTypes
    } = req.body;

    const client = await dbService.pool.connect();
    
    try {
      const resolvedId = await resolveCountryId(client, countryId);
      if (!resolvedId) {
        return res.status(400).json({ error: 'Valid country ID or code is required' });
      }

      const result = await client.query(
        `INSERT INTO enhanced_business_benefits 
         (country_id, business_type_id, plan_code, plan_name, pricing_model, features, pricing, is_active, allowed_response_types)
         VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8, $9::jsonb)
         RETURNING *`,
        [
          resolvedId,
          parseInt(businessTypeId, 10),
          planCode,
          planName,
          pricingModel,
          JSON.stringify(features || {}),
          JSON.stringify(pricing || {}),
          isActive !== false,
          JSON.stringify(allowedResponseTypes || [])
        ]
      );

      res.status(201).json({
        success: true,
        plan: result.rows[0],
        timestamp: new Date().toISOString()
      });

    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Error creating benefit plan:', error);
    res.status(500).json({
      error: 'Failed to create benefit plan',
      details: error.message
    });
  }
});

/**
 * PUT /api/enhanced-business-benefits/:countryId/:businessTypeId/:planId
 * Update a benefit plan
 */
router.put('/:countryId/:businessTypeId/:planId', async (req, res) => {
  try {
    const { countryId, businessTypeId, planId } = req.params;
    const {
      planCode,
      planName,
      pricingModel,
      features,
      pricing,
      isActive,
      allowedResponseTypes
    } = req.body;

    const client = await dbService.pool.connect();
    
    try {
      const resolvedId = await resolveCountryId(client, countryId);
      if (!resolvedId) {
        return res.status(400).json({ error: 'Valid country ID or code is required' });
      }

      const result = await client.query(
        `UPDATE enhanced_business_benefits 
         SET plan_code = $1, plan_name = $2, pricing_model = $3, 
             features = $4::jsonb, pricing = $5::jsonb, is_active = $6, 
             allowed_response_types = $7::jsonb, updated_at = NOW()
         WHERE id = $8 AND country_id = $9 AND business_type_id = $10
         RETURNING *`,
        [
          planCode,
          planName,
          pricingModel,
          JSON.stringify(features || {}),
          JSON.stringify(pricing || {}),
          isActive !== false,
          JSON.stringify(allowedResponseTypes || []),
          planId,
          resolvedId,
          parseInt(businessTypeId, 10)
        ]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Benefit plan not found' });
      }

      res.json({
        success: true,
        plan: result.rows[0],
        timestamp: new Date().toISOString()
      });

    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Error updating benefit plan:', error);
    res.status(500).json({
      error: 'Failed to update benefit plan',
      details: error.message
    });
  }
});

/**
 * DELETE /api/enhanced-business-benefits/:countryId/:businessTypeId/:planId
 * Delete a benefit plan
 */
router.delete('/:countryId/:businessTypeId/:planId', async (req, res) => {
  try {
    const { countryId, businessTypeId, planId } = req.params;
    const client = await dbService.pool.connect();
    
    try {
      const resolvedId = await resolveCountryId(client, countryId);
      if (!resolvedId) {
        return res.status(400).json({ error: 'Valid country ID or code is required' });
      }

      const result = await client.query(
        'DELETE FROM enhanced_business_benefits WHERE id = $1 AND country_id = $2 AND business_type_id = $3 RETURNING id',
        [planId, resolvedId, parseInt(businessTypeId, 10)]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Benefit plan not found' });
      }

      res.json({
        success: true,
        message: 'Benefit plan deleted successfully',
        timestamp: new Date().toISOString()
      });

    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Error deleting benefit plan:', error);
    res.status(500).json({
      error: 'Failed to delete benefit plan',
      details: error.message
    });
  }
});

module.exports = router;
