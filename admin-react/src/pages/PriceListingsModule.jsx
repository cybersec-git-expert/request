import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Chip,
  IconButton,
  Button,
  Grid,
  Card,
  CardContent,
  TextField,
  InputAdornment,
  Menu,
  MenuItem,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Alert,
  CircularProgress,
  Tooltip,
  Avatar,
  Rating
} from '@mui/material';
import {
  Search,
  Visibility,
  Edit,
  Delete,
  FilterList,
  Refresh,
  Add,
  LocationOn,
  Person,
  AccessTime,
  AttachMoney,
  Category,
  Store,
  Star,
  ArrowBack,
  ArrowForward
} from '@mui/icons-material';
import useCountryFilter from '../hooks/useCountryFilter.jsx';
import { DataLookupService } from '../services/DataLookupService.js';
import { CurrencyService } from '../services/CurrencyService.js';

const PriceListingsModule = () => {
  const {
    getFilteredData,
    adminData,
    isSuperAdmin,
    getCountryDisplayName,
    userCountry
  } = useCountryFilter();

  const [listings, setListings] = useState([]);
  const [productGroups, setProductGroups] = useState([]);
  const [selectedProduct, setSelectedProduct] = useState(null);
  const [selectedProductForDetail, setSelectedProductForDetail] = useState(null);
  const [productPrices, setProductPrices] = useState([]);
  const [showProductDetail, setShowProductDetail] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterAnchorEl, setFilterAnchorEl] = useState(null);
  const [selectedStatus, setSelectedStatus] = useState('all');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [selectedListing, setSelectedListing] = useState(null);
  const [viewDialogOpen, setViewDialogOpen] = useState(false);
  const [productDataMap, setProductDataMap] = useState(new Map());
  const [businessDataMap, setBusinessDataMap] = useState(new Map());

  const statusColors = {
    active: 'success',
    inactive: 'error',
    pending: 'warning',
    expired: 'default'
  };

  const loadListings = async () => {
    try {
      setLoading(true);
      setError(null);

      const data = await getFilteredData('price_listings', adminData);
      console.log(`📊 Raw listings data:`, data);
      setListings(data || []);
      
      // Fetch product and business data for all listings
      if (data && data.length > 0) {
        // Get unique product IDs from both productId and masterProductId fields
        const uniqueProductIds = [...new Set(
          data.map(listing => listing.productId || listing.masterProductId).filter(Boolean)
        )];
        const uniqueBusinessIds = [...new Set(data.map(listing => listing.businessId).filter(Boolean))];
        
        console.log(`🔍 Found ${uniqueProductIds.length} unique products and ${uniqueBusinessIds.length} unique businesses`);
        console.log(`📦 Product IDs:`, uniqueProductIds);
        
        const [productData, businessData] = await Promise.all([
          DataLookupService.getMultipleProducts(uniqueProductIds),
          DataLookupService.getMultipleBusinesses(uniqueBusinessIds)
        ]);
        
        const productMap = new Map();
        const businessMap = new Map();
        
        uniqueProductIds.forEach((productId, index) => {
          if (productData[index]) {
            productMap.set(productId, productData[index]);
          }
        });
        
        uniqueBusinessIds.forEach((businessId, index) => {
          if (businessData[index]) {
            businessMap.set(businessId, businessData[index]);
            console.log(`📋 Business ${businessId}:`, businessData[index]);
          } else {
            console.warn(`❌ No business data for ID: ${businessId}`);
          }
        });
        
        setProductDataMap(productMap);
        setBusinessDataMap(businessMap);
        
        // Create product groups with price counts - grouped by product AND country
        const productGroupMap = new Map();
        
        data.forEach(listing => {
          // Try both productId and masterProductId field names
          const productId = listing.productId || listing.masterProductId;
          const productData = productMap.get(productId);
          
          // Try multiple country field names and fallback to user's country
          const country = listing.country || listing.countryCode || listing.countryName || userCountry || 'LK';
          
          // Create unique key combining product and country
          const groupKey = `${productId}_${country}`;
          
          console.log(`Processing listing:`, { 
            listingId: listing.id, 
            productId: listing.productId, 
            masterProductId: listing.masterProductId, 
            finalProductId: productId,
            businessId: listing.businessId,
            businessName: listing.businessName,
            business_name: listing.business_name,
            country: listing.country,
            countryCode: listing.countryCode,
            countryName: listing.countryName,
            finalCountry: country,
            groupKey: groupKey,
            hasProductData: !!productData 
          });
          
          if (productId) {
            // Create a fallback product data if we don't have the actual product data
            const fallbackProductData = productData || {
              name: listing.productName || listing.title || `Product ${productId}`,
              title: listing.productName || listing.title || `Product ${productId}`,
              category: listing.category || 'Other',
              categories: [listing.category || 'Other'],
              images: listing.productImages || []
            };
            
            if (!productGroupMap.has(groupKey)) {
              productGroupMap.set(groupKey, {
                productId,
                country,
                groupKey,
                productData: fallbackProductData,
                productName: fallbackProductData.name || fallbackProductData.title || `Product ${productId}`,
                categories: fallbackProductData.categories || [fallbackProductData.category || 'Other'],
                sampleImage: fallbackProductData.images?.[0] || listing.images?.[0] || listing.productImages?.[0],
                listings: [],
                priceCount: 0,
                totalListings: 0,
                minPrice: null,
                maxPrice: null,
                avgPrice: 0,
                averagePrice: 0,
                priceRange: { min: 0, max: 0 },
                businessCount: 0,
                statusBreakdown: { active: 0, pending: 0, inactive: 0 },
                averageRating: 0,
                totalReviews: 0
              });
            }
            
            const group = productGroupMap.get(groupKey);
            group.listings.push(listing);
            group.priceCount = group.listings.length;
            group.totalListings = group.listings.length;
            
            // Calculate price statistics
            const prices = group.listings
              .filter(l => l.price && !isNaN(parseFloat(l.price)))
              .map(l => parseFloat(l.price));
              
            if (prices.length > 0) {
              group.minPrice = Math.min(...prices);
              group.maxPrice = Math.max(...prices);
              group.avgPrice = prices.reduce((sum, price) => sum + price, 0) / prices.length;
              group.averagePrice = group.avgPrice;
              group.priceRange = { min: group.minPrice, max: group.maxPrice };
            }
            
            // Count unique businesses
            const uniqueBusinesses = new Set(group.listings.map(l => l.businessId).filter(Boolean));
            group.businessCount = uniqueBusinesses.size;
            
            // Calculate status breakdown
            group.statusBreakdown = {
              active: group.listings.filter(l => l.status === 'active').length,
              pending: group.listings.filter(l => l.status === 'pending').length,
              inactive: group.listings.filter(l => l.status === 'inactive').length
            };
            
            // Calculate average rating from businesses
            const businessRatings = group.listings
              .map(l => businessMap.get(l.businessId)?.rating)
              .filter(rating => rating != null);
            
            if (businessRatings.length > 0) {
              group.averageRating = businessRatings.reduce((sum, rating) => sum + rating, 0) / businessRatings.length;
            }
            
            // Count total reviews
            group.totalReviews = group.listings
              .map(l => businessMap.get(l.businessId)?.reviewCount || 0)
              .reduce((sum, count) => sum + count, 0);
          }
        });
        
        setProductGroups(Array.from(productGroupMap.values()));
        console.log(`📦 Created ${productGroupMap.size} product groups from ${data.length} listings`);
      }
      
      console.log(`📊 Loaded ${data?.length || 0} price listings for ${isSuperAdmin ? 'super admin' : `country admin (${userCountry})`}`);
    } catch (err) {
      console.error('Error loading price listings:', err);
      setError('Failed to load price listings: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadListings();
  }, [adminData]);

  const handleViewListing = (listing) => {
    setSelectedListing(listing);
    setViewDialogOpen(true);
  };

  const handleViewProductDetail = (productGroup) => {
    setSelectedProductForDetail(productGroup);
    
    // Sort listings by price (cheapest first), then by business rating
    const sortedListings = [...productGroup.listings].sort((a, b) => {
      const priceA = parseFloat(a.price) || 0;
      const priceB = parseFloat(b.price) || 0;
      
      if (priceA !== priceB) {
        return priceA - priceB; // Cheapest first
      }
      
      // If prices are equal, sort by business rating (highest first)
      const businessA = businessDataMap.get(a.businessId);
      const businessB = businessDataMap.get(b.businessId);
      const ratingA = businessA?.rating || 0;
      const ratingB = businessB?.rating || 0;
      
      return ratingB - ratingA;
    });
    
    setProductPrices(sortedListings);
    setShowProductDetail(true);
  };

  const handleBackToProducts = () => {
    setShowProductDetail(false);
    setSelectedProductForDetail(null);
    setProductPrices([]);
  };

  const handleStatusFilter = (status) => {
    setSelectedStatus(status);
    setFilterAnchorEl(null);
  };

  const handleCategoryFilter = (category) => {
    setSelectedCategory(category);
    setFilterAnchorEl(null);
  };

  const filteredListings = listings.filter(listing => {
    const matchesSearch = listing.title?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         listing.description?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         listing.businessName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         listing.category?.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesStatus = selectedStatus === 'all' || listing.status === selectedStatus;
    const matchesCategory = selectedCategory === 'all' || listing.category === selectedCategory;
    
    return matchesSearch && matchesStatus && matchesCategory;
  });

  const formatDate = (dateValue) => {
    if (!dateValue) return 'N/A';
    
    let date;
    if (dateValue.toDate) {
      date = dateValue.toDate();
    } else if (dateValue instanceof Date) {
      date = dateValue;
    } else {
      date = new Date(dateValue);
    }
    
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
  };

  const formatCurrency = (amount, currency) => {
    if (!amount && amount !== 0) return 'N/A';
    return CurrencyService.formatCurrency(amount, currency, userCountry);
  };

  const getCountryFlag = (countryCode) => {
    const flags = {
      'LK': '🇱🇰', // Sri Lanka
      'UK': '🇬🇧', // United Kingdom
      'US': '🇺🇸', // United States
      'IN': '🇮🇳', // India
      'AU': '🇦🇺', // Australia
      'CA': '🇨🇦', // Canada
      'DE': '🇩🇪', // Germany
      'FR': '🇫🇷', // France
      'JP': '🇯🇵', // Japan
      'CN': '🇨🇳', // China
      'AE': '🇦🇪', // UAE
      'SA': '🇸🇦', // Saudi Arabia
      // Add more country flags as needed
    };
    return flags[countryCode?.toUpperCase()] || '🌐';
  };

  const getCountryCurrency = (countryCode) => {
    const currencies = {
      'LK': 'LKR', // Sri Lanka
      'UK': 'GBP', // United Kingdom
      'US': 'USD', // United States
      'IN': 'INR', // India
      'AU': 'AUD', // Australia
      'CA': 'CAD', // Canada
      'DE': 'EUR', // Germany
      'FR': 'EUR', // France
      'JP': 'JPY', // Japan
      'CN': 'CNY', // China
      'AE': 'AED', // UAE
      'SA': 'SAR', // Saudi Arabia
      // Add more country currencies as needed
    };
    return currencies[countryCode?.toUpperCase()] || 'USD';
  };

  const getListingStats = () => {
    return {
      total: filteredListings.length,
      active: filteredListings.filter(l => l.status === 'active').length,
      inactive: filteredListings.filter(l => l.status === 'inactive').length,
      pending: filteredListings.filter(l => l.status === 'pending').length,
    };
  };

  const getUniqueCategories = () => {
    const categories = listings.map(l => l.category).filter(Boolean);
    return [...new Set(categories)];
  };

  const stats = getListingStats();
  const categories = getUniqueCategories();

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3 }}>
      {/* Header */}
      <Box sx={{ mb: 3 }}>
        <Typography variant="h4" gutterBottom>
          Price Listings Management
        </Typography>
        <Typography variant="body1" color="text.secondary">
          {isSuperAdmin ? 'Manage all price listings across countries' : `Manage price listings in ${getCountryDisplayName(userCountry)}`}
        </Typography>
      </Box>

      {/* Error Alert */}
      {error && (
        <Alert severity="error" sx={{ mb: 3 }}>
          {error}
        </Alert>
      )}

      {/* Stats Cards */}
      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom variant="h6">
                Total Listings
              </Typography>
              <Typography variant="h4">
                {stats.total}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom variant="h6">
                Active
              </Typography>
              <Typography variant="h4" color="success.main">
                {stats.active}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom variant="h6">
                Pending
              </Typography>
              <Typography variant="h4" color="warning.main">
                {stats.pending}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom variant="h6">
                Inactive
              </Typography>
              <Typography variant="h4" color="error.main">
                {stats.inactive}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Search and Filter Bar */}
      <Paper sx={{ p: 2, mb: 3 }}>
        <Box sx={{ display: 'flex', gap: 2, alignItems: 'center', flexWrap: 'wrap' }}>
          <TextField
            placeholder="Search listings..."
            variant="outlined"
            size="small"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <Search />
                </InputAdornment>
              ),
            }}
            sx={{ minWidth: 300 }}
          />
          
          <Button
            variant="outlined"
            startIcon={<FilterList />}
            onClick={(e) => setFilterAnchorEl(e.currentTarget)}
          >
            Filters ({selectedStatus !== 'all' || selectedCategory !== 'all' ? 'Active' : 'None'})
          </Button>

          <Button
            variant="outlined"
            startIcon={<Refresh />}
            onClick={loadListings}
          >
            Refresh
          </Button>
        </Box>
      </Paper>

      {/* Filter Menu */}
      <Menu
        anchorEl={filterAnchorEl}
        open={Boolean(filterAnchorEl)}
        onClose={() => setFilterAnchorEl(null)}
      >
        <MenuItem disabled><strong>Status</strong></MenuItem>
        <MenuItem onClick={() => handleStatusFilter('all')} selected={selectedStatus === 'all'}>All Status</MenuItem>
        <MenuItem onClick={() => handleStatusFilter('active')} selected={selectedStatus === 'active'}>Active</MenuItem>
        <MenuItem onClick={() => handleStatusFilter('inactive')} selected={selectedStatus === 'inactive'}>Inactive</MenuItem>
        <MenuItem onClick={() => handleStatusFilter('pending')} selected={selectedStatus === 'pending'}>Pending</MenuItem>
        <MenuItem onClick={() => handleStatusFilter('expired')} selected={selectedStatus === 'expired'}>Expired</MenuItem>
        
        {categories.length > 0 && (
          <>
            <MenuItem disabled><strong>Category</strong></MenuItem>
            <MenuItem onClick={() => handleCategoryFilter('all')} selected={selectedCategory === 'all'}>All Categories</MenuItem>
            {categories.map((category) => (
              <MenuItem 
                key={category} 
                onClick={() => handleCategoryFilter(category)} 
                selected={selectedCategory === category}
              >
                {category}
              </MenuItem>
            ))}
          </>
        )}
      </Menu>

      {/* Main Content - Products View or Product Detail View */}
      {selectedProductForDetail ? (
        // Product Detail View - Show all businesses for selected product
        <Paper>
          <Box sx={{ p: 2, borderBottom: 1, borderColor: 'divider', display: 'flex', alignItems: 'center', gap: 2 }}>
            <IconButton onClick={handleBackToProducts} color="primary">
              <ArrowBack />
            </IconButton>
            <Box>
              <Typography variant="h6">
                {selectedProductForDetail.productName}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                {selectedProductForDetail.totalListings} listings • Average: {formatCurrency(selectedProductForDetail.averagePrice, getCountryCurrency(selectedProductForDetail.country))} • Range: {formatCurrency(selectedProductForDetail.priceRange.min, getCountryCurrency(selectedProductForDetail.country))} - {formatCurrency(selectedProductForDetail.priceRange.max, getCountryCurrency(selectedProductForDetail.country))}
              </Typography>
            </Box>
          </Box>
          
          <TableContainer>
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell>Business</TableCell>
                  <TableCell>Price</TableCell>
                  <TableCell>Status</TableCell>
                  <TableCell>Location</TableCell>
                  <TableCell>Rating</TableCell>
                  <TableCell>Created</TableCell>
                  <TableCell>Country</TableCell>
                  <TableCell align="center">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {selectedProductForDetail.listings
                  .sort((a, b) => (a.price || 0) - (b.price || 0)) // Sort by price - cheapest first
                  .map((listing) => (
                  <TableRow key={listing.id} hover>
                    <TableCell>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                        {listing.images && listing.images[0] && (
                          <Avatar 
                            src={listing.images[0]} 
                            alt={listing.title}
                            variant="rounded"
                          />
                        )}
                        <Box>
                          <Typography variant="subtitle2">
                            {(() => {
                              const business = businessDataMap.get(listing.businessId);
                              if (business) {
                                return business.businessName || business.name || business.title || `Business ${listing.businessId}`;
                              }
                              return listing.businessName || listing.business_name || 'Unknown Business';
                            })()}
                          </Typography>
                          <Typography variant="caption" color="text.secondary" noWrap sx={{ maxWidth: 200 }}>
                            {listing.description || listing.productName || 'No description'}
                          </Typography>
                        </Box>
                      </Box>
                    </TableCell>
                    <TableCell>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <AttachMoney fontSize="small" color="action" />
                        <Typography variant="body2" fontWeight="bold">
                          {formatCurrency(listing.price, listing.currency)}
                        </Typography>
                      </Box>
                    </TableCell>
                    <TableCell>
                      <Chip 
                        label={listing.status?.toUpperCase() || 'N/A'}
                        color={statusColors[listing.status] || 'default'}
                        size="small"
                      />
                    </TableCell>
                    <TableCell>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <LocationOn fontSize="small" color="action" />
                        <Typography variant="body2" noWrap sx={{ maxWidth: 150 }}>
                          {listing.location?.address || 
                           listing.location?.name || 
                           listing.address || 
                           listing.city || 
                           'N/A'}
                        </Typography>
                      </Box>
                    </TableCell>
                    <TableCell>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Rating 
                          value={(() => {
                            const business = businessDataMap.get(listing.businessId);
                            return business?.rating || listing.averageRating || listing.rating || 0;
                          })()} 
                          size="small" 
                          readOnly 
                          precision={0.1}
                        />
                        <Typography variant="caption" color="text.secondary">
                          ({(() => {
                            const business = businessDataMap.get(listing.businessId);
                            return business?.reviewCount || listing.reviewCount || 0;
                          })()})
                        </Typography>
                      </Box>
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2">
                        {formatDate(listing.createdAt)}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Typography variant="body2">
                          {getCountryFlag(listing.country || listing.countryCode || listing.countryName || userCountry || 'LK')}
                        </Typography>
                        <Typography variant="body2">
                          {getCountryDisplayName(listing.country || listing.countryCode || listing.countryName || userCountry || 'LK')}
                        </Typography>
                      </Box>
                    </TableCell>
                    <TableCell align="center">
                      <Tooltip title="View Details">
                        <IconButton
                          size="small"
                          onClick={() => handleViewListing(listing)}
                          color="primary"
                        >
                          <Visibility fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        </Paper>
      ) : (
        // Products Overview - Show grouped products with statistics
        <Grid container spacing={2}>
          {productGroups.length === 0 ? (
            <Grid item xs={12}>
              <Paper sx={{ p: 4, textAlign: 'center' }}>
                <Typography variant="body1" color="text.secondary">
                  No products found matching your criteria
                </Typography>
              </Paper>
            </Grid>
          ) : (
            productGroups.map((productData) => (
              <Grid item xs={12} sm={6} md={4} key={productData.groupKey}>
                <Card 
                  sx={{ 
                    cursor: 'pointer',
                    transition: 'all 0.2s ease-in-out',
                    position: 'relative',
                    '&:hover': {
                      transform: 'translateY(-2px)',
                      boxShadow: 4
                    }
                  }}
                  onClick={() => handleViewProductDetail(productData)}
                >
                  <CardContent>
                    <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 2, mb: 2 }}>
                      {productData.sampleImage && (
                        <Avatar 
                          src={productData.sampleImage} 
                          alt={productData.productName}
                          variant="rounded"
                          sx={{ width: 60, height: 60 }}
                        />
                      )}
                      <Box sx={{ flex: 1 }}>
                        <Typography variant="h6" noWrap>
                          {productData.productName}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                          {productData.categories.join(', ')}
                        </Typography>
                      </Box>
                    </Box>
                    
                    <Box sx={{ mb: 2 }}>
                      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
                        <Typography variant="body2" color="text.secondary">
                          Total Listings
                        </Typography>
                        <Chip 
                          label={productData.totalListings}
                          color="primary"
                          size="small"
                        />
                      </Box>
                      
                      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
                        <Typography variant="body2" color="text.secondary">
                          Price Range
                        </Typography>
                        <Typography variant="body2" fontWeight="bold">
                          {formatCurrency(productData.priceRange.min, getCountryCurrency(productData.country))} - {formatCurrency(productData.priceRange.max, getCountryCurrency(productData.country))}
                        </Typography>
                      </Box>
                      
                      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
                        <Typography variant="body2" color="text.secondary">
                          Average Price
                        </Typography>
                        <Typography variant="body2" fontWeight="bold" color="primary.main">
                          {formatCurrency(productData.averagePrice, getCountryCurrency(productData.country))}
                        </Typography>
                      </Box>
                      
                      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <Typography variant="body2" color="text.secondary">
                          Businesses
                        </Typography>
                        <Typography variant="body2">
                          {productData.businessCount} businesses
                        </Typography>
                      </Box>
                    </Box>
                    
                    <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                      <Chip 
                        label={`${productData.statusBreakdown.active || 0} Active`}
                        color="success"
                        size="small"
                        variant="outlined"
                      />
                      {productData.statusBreakdown.pending > 0 && (
                        <Chip 
                          label={`${productData.statusBreakdown.pending} Pending`}
                          color="warning"
                          size="small"
                          variant="outlined"
                        />
                      )}
                      {productData.statusBreakdown.inactive > 0 && (
                        <Chip 
                          label={`${productData.statusBreakdown.inactive} Inactive`}
                          color="error"
                          size="small"
                          variant="outlined"
                        />
                      )}
                    </Box>
                    
                    <Box sx={{ mt: 2, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Rating 
                          value={productData.averageRating} 
                          size="small" 
                          readOnly 
                          precision={0.1}
                        />
                        <Typography variant="caption" color="text.secondary">
                          ({productData.totalReviews} reviews)
                        </Typography>
                      </Box>
                      
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Typography sx={{ fontSize: '1.2rem' }}>
                          {getCountryFlag(productData.country)}
                        </Typography>
                        <IconButton 
                          size="small" 
                          color="primary"
                          onClick={(e) => {
                            e.stopPropagation();
                            handleViewProductDetail(productData);
                          }}
                        >
                          <ArrowForward fontSize="small" />
                        </IconButton>
                      </Box>
                    </Box>
                  </CardContent>
                </Card>
              </Grid>
            ))
          )}
        </Grid>
      )}

      {/* View Listing Dialog */}
      <Dialog
        open={viewDialogOpen}
        onClose={() => setViewDialogOpen(false)}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>
          Listing Details
        </DialogTitle>
        <DialogContent>
          {selectedListing && (
            <Box sx={{ pt: 1 }}>
              <Grid container spacing={2}>
                <Grid item xs={12}>
                  <Typography variant="h6">{selectedListing.title}</Typography>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                    {selectedListing.description}
                  </Typography>
                </Grid>
                
                {selectedListing.images && selectedListing.images.length > 0 && (
                  <Grid item xs={12}>
                    <Typography variant="subtitle2" sx={{ mb: 1 }}>Images:</Typography>
                    <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                      {selectedListing.images.slice(0, 4).map((image, index) => (
                        <Avatar 
                          key={index}
                          src={image} 
                          alt={`Image ${index + 1}`}
                          variant="rounded"
                          sx={{ width: 80, height: 80 }}
                        />
                      ))}
                    </Box>
                  </Grid>
                )}
                
                <Grid item xs={6}>
                  <Typography variant="subtitle2">Business:</Typography>
                  <Typography variant="body2">{selectedListing.businessName || 'N/A'}</Typography>
                </Grid>
                
                <Grid item xs={6}>
                  <Typography variant="subtitle2">Category:</Typography>
                  <Typography variant="body2">{selectedListing.category || 'N/A'}</Typography>
                </Grid>
                
                <Grid item xs={6}>
                  <Typography variant="subtitle2">Price:</Typography>
                  <Typography variant="body2">
                    {formatCurrency(selectedListing.price, selectedListing.currency)}
                  </Typography>
                </Grid>
                
                <Grid item xs={6}>
                  <Typography variant="subtitle2">Status:</Typography>
                  <Chip 
                    label={selectedListing.status?.toUpperCase()}
                    color={statusColors[selectedListing.status] || 'default'}
                    size="small"
                  />
                </Grid>
                
                <Grid item xs={6}>
                  <Typography variant="subtitle2">Rating:</Typography>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Rating 
                      value={selectedListing.averageRating || 0} 
                      size="small" 
                      readOnly 
                      precision={0.1}
                    />
                    <Typography variant="body2">
                      ({selectedListing.reviewCount || 0} reviews)
                    </Typography>
                  </Box>
                </Grid>
                
                <Grid item xs={6}>
                  <Typography variant="subtitle2">Country:</Typography>
                  <Typography variant="body2">
                    {getCountryDisplayName(selectedListing.country)}
                  </Typography>
                </Grid>
                
                <Grid item xs={12}>
                  <Typography variant="subtitle2">Location:</Typography>
                  <Typography variant="body2">
                    {selectedListing.location?.address || selectedListing.location?.name || 'N/A'}
                  </Typography>
                </Grid>
                
                <Grid item xs={6}>
                  <Typography variant="subtitle2">Created:</Typography>
                  <Typography variant="body2">{formatDate(selectedListing.createdAt)}</Typography>
                </Grid>
                
                <Grid item xs={6}>
                  <Typography variant="subtitle2">Updated:</Typography>
                  <Typography variant="body2">{formatDate(selectedListing.updatedAt)}</Typography>
                </Grid>

                {selectedListing.tags && selectedListing.tags.length > 0 && (
                  <Grid item xs={12}>
                    <Typography variant="subtitle2">Tags:</Typography>
                    <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1, mt: 1 }}>
                      {selectedListing.tags.map((tag, index) => (
                        <Chip key={index} label={tag} size="small" variant="outlined" />
                      ))}
                    </Box>
                  </Grid>
                )}
              </Grid>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setViewDialogOpen(false)}>Close</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default PriceListingsModule;
