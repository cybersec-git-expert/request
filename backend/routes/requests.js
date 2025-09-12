const express = require('express');
const router = express.Router();
const database = require('../services/database');
const auth = require('../services/auth');
const responsesRouter = require('./responses');
const notify = require('../services/notification-helper');
const BusinessNotificationService = require('../services/business-notification-service'); // NEW
const entitlements = require('../services/entitlements-service'); // NEW - for gating contact visibility

// Optional auth wrapper (copied pattern used in responses)
function optionalAuth(handler){
  return async (req,res,next)=>{
    try {
      const hasAuthHeader = !!req.headers.authorization;
      if (hasAuthHeader) {
        let authErrored = false;
        await auth.authMiddleware()(req, {
          status:(code)=>({ json:(obj)=>{ authErrored = true; res.status(code).json(obj); } })
        }, ()=>{});
        if (authErrored) {
          if (process.env.NODE_ENV !== 'development') return; // response already sent
          console.warn('[requests][optionalAuth] auth header present but failed verification; continuing (dev only).');
        }
      } else if (process.env.NODE_ENV === 'development') {
        console.warn('[requests][optionalAuth] no Authorization header; continuing unauthenticated (dev only).');
      }
      return handler(req,res,next);
    } catch(e){
      next(e);
    }
  };
}

// Helper to mask contact details based on entitlements, ownership, and if viewer already responded
function applyContactGating(row, viewer) {
  const viewerId = viewer?.id || viewer?.userId || null;
  const isOwner = viewerId && row.user_id === viewerId;
  const hasResponded = !!viewer?.hasResponded; // viewer responded to this request
  const ent = viewer?.entitlements || null;
  // Contact can be viewed ONLY by owner or if the viewer already responded
  const canViewContact = isOwner || hasResponded;
  // Messaging may be allowed by entitlements (and always by owner/responded)
  const canMessage = isOwner || hasResponded || (ent ? !!ent.canMessage : false);
  // Shallow copy to avoid mutating original
  const masked = { ...row };
  if (!canViewContact) {
    // Hide requester phone; keep email as-is per requirement (phone + message icon)
    if ('user_phone' in masked) masked.user_phone = null;
  }
  masked.contact_visible = !!canViewContact;
  masked.can_message = !!canMessage;
  return masked;
}

