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
  SubdirectoryArrowRight
} from '@mui/icons-material';
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter.jsx';
import { DataLookupService } from '../services/DataLookupService.js';

const CountrySubcategoryManagement = () => {
  const {
    getFilteredData,
    adminData,
    isSuperAdmin,
    getCountryDisplayName,
    userCountry
  } = useCountryFilter();

  const [subcategories, setSubcategories] = useState([]);
  const [categories, setCategories] = useState([]);
  const [countrySubcategories, setCountrySubcategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [updating, setUpdating] = useState(new Set());

  // Load all subcategories and country-specific activation status
  const loadSubcategories = async () => {
    try {
      setLoading(true);
      setError(null);

      // Get all subcategories and categories (global data)
      const [allSubcategories, allCategories] = await Promise.all([
        getFilteredData('subcategories', adminData),
        getFilteredData('categories', adminData)
      ]);
      
      // Get country-specific subcategory activations
      const countryActivations = await getFilteredData('country_subcategories', adminData) || [];
      
      setSubcategories(allSubcategories || []);
      setCategories(allCategories || []);
      setCountrySubcategories(countryActivations);
      
      console.log(`📂 Loaded ${allSubcategories?.length || 0} subcategories for country management`);
      console.log(`🎯 Found ${countryActivations.length} country-specific activations`);
    } catch (err) {
      console.error('Error loading subcategories:', err);
      setError('Failed to load subcategories: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadSubcategories();
  }, [adminData]);

  // Check if a subcategory is active in the current country
  const isSubcategoryActive = (subcategoryId) => {
    const countryActivation = countrySubcategories.find(
      cs => cs.subcategoryId === subcategoryId && cs.country === userCountry
    );
    return countryActivation?.isActive !== false; // Default to true if not found
  };

  // Get parent category name
  const getCategoryName = (subcategory) => {
    const categoryId = subcategory.categoryId || subcategory.category_id || subcategory.parentCategoryId || subcategory.parentId;
    const category = categories.find(cat => cat.id === categoryId);
    return category?.name || category?.category || category?.title || 'Unknown Category';
  };

  // Toggle subcategory activation for the country
  const toggleSubcategoryActivation = async (subcategoryId, subcategoryName) => {
    if (isSuperAdmin) {
      setError('Super admins cannot modify country-specific settings');
      return;
    }

    try {
      setUpdating(prev => new Set([...prev, subcategoryId]));
      
      const currentStatus = isSubcategoryActive(subcategoryId);
      const newStatus = !currentStatus;

      // Find existing record or create new one
      const existingRecord = countrySubcategories.find(
        cs => cs.subcategoryId === subcategoryId && cs.country === userCountry
      );

      const updateData = {
        subcategoryId,
        subcategoryName,
        country: userCountry,
        countryName: getCountryDisplayName(userCountry),
        isActive: newStatus,
        updatedAt: new Date(),
        updatedBy: adminData.uid,
        updatedByName: adminData.displayName || adminData.email
      };

      if (existingRecord) {
        await api.put(`/country-subcategories/${existingRecord.id}`, updateData);
        setCountrySubcategories(prev => prev.map(cs => cs.id === existingRecord.id ? { ...cs, ...updateData } : cs));
      } else {
        const createRes = await api.post('/country-subcategories', updateData);
        const created = createRes.data?.data || createRes.data;
        setCountrySubcategories(prev => [...prev, { id: created?.id || created?.uuid || Math.random().toString(36).slice(2), ...updateData }]);
      }

      console.log(`🔄 Toggled subcategory ${subcategoryName} to ${newStatus ? 'active' : 'inactive'} in ${userCountry}`);
    } catch (err) {
      console.error('Error toggling subcategory:', err);
      setError(`Failed to update subcategory: ${err.message}`);
    } finally {
      setUpdating(prev => {
        const newSet = new Set(prev);
        newSet.delete(subcategoryId);
        return newSet;
      });
    }
  };

  // Filter subcategories based on search term
  const filteredSubcategories = subcategories.filter(subcategory =>
    subcategory.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    subcategory.subcategory?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    subcategory.title?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    subcategory.description?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    getCategoryName(subcategory)?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  // Get activation stats
  const getActivationStats = () => {
    const total = filteredSubcategories.length;
    const active = filteredSubcategories.filter(sub => isSubcategoryActive(sub.id)).length;
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
          Subcategory Management
        </Typography>
        <Typography variant="body1" color="text.secondary">
          {isSuperAdmin 
            ? 'Super admins cannot modify country-specific settings' 
            : `Manage subcategory availability in ${getCountryDisplayName(userCountry)}`
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
                Total Subcategories
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
            placeholder="Search subcategories..."
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
            onClick={loadSubcategories}
          >
            Refresh
          </Button>
        </Box>
      </Paper>

      {/* Subcategories Table */}
      <Paper>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Subcategory</TableCell>
                <TableCell>Parent Category</TableCell>
                <TableCell>Description</TableCell>
                <TableCell>Status</TableCell>
                <TableCell align="center">Active in {getCountryDisplayName(userCountry)}</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filteredSubcategories.map((subcategory) => (
                <TableRow key={subcategory.id} hover>
                  <TableCell>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                      {subcategory.icon && (
                        <Avatar 
                          src={subcategory.icon} 
                          alt={subcategory.name}
                          variant="rounded"
                          sx={{ width: 40, height: 40 }}
                        >
                          <SubdirectoryArrowRight />
                        </Avatar>
                      )}
                      <Box>
                        <Typography variant="subtitle2">
                          {subcategory.name || subcategory.subcategory || subcategory.title || 'Unnamed Subcategory'}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          ID: {subcategory.id}
                        </Typography>
                      </Box>
                    </Box>
                  </TableCell>
                  <TableCell>
                    <Chip 
                      label={getCategoryName(subcategory)}
                      size="small"
                      variant="outlined"
                    />
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2" noWrap sx={{ maxWidth: 200 }}>
                      {subcategory.description || 'No description'}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    {isSubcategoryActive(subcategory.id) ? (
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
                    <Tooltip title={isSuperAdmin ? "Super admins cannot modify country settings" : "Toggle subcategory availability"}>
                      <span>
                        <FormControlLabel
                          control={
                            <Switch
                              checked={isSubcategoryActive(subcategory.id)}
                              onChange={() => toggleSubcategoryActivation(subcategory.id, subcategory.name || subcategory.subcategory || subcategory.title || 'Unnamed Subcategory')}
                              disabled={isSuperAdmin || updating.has(subcategory.id)}
                              color="primary"
                            />
                          }
                          label=""
                          sx={{ margin: 0 }}
                        />
                        {updating.has(subcategory.id) && (
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

        {filteredSubcategories.length === 0 && (
          <Box sx={{ p: 4, textAlign: 'center' }}>
            <Typography variant="body1" color="text.secondary">
              No subcategories found matching your search criteria
            </Typography>
          </Box>
        )}
      </Paper>
    </Box>
  );
};

export default CountrySubcategoryManagement;
