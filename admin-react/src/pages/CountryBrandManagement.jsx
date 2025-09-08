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
  BrandingWatermark
} from '@mui/icons-material';
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter.jsx';
import { DataLookupService } from '../services/DataLookupService.js';

const CountryBrandManagement = () => {
  const {
    getFilteredData,
    adminData,
    isSuperAdmin,
    getCountryDisplayName,
    userCountry
  } = useCountryFilter();

  const [brands, setBrands] = useState([]);
  const [countryBrands, setCountryBrands] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [updating, setUpdating] = useState(new Set());

  // Load all brands and country-specific activation status
  const loadBrands = async () => {
    try {
      setLoading(true);
      setError(null);

      // Get all brands (global data)
      const allBrands = await getFilteredData('brands', adminData) || [];
      
      // Get country-specific brand activations
      const countryActivations = await getFilteredData('country_brands', adminData) || [];
      
      setBrands(allBrands || []);
      setCountryBrands(countryActivations);
      
      console.log(`🏷️ Loaded ${allBrands?.length || 0} brands for country management`);
      console.log(`🎯 Found ${countryActivations.length} country-specific activations`);
    } catch (err) {
      console.error('Error loading brands:', err);
      setError('Failed to load brands: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadBrands();
  }, [adminData]);

  // Check if a brand is active in the current country
  const isBrandActive = (brandId) => {
    const countryActivation = countryBrands.find(
      cb => cb.brandId === brandId && cb.country === userCountry
    );
    return countryActivation?.isActive !== false; // Default to true if not found
  };

  // Toggle brand activation for the country
  const toggleBrandActivation = async (brandId, brandName) => {
    if (isSuperAdmin) {
      setError('Super admins cannot modify country-specific settings');
      return;
    }

    try {
      setUpdating(prev => new Set([...prev, brandId]));
      
      const currentStatus = isBrandActive(brandId);
      const newStatus = !currentStatus;

      // Find existing record or create new one
      const existingRecord = countryBrands.find(
        cb => cb.brandId === brandId && cb.country === userCountry
      );

      const updateData = {
        brandId,
        brandName,
        country: userCountry,
        countryName: getCountryDisplayName(userCountry),
        isActive: newStatus,
        updatedAt: new Date(),
        updatedBy: adminData.uid,
        updatedByName: adminData.displayName || adminData.email
      };

      if (existingRecord) {
        await api.put(`/country-brands/${existingRecord.id}`, updateData);
        setCountryBrands(prev => prev.map(cb => cb.id === existingRecord.id ? { ...cb, ...updateData } : cb));
      } else {
        const createRes = await api.post('/country-brands', updateData);
        const created = createRes.data?.data || createRes.data;
        setCountryBrands(prev => [...prev, { id: created?.id || created?.uuid || Math.random().toString(36).slice(2), ...updateData }]);
      }

      console.log(`🔄 Toggled brand ${brandName} to ${newStatus ? 'active' : 'inactive'} in ${userCountry}`);
    } catch (err) {
      console.error('Error toggling brand:', err);
      setError(`Failed to update brand: ${err.message}`);
    } finally {
      setUpdating(prev => {
        const newSet = new Set(prev);
        newSet.delete(brandId);
        return newSet;
      });
    }
  };

  // Filter brands based on search term
  const filteredBrands = brands.filter(brand =>
    brand.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    brand.title?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    brand.description?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  // Get activation stats
  const getActivationStats = () => {
    const total = filteredBrands.length;
    const active = filteredBrands.filter(brand => isBrandActive(brand.id)).length;
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
          Brand Management
        </Typography>
        <Typography variant="body1" color="text.secondary">
          {isSuperAdmin 
            ? 'Super admins cannot modify country-specific settings' 
            : `Manage brand availability in ${getCountryDisplayName(userCountry)}`
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
                Total Brands
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
            placeholder="Search brands..."
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
            onClick={loadBrands}
          >
            Refresh
          </Button>
        </Box>
      </Paper>

      {/* Brands Table */}
      <Paper>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Brand</TableCell>
                <TableCell>Description</TableCell>
                <TableCell>Status</TableCell>
                <TableCell align="center">Active in {getCountryDisplayName(userCountry)}</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filteredBrands.map((brand) => (
                <TableRow key={brand.id} hover>
                  <TableCell>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                      {brand.logo && (
                        <Avatar 
                          src={brand.logo} 
                          alt={brand.name}
                          variant="rounded"
                          sx={{ width: 40, height: 40 }}
                        >
                          <BrandingWatermark />
                        </Avatar>
                      )}
                      <Box>
                        <Typography variant="subtitle2">
                          {brand.name || brand.title || 'Unnamed Brand'}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          ID: {brand.id}
                        </Typography>
                      </Box>
                    </Box>
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2" noWrap sx={{ maxWidth: 200 }}>
                      {brand.description || 'No description'}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    {isBrandActive(brand.id) ? (
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
                    <Tooltip title={isSuperAdmin ? "Super admins cannot modify country settings" : "Toggle brand availability"}>
                      <span>
                        <FormControlLabel
                          control={
                            <Switch
                              checked={isBrandActive(brand.id)}
                              onChange={() => toggleBrandActivation(brand.id, brand.name)}
                              disabled={isSuperAdmin || updating.has(brand.id)}
                              color="primary"
                            />
                          }
                          label=""
                          sx={{ margin: 0 }}
                        />
                        {updating.has(brand.id) && (
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

        {filteredBrands.length === 0 && (
          <Box sx={{ p: 4, textAlign: 'center' }}>
            <Typography variant="body1" color="text.secondary">
              No brands found matching your search criteria
            </Typography>
          </Box>
        )}
      </Paper>
    </Box>
  );
};

export default CountryBrandManagement;
