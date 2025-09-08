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
  Category
} from '@mui/icons-material';
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter.jsx';
import { DataLookupService } from '../services/DataLookupService.js';

const CountryCategoryManagement = () => {
  const {
    getFilteredData,
    adminData,
    isSuperAdmin,
    getCountryDisplayName,
    userCountry
  } = useCountryFilter();

  const [categories, setCategories] = useState([]);
  const [countryCategories, setCountryCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [updating, setUpdating] = useState(new Set());

  // Load all categories and country-specific activation status
  const loadCategories = async () => {
    try {
      setLoading(true);
      setError(null);

      // Get all categories (global data) - use same method as super admin
      const allCategories = await getFilteredData('categories', adminData) || [];
      
      // Get country-specific category activations
      const countryActivations = await getFilteredData('country_categories', adminData) || [];
      
      setCategories(allCategories);
      setCountryCategories(countryActivations);
      
      console.log(`📁 Loaded ${allCategories.length} categories for country management`);
      console.log(`🎯 Found ${countryActivations.length} country-specific activations`);
    } catch (err) {
      console.error('Error loading categories:', err);
      setError('Failed to load categories: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadCategories();
  }, [adminData]);

  // Check if a category is active in the current country
  const isCategoryActive = (categoryId) => {
    const countryActivation = countryCategories.find(
      cc => cc.categoryId === categoryId && cc.country === userCountry
    );
    return countryActivation?.isActive !== false; // Default to true if not found
  };

  // Toggle category activation for the country
  const toggleCategoryActivation = async (categoryId, categoryName) => {
    if (isSuperAdmin) {
      setError('Super admins cannot modify country-specific settings');
      return;
    }

    try {
      setUpdating(prev => new Set([...prev, categoryId]));
      
      const currentStatus = isCategoryActive(categoryId);
      const newStatus = !currentStatus;

      // Find existing record or create new one
      const existingRecord = countryCategories.find(
        cc => cc.categoryId === categoryId && cc.country === userCountry
      );

      const updateData = {
        categoryId,
        categoryName,
        country: userCountry,
        countryName: getCountryDisplayName(userCountry),
        isActive: newStatus,
        updatedAt: new Date(),
        updatedBy: adminData.uid,
        updatedByName: adminData.displayName || adminData.email
      };

      if (existingRecord) {
        await api.put(`/country-categories/${existingRecord.id}`, updateData);
        setCountryCategories(prev => prev.map(cc => cc.id === existingRecord.id ? { ...cc, ...updateData } : cc));
      } else {
        const createRes = await api.post('/country-categories', updateData);
        const created = createRes.data?.data || createRes.data;
        setCountryCategories(prev => [...prev, { id: created?.id || created?.uuid || Math.random().toString(36).slice(2), ...updateData }]);
      }

      console.log(`🔄 Toggled category ${categoryName} to ${newStatus ? 'active' : 'inactive'} in ${userCountry}`);
    } catch (err) {
      console.error('Error toggling category:', err);
      setError(`Failed to update category: ${err.message}`);
    } finally {
      setUpdating(prev => {
        const newSet = new Set(prev);
        newSet.delete(categoryId);
        return newSet;
      });
    }
  };

  // Filter categories based on search term
  const filteredCategories = categories.filter(category =>
    category.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    category.category?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    category.title?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    category.description?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  // Get activation stats
  const getActivationStats = () => {
    const total = filteredCategories.length;
    const active = filteredCategories.filter(cat => isCategoryActive(cat.id)).length;
    const inactive = total - active;
    return { total, active, inactive };
  };

  const stats = getActivationStats();

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
          Category Management
        </Typography>
        <Typography variant="body1" color="text.secondary">
          {isSuperAdmin 
            ? 'Super admins cannot modify country-specific settings' 
            : `Manage category availability in ${getCountryDisplayName(userCountry)}`
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
        <Grid item xs={12} sm={4}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom variant="h6">
                Total Categories
              </Typography>
              <Typography variant="h4">
                {stats.total}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={4}>
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
        <Grid item xs={12} sm={4}>
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

      {/* Search and Actions */}
      <Paper sx={{ p: 2, mb: 3 }}>
        <Box sx={{ display: 'flex', gap: 2, alignItems: 'center', flexWrap: 'wrap' }}>
          <TextField
            placeholder="Search categories..."
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
            onClick={loadCategories}
          >
            Refresh
          </Button>
        </Box>
      </Paper>

      {/* Categories Table */}
      <Paper>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Category</TableCell>
                <TableCell>Type</TableCell>
                <TableCell>Description</TableCell>
                <TableCell>Status</TableCell>
                <TableCell align="center">Active in {getCountryDisplayName(userCountry)}</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filteredCategories.map((category) => (
                <TableRow key={category.id} hover>
                  <TableCell>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                      {category.icon && (
                        <Avatar 
                          src={category.icon} 
                          alt={category.name}
                          variant="rounded"
                          sx={{ width: 40, height: 40 }}
                        >
                          <Category />
                        </Avatar>
                      )}
                      <Box>
                        <Typography variant="subtitle2">
                          {category.name || category.category || category.title || 'Unnamed Category'}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          ID: {category.id}
                        </Typography>
                      </Box>
                    </Box>
                  </TableCell>
                  <TableCell>
                    <Chip
                      label={category.type || 'item'}
                      color={
                        category.type === 'service' ? 'primary' :
                        category.type === 'delivery' ? 'secondary' :
                        category.type === 'ride' ? 'warning' :
                        'default'
                      }
                      size="small"
                      variant="outlined"
                    />
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2" noWrap sx={{ maxWidth: 200 }}>
                      {category.description || 'No description'}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    {isCategoryActive(category.id) ? (
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
                    <Tooltip title={isSuperAdmin ? "Super admins cannot modify country settings" : "Toggle category availability"}>
                      <span>
                        <FormControlLabel
                          control={
                            <Switch
                              checked={isCategoryActive(category.id)}
                              onChange={() => toggleCategoryActivation(category.id, category.name || category.category || category.title || 'Unnamed Category')}
                              disabled={isSuperAdmin || updating.has(category.id)}
                              color="primary"
                            />
                          }
                          label=""
                          sx={{ margin: 0 }}
                        />
                        {updating.has(category.id) && (
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

        {filteredCategories.length === 0 && (
          <Box sx={{ p: 4, textAlign: 'center' }}>
            <Typography variant="body1" color="text.secondary">
              No categories found matching your search criteria
            </Typography>
          </Box>
        )}
      </Paper>
    </Box>
  );
};

export default CountryCategoryManagement;
