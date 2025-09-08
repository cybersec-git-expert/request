const express = require('express');
const database = require('../services/database');
const authService = require('../services/auth');
const multer = require('multer');
const path = require('path');
const { getSignedUrl } = require('../services/s3Upload');

const router = express.Router();
const db = require('../services/database');

// Multer configuration for image uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/price-listings/');
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'listing-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|webp/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);
    
    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Only image files (JPEG, PNG, WebP) are allowed'));
    }
  }
});

// Helper function to format price listing data
async function getBusinessPaymentMethods(businessId) {
  if (!businessId) return [];
  try {
    const sql = `
      SELECT cpm.id, cpm.name, cpm.category, cpm.image_url AS image_url
      FROM business_payment_methods bpm
      JOIN country_payment_methods cpm ON cpm.id = bpm.payment_method_id
      WHERE bpm.business_id = $1 AND bpm.is_active = true AND cpm.is_active = true
      ORDER BY cpm.name`;
    const r = await database.query(sql, [businessId]);
    return r.rows.map(pm => ({ id: pm.id, name: pm.name, category: pm.category, imageUrl: pm.image_url }));
  } catch (e) {
    console.error('Error loading business payment methods', e);
    return [];
  }
}

async function formatPriceListing(row, includeBusiness = false) {
  if (!row) return null;
  
  // Use staged data if available, otherwise use current data
  const hasStaging = row.has_pending_changes;
  
  const listing = {
    id: row.id,
    businessId: row.business_id,
    masterProductId: row.master_product_id,
    title: row.title,
    description: row.description,
    price: parseFloat(hasStaging ? row.staged_price : row.price) || 0,
    currency: row.currency || 'LKR',
    unit: row.unit,
    deliveryCharge: parseFloat(row.delivery_charge) || 0,
    images: row.images ? (Array.isArray(row.images) ? row.images : JSON.parse(row.images || '[]')) : [],
    website: row.website,
    whatsapp: hasStaging ? (row.staged_whatsapp_number || row.whatsapp) : row.whatsapp,
    cityId: row.city_id,
    countryCode: row.country_code,
    isActive: hasStaging ? row.staged_is_available : row.is_active,
    isAvailable: hasStaging ? row.staged_is_available : row.is_available,
    stockQuantity: hasStaging ? row.staged_stock_quantity : row.stock_quantity,
    whatsappNumber: hasStaging ? (row.staged_whatsapp_number || row.whatsapp_number) : row.whatsapp_number,
    productLink: hasStaging ? (row.staged_product_link || row.product_link) : row.product_link,
    modelNumber: hasStaging ? (row.staged_model_number || row.model_number) : row.model_number,
    viewCount: row.view_count || 0,
    contactCount: row.contact_count || 0,
    createdAt: row.created_at,
    updatedAt: hasStaging ? row.staged_updated_at : row.updated_at,
    // Add staging status information
    hasPendingChanges: hasStaging,
    stagingStatus: hasStaging ? 'pending' : 'active',
    // Add selectedVariables and subcategory fields
    selectedVariables: hasStaging ? 
      (row.staged_selected_variables ? 
        (typeof row.staged_selected_variables === 'string' ? 
          JSON.parse(row.staged_selected_variables) : row.staged_selected_variables) : 
        (row.selected_variables ? 
          (typeof row.selected_variables === 'string' ? 
            JSON.parse(row.selected_variables) : row.selected_variables) : {})) :
      (row.selected_variables ? 
        (typeof row.selected_variables === 'string' ? 
          JSON.parse(row.selected_variables) : row.selected_variables) : {}),
    subcategoryId: row.subcategory_id,
    categoryId: row.category_id
  };
  
  // Add business details if included in query
  if (includeBusiness && row.business_name) {
    listing.business = {
      name: row.business_name,
      category: row.business_category,
      isVerified: row.business_verified || false,
      paymentMethods: []
    };
  }
  
  // Add product details if included
  if (row.product_name) {
    listing.product = {
      name: row.product_name,
      brandId: null,
      brandName: row.brand_name,
      baseUnit: row.base_unit
    };
  }
  
  return listing;
}