// Get requests with optional filtering
router.get('/', optionalAuth(async (req, res) => {
  try {
    const {
      category_id,
      subcategory_id,
      city_id,
      country_code, // no default so super admins (or unspecified) see all countries
      status,
      user_id,
      has_accepted,
      request_type, // Filter by request type: item, service, ride, rent, delivery
      page = 1,
      limit = 20,
      sort_by = 'created_at',
      sort_order = 'DESC'
    } = req.query;

    // Build dynamic query
    const conditions = [];
    const values = [];
    let paramCounter = 1;
    // Default: only active unless explicitly filtering accepted or specifying status
    if (status) {
      conditions.push(`r.status = $${paramCounter++}`);
      values.push(status);
    } else if (has_accepted === 'true') {
      // don't force status; accepted requests are typically closed
    } else {
      conditions.push(`r.status = $${paramCounter++}`);
      values.push('active');
    }

    if (category_id) {
      conditions.push(`r.category_id = $${paramCounter++}`);
      values.push(category_id);
    }
    if (subcategory_id) {
      conditions.push(`r.subcategory_id = $${paramCounter++}`);
      values.push(subcategory_id);
    }
    if (city_id) {
      conditions.push(`r.location_city_id = $${paramCounter++}`);
      values.push(city_id);
    }
    if (request_type) {
      // Normalize legacy aliases for filtering
      let rt = String(request_type).toLowerCase();
      if (/^requesttype\./i.test(rt)) rt = rt.split('.')?.pop() || rt;
      const map = { 'item_request':'item','service_request':'service','ride_request':'ride','rent_request':'rent','delivery_request':'delivery', 'hiring':'job','job_request':'job','jobs':'job' };
      if (map[rt]) rt = map[rt];
      conditions.push(`r.request_type = $${paramCounter++}`);
      values.push(rt);
    }
    if (country_code) { // only filter when explicitly provided
      conditions.push(`r.country_code = $${paramCounter++}`);
      values.push(country_code);
    }
    if (user_id) {
      conditions.push(`r.user_id = $${paramCounter++}`);
      values.push(user_id);
    }
    if (has_accepted === 'true') {
      conditions.push('r.accepted_response_id IS NOT NULL');
    }

    const offset = (page - 1) * limit;
  const validSortColumns = ['created_at', 'updated_at', 'title', 'budget'];
    const finalSortBy = validSortColumns.includes(sort_by) ? sort_by : 'created_at';
    const finalSortOrder = sort_order.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';

  const query = `
      SELECT 
        r.*,
        u.display_name as user_name,
        u.email as user_email,
        c.name as category_name,
        c.request_type as category_request_type,
        sc.name as subcategory_name,
        ct.name as city_name,
        COALESCE(r.country_code, ct.country_code) as effective_country_code,
        co.default_currency as country_default_currency,
        rc.response_count
      FROM requests r
      LEFT JOIN users u ON r.user_id = u.id
      LEFT JOIN categories c ON r.category_id = c.id
      LEFT JOIN sub_categories sc ON r.subcategory_id = sc.id
      LEFT JOIN cities ct ON r.location_city_id = ct.id
      LEFT JOIN countries co ON r.country_code = co.code
      LEFT JOIN LATERAL (
        SELECT COUNT(*)::int AS response_count
        FROM responses resp
        WHERE resp.request_id = r.id
      ) rc ON TRUE
      WHERE ${conditions.join(' AND ')}
      ORDER BY 
        CASE WHEN r.is_urgent = true AND (r.urgent_until IS NULL OR r.urgent_until > NOW()) THEN 0 ELSE 1 END,
        r.${finalSortBy} ${finalSortOrder}
      LIMIT $${paramCounter++} OFFSET $${paramCounter++}
    `;

    values.push(limit, offset);

    const requests = await database.query(query, values);

    // Compute viewer entitlements once (if logged in)
    let ent = null;
    if (req.user && req.user.id) {
      try { 
        ent = await entitlements.getEntitlements(req.user.id, req.user.role); 
      } catch (e) { 
        console.warn('[requests] entitlements failed', e?.message || e);
        // No fallback - ent remains null
      }
    }
    const viewer = { id: req.user?.id || req.user?.userId || null, entitlements: ent };
    const gatedRows = requests.rows.map(r => applyContactGating(r, viewer));

    // Get total count for pagination
    const countQuery = `
      SELECT COUNT(*) as total
      FROM requests r
      WHERE ${conditions.join(' AND ')}
    `;
    
    const countResult = await database.queryOne(countQuery, values.slice(0, -2));
    const total = parseInt(countResult.total);

    res.json({
      success: true,
      data: {
  requests: gatedRows,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          totalPages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    console.error('Error fetching requests:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({
      success: false,
      message: 'Error fetching requests',
      error: error.message
    });
  }
}));

// Search requests by title or description (must come before :id route)
router.get('/search', optionalAuth(async (req, res) => {
  try {
    const {
      q,
      category_id,
      subcategory_id,
      city_id,
      country_code,
      status,
      user_id,
      has_accepted,
      page = 1,
      limit = 20,
      sort_by = 'created_at',
      sort_order = 'DESC'
    } = req.query;

    if (!q || String(q).trim().length === 0) {
      return res.status(400).json({ success: false, message: 'Query parameter q is required' });
    }

    const search = `%${q.trim()}%`;

    const conditions = ['(r.title ILIKE $1 OR r.description ILIKE $1)'];
    const values = [search];
    let paramCounter = 2;
    if (status) {
      conditions.push(`r.status = $${paramCounter++}`);
      values.push(status);
    } else if (has_accepted === 'true') {
      // allow closed accepted requests
    } else {
      conditions.push(`r.status = $${paramCounter++}`);
      values.push('active');
    }

    if (category_id) { conditions.push(`r.category_id = $${paramCounter++}`); values.push(category_id); }
    if (subcategory_id) { conditions.push(`r.subcategory_id = $${paramCounter++}`); values.push(subcategory_id); }
    if (city_id) { conditions.push(`r.location_city_id = $${paramCounter++}`); values.push(city_id); }
    if (country_code) { conditions.push(`r.country_code = $${paramCounter++}`); values.push(country_code); }
    if (status) { conditions.push(`r.status = $${paramCounter++}`); values.push(status); }
    if (user_id) { conditions.push(`r.user_id = $${paramCounter++}`); values.push(user_id); }
    if (has_accepted === 'true') { conditions.push('r.accepted_response_id IS NOT NULL'); }

    const offset = (page - 1) * limit;
    const validSortColumns = ['created_at', 'updated_at', 'title', 'budget'];
    const finalSortBy = validSortColumns.includes(sort_by) ? sort_by : 'created_at';
    const finalSortOrder = sort_order.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';

  const query = `
      SELECT 
        r.*,
        u.display_name as user_name,
        u.email as user_email,
        c.name as category_name,
        c.request_type as category_request_type,
        sc.name as subcategory_name,
        ct.name as city_name,
        COALESCE(r.country_code, ct.country_code) as effective_country_code,
        co.default_currency as country_default_currency,
        rc.response_count
      FROM requests r
      LEFT JOIN users u ON r.user_id = u.id
      LEFT JOIN categories c ON r.category_id = c.id
      LEFT JOIN sub_categories sc ON r.subcategory_id = sc.id
      LEFT JOIN cities ct ON r.location_city_id = ct.id
      LEFT JOIN countries co ON r.country_code = co.code
      LEFT JOIN LATERAL (
        SELECT COUNT(*)::int AS response_count
        FROM responses resp
        WHERE resp.request_id = r.id
      ) rc ON TRUE
      WHERE ${conditions.join(' AND ')}
      ORDER BY 
        CASE WHEN r.is_urgent = true AND (r.urgent_until IS NULL OR r.urgent_until > NOW()) THEN 0 ELSE 1 END,
        r.${finalSortBy} ${finalSortOrder}
      LIMIT $${paramCounter++} OFFSET $${paramCounter++}
    `;

    values.push(limit, offset);

    const requests = await database.query(query, values);
    const countQuery = `SELECT COUNT(*) as total FROM requests r WHERE ${conditions.join(' AND ')}`;
    const countResult = await database.queryOne(countQuery, values.slice(0, -2));
    const total = parseInt(countResult.total);

    // Compute viewer entitlements once (if logged in)
    let ent = null;
    if (req.user && req.user.id) {
      try { 
        ent = await entitlements.getEntitlements(req.user.id, req.user.role); 
      } catch (e) { 
        console.warn('[requests][search] entitlements failed', e?.message || e);
        // No fallback - ent remains null
      }
    }
    const viewer = { id: req.user?.id || req.user?.userId || null, entitlements: ent };
    const gatedRows = requests.rows.map(r => applyContactGating(r, viewer));

    res.json({
      success: true,
      data: {
  requests: gatedRows,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          totalPages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    console.error('Error searching requests:', error);
    res.status(500).json({ success: false, message: 'Error searching requests', error: error.message });
  }
}));

// Get single request by ID
router.get('/:id', optionalAuth(async (req, res) => {
  try {
    const requestId = req.params.id;

    const request = await database.queryOne(`
      SELECT 
        r.*,
        u.display_name as user_name,
        u.email as user_email,
        u.phone as user_phone,
        c.name as category_name,
        c.request_type as category_request_type,
        sc.name as subcategory_name,
        ct.name as city_name,
        ar.user_id as accepted_response_user_id,
        COALESCE(r.country_code, ct.country_code) as effective_country_code,
        co.default_currency as country_default_currency
      FROM requests r
      LEFT JOIN users u ON r.user_id = u.id
      LEFT JOIN categories c ON r.category_id = c.id
      LEFT JOIN sub_categories sc ON r.subcategory_id = sc.id
      LEFT JOIN cities ct ON r.location_city_id = ct.id
      LEFT JOIN responses ar ON r.accepted_response_id = ar.id
      LEFT JOIN countries co ON r.country_code = co.code
      WHERE r.id = $1
    `, [requestId]);

    if (!request) {
      return res.status(404).json({
        success: false,
        message: 'Request not found'
      });
    }

    // Parse metadata if it exists
    let metadata = {};
    try {
      if (request.metadata) {
        metadata = typeof request.metadata === 'string' 
          ? JSON.parse(request.metadata) 
          : request.metadata;
      }
    } catch (e) {
      console.log('Error parsing metadata:', e);
      metadata = {};
    }

    // Compute viewer info (auth or dev-only fallbacks)
    let viewerId = req.user?.id || req.user?.userId || null;
    // Dev-only fallback to help local testing when Authorization header is missing
    if (!viewerId && process.env.NODE_ENV === 'development') {
      const headerId = req.headers['x-user-id'] || req.headers['user-id'];
      const queryId = req.query.viewer_id;
      viewerId = (typeof headerId === 'string' && headerId.trim()) ? headerId.trim() : (typeof queryId === 'string' && queryId.trim() ? queryId.trim() : null);
      if (viewerId) console.warn('[requests][detail] DEV viewer override in use (no auth)', { viewerId });
    }

    // Entitlements (if we have a viewer)
    let ent = null;
    if (viewerId) {
      try { 
        ent = await entitlements.getEntitlements(viewerId, req.user?.role); 
      } catch (e) { 
        console.warn('[requests][detail] entitlements failed', e?.message || e);
        // No fallback - ent remains null
      }
    }

    // Has the viewer already responded to this request?
    let respondedRow = null;
    if (viewerId) {
      try {
        respondedRow = await database.queryOne('SELECT id FROM responses WHERE request_id = $1 AND user_id = $2 LIMIT 1', [requestId, viewerId]);
      } catch (e) {
        console.warn('[requests][detail] responded check failed', e?.message || e);
      }
    }

    const viewer = { id: viewerId, entitlements: ent, hasResponded: !!respondedRow };
    const masked = applyContactGating(request, viewer);

    res.json({
      success: true,
      data: {
        ...masked,
        metadata,
        variables: [], // For compatibility with frontend expecting variables array
        // Provide viewer context to help the app decide UI (e.g., hide subscribe bar if responded)
        viewer_context: {
          is_owner: !!(viewerId && request.user_id === viewerId),
          has_responded: !!respondedRow,
          response_id: respondedRow ? respondedRow.id : null,
          entitlements: ent || null
        }
      }
    });
  } catch (error) {
    console.error('Error fetching request:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching request',
      error: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
    });
  }
}));

// Create new request (requires authentication)
router.post('/', auth.authMiddleware(), async (req, res) => {
  try {
    // Helper to normalize various enum/string forms to allowed DB values
    const normalizeRequestType = (val) => {
      if (!val) return null;
      if (typeof val !== 'string') {
        try { val = String(val); } catch (_) { return null; }
      }
      let s = val.trim();
      // Handle Dart enum toString: 'RequestType.item' or similar
      if (/^requesttype\./i.test(s)) s = s.split('.')?.pop() || s;
      s = s.toLowerCase();
      // Map alternate forms
      const map = {
        'item_request': 'item',
        'service_request': 'service',
        'ride_request': 'ride',
        'rent_request': 'rent',
        'delivery_request': 'delivery',
        // Legacy to new mapping
        'hiring': 'job',
        'job_request': 'job',
        'jobs': 'job'
      };
      if (map[s]) s = map[s];
      const allowed = new Set(['item', 'service', 'ride', 'rent', 'delivery', 'job']);
      return allowed.has(s) ? s : null;
    };

    const {
      title,
      description,
      category_id,
      subcategory_id,
      city_id,
      budget,
      variables = [],
      metadata,
      location_address,
      location_latitude,
      location_longitude,
      currency,
      deadline,
      image_urls,
      request_type // Add request_type field (may come as e.g. 'RequestType.item')
    } = req.body;

    const user_id = req.user.id;
    const country_code = req.user.country_code || 'LK';

    console.log('=== FULL REQUEST BODY DEBUG ===');
    console.log('Full req.body:', JSON.stringify(req.body, null, 2));
    console.log('metadata field exists?', 'metadata' in req.body);
    console.log('metadata value:', req.body.metadata);
    console.log('metadata type:', typeof req.body.metadata);
    console.log('request_type field:', request_type);
    console.log('=== LOCATION DATA DEBUG ===');
    console.log('location_address:', location_address);
    console.log('location_latitude:', location_latitude);
    console.log('location_longitude:', location_longitude);
    console.log('=== IMAGE DATA DEBUG ===');
    console.log('image_urls:', image_urls);
    console.log('image_urls type:', typeof image_urls);

    console.log('Request creation data:', {
      user_id,
      country_code,
      title,
      description,
      category_id,
      city_id,
      budget,
      request_type,
      metadata: metadata ? JSON.stringify(metadata) : null
    });

    // Normalize request_type from body or metadata to satisfy DB constraint
    let normalizedRequestType = normalizeRequestType(request_type) || normalizeRequestType(metadata && metadata.request_type);

    // Determine if it's a ride request using normalized type or metadata shape
    const looksLikeRideByMetadata = !!(metadata && metadata.pickup && metadata.destination);
    const isRideRequest = normalizedRequestType === 'ride' || looksLikeRideByMetadata;

    // If normalization failed and it's clearly a ride request, set to 'ride';
    // Otherwise leave null to allow DB trigger to derive from category.
    if (!normalizedRequestType) {
      if (isRideRequest) normalizedRequestType = 'ride';
    }

    console.log('Normalized request_type:', normalizedRequestType);

    // Validate required fields
    // For ride requests (identified by type or metadata), category_id is optional
    
    if (!title || !description || !city_id) {
      return res.status(400).json({
        success: false,
        message: 'Title, description, and city_id are required'
      });
    }
    
    // Only require category_id for non-ride requests
    if (!isRideRequest && !category_id) {
      return res.status(400).json({
        success: false,
        message: 'Category is required for non-ride requests'
      });
    }

    // Create the request with metadata and request_type
    const request = await database.queryOne(`
      INSERT INTO requests (
        user_id, title, description, category_id, subcategory_id, location_city_id,
        location_address, location_latitude, location_longitude,
        budget, currency, deadline, image_urls, country_code, metadata, request_type, status, created_at, updated_at
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, 'active',
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      ) RETURNING *
    `, [
      user_id, title, description, category_id, subcategory_id, city_id,
      location_address, location_latitude, location_longitude,
      budget, currency, deadline, image_urls, country_code, metadata ? JSON.stringify(metadata) : null, normalizedRequestType
    ]);

    // After successful request creation, notify relevant businesses
    try {
      console.log('🔔 Finding businesses to notify for new request...');
      const businessesToNotify = await BusinessNotificationService.getBusinessesToNotify(
        request.id,
        category_id,
        subcategory_id,
        normalizedRequestType || 'item',
        country_code
      );

      if (businessesToNotify.length > 0) {
        console.log(`📢 Notifying ${businessesToNotify.length} businesses about new request`);
        
        // Send notifications to businesses (implement as needed)
        for (const business of businessesToNotify) {
          console.log(`  📨 Would notify: ${business.businessName} (${business.userId})`);
          // TODO: Implement actual notification sending (email, push, SMS, etc.)
          // await notify.sendBusinessNotification(business.userId, request, business.notificationReason);
        }
      } else {
        console.log('📭 No businesses found to notify for this request');
      }
    } catch (notificationError) {
      console.error('⚠️ Failed to send business notifications (request still created):', notificationError);
      // Don't fail the request creation if notifications fail
    }

    res.status(201).json({
      success: true,
      message: 'Request created successfully',
      data: request
    });
  } catch (error) {
    console.error('Error creating request:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({
      success: false,
      message: 'Error creating request',
      error: error.message // Always show error message for debugging
    });
  }
});

// Start urgent boost checkout (creates pending transaction)
// Client/mobile will use returned tx id to process payment via selected country gateway
router.post('/:id/urgent-boost/start', auth.authMiddleware(), async (req, res) => {
  try {
    const requestId = req.params.id;
    const userId = req.user.id;
    const requestRow = await database.queryOne('SELECT id, user_id, country_code FROM requests WHERE id=$1', [requestId]);
    if (!requestRow) return res.status(404).json({ success:false, message:'Request not found' });
    if (requestRow.user_id !== userId && req.user.role !== 'admin') return res.status(403).json({ success:false, message:'Not permitted' });

    // Default 900 LKR per requirement; could be made country-configurable later
    const country = requestRow.country_code || 'LK';
    const amount = 900;
    const currency = 'LKR';

    const tx = await database.queryOne(`
      INSERT INTO subscription_transactions (user_id, country_code, plan_id, subscription_id, purpose, amount, currency, status, metadata)
      VALUES ($1,$2,NULL,NULL,'urgent_boost',$3,$4,'pending', jsonb_build_object('request_id',$5))
      RETURNING *
    `, [userId, country, amount, currency, requestId]);

    res.status(201).json({ success:true, data:{ transaction: tx } });
  } catch (error) {
    console.error('Error starting urgent boost:', error);
    res.status(500).json({ success:false, message:'Error starting urgent boost', error: error.message });
  }
});

// Confirm urgent boost payment (webhook or client callback once provider says paid)
router.post('/:id/urgent-boost/confirm', auth.authMiddleware(), async (req, res) => {
  try {
    const requestId = req.params.id;
    const userId = req.user.id;
    const { transaction_id } = req.body || {};
    if (!transaction_id) return res.status(400).json({ success:false, message:'transaction_id required' });

    const requestRow = await database.queryOne('SELECT id, user_id, country_code FROM requests WHERE id=$1', [requestId]);
    if (!requestRow) return res.status(404).json({ success:false, message:'Request not found' });
    if (requestRow.user_id !== userId && req.user.role !== 'admin') return res.status(403).json({ success:false, message:'Not permitted' });

    const tx = await database.queryOne('SELECT * FROM subscription_transactions WHERE id=$1 AND purpose=$2 AND user_id=$3', [transaction_id, 'urgent_boost', requestRow.user_id]);
    if (!tx) return res.status(404).json({ success:false, message:'Transaction not found' });
    if (tx.status !== 'paid') {
      // for now allow client to mark paid manually; in production this should be set by webhook
      await database.query('UPDATE subscription_transactions SET status=$1, updated_at=NOW() WHERE id=$2', ['paid', transaction_id]);
    }

    // Set urgent for 30 days from now per requirement
    const until = new Date(Date.now() + 30*24*60*60*1000);
    const updated = await database.queryOne('UPDATE requests SET is_urgent=true, urgent_until=$1, urgent_paid_tx_id=$2, updated_at=NOW() WHERE id=$3 RETURNING *', [until, transaction_id, requestId]);
    res.json({ success:true, message:'Urgent boost activated', data: updated });
  } catch (error) {
    console.error('Error confirming urgent boost:', error);
    res.status(500).json({ success:false, message:'Error confirming urgent boost', error: error.message });
  }
});

// Admin or owner can clear urgent
router.post('/:id/urgent-boost/clear', auth.authMiddleware(), async (req, res) => {
  try {
    const requestId = req.params.id;
    const userId = req.user.id;
    const row = await database.queryOne('SELECT id, user_id FROM requests WHERE id=$1', [requestId]);
    if (!row) return res.status(404).json({ success:false, message:'Request not found' });
    if (row.user_id !== userId && req.user.role !== 'admin') return res.status(403).json({ success:false, message:'Not permitted' });
    const updated = await database.queryOne('UPDATE requests SET is_urgent=false, urgent_until=NULL, updated_at=NOW() WHERE id=$1 RETURNING *', [requestId]);
    res.json({ success:true, message:'Urgent boost cleared', data: updated });
  } catch (error) {
    console.error('Error clearing urgent boost:', error);
    res.status(500).json({ success:false, message:'Error clearing urgent boost', error: error.message });
  }
});

// Update request (requires authentication and ownership)
router.put('/:id', auth.authMiddleware(), async (req, res) => {
  try {
    const requestId = req.params.id;
    const userId = req.user.id;
    const userRole = req.user.role;

    // Check if request exists and user has permission
    const existingRequest = await database.queryOne(
      'SELECT * FROM requests WHERE id = $1',
      [requestId]
    );

    if (!existingRequest) {
      return res.status(404).json({
        success: false,
        message: 'Request not found'
      });
    }

    // Check ownership or admin role
    if (existingRequest.user_id !== userId && userRole !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'You can only update your own requests'
      });
    }

    const {
      title,
      description,
      category_id,
      subcategory_id,
      city_id, // client may send city_id; map to location_city_id
      budget_min,
      budget_max,
      budget, // new single budget field
      currency,
      priority,
      status,
      is_active,
      location_address,
      location_latitude,
      location_longitude,
      deadline,
      image_urls,
      metadata
    } = req.body;

    // Build dynamic update query
    const updates = [];
    const values = [];
    let paramCounter = 1;

    if (title !== undefined) {
      updates.push(`title = $${paramCounter++}`);
      values.push(title);
    }
    if (description !== undefined) {
      updates.push(`description = $${paramCounter++}`);
      values.push(description);
    }
    if (category_id !== undefined) {
      updates.push(`category_id = $${paramCounter++}`);
      values.push(category_id);
    }
    if (subcategory_id !== undefined) {
      updates.push(`subcategory_id = $${paramCounter++}`);
      values.push(subcategory_id);
    }
    if (city_id !== undefined) {
      updates.push(`location_city_id = $${paramCounter++}`);
      values.push(city_id);
    }
    if (budget_min !== undefined) {
      updates.push(`budget_min = $${paramCounter++}`);
      values.push(budget_min);
    }
    if (budget_max !== undefined) {
      updates.push(`budget_max = $${paramCounter++}`);
      values.push(budget_max);
    }
    if (budget !== undefined) {
      updates.push(`budget = $${paramCounter++}`);
      values.push(budget);
    }
    if (currency !== undefined) {
      updates.push(`currency = $${paramCounter++}`);
      values.push(currency);
    }
    if (priority !== undefined) {
      updates.push(`priority = $${paramCounter++}`);
      values.push(priority);
    }
    if (status !== undefined) {
      updates.push(`status = $${paramCounter++}`);
      values.push(status);
    }
    if (is_active !== undefined) {
      updates.push(`is_active = $${paramCounter++}`);
      values.push(is_active);
    }
    if (location_address !== undefined) {
      updates.push(`location_address = $${paramCounter++}`);
      values.push(location_address);
    }
    if (location_latitude !== undefined) {
      updates.push(`location_latitude = $${paramCounter++}`);
      values.push(location_latitude);
    }
    if (location_longitude !== undefined) {
      updates.push(`location_longitude = $${paramCounter++}`);
      values.push(location_longitude);
    }
    if (deadline !== undefined) {
      updates.push(`deadline = $${paramCounter++}`);
      values.push(deadline);
    }
    if (image_urls !== undefined) {
      updates.push(`image_urls = $${paramCounter++}`);
      values.push(image_urls);
    }
    if (metadata !== undefined) {
      updates.push(`metadata = $${paramCounter++}`);
      values.push(metadata ? JSON.stringify(metadata) : null);
    }

    if (updates.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No valid fields to update'
      });
    }

    updates.push('updated_at = CURRENT_TIMESTAMP');
    values.push(requestId);

    const query = `
      UPDATE requests 
      SET ${updates.join(', ')}
      WHERE id = $${paramCounter}
      RETURNING *
    `;

    const request = await database.queryOne(query, values);

    res.json({
      success: true,
      message: 'Request updated successfully',
      data: request
    });
  } catch (error) {
    console.error('Error updating request:', error);
    res.status(500).json({
      success: false,
      message: 'Error updating request',
      error: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
    });
  }
});

