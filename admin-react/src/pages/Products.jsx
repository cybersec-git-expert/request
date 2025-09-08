import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Grid,
  Chip,
  Alert,
  LinearProgress,
  IconButton,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Avatar,
  Switch,
  FormControlLabel,
  ImageList,
  ImageListItem
} from '@mui/material';
import { 
  Add, 
  Edit, 
  Delete, 
  Search,
  FilterList,
  Visibility,
  VisibilityOff,
  PhotoCamera,
  Close,
  Public,
  Language
} from '@mui/icons-material';
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter';
import CountryProductManager from '../components/CountryProductManager';

const Products = () => {
  const { getFilteredData, adminData, isSuperAdmin, userCountry } = useCountryFilter();
  const [products, setProducts] = useState([]);
  const [filteredProducts, setFilteredProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openDialog, setOpenDialog] = useState(false);
  const [openCountryManager, setOpenCountryManager] = useState(false);
  const [selectedProductForCountry, setSelectedProductForCountry] = useState(null);
  const [editingProduct, setEditingProduct] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');
  const [brandFilter, setBrandFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('active'); // 'active' | 'inactive' | 'all'
  const [categories, setCategories] = useState([]);
  const [subcategories, setSubcategories] = useState([]);
  const [brands, setBrands] = useState([]);
  const [uploadedImages, setUploadedImages] = useState([]);
  const [formData, setFormData] = useState({
    name: '',
    brand: '',
    categoryId: '',
    subcategoryId: '',
    description: '',
    keywords: [],
    images: [],
    availableVariables: {},
    isActive: true
  });

  useEffect(() => {
    loadProducts();
    loadCategories();
    loadBrands();
  }, []);

  useEffect(() => {
    filterProducts();
  }, [products, searchTerm, categoryFilter, brandFilter, statusFilter]);

  // Load subcategories when category changes
  useEffect(() => {
    if (formData.categoryId) {
      loadSubcategories(formData.categoryId);
    } else {
      setSubcategories([]);
    }
  }, [formData.categoryId]);

  const loadProducts = async () => {
    try {
      setLoading(true);
  // Fetch both active & inactive so we can filter client-side
  const data = await getFilteredData('master_products', adminData, { includeInactive: 'true' });
      const productsData = data || [];
      setProducts(productsData);
    } catch (error) {
      console.error('Error loading products:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadCategories = async () => {
    try {
      const data = await getFilteredData('categories', adminData);
      const categoriesData = (data || []).filter(category => 
        category.type === 'item' || !category.type
      );
      console.log('Loaded item categories:', categoriesData);
      setCategories(categoriesData.sort((a, b) => {
        const aName = a.name || a.category || '';
        const bName = b.name || b.category || '';
        return aName.localeCompare(bName);
      }));
    } catch (error) {
      console.error('Error loading categories:', error);
    }
  };

  // Load subcategories for selected category
  const loadSubcategories = async (categoryId) => {
    if (!categoryId) {
      setSubcategories([]);
      return;
    }
    
    try {
      // Hit the dedicated endpoint that filters by category on the server
      const res = await api.get(`/subcategories/category/${categoryId}`);
      const list = Array.isArray(res.data) ? res.data : (res.data?.data || []);
      setSubcategories(list.sort((a,b)=> (a.name||'').localeCompare(b.name||'')));
    } catch (error) {
      console.error('Error loading subcategories by category, falling back to client-side filter:', error);
      // Fallback: fetch all then filter client-side if the specific route is unavailable
      try {
        const all = await api.get('/subcategories');
        const arr = Array.isArray(all.data) ? all.data : (all.data?.data || []);
        const list = arr.filter(sc => (sc.category_id || sc.categoryId) === categoryId);
        setSubcategories(list.sort((a,b)=> (a.name||'').localeCompare(b.name||'')));
      } catch (e2) {
        console.error('Fallback subcategory load failed:', e2);
        setSubcategories([]);
      }
    }
  };

  const loadBrands = async () => {
    try {
      const data = await getFilteredData('brands', adminData);
      const brandsData = (data || []).filter(brand => brand.isActive !== false);
      
      // Sort brands by name
      brandsData.sort((a, b) => {
        const aName = a.name || a.brandName || '';
        const bName = b.name || b.brandName || '';
        return aName.localeCompare(bName);
      });
      
      setBrands(brandsData);
    } catch (error) {
      console.error('Error loading brands:', error);
    }
  };

  const filterProducts = () => {
    let filtered = products;
    
    if (searchTerm) {
      filtered = filtered.filter(product =>
        product.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        product.brand?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        product.description?.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }
    
    if (categoryFilter) {
      filtered = filtered.filter(product => product.categoryId === categoryFilter);
    }
    
    if (brandFilter) {
      filtered = filtered.filter(product => product.brand === brandFilter);
    }

    if (statusFilter === 'active') {
      filtered = filtered.filter(p => p.isActive !== false);
    } else if (statusFilter === 'inactive') {
      filtered = filtered.filter(p => p.isActive === false);
    }
    
    setFilteredProducts(filtered);
  };

  const handleOpenDialog = (product = null) => {
    if (product) {
      setEditingProduct(product.id);
      setFormData({
        name: product.name || '',
        brand: product.brand || '',
        categoryId: product.categoryId || '',
        subcategoryId: product.subcategoryId || '',
        description: product.description || '',
        keywords: product.keywords || [],
        images: product.images || [],
        availableVariables: product.availableVariables || {},
        isActive: product.isActive !== false
      });
      // Load subcategories for existing product
      if (product.categoryId) {
        loadSubcategories(product.categoryId);
      }
    } else {
      setEditingProduct(null);
      setFormData({
        name: '',
        brand: '',
        categoryId: '',
        subcategoryId: '',
        description: '',
        keywords: [],
        images: [],
        availableVariables: {},
        isActive: true
      });
      setSubcategories([]);
    }
    setUploadedImages([]);
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setEditingProduct(null);
    setUploadedImages([]);
  };

  const handleImageUpload = async (event) => {
    const files = Array.from(event.target.files || []);
    if (files.length === 0) return;

    // Always allow re-selecting the same files next time
    if (event.target) {
      try { 
        event.target.value = ''; 
      } catch (error) {
        // Ignore errors when resetting file input
      }
    }

    try {
      // Try S3 first — one request per file
      const urls = [];
      for (let i = 0; i < files.length; i++) {
        const f = files[i];
        const s3Form = new FormData();
        s3Form.append('file', f);
        s3Form.append('uploadType', 'master-products');
        if (adminData?.id) s3Form.append('userId', adminData.id);
        s3Form.append('imageIndex', String(i));
        const { data } = await api.post('/s3/upload', s3Form, {
          headers: { 'Content-Type': 'multipart/form-data' }
        });
        if (data?.success && data?.url) {
          urls.push(data.url);
        } else {
          throw new Error('S3 upload did not return URL');
        }
      }

      setUploadedImages(prev => [...prev, ...urls]);
      setFormData(prev => ({ ...prev, images: [...(prev.images || []), ...urls] }));
    } catch (s3Error) {
      console.warn('S3 upload failed, falling back to local upload:', s3Error?.message || s3Error);
      try {
        const form = new FormData();
        files.forEach(f => form.append('files', f));
        const res = await api.post('/uploads/products', form, {
          headers: { 'Content-Type': 'multipart/form-data' }
        });
        const uploaded = res.data?.files || res.data?.data || res.data || [];
        const urls = uploaded.map(f => f.url || f.location || f.path || f);
        setUploadedImages(prev => [...prev, ...urls]);
        setFormData(prev => ({ ...prev, images: [...(prev.images || []), ...urls] }));
      } catch (error) {
        console.error('Error uploading images (both S3 and local):', error);
        alert('Error uploading images: ' + (error.response?.data?.message || error.message));
      }
    }
  };

  const removeImage = (indexToRemove) => {
    setFormData(prev => ({
      ...prev,
      images: prev.images.filter((_, index) => index !== indexToRemove)
    }));
  };

  const handleCategoryChange = (categoryId) => {
    setFormData(prev => ({
      ...prev,
      categoryId,
      subcategoryId: '' // Reset subcategory when category changes
    }));
  };

  const handleSave = async () => {
    try {
      // Parse availableVariables if it's a JSON string
      let availableVariables = formData.availableVariables;
      if (typeof availableVariables === 'string') {
        try {
          availableVariables = availableVariables.trim() ? JSON.parse(availableVariables) : {};
        } catch (e) {
          alert('Available Variables must be valid JSON. Please fix and try again.');
          return;
        }
      }

      // Find brandId from brand name
      let brandId = null;
      if (formData.brand) {
        const selectedBrand = brands.find(b => 
          (b.name || b.brandName) === formData.brand
        );
        brandId = selectedBrand?.id || null;
      }

      // Ensure images from uploads are included
      const productData = {
        name: formData.name,
        brand: formData.brand, // Keep for compatibility
        brandId: brandId,
        categoryId: formData.categoryId,
        subcategoryId: formData.subcategoryId,
        description: formData.description,
        keywords: formData.keywords,
        images: formData.images || [],
        availableVariables,
        isActive: formData.isActive,
        // updatedBy is optional; guard if adminData not yet loaded
        ...(adminData?.email ? { updatedBy: adminData.email } : {})
      };

      console.log('Saving product with data:', productData);

      if (editingProduct) {
        await api.put(`/master-products/${editingProduct}`, productData);
      } else {
        await api.post('/master-products', { ...productData, createdBy: adminData?.email || 'system' });
      }

      handleCloseDialog();
      loadProducts();
    } catch (error) {
      console.error('Error saving product:', error);
      alert('Error saving product: ' + error.message);
    }
  };

  const handleDelete = async (productId) => {
    if (window.confirm('Are you sure you want to delete this product?')) {
      try {
        await api.delete(`/master-products/${productId}`);
        loadProducts();
      } catch (error) {
        console.error('Error deleting product:', error);
        alert('Delete failed: ' + (error.response?.data?.message || error.message));
      }
    }
  };

  const toggleProductStatus = async (product) => {
    try {
  const payload = { isActive: !product.isActive };
  if (adminData?.email) payload.updatedBy = adminData.email;
  await api.put(`/master-products/${product.id}/status`, payload);
      loadProducts();
    } catch (error) {
      console.error('Error updating product status:', error);
      alert('Status update failed: ' + (error.response?.data?.message || error.message));
    }
  };

  const getCategoryName = (categoryId) => {
    const category = categories.find(c => c.id === categoryId);
    return category?.name || category?.category || categoryId || 'Unknown Category';
  };

  const handleOpenCountryManager = (product) => {
    setSelectedProductForCountry(product);
    setOpenCountryManager(true);
  };

  const handleCloseCountryManager = () => {
    setOpenCountryManager(false);
    setSelectedProductForCountry(null);
  };

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4">Master Products</Typography>
        <Button
          variant="contained"
          startIcon={<Add />}
          onClick={() => handleOpenDialog()}
        >
          Add Product
        </Button>
      </Box>

      <Alert severity="info" sx={{ mb: 3 }}>
        Master products are managed centrally and available to all countries. 
        Businesses worldwide can create price listings based on these products.
        Only item categories are available for products.
      </Alert>

      {/* Filters */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={12} md={3}>
              <TextField
                fullWidth
                placeholder="Search products..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                InputProps={{
                  startAdornment: <Search sx={{ mr: 1, color: 'text.secondary' }} />
                }}
              />
            </Grid>
            <Grid item xs={12} md={3}>
              <FormControl fullWidth>
                <InputLabel>Category</InputLabel>
                <Select
                  value={categoryFilter}
                  onChange={(e) => setCategoryFilter(e.target.value)}
                >
                  <MenuItem value="">All Categories</MenuItem>
                  {categories.map(category => (
                    <MenuItem key={category.id} value={category.id}>
                      {category.name}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={2}>
              <FormControl fullWidth>
                <InputLabel>Brand</InputLabel>
                <Select
                  value={brandFilter}
                  onChange={(e) => setBrandFilter(e.target.value)}
                >
                  <MenuItem value="">All Brands</MenuItem>
                  {brands.map(brand => (
                    <MenuItem key={brand.id} value={brand.name || brand.brandName}>
                      {brand.name || brand.brandName}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={2}>
              <FormControl fullWidth>
                <InputLabel>Status</InputLabel>
                <Select
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value)}
                >
                  <MenuItem value="active">Active</MenuItem>
                  <MenuItem value="inactive">Inactive</MenuItem>
                  <MenuItem value="all">All Statuses</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={2}>
              <Typography variant="body2" color="text.secondary">
                {filteredProducts.length} of {products.length} products
              </Typography>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {loading && <LinearProgress sx={{ mb: 2 }} />}

      {/* Products Table */}
      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Product</TableCell>
              <TableCell>Category</TableCell>
              <TableCell>Brand</TableCell>
              <TableCell>Variables</TableCell>
              <TableCell>Status</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredProducts.map((product) => (
              <TableRow key={product.id}>
                <TableCell>
                  <Box display="flex" alignItems="center" gap={2}>
                    {product.images && product.images.length > 0 ? (
                      <Avatar 
                        src={product.images[0]} 
                        imgProps={{ crossOrigin: 'anonymous' }}
                        variant="rounded"
                        sx={{ width: 48, height: 48 }}
                      />
                    ) : (
                      <Avatar 
                        variant="rounded"
                        sx={{ width: 48, height: 48 }}
                      >
                        {product.name?.charAt(0)}
                      </Avatar>
                    )}
                    <Box>
                      <Typography variant="subtitle2">{product.name}</Typography>
                      <Typography variant="body2" color="text.secondary">
                        {product.description?.substring(0, 60)}...
                      </Typography>
                    </Box>
                  </Box>
                </TableCell>
                <TableCell>
                  <Chip 
                    label={getCategoryName(product.categoryId)} 
                    size="small" 
                    variant="outlined"
                  />
                </TableCell>
                <TableCell>{product.brand || '-'}</TableCell>
                <TableCell>
                  {product.availableVariables && Object.keys(product.availableVariables).length > 0 ? (
                    <Chip 
                      label={`${Object.keys(product.availableVariables).length} variables`}
                      size="small"
                      color="primary"
                    />
                  ) : (
                    <Chip label="No variables" size="small" />
                  )}
                </TableCell>
                <TableCell>
                  <FormControlLabel
                    control={
                      <Switch
                        checked={product.isActive !== false}
                        onChange={() => toggleProductStatus(product)}
                        size="small"
                      />
                    }
                    label={product.isActive !== false ? 'Active' : 'Inactive'}
                  />
                </TableCell>
                <TableCell align="right">
                  <IconButton 
                    size="small" 
                    onClick={() => handleOpenDialog(product)}
                    color="primary"
                    title="Edit Product"
                  >
                    <Edit />
                  </IconButton>
                  <IconButton 
                    size="small" 
                    onClick={() => handleOpenCountryManager(product)}
                    color="info"
                    title="Manage Country Variations"
                  >
                    <Language />
                  </IconButton>
                  <IconButton 
                    size="small" 
                    onClick={() => handleDelete(product.id)}
                    color="error"
                    title="Delete Product"
                  >
                    <Delete />
                  </IconButton>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      {filteredProducts.length === 0 && !loading && (
        <Box textAlign="center" py={4}>
          <Typography variant="h6" color="text.secondary" gutterBottom>
            No products found
          </Typography>
          <Typography variant="body2" color="text.secondary" mb={2}>
            {products.length === 0 ? 
              'Create your first master product to get started' :
              'Try adjusting your search criteria'
            }
          </Typography>
          {products.length === 0 && (
            <Button variant="contained" startIcon={<Add />} onClick={() => handleOpenDialog()}>
              Add First Product
            </Button>
          )}
        </Box>
      )}

      {/* Add/Edit Dialog */}
      <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="md" fullWidth>
        <DialogTitle>
          {editingProduct ? 'Edit Product' : 'Add Product'}
        </DialogTitle>
        <DialogContent>
          <Box display="flex" flexDirection="column" gap={3} pt={2}>
            <TextField
              fullWidth
              label="Product Name"
              value={formData.name}
              onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
              required
            />
            
            <FormControl fullWidth>
              <InputLabel>Brand</InputLabel>
              <Select
                value={formData.brand}
                onChange={(e) => setFormData(prev => ({ ...prev, brand: e.target.value }))}
              >
                <MenuItem value="">
                  <em>Select Brand (Optional)</em>
                </MenuItem>
                {brands.map(brand => (
                  <MenuItem key={brand.id} value={brand.name || brand.brandName}>
                    {brand.name || brand.brandName}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>

            <Grid container spacing={2}>
              <Grid item xs={12} md={6}>
                <FormControl fullWidth required>
                  <InputLabel>Category</InputLabel>
                  <Select
                    value={formData.categoryId}
                    onChange={(e) => handleCategoryChange(e.target.value)}
                  >
                    {categories.map(category => (
                      <MenuItem key={category.id} value={category.id}>
                        {category.name || category.category}
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              </Grid>
              <Grid item xs={12} md={6}>
                <FormControl fullWidth disabled={!formData.categoryId}>
                  <InputLabel>Subcategory</InputLabel>
                  <Select
                    value={formData.subcategoryId}
                    onChange={(e) => setFormData(prev => ({ ...prev, subcategoryId: e.target.value }))}
                  >
                    <MenuItem value="">No subcategory</MenuItem>
                    {subcategories.map(subcategory => (
                      <MenuItem key={subcategory.id} value={subcategory.id}>
                        {subcategory.name || subcategory.subcategory}
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              </Grid>
            </Grid>

            <TextField
              fullWidth
              multiline
              rows={3}
              label="Description"
              value={formData.description}
              onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
            />

            <TextField
              fullWidth
              label="Keywords (comma-separated)"
              value={Array.isArray(formData.keywords) ? formData.keywords.join(', ') : ''}
              onChange={(e) => setFormData(prev => ({ 
                ...prev, 
                keywords: e.target.value.split(',').map(k => k.trim()).filter(k => k)
              }))}
              placeholder="smartphone, electronics, apple"
            />

            <Box>
              <Typography variant="subtitle1" gutterBottom>
                Product Images
              </Typography>
              <input
                accept="image/*"
                style={{ display: 'none' }}
                id="image-upload"
                multiple
                type="file"
                onChange={handleImageUpload}
              />
              <label htmlFor="image-upload">
                <Button
                  variant="outlined"
                  component="span"
                  startIcon={<PhotoCamera />}
                  sx={{ mb: 2 }}
                >
                  Upload Images
                </Button>
              </label>
              
              {/* Display uploaded images */}
              {formData.images && formData.images.length > 0 && (
                <ImageList sx={{ width: '100%', height: 200 }} cols={4} rowHeight={160}>
                  {formData.images.map((image, index) => (
                    <ImageListItem key={index}>
                      <img
                        src={image}
                        alt={`Product ${index + 1}`}
                        loading="lazy"
                        style={{ objectFit: 'cover' }}
                        crossOrigin="anonymous"
                        onError={(e) => {
                          console.warn('Image load failed:', image);
                          // Optionally set a placeholder or hide the image
                        }}
                      />
                      <IconButton
                        sx={{
                          position: 'absolute',
                          top: 5,
                          right: 5,
                          bgcolor: 'rgba(255,255,255,0.8)',
                          '&:hover': { bgcolor: 'rgba(255,255,255,0.9)' }
                        }}
                        size="small"
                        onClick={() => removeImage(index)}
                      >
                        <Close fontSize="small" />
                      </IconButton>
                    </ImageListItem>
                  ))}
                </ImageList>
              )}
            </Box>

            <TextField
              fullWidth
              multiline
              rows={4}
              label="Available Variables (JSON)"
              value={
                typeof formData.availableVariables === 'string'
                  ? formData.availableVariables
                  : JSON.stringify(formData.availableVariables || {}, null, 2)
              }
              onChange={(e) => {
                const text = e.target.value;
                // Keep text as-is for edit experience; parse on save
                setFormData(prev => ({ ...prev, availableVariables: text }));
              }}
              placeholder='{"color": ["Red", "Blue", "Green"], "size": ["Small", "Medium", "Large"]}'
              helperText="Define product variations in JSON format for mobile app variable selection"
            />

            <FormControlLabel
              control={
                <Switch
                  checked={formData.isActive}
                  onChange={(e) => setFormData(prev => ({ ...prev, isActive: e.target.checked }))}
                />
              }
              label="Active (visible to businesses)"
            />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog}>Cancel</Button>
          <Button 
            onClick={handleSave} 
            variant="contained"
            disabled={!formData.name || !formData.categoryId}
          >
            {editingProduct ? 'Update' : 'Create'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Country Product Manager */}
      <CountryProductManager
        open={openCountryManager}
        onClose={handleCloseCountryManager}
        masterProduct={selectedProductForCountry}
      />
    </Box>
  );
};

export default Products;
