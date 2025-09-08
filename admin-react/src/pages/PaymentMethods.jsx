import React, { useState, useEffect } from 'react';
import {
  Container,
  Typography,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Grid,
  Card,
  CardContent,
  CardMedia,
  Box,
  IconButton,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Chip,
  Alert,
  Switch,
  FormControlLabel
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  CloudUpload as UploadIcon
} from '@mui/icons-material';
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter';

const PaymentMethods = () => {
  const { adminData, isSuperAdmin, userCountry } = useCountryFilter();
  
  // Initialize state first
  const [paymentMethods, setPaymentMethods] = useState([]);
  const [countries, setCountries] = useState([]);
  const [open, setOpen] = useState(false);
  const [editingMethod, setEditingMethod] = useState(null);
  const [loading, setLoading] = useState(false);
  const [imageFile, setImageFile] = useState(null);
  const [imagePreview, setImagePreview] = useState('');

  const [formData, setFormData] = useState({
    name: '',
    description: '',
    country: '',
    imageUrl: '',
    linkUrl: '',
    isActive: true,
    category: 'digital', // digital, bank, cash, crypto
    fees: '',
    processingTime: '',
    minAmount: '',
    maxAmount: ''
  });

  // Check permissions
  const hasPaymentPermission = isSuperAdmin || adminData?.permissions?.paymentMethodManagement;

  useEffect(() => {
    if (hasPaymentPermission) {
      fetchPaymentMethods();
      fetchCountries();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSuperAdmin, userCountry, hasPaymentPermission]);

  if (!hasPaymentPermission) {
    return (
      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Alert severity="error">
          You don't have permission to access Payment Methods Management. Please contact your administrator.
        </Alert>
      </Container>
    );
  }

  const fetchPaymentMethods = async () => {
    try {
      const params = {};
      if (!isSuperAdmin && userCountry) params.country = userCountry;
      const { data } = await api.get('/payment-methods', { params });
      console.log('Payment methods API response:', data); // Debug log
      
      let methodsArray = [];
      
      // Handle both direct array response and structured response
      if (Array.isArray(data)) {
        methodsArray = data;
      } else if (data && data.success && Array.isArray(data.data)) {
        methodsArray = data.data;
      } else if (data && Array.isArray(data.items)) {
        methodsArray = data.items;
      } else if (data && Array.isArray(data.methods)) {
        methodsArray = data.methods;
      } else {
        console.warn('Unexpected payment methods API response format:', data);
        methodsArray = [];
      }
      
      setPaymentMethods(methodsArray);
    } catch (error) {
      console.error('Error fetching payment methods:', error);
      setPaymentMethods([]); // Set empty array on error
    }
  };

  const fetchCountries = async () => {
    try {
      const { data } = await api.get('/countries');
      console.log('Countries API response:', data); // Debug log
      
      let countriesArray = [];
      
      // Handle the actual backend response format: { success: true, data: [...] }
      if (data && data.success && Array.isArray(data.data)) {
        countriesArray = data.data;
      } else if (Array.isArray(data)) {
        countriesArray = data;
      } else if (data && Array.isArray(data.countries)) {
        countriesArray = data.countries;
      } else if (data && Array.isArray(data.items)) {
        countriesArray = data.items;
      } else {
        console.warn('Unexpected countries API response format:', data);
        countriesArray = [];
      }
      
      const filteredCountries = countriesArray.filter(c => c && c.isEnabled !== false);
      setCountries(filteredCountries);
    } catch (error) {
      console.error('Error fetching countries:', error);
      setCountries([]); // Set empty array on error
    }
  };

  const handleImageChange = (event) => {
    const file = event.target.files[0];
    if (file) {
      setImageFile(file);
      const reader = new FileReader();
      reader.onload = (e) => {
        setImagePreview(e.target.result);
      };
      reader.readAsDataURL(file);
    }
  };

  const uploadImage = async () => {
    if (!imageFile) return formData.imageUrl;
    // Try S3 upload first
    try {
      const s3Form = new FormData();
      s3Form.append('file', imageFile);
      s3Form.append('uploadType', 'payment-methods');
      const { data } = await api.post('/s3/upload', s3Form, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
      if (data?.success && data?.url) return data.url;
    } catch (e) {
      console.warn('S3 upload failed, will try local upload as fallback', e);
    }

    // Fallback to local upload route
    try {
      const form = new FormData();
      form.append('file', imageFile);
      const { data } = await api.post('/uploads/payment-methods', form, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
      return data?.url || data?.path || formData.imageUrl;
    } catch (e) {
      console.error('Image upload failed, continuing without new image', e);
      return formData.imageUrl;
    }
  };

  const handleSubmit = async () => {
    setLoading(true);
    try {
      const imageUrl = await uploadImage();
      
      const methodData = {
        ...formData,
        imageUrl,
        country: isSuperAdmin ? formData.country : userCountry,
      };

      if (editingMethod) {
        await api.put(`/payment-methods/${editingMethod.id}`, methodData);
      } else {
        await api.post('/payment-methods', methodData);
      }

      fetchPaymentMethods();
      handleClose();
    } catch (error) {
      console.error('Error saving payment method:', error);
    }
    setLoading(false);
  };

  const handleEdit = (method) => {
    setEditingMethod(method);
    setFormData(method);
    setImagePreview(method.imageUrl);
    setOpen(true);
  };

  const handleDelete = async (methodId) => {
    if (window.confirm('Are you sure you want to delete this payment method?')) {
      try {
        await api.delete(`/payment-methods/${methodId}`);
        fetchPaymentMethods();
      } catch (error) {
        console.error('Error deleting payment method:', error);
      }
    }
  };

  const handleClose = () => {
    setOpen(false);
    setEditingMethod(null);
    setFormData({
      name: '',
      description: '',
      country: '',
      imageUrl: '',
      linkUrl: '',
      isActive: true,
      category: 'digital',
      fees: '',
      processingTime: '',
      minAmount: '',
      maxAmount: ''
    });
    setImageFile(null);
    setImagePreview('');
  };

  const handleInputChange = (field, value) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4" gutterBottom>
          Payment Methods Management
        </Typography>
        <Button
          variant="contained"
          startIcon={<AddIcon />}
          onClick={() => setOpen(true)}
        >
          Add Payment Method
        </Button>
      </Box>

      {!isSuperAdmin && (
        <Alert severity="info" sx={{ mb: 3 }}>
          You are managing payment methods for: <strong>{userCountry}</strong>
        </Alert>
      )}

      <Grid container spacing={3}>
        {paymentMethods.map((method) => (
          <Grid item xs={12} sm={6} md={4} key={method.id}>
            <Card>
              {method.imageUrl && (
                <CardMedia
                  component="img"
                  height="120"
                  image={method.imageUrl}
                  alt={method.name}
                  sx={{ objectFit: 'contain', p: 1 }}
                />
              )}
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  {method.name}
                </Typography>
                <Typography variant="body2" color="text.secondary" gutterBottom>
                  {method.description}
                </Typography>
                
                <Box display="flex" flexWrap="wrap" gap={1} mt={1}>
                  <Chip 
                    label={method.country} 
                    size="small" 
                    color="primary" 
                  />
                  <Chip 
                    label={method.category} 
                    size="small" 
                    variant="outlined" 
                  />
                  <Chip 
                    label={method.isActive ? 'Active' : 'Inactive'} 
                    size="small" 
                    color={method.isActive ? 'success' : 'error'}
                  />
                </Box>

                {method.fees && (
                  <Typography variant="caption" display="block" mt={1}>
                    Fees: {method.fees}
                  </Typography>
                )}

                <Box display="flex" justifyContent="flex-end" mt={2}>
                  <IconButton onClick={() => handleEdit(method)}>
                    <EditIcon />
                  </IconButton>
                  <IconButton onClick={() => handleDelete(method.id)} color="error">
                    <DeleteIcon />
                  </IconButton>
                </Box>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>

      {/* Add/Edit Dialog */}
      <Dialog open={open} onClose={handleClose} maxWidth="md" fullWidth>
        <DialogTitle>
          {editingMethod ? 'Edit Payment Method' : 'Add Payment Method'}
        </DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="Payment Method Name"
                value={formData.name}
                onChange={(e) => handleInputChange('name', e.target.value)}
                required
              />
            </Grid>
            
            {isSuperAdmin && (
              <Grid item xs={12} sm={6}>
                <FormControl fullWidth required>
                  <InputLabel>Country</InputLabel>
                  <Select
                    value={formData.country}
                    label="Country"
                    onChange={(e) => handleInputChange('country', e.target.value)}
                  >
                    {countries.map((country) => (
                      <MenuItem key={country.id} value={country.code}>
                        {country.name}
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              </Grid>
            )}

            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Description"
                multiline
                rows={2}
                value={formData.description}
                onChange={(e) => handleInputChange('description', e.target.value)}
              />
            </Grid>

            <Grid item xs={12} sm={6}>
              <FormControl fullWidth>
                <InputLabel>Category</InputLabel>
                <Select
                  value={formData.category}
                  label="Category"
                  onChange={(e) => handleInputChange('category', e.target.value)}
                >
                  <MenuItem value="digital">Digital Wallet</MenuItem>
                  <MenuItem value="bank">Bank Transfer</MenuItem>
                  <MenuItem value="card">Credit/Debit Card</MenuItem>
                  <MenuItem value="cash">Cash</MenuItem>
                  <MenuItem value="crypto">Cryptocurrency</MenuItem>
                </Select>
              </FormControl>
            </Grid>

            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="Website/App Link"
                value={formData.linkUrl}
                onChange={(e) => handleInputChange('linkUrl', e.target.value)}
                placeholder="https://example.com"
              />
            </Grid>

            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="Fees"
                value={formData.fees}
                onChange={(e) => handleInputChange('fees', e.target.value)}
                placeholder="e.g., Free, 2.5%, $1.50"
              />
            </Grid>

            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="Processing Time"
                value={formData.processingTime}
                onChange={(e) => handleInputChange('processingTime', e.target.value)}
                placeholder="e.g., Instant, 1-3 business days"
              />
            </Grid>

            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="Minimum Amount"
                value={formData.minAmount}
                onChange={(e) => handleInputChange('minAmount', e.target.value)}
                placeholder="e.g., $10"
              />
            </Grid>

            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="Maximum Amount"
                value={formData.maxAmount}
                onChange={(e) => handleInputChange('maxAmount', e.target.value)}
                placeholder="e.g., $5000"
              />
            </Grid>

            <Grid item xs={12}>
              <Box border={1} borderColor="grey.300" borderRadius={1} p={2}>
                <Typography variant="subtitle2" gutterBottom>
                  Payment Method Logo/Image
                </Typography>
                <input
                  type="file"
                  accept="image/*"
                  onChange={handleImageChange}
                  style={{ marginBottom: '10px' }}
                />
                {imagePreview && (
                  <Box mt={2}>
                    <img
                      src={imagePreview}
                      alt="Preview"
                      style={{ maxWidth: '200px', maxHeight: '100px', objectFit: 'contain' }}
                    />
                  </Box>
                )}
              </Box>
            </Grid>

            <Grid item xs={12}>
              <FormControlLabel
                control={
                  <Switch
                    checked={formData.isActive}
                    onChange={(e) => handleInputChange('isActive', e.target.checked)}
                  />
                }
                label="Active (visible to users)"
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleClose}>Cancel</Button>
          <Button 
            onClick={handleSubmit} 
            variant="contained"
            disabled={loading}
          >
            {loading ? 'Saving...' : 'Save'}
          </Button>
        </DialogActions>
      </Dialog>
    </Container>
  );
};

export default PaymentMethods;