// Delete request (requires authentication and ownership)
router.delete('/:id', auth.authMiddleware(), async (req, res) => {
  try {
    const requestId = req.params.id;
    const userId = req.user.id;
    const userRole = req.user.role;

    // Check if request exists and user has permission
    const existingRequest = await database.queryOne(
      'SELECT * FROM requests WHERE id = $1',
      [requestId]
    );

    if (!existingRequest) {
      return res.status(404).json({
        success: false,
        message: 'Request not found'
      });
    }

    // Check ownership or admin role
    if (existingRequest.user_id !== userId && userRole !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'You can only delete your own requests'
      });
    }

    const request = await database.queryOne(
      'DELETE FROM requests WHERE id = $1 RETURNING *',
      [requestId]
    );

    res.json({
      success: true,
      message: 'Request deleted successfully',
      data: request
    });
  } catch (error) {
    console.error('Error deleting request:', error);
    res.status(500).json({
      success: false,
      message: 'Error deleting request',
      error: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
    });
  }
});

// Accept a response (owner only)
router.put('/:id/accept-response', auth.authMiddleware(), async (req, res) => {
  try {
    const requestId = req.params.id;
    const { response_id } = req.body;
    const userId = req.user.id;
    if (!response_id) {
      return res.status(400).json({ success: false, message: 'response_id required' });
    }
    const request = await database.queryOne('SELECT * FROM requests WHERE id=$1', [requestId]);
    if (!request) return res.status(404).json({ success: false, message: 'Request not found' });
    if (request.user_id !== userId && req.user.role !== 'admin') return res.status(403).json({ success: false, message: 'Not permitted' });
    // Ensure response belongs to request
    const resp = await database.queryOne('SELECT * FROM responses WHERE id=$1 AND request_id=$2', [response_id, requestId]);
    if (!resp) return res.status(404).json({ success: false, message: 'Response not found for this request' });
    // Auto-close if currently active
    const updated = await database.queryOne('UPDATE requests SET accepted_response_id=$1, status=CASE WHEN status=\'active\' THEN \'closed\' ELSE status END, updated_at=NOW() WHERE id=$2 RETURNING *', [response_id, requestId]);
    try {
      await notify.createNotification({
        recipientId: resp.user_id,
        senderId: userId,
        type: 'responseAccepted',
        title: 'Your response was accepted',
        message: 'A requester accepted your response',
        data: { requestId, responseId: response_id }
      });
    } catch (e) { console.warn('notify responseAccepted failed', e?.message || e); }
    return res.json({ success: true, message: 'Response accepted', data: updated });
  } catch (error) {
    console.error('Error accepting response:', error);
    res.status(500).json({ success: false, message: 'Error accepting response', error: error.message });
  }
});