// GET /api/price-listings - Get all price listings with optional filters
router.get('/', async (req, res) => {
  try {
    const { 
      masterProductId, 
      businessId, 
      categoryId, 
      subcategoryId,
      cityId,
      country = 'LK',
      minPrice,
      maxPrice,
      search,
      sortBy = 'price', // price, rating, created_at
      sortOrder = 'asc',
      page = 1,
      limit = 20,
      includeInactive = 'false'
    } = req.query;

    const whereConditions = [];
    const queryParams = [];
    let paramIndex = 1;

    // Base query with business and product details, including staged prices
    let query = `
      SELECT 
        pl.*,
        cp.product_name as product_name,
        NULL as base_unit,
        NULL as brand_name,
        bv.business_name,
        bv.business_category,
        bv.is_verified as business_verified,
        c.name as city_name,
        ps.staged_price,
        ps.staged_stock_quantity,
        ps.staged_is_available,
        ps.staged_whatsapp_number,
        ps.staged_product_link,
        ps.staged_model_number,
        ps.staged_selected_variables,
        ps.updated_at as staged_updated_at,
        CASE 
          WHEN ps.id IS NOT NULL AND ps.is_processed = false THEN true 
          ELSE false 
        END as has_pending_changes
      FROM price_listings pl
      LEFT JOIN country_products cp ON pl.master_product_id = cp.product_id
      LEFT JOIN business_verifications bv ON pl.business_id = bv.user_id
      LEFT JOIN cities c ON pl.city_id = c.id
      LEFT JOIN price_staging ps ON pl.id = ps.price_listing_id AND ps.is_processed = false
    `;

    // Apply filters
    if (country) {
      whereConditions.push(`pl.country_code = $${paramIndex}`);
      queryParams.push(country);
      paramIndex++;
    }

    if (includeInactive !== 'true') {
      whereConditions.push('pl.is_active = true');
    }

    if (masterProductId) {
      whereConditions.push(`pl.master_product_id = $${paramIndex}`);
      queryParams.push(masterProductId);
      paramIndex++;
    }

    if (businessId) {
      whereConditions.push(`pl.business_id = $${paramIndex}`);
      queryParams.push(businessId);
      paramIndex++;
    }

    if (categoryId) {
      whereConditions.push(`pl.category_id = $${paramIndex}`);
      queryParams.push(categoryId);
      paramIndex++;
    }

    if (subcategoryId) {
      whereConditions.push(`pl.subcategory_id = $${paramIndex}`);
      queryParams.push(subcategoryId);
      paramIndex++;
    }

    if (cityId) {
      whereConditions.push(`pl.city_id = $${paramIndex}`);
      queryParams.push(cityId);
      paramIndex++;
    }

    if (minPrice) {
      whereConditions.push(`pl.price >= $${paramIndex}`);
      queryParams.push(parseFloat(minPrice));
      paramIndex++;
    }

    if (maxPrice) {
      whereConditions.push(`pl.price <= $${paramIndex}`);
      queryParams.push(parseFloat(maxPrice));
      paramIndex++;
    }

    if (search) {
      whereConditions.push(`(pl.title ILIKE $${paramIndex} OR pl.description ILIKE $${paramIndex} OR cp.product_name ILIKE $${paramIndex})`);
      queryParams.push(`%${search}%`);
      paramIndex++;
    }

    // Add WHERE clause if we have conditions
    if (whereConditions.length > 0) {
      query += ` WHERE ${whereConditions.join(' AND ')}`;
    }

    // Add sorting
    let orderBy = '';
    switch (sortBy) {
    case 'price':
      orderBy = `pl.price ${sortOrder.toUpperCase()}`;
      break;
    case 'rating':
      orderBy = `bv.business_name ${sortOrder.toUpperCase()}`; // Sort by business name instead of rating
      break;
    case 'created_at':
      orderBy = `pl.created_at ${sortOrder.toUpperCase()}`;
      break;
    default:
      orderBy = 'pl.price ASC';
    }
    query += ` ORDER BY ${orderBy}`;

    // Add pagination
    const offset = (page - 1) * limit;
    query += ` LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    queryParams.push(limit, offset);

    console.log('Price listings query:', query);
    console.log('Params:', queryParams);

    const result = await database.query(query, queryParams);
    const temp = await Promise.all(result.rows.map(row => formatPriceListing(row, true)));
    // Populate payment methods for each listing's business
    const listings = await Promise.all(temp.map(async (l, idx) => {
      if (!l) return l;
      const row = result.rows[idx];
      if (row.business_id) {
        const pms = await getBusinessPaymentMethods(row.business_id);
        if (l.business) l.business.paymentMethods = pms;
      }
      return l;
    }));

    // Get total count for pagination
    let countQuery = `
      SELECT COUNT(*) as total
      FROM price_listings pl
      LEFT JOIN country_products cp ON pl.master_product_id = cp.product_id
      LEFT JOIN business_verifications bv ON pl.business_id = bv.user_id
    `;
    
    if (whereConditions.length > 0) {
      countQuery += ` WHERE ${whereConditions.join(' AND ')}`;
    }

    const countResult = await database.query(countQuery, queryParams.slice(0, -2)); // Remove limit and offset
    const total = parseInt(countResult.rows[0].total);

    res.json({
      success: true,
      data: listings,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        totalPages: Math.ceil(total / limit)
      }
    });

  } catch (error) {
    console.error('Error fetching price listings:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching price listings', 
      error: error.message 
    });
  }
});

// GET /api/price-listings/search - Search products for price comparison
router.get('/search', async (req, res) => {
  try {
    const { 
      q: query, 
      country = 'LK', 
      categoryId, 
      brandId,
      limit = 10
    } = req.query;

    // If no query or empty query, return popular products
    const isPopularProductsRequest = !query || query.trim().length === 0;
    const searchTerm = isPopularProductsRequest ? null : query.trim();

    // Load products that actually have price listings, regardless of country_products activation
    // Source of truth: price_listings joined with master_products
    let searchQuery = `
      SELECT DISTINCT
        mp.id as id,
        mp.name as name,
        LOWER(REPLACE(mp.name, ' ', '-')) as slug,
        mp.base_unit as base_unit,
        mp.images as images,
        NULL as brand_name,
        COUNT(pl.id) as listing_count,
        MIN(pl.price) as min_price,
        MAX(pl.price) as max_price,
        AVG(pl.price) as avg_price
      FROM price_listings pl
      JOIN master_products mp ON mp.id = pl.master_product_id
      WHERE pl.is_active = true AND pl.country_code = $1
    `;

    const queryParams = [country];
    let paramIndex = 2;

    // Add search filter only if we have a search term
    if (searchTerm && searchTerm.length >= 2) {
      searchQuery += ` AND mp.name ILIKE $${paramIndex}`;
      queryParams.push(`%${searchTerm}%`);
      paramIndex++;
    }

    if (categoryId) {
      searchQuery += ` AND EXISTS (
        SELECT 1 FROM price_listings pl2 
        WHERE pl2.master_product_id = mp.id 
          AND pl2.category_id = $${paramIndex}
          AND pl2.is_active = true
          AND pl2.country_code = $1
      )`;
      queryParams.push(categoryId);
      paramIndex++;
    }

    searchQuery += `
      GROUP BY mp.id, mp.name, mp.base_unit, mp.images
    `;

    // Order by listing count for popular products, or by name for search results
    if (isPopularProductsRequest) {
      searchQuery += ' ORDER BY listing_count DESC, mp.name';
    } else {
      searchQuery += ' ORDER BY mp.name, listing_count DESC';
    }

    searchQuery += ` LIMIT $${paramIndex}`;
    queryParams.push(limit);

    console.log('Product search query:', searchQuery);
    console.log('Params:', queryParams);

    const result = await database.query(searchQuery, queryParams);
    
    const products = await Promise.all(result.rows.map(async (row) => {
      const images = row.images ? (Array.isArray(row.images) ? row.images : JSON.parse(row.images || '[]')) : [];
      console.log(`DEBUG: Product "${row.name}" - Raw Images:`, images);
      
      // Generate signed URLs for S3 images
      const signedImages = await Promise.all(images.map(async (imageUrl) => {
        try {
          if (imageUrl && imageUrl.includes('s3.amazonaws.com')) {
            const signedUrl = await getSignedUrl(imageUrl, 3600); // 1 hour expiry
            console.log(`DEBUG: Generated signed URL for ${row.name}:`, signedUrl);
            return signedUrl;
          }
          return imageUrl; // Return as-is if not an S3 URL
        } catch (error) {
          console.error(`Error generating signed URL for ${imageUrl}:`, error);
          return imageUrl; // Fallback to original URL
        }
      }));
      
      return {
        id: row.id,
        name: row.name,
        slug: row.slug,
        baseUnit: row.base_unit,
        images: signedImages,
        brand: null,
        listingCount: parseInt(row.listing_count) || 0,
        priceRange: {
          min: parseFloat(row.min_price) || 0,
          max: parseFloat(row.max_price) || 0,
          avg: parseFloat(row.avg_price) || 0
        }
      };
    }));

    res.json({
      success: true,
      data: products,
      count: products.length,
      message: isPopularProductsRequest ? 'Popular products' : `Search results for "${searchTerm}"`
    });

  } catch (error) {
    console.error('Error searching products:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error searching products', 
      error: error.message 
    });
  }
});

// GET /api/price-listings/product/:productId - Get price listings for a specific product
router.get('/product/:productId', async (req, res) => {
  try {
    const { productId } = req.params;
    const { country = 'LK', sortBy = 'price' } = req.query;

    // Get product details first
    const productQuery = `
      SELECT 
        mp.id AS id,
        mp.name AS name
      FROM master_products mp
      WHERE mp.id = $1 AND mp.is_active = true
    `;

    const productResult = await database.query(productQuery, [productId]);
    
    if (productResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Product not found'
      });
    }

    const product = productResult.rows[0];

    // Get price listings for this product
    let orderBy = 'pl.price ASC'; // Default: cheapest first
    if (sortBy === 'rating') {
      orderBy = 'bv.business_name ASC, pl.price ASC'; // Sort by business name instead of rating
    } else if (sortBy === 'newest') {
      orderBy = 'pl.created_at DESC';
    }

    const listingsQuery = `
      SELECT 
        pl.*,
        bv.business_name,
        bv.business_category,
        bv.is_verified as business_verified,
        c.name as city_name
      FROM price_listings pl
      LEFT JOIN business_verifications bv ON pl.business_id = bv.user_id
      LEFT JOIN cities c ON pl.city_id = c.id
      WHERE pl.master_product_id = $1 
        AND pl.country_code = $2 
        AND pl.is_active = true
      ORDER BY ${orderBy}
    `;

    const listingsResult = await database.query(listingsQuery, [productId, country]);
    const temp = await Promise.all(listingsResult.rows.map(row => formatPriceListing(row, true)));
    const listings = await Promise.all(temp.map(async (l, idx) => {
      if (!l) return l;
      const row = listingsResult.rows[idx];
      if (row.business_id) {
        const pms = await getBusinessPaymentMethods(row.business_id);
        if (l.business) l.business.paymentMethods = pms;
      }
      return l;
    }));

    res.json({
      success: true,
      data: {
        product: {
          id: product.id,
          name: product.name,
          slug: (product.name || '').toLowerCase().replace(/\s+/g, '-'),
          baseUnit: null,
          brand: null
        },
        listings,
        summary: {
          totalListings: listings.length,
          priceRange: listings.length > 0 ? {
            min: Math.min(...listings.map(l => l.price)),
            max: Math.max(...listings.map(l => l.price)),
            avg: listings.reduce((sum, l) => sum + l.price, 0) / listings.length
          } : { min: 0, max: 0, avg: 0 }
        }
      }
    });

  } catch (error) {
    console.error('Error fetching product price listings:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching product price listings', 
      error: error.message 
    });
  }
});

// GET /api/price-listings/:id - Get a specific price listing
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const query = `
      SELECT 
        pl.*,
        cp.product_name as product_name,
        NULL as base_unit,
        NULL as brand_name,
        bv.business_name,
        bv.business_category,
        bv.is_verified as business_verified,
        c.name as city_name
      FROM price_listings pl
      LEFT JOIN country_products cp ON pl.master_product_id = cp.product_id
      LEFT JOIN business_verifications bv ON pl.business_id = bv.user_id
      LEFT JOIN cities c ON pl.city_id = c.id
      WHERE pl.id = $1
    `;

    const result = await database.query(query, [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Price listing not found'
      });
    }

    const listing = await formatPriceListing(result.rows[0], true);
    if (listing && result.rows[0].business_id) {
      listing.business = listing.business || {};
      listing.business.paymentMethods = await getBusinessPaymentMethods(result.rows[0].business_id);
    }

    res.json({
      success: true,
      data: listing
    });

  } catch (error) {
    console.error('Error fetching price listing:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching price listing', 
      error: error.message 
    });
  }
});

// POST /api/price-listings - Create a new price listing (Business users only)
router.post('/', authService.authMiddleware(), upload.array('images', 5), async (req, res) => {
  try {
    const userId = req.user.id; // Fixed: use 'id' instead of 'uid'
    
    // Verify user is a verified business
    const businessCheck = await database.query(
      'SELECT id, business_name, is_verified FROM business_verifications WHERE user_id = $1 AND status = $2',
      [userId, 'approved']
    );

    // TEMPORARY: Allow for development/testing - bypass business verification
    console.log(`DEBUG: Business verification check for user ${userId} - found ${businessCheck.rows.length} rows`);
    
    // if (businessCheck.rows.length === 0) {
    //   return res.status(403).json({
    //     success: false,
    //     message: 'Only verified businesses can create price listings'
    //   });
    // }

    const {
      masterProductId,
      categoryId,
      subcategoryId,
      title,
      description,
      price,
      currency = 'LKR',
      unit,
      deliveryCharge = 0,
      website,
      whatsapp,
      cityId,
      countryCode = 'LK',
      images: bodyImages, // Images from request body (S3 URLs)
      selectedVariables = {} // Add selectedVariables from request body
    } = req.body;

    console.log('DEBUG: CREATE - selectedVariables from request:', selectedVariables);

    // Validate required fields
    if (!masterProductId || !title || !price) {
      return res.status(400).json({
        success: false,
        message: 'Master product ID, title, and price are required'
      });
    }

    // Verify master product exists
    const productCheck = await database.query(
      'SELECT product_id FROM country_products WHERE product_id = $1 AND is_active = true',
      [masterProductId]
    );

    if (productCheck.rows.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or inactive master product'
      });
    }

    // Handle uploaded images - support both multer file uploads and S3 URLs from request body
    let images = [];
    
    // Add multer uploaded files (if any)
    if (req.files && req.files.length > 0) {
      images = req.files.map(file => `/uploads/price-listings/${file.filename}`);
    }
    
    // Add S3 URLs from request body (if any)
    if (bodyImages) {
      const s3Images = Array.isArray(bodyImages) ? bodyImages : [bodyImages];
      images = [...images, ...s3Images];
    }
    
    console.log(`DEBUG: Processing images - multer files: ${req.files?.length || 0}, S3 URLs: ${bodyImages ? (Array.isArray(bodyImages) ? bodyImages.length : 1) : 0}, total: ${images.length}`);

    // Create the price listing (allow multiple listings per business for same product)
    const insertQuery = `
      INSERT INTO price_listings (
        business_id, master_product_id, category_id, subcategory_id,
        title, description, price, currency, unit, delivery_charge,
        images, website, whatsapp, city_id, country_code, selected_variables
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
      RETURNING *
    `;

    const values = [
      userId, masterProductId, categoryId, subcategoryId,
      title, description, parseFloat(price), currency, unit, parseFloat(deliveryCharge),
      JSON.stringify(images), website, whatsapp, cityId, countryCode, JSON.stringify(selectedVariables)
    ];

    const result = await database.query(insertQuery, values);
    const newListing = await formatPriceListing(result.rows[0]);

    res.status(201).json({
      success: true,
      message: 'Price listing created successfully',
      data: newListing
    });

  } catch (error) {
    console.error('Error creating price listing:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error creating price listing', 
      error: error.message 
    });
  }
});

// PUT /api/price-listings/:id - Update a price listing (Business owner only)
router.put('/:id', authService.authMiddleware(), upload.array('images', 5), async (req, res) => {
  try {
    const userId = req.user.id; // Fixed: use 'id' instead of 'uid' for consistency
    const { id } = req.params;

    // Check if listing exists and belongs to the user
    const existingListing = await database.query(
      'SELECT * FROM price_listings WHERE id = $1 AND business_id = $2',
      [id, userId]
    );

    if (existingListing.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Price listing not found or you do not have permission to edit it'
      });
    }

    const {
      title,
      description,
      price,
      currency,
      unit,
      deliveryCharge,
      website,
      whatsapp,
      cityId,
      isActive,
      selectedVariables // Add selectedVariables to UPDATE request
    } = req.body;

    console.log('DEBUG: UPDATE - selectedVariables from request:', selectedVariables);

    // Handle uploaded images
    let images = existingListing.rows[0].images || [];
    if (typeof images === 'string') {
      images = JSON.parse(images);
    }
    
    if (req.files && req.files.length > 0) {
      const newImages = req.files.map(file => `/uploads/price-listings/${file.filename}`);
      images = [...images, ...newImages];
    }

    // Build update query dynamically
    const updateFields = [];
    const updateValues = [];
    let paramIndex = 1;

    if (title !== undefined) {
      updateFields.push(`title = $${paramIndex}`);
      updateValues.push(title);
      paramIndex++;
    }

    if (description !== undefined) {
      updateFields.push(`description = $${paramIndex}`);
      updateValues.push(description);
      paramIndex++;
    }

    if (price !== undefined) {
      updateFields.push(`price = $${paramIndex}`);
      updateValues.push(parseFloat(price));
      paramIndex++;
    }

    if (currency !== undefined) {
      updateFields.push(`currency = $${paramIndex}`);
      updateValues.push(currency);
      paramIndex++;
    }

    if (unit !== undefined) {
      updateFields.push(`unit = $${paramIndex}`);
      updateValues.push(unit);
      paramIndex++;
    }

    if (deliveryCharge !== undefined) {
      updateFields.push(`delivery_charge = $${paramIndex}`);
      updateValues.push(parseFloat(deliveryCharge));
      paramIndex++;
    }

    if (website !== undefined) {
      updateFields.push(`website = $${paramIndex}`);
      updateValues.push(website);
      paramIndex++;
    }

    if (whatsapp !== undefined) {
      updateFields.push(`whatsapp = $${paramIndex}`);
      updateValues.push(whatsapp);
      paramIndex++;
    }

    if (cityId !== undefined) {
      updateFields.push(`city_id = $${paramIndex}`);
      updateValues.push(cityId);
      paramIndex++;
    }

    if (isActive !== undefined) {
      updateFields.push(`is_active = $${paramIndex}`);
      updateValues.push(isActive);
      paramIndex++;
    }

    if (images !== existingListing.rows[0].images) {
      updateFields.push(`images = $${paramIndex}`);
      updateValues.push(JSON.stringify(images));
      paramIndex++;
    }

    if (selectedVariables !== undefined) {
      updateFields.push(`selected_variables = $${paramIndex}`);
      updateValues.push(JSON.stringify(selectedVariables));
      paramIndex++;
    }

    if (updateFields.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No fields to update'
      });
    }

    // Add updated_at
    updateFields.push('updated_at = NOW()');

    const updateQuery = `
      UPDATE price_listings 
      SET ${updateFields.join(', ')}
      WHERE id = $${paramIndex} AND business_id = $${paramIndex + 1}
      RETURNING *
    `;
    
    updateValues.push(id, userId);

    const result = await database.query(updateQuery, updateValues);
    const updatedListing = await formatPriceListing(result.rows[0]);

    res.json({
      success: true,
      message: 'Price listing updated successfully',
      data: updatedListing
    });

  } catch (error) {
    console.error('Error updating price listing:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error updating price listing', 
      error: error.message 
    });
  }
});

// PATCH /api/price-listings/:id/toggle-status - Toggle active/inactive status (Business owner only)
router.patch('/:id/toggle-status', authService.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;

    // Require business subscription (monthly or PPC) for product listings
    try {
      const sub = await db.queryOne(`
        SELECT us.*, sp.plan_type, sp.type AS plan_user_type
        FROM user_subscriptions us
        JOIN subscription_plans_new sp ON sp.id = us.plan_id
        WHERE us.user_id=$1 AND us.status IN ('active','trialing','past_due') AND sp.type='business'
        ORDER BY COALESCE(us.next_renewal_at, us.ends_at) DESC NULLS LAST, us.created_at DESC
        LIMIT 1
      `, [userId]);
      if (!sub) return res.status(402).json({ success:false, error:'subscription_required', message:'Active business subscription required to add prices' });
    } catch (e) {
      console.warn('[price-listings] subscription check failed', e?.message || e);
    }
    const { id } = req.params;

    // Check if listing exists and belongs to the user
    const existingListing = await database.query(
      'SELECT * FROM price_listings WHERE id = $1 AND business_id = $2',
      [id, userId]
    );

    if (existingListing.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Price listing not found or you do not have permission to modify it'
      });
    }

    const currentStatus = existingListing.rows[0].is_active;
    const newStatus = !currentStatus;

    // Toggle the is_active status
    const toggleQuery = `
      UPDATE price_listings 
      SET is_active = $3, updated_at = NOW()
      WHERE id = $1 AND business_id = $2
      RETURNING *
    `;

    const result = await database.query(toggleQuery, [id, userId, newStatus]);

    res.json({
      success: true,
      message: `Price listing ${newStatus ? 'activated' : 'deactivated'} successfully`,
      data: await formatPriceListing(result.rows[0])
    });

  } catch (error) {
    console.error('Error toggling price listing status:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error toggling price listing status', 
      error: error.message 
    });
  }
});

// DELETE /api/price-listings/:id/permanent - Permanently delete a price listing (Business owner only)
router.delete('/:id/permanent', authService.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    // Check if listing exists and belongs to the user
    const existingListing = await database.query(
      'SELECT * FROM price_listings WHERE id = $1 AND business_id = $2',
      [id, userId]
    );

    if (existingListing.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Price listing not found or you do not have permission to delete it'
      });
    }

    // Hard delete - completely remove from database
    const deleteQuery = `
      DELETE FROM price_listings 
      WHERE id = $1 AND business_id = $2
      RETURNING *
    `;

    const result = await database.query(deleteQuery, [id, userId]);

    res.json({
      success: true,
      message: 'Price listing permanently deleted',
      data: result.rows[0]
    });

  } catch (error) {
    console.error('Error permanently deleting price listing:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error permanently deleting price listing', 
      error: error.message 
    });
  }
});

// DELETE /api/price-listings/:id - Delete/deactivate a price listing (Business owner only)
router.delete('/:id', authService.authMiddleware(), async (req, res) => {
  try {
    const userId = req.user.id; // Changed from req.user.uid to req.user.id
    const { id } = req.params;

    // Check if listing exists and belongs to the user
    const existingListing = await database.query(
      'SELECT * FROM price_listings WHERE id = $1 AND business_id = $2',
      [id, userId]
    );

    if (existingListing.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Price listing not found or you do not have permission to delete it'
      });
    }

    // Soft delete by setting is_active to false
    const deleteQuery = `
      UPDATE price_listings 
      SET is_active = false, updated_at = NOW()
      WHERE id = $1 AND business_id = $2
      RETURNING *
    `;

    const result = await database.query(deleteQuery, [id, userId]);

    res.json({
      success: true,
      message: 'Price listing deleted successfully',
      data: await formatPriceListing(result.rows[0])
    });

  } catch (error) {
    console.error('Error deleting price listing:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error deleting price listing', 
      error: error.message 
    });
  }
});

// POST /api/price-listings/:id/track-view - Track when someone views a listing
router.post('/:id/track-view', async (req, res) => {
  try {
    const { id } = req.params;

    const updateQuery = `
      UPDATE price_listings 
      SET view_count = view_count + 1
      WHERE id = $1 AND is_active = true
      RETURNING view_count
    `;

    const result = await database.query(updateQuery, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Price listing not found'
      });
    }

    res.json({
      success: true,
      data: { viewCount: result.rows[0].view_count }
    });

  } catch (error) {
    console.error('Error tracking view:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error tracking view', 
      error: error.message 
    });
  }
});

// POST /api/price-listings/:id/track-contact - Track when someone contacts a business
router.post('/:id/track-contact', async (req, res) => {
  try {
    const { id } = req.params;

    const updateQuery = `
      UPDATE price_listings 
      SET contact_count = contact_count + 1
      WHERE id = $1 AND is_active = true
      RETURNING contact_count
    `;

    const result = await database.query(updateQuery, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Price listing not found'
      });
    }

    res.json({
      success: true,
      data: { contactCount: result.rows[0].contact_count }
    });

  } catch (error) {
    console.error('Error tracking contact:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error tracking contact', 
      error: error.message 
    });
  }
});

module.exports = router;
