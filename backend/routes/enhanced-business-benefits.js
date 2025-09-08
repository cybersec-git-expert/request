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
        // Get plans for this business type
        const plansResult = await client.query(
          `SELECT * FROM enhanced_business_benefits 
           WHERE country_id = $1 AND business_type_id = $2 
           ORDER BY plan_code`,
          [resolvedId, businessType.id]
        );

        // Format plans
        const plans = plansResult.rows.map(plan => ({
          planId: plan.id,
          planCode: plan.plan_code,
          planName: plan.plan_name,
          pricingModel: plan.pricing_model,
          features: plan.features || {},
          pricing: plan.pricing || {},
          allowedResponseTypes: plan.allowed_response_types || [],
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
    console.error('Error fetching enhanced business benefits:', error);
    res.status(500).json({
      error: 'Failed to fetch business benefits',
      details: error.message
    });
  }
});

/**
 * GET /api/enhanced-business-benefits/:countryId/:businessTypeId
 * Get benefit plans for a specific business type in a country
 */
router.get('/:countryId/:businessTypeId', async (req, res) => {
  try {
    const { countryId, businessTypeId } = req.params;
    const client = await dbService.pool.connect();
    
    try {
      const resolvedCountryId = await resolveCountryId(client, countryId);
      if (!resolvedCountryId) {
        return res.status(400).json({ error: 'Valid country ID or code is required' });
      }

      // Get plans for this business type
      const plansResult = await client.query(
        `SELECT ebs.*, bt.name as business_type_name 
         FROM enhanced_business_benefits ebs
         JOIN business_types bt ON ebs.business_type_id = bt.id
         WHERE ebs.country_id = $1 AND ebs.business_type_id = $2 
         ORDER BY ebs.plan_code`,
        [resolvedCountryId, businessTypeId]
      );

      if (plansResult.rows.length === 0) {
        return res.status(404).json({ 
          error: 'No benefit plans found for this business type and country' 
        });
      }

      const plans = plansResult.rows.map(plan => ({
        planId: plan.id,
        planCode: plan.plan_code,
        planName: plan.plan_name,
        pricingModel: plan.pricing_model,
        features: plan.features || {},
        pricing: plan.pricing || {},
        allowedResponseTypes: plan.allowed_response_types || [],
        isActive: plan.is_active
      }));

      res.json({
        success: true,
        countryId: resolvedCountryId,
        businessTypeId: businessTypeId,
        businessTypeName: plansResult.rows[0].business_type_name,
        plans: plans,
        timestamp: new Date().toISOString()
      });

    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Error fetching enhanced business benefits for specific type:', error);
    res.status(500).json({
      error: 'Failed to fetch business benefits',
      details: error.message
    });
  }
});

/**
 * POST /api/enhanced-business-benefits
 * Create a new benefit plan
 */
router.post('/', async (req, res) => {
  try {
    const {
      countryId,
      businessTypeId,
      planCode,
      planName,
      pricingModel,
      features = {},
      pricing = {},
      allowedResponseTypes = []
    } = req.body;

    // Validate required fields
    if (!countryId || !businessTypeId || !planCode || !planName || !pricingModel) {
      return res.status(400).json({
        error: 'Missing required fields: countryId, businessTypeId, planCode, planName, pricingModel'
      });
    }

    // Validate pricing model
    const validPricingModels = ['response_based', 'pay_per_click', 'monthly_subscription', 'bundle'];
    if (!validPricingModels.includes(pricingModel)) {
      return res.status(400).json({
        error: `Invalid pricing model. Must be one of: ${validPricingModels.join(', ')}`
      });
    }

    const client = await dbService.pool.connect();
    
    try {
      const resolvedCountryId = await resolveCountryId(client, countryId);
      if (!resolvedCountryId) {
        return res.status(400).json({ error: 'Valid country ID or code is required' });
      }

      // Insert new plan
      const result = await client.query(
        `INSERT INTO enhanced_business_benefits 
         (country_id, business_type_id, plan_code, plan_name, pricing_model, features, pricing, allowed_response_types)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING *`,
        [
          resolvedCountryId,
          businessTypeId,
          planCode,
          planName,
          pricingModel,
          JSON.stringify(features),
          JSON.stringify(pricing),
          JSON.stringify(allowedResponseTypes)
        ]
      );

      const newPlan = result.rows[0];

      res.status(201).json({
        success: true,
        plan: {
          planId: newPlan.id,
          planCode: newPlan.plan_code,
          planName: newPlan.plan_name,
          pricingModel: newPlan.pricing_model,
          features: newPlan.features,
          pricing: newPlan.pricing,
          allowedResponseTypes: newPlan.allowed_response_types,
          isActive: newPlan.is_active
        },
        timestamp: new Date().toISOString()
      });

    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Error creating enhanced business benefit plan:', error);
    
    if (error.code === '23505') { // Unique violation
      return res.status(409).json({
        error: 'Plan code already exists',
        details: error.detail
      });
    }
    
    res.status(500).json({
      error: 'Failed to create business benefit plan',
      details: error.message
    });
  }
});

/**
 * PUT /api/enhanced-business-benefits/:planId
 * Update an existing benefit plan
 */
router.put('/:planId', async (req, res) => {
  try {
    const { planId } = req.params;
    const {
      planName,
      pricingModel,
      features,
      pricing,
      allowedResponseTypes,
      isActive
    } = req.body;

    const client = await dbService.pool.connect();
    
    try {
      // Build dynamic update query
      const updates = [];
      const values = [];
      let paramIndex = 1;

      if (planName !== undefined) {
        updates.push(`plan_name = $${paramIndex++}`);
        values.push(planName);
      }
      if (pricingModel !== undefined) {
        updates.push(`pricing_model = $${paramIndex++}`);
        values.push(pricingModel);
      }
      if (features !== undefined) {
        updates.push(`features = $${paramIndex++}`);
        values.push(JSON.stringify(features));
      }
      if (pricing !== undefined) {
        updates.push(`pricing = $${paramIndex++}`);
        values.push(JSON.stringify(pricing));
      }
      if (allowedResponseTypes !== undefined) {
        updates.push(`allowed_response_types = $${paramIndex++}`);
        values.push(JSON.stringify(allowedResponseTypes));
      }
      if (isActive !== undefined) {
        updates.push(`is_active = $${paramIndex++}`);
        values.push(isActive);
      }

      if (updates.length === 0) {
        return res.status(400).json({ error: 'No fields to update' });
      }

      updates.push(`updated_at = CURRENT_TIMESTAMP`);
      values.push(planId);

      const query = `
        UPDATE enhanced_business_benefits 
        SET ${updates.join(', ')}
        WHERE id = $${paramIndex}
        RETURNING *
      `;

      const result = await client.query(query, values);

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Benefit plan not found' });
      }

      const updatedPlan = result.rows[0];

      res.json({
        success: true,
        plan: {
          planId: updatedPlan.id,
          planCode: updatedPlan.plan_code,
          planName: updatedPlan.plan_name,
          pricingModel: updatedPlan.pricing_model,
          features: updatedPlan.features,
          pricing: updatedPlan.pricing,
          allowedResponseTypes: updatedPlan.allowed_response_types,
          isActive: updatedPlan.is_active
        },
        timestamp: new Date().toISOString()
      });

    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Error updating enhanced business benefit plan:', error);
    res.status(500).json({
      error: 'Failed to update business benefit plan',
      details: error.message
    });
  }
});

/**
 * DELETE /api/enhanced-business-benefits/:planId
 * Delete a benefit plan
 */
router.delete('/:planId', async (req, res) => {
  try {
    const { planId } = req.params;
    const client = await dbService.pool.connect();
    
    try {
      const result = await client.query(
        'DELETE FROM enhanced_business_benefits WHERE id = $1 RETURNING plan_code',
        [planId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Benefit plan not found' });
      }

      res.json({
        success: true,
        message: `Benefit plan ${result.rows[0].plan_code} deleted successfully`,
        timestamp: new Date().toISOString()
      });

    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Error deleting enhanced business benefit plan:', error);
    res.status(500).json({
      error: 'Failed to delete business benefit plan',
      details: error.message
    });
  }
});

module.exports = router;
