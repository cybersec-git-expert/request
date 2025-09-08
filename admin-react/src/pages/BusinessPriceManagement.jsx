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
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Alert,
  CircularProgress,
  Chip,
  IconButton,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Autocomplete,
  Stack,
  Divider
} from '@mui/material';
import {
  Search,
  Add,
  Edit,
  Delete,
  Visibility,
  AttachMoney,
  LocalShipping,
  PhotoCamera,
  WhatsApp,
  Language,
  LocationOn,
  Save,
  Cancel
} from '@mui/icons-material';
import api from '../services/apiClient';

const BusinessPriceManagement = () => {
  const [listings, setListings] = useState([]);
  const [products, setProducts] = useState([]);
  const [selectedProduct, setSelectedProduct] = useState(null);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [addDialogOpen, setAddDialogOpen] = useState(false);
  const [editDialogOpen, setEditDialogOpen] = useState(false);
  const [selectedListing, setSelectedListing] = useState(null);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);

  // Form states
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    price: '',
    deliveryCharge: '0',
    unit: '',
    website: '',
    whatsapp: '',
    images: []
  });

  useEffect(() => {
    loadBusinessListings();
  }, []);

  const loadBusinessListings = async () => {
    try {
      setLoading(true);
      const response = await api.get('/api/price-listings', {
        params: { country: 'LK' }
      });
      
      if (response.data.success) {
        setListings(response.data.data);
      }
    } catch (error) {
      console.error('Error loading business listings:', error);
      setError('Failed to load your price listings');
    } finally {
      setLoading(false);
    }
  };

  const searchProducts = async (query) => {
    if (!query || query.length < 2) {
      setProducts([]);
      return;
    }

    try {
      const response = await api.get('/api/price-listings/search', {
        params: { q: query, country: 'LK', limit: 20 }
      });
      
      if (response.data.success) {
        setProducts(response.data.data);
      }
    } catch (error) {
      console.error('Error searching products:', error);
    }
  };

  const handleProductSelect = (product) => {
    setSelectedProduct(product);
    setFormData({
      ...formData,
      title: product.name,
      unit: product.baseUnit || ''
    });
  };

  const handleAddListing = async () => {
    if (!selectedProduct) {
      setError('Please select a product first');
      return;
    }

    try {
      const listingData = {
        masterProductId: selectedProduct.id,
        title: formData.title,
        description: formData.description,
        price: parseFloat(formData.price),
        deliveryCharge: parseFloat(formData.deliveryCharge),
        unit: formData.unit,
        website: formData.website,
        whatsapp: formData.whatsapp,
        countryCode: 'LK'
      };

      const response = await api.post('/api/price-listings', listingData);
      
      if (response.data.success) {
        setSuccess('Price listing added successfully!');
        setAddDialogOpen(false);
        resetForm();
        loadBusinessListings();
      }
    } catch (error) {
      console.error('Error adding listing:', error);
      setError(error.response?.data?.message || 'Failed to add price listing');
    }
  };

  const handleEditListing = async () => {
    try {
      const updates = {
        title: formData.title,
        description: formData.description,
        price: parseFloat(formData.price),
        deliveryCharge: parseFloat(formData.deliveryCharge),
        unit: formData.unit,
        website: formData.website,
        whatsapp: formData.whatsapp
      };

      const response = await api.put(`/api/price-listings/${selectedListing.id}`, updates);
      
      if (response.data.success) {
        setSuccess('Price listing updated successfully!');
        setEditDialogOpen(false);
        resetForm();
        loadBusinessListings();
      }
    } catch (error) {
      console.error('Error updating listing:', error);
      setError(error.response?.data?.message || 'Failed to update price listing');
    }
  };

  const handleDeleteListing = async (listingId) => {
    if (!window.confirm('Are you sure you want to delete this price listing?')) {
      return;
    }

    try {
      const response = await api.delete(`/api/price-listings/${listingId}`);
      
      if (response.data.success) {
        setSuccess('Price listing deleted successfully!');
        loadBusinessListings();
      }
    } catch (error) {
      console.error('Error deleting listing:', error);
      setError(error.response?.data?.message || 'Failed to delete price listing');
    }
  };

  const openEditDialog = (listing) => {
    setSelectedListing(listing);
    setFormData({
      title: listing.title,
      description: listing.description || '',
      price: listing.price.toString(),
      deliveryCharge: listing.deliveryCharge.toString(),
      unit: listing.unit || '',
      website: listing.website || '',
      whatsapp: listing.whatsapp || '',
      images: listing.images || []
    });
    setEditDialogOpen(true);
  };

  const resetForm = () => {
    setFormData({
      title: '',
      description: '',
      price: '',
      deliveryCharge: '0',
      unit: '',
      website: '',
      whatsapp: '',
      images: []
    });
    setSelectedProduct(null);
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('en-LK', {
      style: 'currency',
      currency: 'LKR',
      minimumFractionDigits: 0
    }).format(amount);
  };

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
      <Box sx={{ mb: 3, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Box>
          <Typography variant="h4" gutterBottom>
            Price Management
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Manage your product pricing and compete in the marketplace
          </Typography>
        </Box>
        <Button
          variant="contained"
          startIcon={<Add />}
          onClick={() => setAddDialogOpen(true)}
          sx={{ height: 'fit-content' }}
        >
          Add Price Listing
        </Button>
      </Box>

      {/* Alerts */}
      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}
      {success && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccess(null)}>
          {success}
        </Alert>
      )}

      {/* Stats Cards */}
      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                <AttachMoney color="primary" />
                <Box>
                  <Typography variant="h6">{listings.length}</Typography>
                  <Typography variant="body2" color="text.secondary">
                    Active Listings
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                <Visibility color="success" />
                <Box>
                  <Typography variant="h6">
                    {listings.reduce((sum, listing) => sum + listing.viewCount, 0)}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Total Views
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                <WhatsApp color="info" />
                <Box>
                  <Typography variant="h6">
                    {listings.reduce((sum, listing) => sum + listing.contactCount, 0)}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Contacts
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                <AttachMoney color="warning" />
                <Box>
                  <Typography variant="h6">
                    {listings.length > 0 
                      ? formatCurrency(listings.reduce((sum, listing) => sum + listing.price, 0) / listings.length)
                      : formatCurrency(0)
                    }
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Avg. Price
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Listings Grid */}
      {listings.length === 0 ? (
        <Paper sx={{ p: 4, textAlign: 'center' }}>
          <Typography variant="h6" gutterBottom>
            No Price Listings Yet
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Start by adding your first product pricing to compete in the marketplace
          </Typography>
          <Button
            variant="contained"
            startIcon={<Add />}
            onClick={() => setAddDialogOpen(true)}
          >
            Add Your First Listing
          </Button>
        </Paper>
      ) : (
        <Grid container spacing={3}>
          {listings.map((listing) => (
            <Grid item xs={12} sm={6} md={4} key={listing.id}>
              <Card sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
                {listing.images && listing.images.length > 0 && (
                  <CardMedia
                    component="img"
                    height="140"
                    image={listing.images[0]}
                    alt={listing.title}
                  />
                )}
                <CardContent sx={{ flexGrow: 1 }}>
                  <Typography variant="h6" gutterBottom noWrap>
                    {listing.title}
                  </Typography>
                  {listing.description && (
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                      {listing.description.substring(0, 100)}
                      {listing.description.length > 100 && '...'}
                    </Typography>
                  )}
                  
                  <Box sx={{ mb: 2 }}>
                    <Typography variant="h5" color="primary" gutterBottom>
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
                  </Box>

                  <Stack direction="row" spacing={1} sx={{ mb: 2 }}>
                    <Chip
                      icon={<Visibility />}
                      label={`${listing.viewCount} views`}
                      size="small"
                      variant="outlined"
                    />
                    <Chip
                      icon={<WhatsApp />}
                      label={`${listing.contactCount} contacts`}
                      size="small"
                      variant="outlined"
                    />
                  </Stack>
                </CardContent>
                
                <Box sx={{ p: 2, pt: 0 }}>
                  <Stack direction="row" spacing={1}>
                    <Button
                      size="small"
                      startIcon={<Edit />}
                      onClick={() => openEditDialog(listing)}
                    >
                      Edit
                    </Button>
                    <Button
                      size="small"
                      color="error"
                      startIcon={<Delete />}
                      onClick={() => handleDeleteListing(listing.id)}
                    >
                      Delete
                    </Button>
                  </Stack>
                </Box>
              </Card>
            </Grid>
          ))}
        </Grid>
      )}

      {/* Add Listing Dialog */}
      <Dialog 
        open={addDialogOpen} 
        onClose={() => setAddDialogOpen(false)}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>Add New Price Listing</DialogTitle>
        <DialogContent>
          <Box sx={{ pt: 1 }}>
            {/* Product Search */}
            <Autocomplete
              options={products}
              getOptionLabel={(option) => option.name}
              value={selectedProduct}
              onChange={(event, newValue) => handleProductSelect(newValue)}
              onInputChange={(event, newInputValue) => {
                setSearchQuery(newInputValue);
                searchProducts(newInputValue);
              }}
              renderInput={(params) => (
                <TextField
                  {...params}
                  label="Search and Select Product"
                  fullWidth
                  margin="normal"
                  InputProps={{
                    ...params.InputProps,
                    startAdornment: (
                      <InputAdornment position="start">
                        <Search />
                      </InputAdornment>
                    ),
                  }}
                />
              )}
              renderOption={(props, option) => (
                <Box component="li" {...props}>
                  <Box>
                    <Typography variant="body1">{option.name}</Typography>
                    {option.brand && (
                      <Typography variant="body2" color="text.secondary">
                        Brand: {option.brand.name}
                      </Typography>
                    )}
                    <Typography variant="body2" color="text.secondary">
                      {option.listingCount} existing listings
                    </Typography>
                  </Box>
                </Box>
              )}
              sx={{ mb: 2 }}
            />

            <Grid container spacing={2}>
              <Grid item xs={12}>
                <TextField
                  fullWidth
                  label="Listing Title"
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  margin="normal"
                />
              </Grid>
              <Grid item xs={12}>
                <TextField
                  fullWidth
                  label="Description"
                  multiline
                  rows={3}
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  margin="normal"
                />
              </Grid>
              <Grid item xs={6}>
                <TextField
                  fullWidth
                  label="Price"
                  type="number"
                  value={formData.price}
                  onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                  margin="normal"
                  InputProps={{
                    startAdornment: <InputAdornment position="start">LKR</InputAdornment>,
                  }}
                />
              </Grid>
              <Grid item xs={6}>
                <TextField
                  fullWidth
                  label="Delivery Charge"
                  type="number"
                  value={formData.deliveryCharge}
                  onChange={(e) => setFormData({ ...formData, deliveryCharge: e.target.value })}
                  margin="normal"
                  InputProps={{
                    startAdornment: <InputAdornment position="start">LKR</InputAdornment>,
                  }}
                />
              </Grid>
              <Grid item xs={6}>
                <TextField
                  fullWidth
                  label="Unit (e.g., per kg, per item)"
                  value={formData.unit}
                  onChange={(e) => setFormData({ ...formData, unit: e.target.value })}
                  margin="normal"
                />
              </Grid>
              <Grid item xs={6}>
                <TextField
                  fullWidth
                  label="WhatsApp Number"
                  value={formData.whatsapp}
                  onChange={(e) => setFormData({ ...formData, whatsapp: e.target.value })}
                  margin="normal"
                  placeholder="+94771234567"
                />
              </Grid>
              <Grid item xs={12}>
                <TextField
                  fullWidth
                  label="Website URL"
                  value={formData.website}
                  onChange={(e) => setFormData({ ...formData, website: e.target.value })}
                  margin="normal"
                  placeholder="https://your-business.com"
                />
              </Grid>
            </Grid>
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setAddDialogOpen(false)}>Cancel</Button>
          <Button 
            variant="contained" 
            onClick={handleAddListing}
            disabled={!selectedProduct || !formData.title || !formData.price}
          >
            Add Listing
          </Button>
        </DialogActions>
      </Dialog>

      {/* Edit Listing Dialog */}
      <Dialog 
        open={editDialogOpen} 
        onClose={() => setEditDialogOpen(false)}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>Edit Price Listing</DialogTitle>
        <DialogContent>
          <Box sx={{ pt: 1 }}>
            <Grid container spacing={2}>
              <Grid item xs={12}>
                <TextField
                  fullWidth
                  label="Listing Title"
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  margin="normal"
                />
              </Grid>
              <Grid item xs={12}>
                <TextField
                  fullWidth
                  label="Description"
                  multiline
                  rows={3}
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  margin="normal"
                />
              </Grid>
              <Grid item xs={6}>
                <TextField
                  fullWidth
                  label="Price"
                  type="number"
                  value={formData.price}
                  onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                  margin="normal"
                  InputProps={{
                    startAdornment: <InputAdornment position="start">LKR</InputAdornment>,
                  }}
                />
              </Grid>
              <Grid item xs={6}>
                <TextField
                  fullWidth
                  label="Delivery Charge"
                  type="number"
                  value={formData.deliveryCharge}
                  onChange={(e) => setFormData({ ...formData, deliveryCharge: e.target.value })}
                  margin="normal"
                  InputProps={{
                    startAdornment: <InputAdornment position="start">LKR</InputAdornment>,
                  }}
                />
              </Grid>
              <Grid item xs={6}>
                <TextField
                  fullWidth
                  label="Unit (e.g., per kg, per item)"
                  value={formData.unit}
                  onChange={(e) => setFormData({ ...formData, unit: e.target.value })}
                  margin="normal"
                />
              </Grid>
              <Grid item xs={6}>
                <TextField
                  fullWidth
                  label="WhatsApp Number"
                  value={formData.whatsapp}
                  onChange={(e) => setFormData({ ...formData, whatsapp: e.target.value })}
                  margin="normal"
                  placeholder="+94771234567"
                />
              </Grid>
              <Grid item xs={12}>
                <TextField
                  fullWidth
                  label="Website URL"
                  value={formData.website}
                  onChange={(e) => setFormData({ ...formData, website: e.target.value })}
                  margin="normal"
                  placeholder="https://your-business.com"
                />
              </Grid>
            </Grid>
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setEditDialogOpen(false)}>Cancel</Button>
          <Button 
            variant="contained" 
            onClick={handleEditListing}
            disabled={!formData.title || !formData.price}
          >
            Update Listing
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default BusinessPriceManagement;