// Clear accepted response
router.put('/:id/clear-accepted', auth.authMiddleware(), async (req, res) => {
  try {
    const requestId = req.params.id;
    const userId = req.user.id;
    const request = await database.queryOne('SELECT * FROM requests WHERE id=$1', [requestId]);
    if (!request) return res.status(404).json({ success: false, message: 'Request not found' });
    if (request.user_id !== userId && req.user.role !== 'admin') return res.status(403).json({ success: false, message: 'Not permitted' });
    // Re-open if it was closed due to acceptance
    const updated = await database.queryOne('UPDATE requests SET accepted_response_id=NULL, status=CASE WHEN status=\'closed\' THEN \'active\' ELSE status END, updated_at=NOW() WHERE id=$1 RETURNING *', [requestId]);
    return res.json({ success: true, message: 'Accepted response cleared', data: updated });
  } catch (error) {
    console.error('Error clearing accepted response:', error);
    res.status(500).json({ success: false, message: 'Error clearing accepted response', error: error.message });
  }
});

// Mark request as completed (owner only, requires an accepted response)
router.put('/:id/mark-completed', auth.authMiddleware(), async (req, res) => {
  try {
    const requestId = req.params.id;
    const userId = req.user.id;
    const request = await database.queryOne('SELECT id, user_id, status, accepted_response_id FROM requests WHERE id=$1', [requestId]);
    if (!request) return res.status(404).json({ success: false, message: 'Request not found' });
    if (request.user_id !== userId && req.user.role !== 'admin') return res.status(403).json({ success: false, message: 'Not permitted' });
    if (!request.accepted_response_id) return res.status(400).json({ success: false, message: 'Cannot complete without an accepted response' });
    if ((request.status || '').toLowerCase() === 'completed') {
      return res.json({ success: true, message: 'Already completed', data: request });
    }
    const updated = await database.queryOne('UPDATE requests SET status=\'completed\', updated_at=NOW() WHERE id=$1 RETURNING *', [requestId]);
    return res.json({ success: true, message: 'Request marked as completed', data: updated });
  } catch (error) {
    console.error('Error marking request completed:', error);
    res.status(500).json({ success: false, message: 'Error marking request completed', error: error.message });
  }
});

