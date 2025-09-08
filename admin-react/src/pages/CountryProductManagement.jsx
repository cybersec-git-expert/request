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
  Switch,
  FormControlLabel,
  Button,
  Grid,
  Card,
  CardContent,
  TextField,
  InputAdornment,
  Alert,
  CircularProgress,
  Chip,
  Avatar,
  Tooltip
} from '@mui/material';
import {
  Search,
  Refresh,
  CheckCircle,
  Cancel,
  Category,
  Inventory
} from '@mui/icons-material';
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter.jsx';
import { DataLookupService } from '../services/DataLookupService.js';

const CountryProductManagement = () => {
  const {
    getFilteredData,
    adminData,
    isSuperAdmin,
    getCountryDisplayName,
    userCountry
  } = useCountryFilter();

  const [products, setProducts] = useState([]);
  const [countryProducts, setCountryProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [updating, setUpdating] = useState(new Set());

  // Load all products and country-specific activation status
  const loadProducts = async () => {
    try {
      setLoading(true);
      setError(null);

      // Get all products (global data) - use master_products like super admin
      const allProducts = await getFilteredData('master_products', adminData) || [];
      
      // Get country-specific product activations
      const countryActivations = await getFilteredData('country_products', adminData) || [];
      
      setProducts(allProducts);
      setCountryProducts(countryActivations);
      
      console.log(`📦 Loaded ${allProducts.length} products for country management`);
      console.log(`🎯 Found ${countryActivations.length} country-specific activations`);
    } catch (err) {
      console.error('Error loading products:', err);
      setError('Failed to load products: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadProducts();
  }, [adminData]);

  // Check if a product is active in the current country
  const isProductActive = (productId) => {
    const countryActivation = countryProducts.find(
      cp => cp.productId === productId && cp.country === userCountry
    );
    return countryActivation?.isActive !== false; // Default to true if not found
  };

  // Toggle product activation for the country
  const toggleProductActivation = async (productId, productName) => {
    if (isSuperAdmin) {
      setError('Super admins cannot modify country-specific settings');
      return;
    }

    try {
      setUpdating(prev => new Set([...prev, productId]));
      
      const currentStatus = isProductActive(productId);
      const newStatus = !currentStatus;

      // Find existing record or create new one
      const existingRecord = countryProducts.find(
        cp => cp.productId === productId && cp.country === userCountry
      );

      const updateData = {
        productId,
        productName,
        country: userCountry,
        countryName: getCountryDisplayName(userCountry),
        isActive: newStatus,
        updatedAt: new Date(),
        updatedBy: adminData.uid,
        updatedByName: adminData.displayName || adminData.email
      };

      if (existingRecord) {
        await api.put(`/country-products/${existingRecord.id}`, updateData);
        setCountryProducts(prev => prev.map(cp => cp.id === existingRecord.id ? { ...cp, ...updateData } : cp));
      } else {
        const createRes = await api.post('/country-products', updateData);
        const created = createRes.data?.data || createRes.data;
        setCountryProducts(prev => [...prev, { id: created?.id || created?.uuid || Math.random().toString(36).slice(2), ...updateData }]);
      }

      console.log(`✅ Product ${productName} ${newStatus ? 'activated' : 'deactivated'} for ${userCountry}`);
    } catch (err) {
      console.error('Error updating product activation:', err);
      setError('Failed to update product activation: ' + err.message);
    } finally {
      setUpdating(prev => {
        const newSet = new Set(prev);
        newSet.delete(productId);
        return newSet;
      });
    }
  };

  // Filter products based on search term
  const filteredProducts = products.filter(product =>
    product.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    product.title?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    product.category?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  // Get statistics
  const getStats = () => {
    const activeCount = filteredProducts.filter(p => isProductActive(p.id)).length;
    const inactiveCount = filteredProducts.length - activeCount;
    
    return {
      total: filteredProducts.length,
      active: activeCount,
      inactive: inactiveCount
    };
  };

  const stats = getStats();

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
          Country Product Management
        </Typography>
        <Typography variant="body1" color="text.secondary">
          {isSuperAdmin 
            ? 'View product activations across all countries (Read-only for Super Admin)'
            : `Manage product availability in ${getCountryDisplayName(userCountry)}`
          }
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
        <Grid item xs={12} sm={6} md={4}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom variant="h6">
                Total Products
              </Typography>
              <Typography variant="h4">
                {stats.total}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={4}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom variant="h6">
                Active in Country
              </Typography>
              <Typography variant="h4" color="success.main">
                {stats.active}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={4}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom variant="h6">
                Inactive in Country
              </Typography>
              <Typography variant="h4" color="error.main">
                {stats.inactive}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Search and Actions */}
      <Paper sx={{ p: 2, mb: 3 }}>
        <Box sx={{ display: 'flex', gap: 2, alignItems: 'center', flexWrap: 'wrap' }}>
          <TextField
            placeholder="Search products..."
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
            startIcon={<Refresh />}
            onClick={loadProducts}
          >
            Refresh
          </Button>
        </Box>
      </Paper>

      {/* Products Table */}
      <Paper>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Product</TableCell>
                <TableCell>Category</TableCell>
                <TableCell>Status in Country</TableCell>
                <TableCell align="center">Active in {getCountryDisplayName(userCountry)}</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filteredProducts.map((product) => (
                <TableRow key={product.id} hover>
                  <TableCell>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                      {product.images?.[0] && (
                        <Avatar
                          src={product.images[0]}
                          alt={product.name}
                          variant="rounded"
                          sx={{ width: 40, height: 40 }}
                        />
                      )}
                      <Box>
                        <Typography variant="subtitle2">
                          {product.name || product.title || 'Unnamed Product'}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          ID: {product.id}
                        </Typography>
                      </Box>
                    </Box>
                  </TableCell>
                  <TableCell>
                    <Chip
                      icon={<Category />}
                      label={product.category || 'Uncategorized'}
                      size="small"
                      variant="outlined"
                    />
                  </TableCell>
                  <TableCell>
                    {isProductActive(product.id) ? (
                      <Chip
                        icon={<CheckCircle />}
                        label="Active"
                        color="success"
                        size="small"
                      />
                    ) : (
                      <Chip
                        icon={<Cancel />}
                        label="Inactive"
                        color="error"
                        size="small"
                      />
                    )}
                  </TableCell>
                  <TableCell align="center">
                    <Tooltip title={isSuperAdmin ? "Super admins cannot modify country settings" : "Toggle product availability"}>
                      <span>
                        <FormControlLabel
                          control={
                            <Switch
                              checked={isProductActive(product.id)}
                              onChange={() => toggleProductActivation(product.id, product.name || product.title)}
                              disabled={isSuperAdmin || updating.has(product.id)}
                            />
                          }
                          label=""
                        />
                        {updating.has(product.id) && (
                          <CircularProgress size={16} sx={{ ml: 1 }} />
                        )}
                      </span>
                    </Tooltip>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>
    </Box>
  );
};

export default CountryProductManagement;
