import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Paper,
  Button,
  Grid,
  Card,
  CardContent,
  CardMedia,
  TextField,
  InputAdornment,
  Chip,
  IconButton,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Stack,
  Divider,
  Link,
  Alert,
  CircularProgress,
  Avatar,
  Tooltip,
  Dialog,
  DialogTitle,
  DialogContent
} from '@mui/material';
import {
  Search,
  LocationOn,
  AttachMoney,
  LocalShipping,
  WhatsApp,
  Language,
  Store,
  Visibility,
  Sort,
  FilterList,
  Compare,
  Star,
  Phone,
  ExpandMore,
  ExpandLess
} from '@mui/icons-material';
import api from '../services/apiClient';

const PriceComparisonPage = () => {
  const [products, setProducts] = useState([]);
  const [priceListings, setPriceListings] = useState([]);
  const [selectedProduct, setSelectedProduct] = useState(null);
  const [loading, setLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [sortBy, setSortBy] = useState('price_asc');
  const [showFilters, setShowFilters] = useState(false);
  const [error, setError] = useState(null);
  const [detailsDialogOpen, setDetailsDialogOpen] = useState(false);
  const [selectedListing, setSelectedListing] = useState(null);

  // Filters
  const [filters, setFilters] = useState({
    maxPrice: '',
    hasDelivery: false,
    hasWhatsApp: false,
    hasWebsite: false
  });

  useEffect(() => {
    if (searchQuery.length > 2) {
      searchProducts();
    }
  }, [searchQuery]);

  useEffect(() => {
    if (selectedProduct) {
      loadPriceListings();
    }
  }, [selectedProduct, sortBy, filters]);

  const searchProducts = async () => {
    try {
      setLoading(true);
      const response = await api.get('/api/price-listings/search', {
        params: { 
          q: searchQuery, 
          country: 'LK',
          limit: 50
        }
      });
      
      if (response.data.success) {
        setProducts(response.data.data);
      }
    } catch (error) {
      console.error('Error searching products:', error);
      setError('Failed to search products');
    } finally {
      setLoading(false);
    }
  };

  const loadPriceListings = async () => {
    try {
      setLoading(true);
      const params = {
        masterProductId: selectedProduct.id,
        country: 'LK',
        sortBy: sortBy
      };

      // Apply filters
      if (filters.maxPrice) {
        params.maxPrice = parseFloat(filters.maxPrice);
      }
      if (filters.hasDelivery) {
        params.hasDelivery = true;
      }
      if (filters.hasWhatsApp) {
        params.hasWhatsApp = true;
      }
      if (filters.hasWebsite) {
        params.hasWebsite = true;
      }

      const response = await api.get('/api/price-listings', { params });
      
      if (response.data.success) {
        setPriceListings(response.data.data);
      }
    } catch (error) {
      console.error('Error loading price listings:', error);
      setError('Failed to load price listings');
    } finally {
      setLoading(false);
    }
  };

  const handleProductSelect = (product) => {
    setSelectedProduct(product);
    setPriceListings([]);
  };

  const handleContactClick = async (listing) => {
    try {
      // Track contact
      await api.post(`/api/price-listings/${listing.id}/contact`);
      
      // Update contact count in UI
      setPriceListings(prev => 
        prev.map(item => 
          item.id === listing.id 
            ? { ...item, contactCount: item.contactCount + 1 }
            : item
        )
      );
    } catch (error) {
      console.error('Error tracking contact:', error);
    }
  };

  const handleViewDetails = async (listing) => {
    try {
      // Track view
      await api.post(`/api/price-listings/${listing.id}/view`);
      
      // Update view count in UI
      setPriceListings(prev => 
        prev.map(item => 
          item.id === listing.id 
            ? { ...item, viewCount: item.viewCount + 1 }
            : item
        )
      );

      setSelectedListing(listing);
      setDetailsDialogOpen(true);
    } catch (error) {
      console.error('Error tracking view:', error);
    }
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('en-LK', {
      style: 'currency',
      currency: 'LKR',
      minimumFractionDigits: 0
    }).format(amount);
  };

  const getTotalPrice = (listing) => {
    return listing.price + (listing.deliveryCharge || 0);
  };

  const sortOptions = [
    { value: 'price_asc', label: 'Price: Low to High' },
    { value: 'price_desc', label: 'Price: High to Low' },
    { value: 'total_price_asc', label: 'Total Price: Low to High' },
    { value: 'newest', label: 'Newest First' },
    { value: 'most_viewed', label: 'Most Viewed' }
  ];

  return (
    <Box sx={{ p: 3, maxWidth: 1200, mx: 'auto' }}>
      {/* Header */}
      <Box sx={{ textAlign: 'center', mb: 4 }}>
        <Typography variant="h3" gutterBottom color="primary">
          Price Comparison
        </Typography>
        <Typography variant="h6" color="text.secondary">
          Find the best prices from verified businesses
        </Typography>
      </Box>

      {/* Search Section */}
      <Paper sx={{ p: 3, mb: 3 }}>
        <TextField
          fullWidth
          placeholder="Search for products (e.g., iPhone, Samsung TV, Rice)"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <Search />
              </InputAdornment>
            ),
          }}
          sx={{ mb: 2 }}
        />

        {/* Product Selection */}
        {products.length > 0 && !selectedProduct && (
          <Box>
            <Typography variant="h6" gutterBottom>
              Select a Product:
            </Typography>
            <Grid container spacing={2}>
              {products.map((product) => (
                <Grid item xs={12} sm={6} md={4} key={product.id}>
                  <Card 
                    sx={{ 
                      cursor: 'pointer',
                      '&:hover': { elevation: 4 }
                    }}
                    onClick={() => handleProductSelect(product)}
                  >
                    <CardContent>
                      <Typography variant="h6" gutterBottom>
                        {product.name}
                      </Typography>
                      {product.brand && (
                        <Typography variant="body2" color="text.secondary">
                          Brand: {product.brand.name}
                        </Typography>
                      )}
                      <Chip
                        label={`${product.listingCount} prices available`}
                        size="small"
                        color="primary"
                        sx={{ mt: 1 }}
                      />
                    </CardContent>
                  </Card>
                </Grid>
              ))}
            </Grid>
          </Box>
        )}
      </Paper>

      {/* Selected Product & Filters */}
      {selectedProduct && (
        <Paper sx={{ p: 3, mb: 3 }}>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 2 }}>
            <Box>
              <Typography variant="h5" gutterBottom>
                {selectedProduct.name}
              </Typography>
              {selectedProduct.brand && (
                <Typography variant="body1" color="text.secondary">
                  Brand: {selectedProduct.brand.name}
                </Typography>
              )}
            </Box>
            <Button
              variant="outlined"
              onClick={() => {
                setSelectedProduct(null);
                setPriceListings([]);
              }}
            >
              Search Different Product
            </Button>
          </Box>

          <Stack direction="row" spacing={2} alignItems="center" flexWrap="wrap" gap={2}>
            <FormControl size="small" sx={{ minWidth: 200 }}>
              <InputLabel>Sort By</InputLabel>
              <Select
                value={sortBy}
                label="Sort By"
                onChange={(e) => setSortBy(e.target.value)}
              >
                {sortOptions.map((option) => (
                  <MenuItem key={option.value} value={option.value}>
                    {option.label}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>

            <Button
              startIcon={<FilterList />}
              onClick={() => setShowFilters(!showFilters)}
              endIcon={showFilters ? <ExpandLess /> : <ExpandMore />}
            >
              Filters
            </Button>
          </Stack>

          {/* Filters */}
          {showFilters && (
            <Box sx={{ mt: 2, p: 2, bgcolor: 'grey.50', borderRadius: 1 }}>
              <Grid container spacing={2}>
                <Grid item xs={12} sm={6} md={3}>
                  <TextField
                    fullWidth
                    label="Max Price"
                    type="number"
                    size="small"
                    value={filters.maxPrice}
                    onChange={(e) => setFilters({ ...filters, maxPrice: e.target.value })}
                    InputProps={{
                      startAdornment: <InputAdornment position="start">LKR</InputAdornment>,
                    }}
                  />
                </Grid>
                <Grid item xs={12} sm={6} md={9}>
                  <Stack direction="row" spacing={1} flexWrap="wrap">
                    <Chip
                      label="Has Delivery"
                      clickable
                      color={filters.hasDelivery ? 'primary' : 'default'}
                      onClick={() => setFilters({ ...filters, hasDelivery: !filters.hasDelivery })}
                      icon={<LocalShipping />}
                    />
                    <Chip
                      label="Has WhatsApp"
                      clickable
                      color={filters.hasWhatsApp ? 'primary' : 'default'}
                      onClick={() => setFilters({ ...filters, hasWhatsApp: !filters.hasWhatsApp })}
                      icon={<WhatsApp />}
                    />
                    <Chip
                      label="Has Website"
                      clickable
                      color={filters.hasWebsite ? 'primary' : 'default'}
                      onClick={() => setFilters({ ...filters, hasWebsite: !filters.hasWebsite })}
                      icon={<Language />}
                    />
                  </Stack>
                </Grid>
              </Grid>
            </Box>
          )}
        </Paper>
      )}

      {/* Error Alert */}
      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {/* Loading */}
      {loading && (
        <Box display="flex" justifyContent="center" my={4}>
          <CircularProgress />
        </Box>
      )}

      {/* Price Listings */}
      {!loading && selectedProduct && priceListings.length === 0 && (
        <Paper sx={{ p: 4, textAlign: 'center' }}>
          <Typography variant="h6" gutterBottom>
            No Prices Found
          </Typography>
          <Typography variant="body2" color="text.secondary">
            No businesses have listed prices for this product yet.
          </Typography>
        </Paper>
      )}

      {priceListings.length > 0 && (
        <Box>
          <Typography variant="h5" gutterBottom>
            Price Comparison ({priceListings.length} listings)
          </Typography>
          
          <Grid container spacing={3}>
            {priceListings.map((listing, index) => (
              <Grid item xs={12} md={6} lg={4} key={listing.id}>
                <Card sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
                  {/* Best Price Badge */}
                  {index === 0 && sortBy.includes('price_asc') && (
                    <Box sx={{ position: 'absolute', top: 10, left: 10, zIndex: 1 }}>
                      <Chip
                        label="Best Price"
                        color="success"
                        size="small"
                        icon={<Star />}
                      />
                    </Box>
                  )}

                  {listing.images && listing.images.length > 0 && (
                    <CardMedia
                      component="img"
                      height="140"
                      image={listing.images[0]}
                      alt={listing.title}
                    />
                  )}

                  <CardContent sx={{ flexGrow: 1 }}>
                    <Typography variant="h6" gutterBottom>
                      {listing.title}
                    </Typography>

                    {listing.description && (
                      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                        {listing.description.substring(0, 100)}
                        {listing.description.length > 100 && '...'}
                      </Typography>
                    )}

                    {/* Business Info */}
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                      <Avatar sx={{ width: 24, height: 24 }}>
                        <Store fontSize="small" />
                      </Avatar>
                      <Typography variant="body2">
                        {listing.business?.name || 'Verified Business'}
                      </Typography>
                    </Box>

                    {/* Pricing */}
                    <Box sx={{ mb: 2 }}>
                      <Typography variant="h4" color="primary" gutterBottom>
                        {formatCurrency(listing.price)}
                        {listing.unit && (
                          <Typography component="span" variant="body2" color="text.secondary">
                            /{listing.unit}
                          </Typography>
                        )}
                      </Typography>

                      {listing.deliveryCharge > 0 && (
                        <Typography variant="body2" color="text.secondary">
                          + {formatCurrency(listing.deliveryCharge)} delivery
                        </Typography>
                      )}

                      <Typography variant="h6" color="success.main">
                        Total: {formatCurrency(getTotalPrice(listing))}
                      </Typography>
                    </Box>

                    {/* Stats */}
                    <Stack direction="row" spacing={1} sx={{ mb: 2 }}>
                      <Chip
                        icon={<Visibility />}
                        label={`${listing.viewCount} views`}
                        size="small"
                        variant="outlined"
                      />
                    </Stack>

                    {/* Contact Options */}
                    <Stack direction="row" spacing={1} flexWrap="wrap" gap={1}>
                      {listing.whatsapp && (
                        <Tooltip title={`WhatsApp: ${listing.whatsapp}`}>
                          <IconButton
                            color="success"
                            onClick={() => {
                              handleContactClick(listing);
                              window.open(`https://wa.me/${listing.whatsapp.replace(/[^0-9]/g, '')}`, '_blank');
                            }}
                          >
                            <WhatsApp />
                          </IconButton>
                        </Tooltip>
                      )}
                      {listing.website && (
                        <Tooltip title="Visit Website">
                          <IconButton
                            color="primary"
                            onClick={() => {
                              handleContactClick(listing);
                              window.open(listing.website, '_blank');
                            }}
                          >
                            <Language />
                          </IconButton>
                        </Tooltip>
                      )}
                      <Button
                        size="small"
                        variant="outlined"
                        onClick={() => handleViewDetails(listing)}
                      >
                        View Details
                      </Button>
                    </Stack>
                  </CardContent>
                </Card>
              </Grid>
            ))}
          </Grid>
        </Box>
      )}

      {/* Details Dialog */}
      <Dialog
        open={detailsDialogOpen}
        onClose={() => setDetailsDialogOpen(false)}
        maxWidth="md"
        fullWidth
      >
        {selectedListing && (
          <>
            <DialogTitle>
              {selectedListing.title}
            </DialogTitle>
            <DialogContent>
              <Grid container spacing={3}>
                {selectedListing.images && selectedListing.images.length > 0 && (
                  <Grid item xs={12} md={6}>
                    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                      {selectedListing.images.map((image, index) => (
                        <img
                          key={index}
                          src={image}
                          alt={`${selectedListing.title} ${index + 1}`}
                          style={{ width: '100%', borderRadius: 8 }}
                        />
                      ))}
                    </Box>
                  </Grid>
                )}
                
                <Grid item xs={12} md={selectedListing.images?.length > 0 ? 6 : 12}>
                  <Stack spacing={2}>
                    <Box>
                      <Typography variant="h4" color="primary">
                        {formatCurrency(selectedListing.price)}
                        {selectedListing.unit && (
                          <Typography component="span" variant="body1" color="text.secondary">
                            /{selectedListing.unit}
                          </Typography>
                        )}
                      </Typography>
                      {selectedListing.deliveryCharge > 0 && (
                        <Typography variant="body1" color="text.secondary">
                          + {formatCurrency(selectedListing.deliveryCharge)} delivery
                        </Typography>
                      )}
                      <Typography variant="h5" color="success.main">
                        Total: {formatCurrency(getTotalPrice(selectedListing))}
                      </Typography>
                    </Box>

                    {selectedListing.description && (
                      <Box>
                        <Typography variant="h6" gutterBottom>
                          Description
                        </Typography>
                        <Typography variant="body1">
                          {selectedListing.description}
                        </Typography>
                      </Box>
                    )}

                    <Box>
                      <Typography variant="h6" gutterBottom>
                        Business Information
                      </Typography>
                      <Typography variant="body1">
                        {selectedListing.business?.name || 'Verified Business'}
                      </Typography>
                      {selectedListing.business?.address && (
                        <Typography variant="body2" color="text.secondary">
                          {selectedListing.business.address}
                        </Typography>
                      )}
                    </Box>

                    <Box>
                      <Typography variant="h6" gutterBottom>
                        Contact Information
                      </Typography>
                      <Stack spacing={1}>
                        {selectedListing.whatsapp && (
                          <Button
                            variant="contained"
                            color="success"
                            startIcon={<WhatsApp />}
                            onClick={() => {
                              handleContactClick(selectedListing);
                              window.open(`https://wa.me/${selectedListing.whatsapp.replace(/[^0-9]/g, '')}`, '_blank');
                            }}
                          >
                            WhatsApp: {selectedListing.whatsapp}
                          </Button>
                        )}
                        {selectedListing.website && (
                          <Button
                            variant="outlined"
                            startIcon={<Language />}
                            onClick={() => {
                              handleContactClick(selectedListing);
                              window.open(selectedListing.website, '_blank');
                            }}
                          >
                            Visit Website
                          </Button>
                        )}
                      </Stack>
                    </Box>
                  </Stack>
                </Grid>
              </Grid>
            </DialogContent>
          </>
        )}
      </Dialog>
    </Box>
  );
};

export default PriceComparisonPage;