// Test endpoint for debugging
router.post('/test', auth.authMiddleware(), async (req, res) => {
  try {
    console.log('Test endpoint hit with user:', req.user);
    console.log('Request body:', req.body);
    
    res.json({
      success: true,
      message: 'Test endpoint working',
      user: req.user,
      body: req.body
    });
  } catch (error) {
    console.error('Test endpoint error:', error);
    res.status(500).json({
      success: false,
      message: 'Test endpoint error',
      error: error.message
    });
  }
});

// Get user's own requests
router.get('/user/my-requests', auth.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    const { status, page = 1, limit = 20 } = req.query;

    const conditions = ['r.user_id = $1'];
    const values = [userId];
    let paramCounter = 2;

    if (status) {
      conditions.push(`r.status = $${paramCounter++}`);
      values.push(status);
    }

    const offset = (page - 1) * limit;

    const query = `
      SELECT 
        r.*,
        c.name as category_name,
        c.request_type as category_request_type,
        sc.name as subcategory_name,
        ct.name as city_name,
        COALESCE(r.country_code, ct.country_code) as effective_country_code,
        co.default_currency as country_default_currency
      FROM requests r
      LEFT JOIN categories c ON r.category_id = c.id
      LEFT JOIN sub_categories sc ON r.subcategory_id = sc.id
      LEFT JOIN cities ct ON r.location_city_id = ct.id
      LEFT JOIN countries co ON r.country_code = co.code
      WHERE ${conditions.join(' AND ')}
      ORDER BY r.created_at DESC
      LIMIT $${paramCounter++} OFFSET $${paramCounter++}
    `;

    values.push(limit, offset);

    const requests = await database.query(query, values);

    // Get total count
    const countQuery = `
      SELECT COUNT(*) as total
      FROM requests r
      WHERE ${conditions.join(' AND ')}
    `;
    
    const countResult = await database.queryOne(countQuery, values.slice(0, -2));
    const total = parseInt(countResult.total);

    res.json({
      success: true,
      data: {
        requests: requests.rows,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          totalPages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    console.error('Error fetching user requests:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching user requests',
      error: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
    });
  }
});

router.use('/:requestId/responses', responsesRouter);

module.exports = router;
