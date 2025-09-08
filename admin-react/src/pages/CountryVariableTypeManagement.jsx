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
  Settings,
  TuneRounded
} from '@mui/icons-material';
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter.jsx';
import { DataLookupService } from '../services/DataLookupService.js';

const CountryVariableTypeManagement = () => {
  const {
    getFilteredData,
    adminData,
    isSuperAdmin,
    getCountryDisplayName,
    userCountry
  } = useCountryFilter();

  const [variableTypes, setVariableTypes] = useState([]);
  const [countryVariableTypes, setCountryVariableTypes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [updating, setUpdating] = useState(new Set());

  // Load all variable types and country-specific activation status
  const loadVariableTypes = async () => {
    try {
      setLoading(true);
      setError(null);

      // Get all variable types (global data)
  const allVariableTypes = await getFilteredData('custom_product_variables', adminData) || [];
  const countryActivations = await getFilteredData('country_variable_types', adminData) || [];
      
      setVariableTypes(allVariableTypes || []);
      setCountryVariableTypes(countryActivations);
      
      console.log(`⚙️ Loaded ${allVariableTypes?.length || 0} variable types for country management`);
      console.log(`🎯 Found ${countryActivations.length} country-specific activations`);
    } catch (err) {
      console.error('Error loading variable types:', err);
      setError('Failed to load variable types: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadVariableTypes();
  }, [adminData]);

  // Check if a variable type is active in the current country
  const isVariableTypeActive = (variableTypeId) => {
    const countryActivation = countryVariableTypes.find(
      cvt => cvt.variableTypeId === variableTypeId && cvt.country === userCountry
    );
    return countryActivation?.isActive !== false; // Default to true if not found
  };

  // Toggle variable type activation for the country
  const toggleVariableTypeActivation = async (variableTypeId, variableTypeName) => {
    if (isSuperAdmin) {
      setError('Super admins cannot modify country-specific settings');
      return;
    }

    try {
      setUpdating(prev => new Set([...prev, variableTypeId]));
      
      const currentStatus = isVariableTypeActive(variableTypeId);
      const newStatus = !currentStatus;

      // Find existing record or create new one
      const existingRecord = countryVariableTypes.find(cvt => cvt.variableTypeId === variableTypeId && cvt.country === userCountry);
      const payload = {
        variable_type_id: variableTypeId,
        variable_type_name: variableTypeName,
        country: userCountry,
        country_name: getCountryDisplayName(userCountry),
        is_active: newStatus
      };
      if (existingRecord) {
        await api.put(`/country-variable-types/${existingRecord.id}`, payload);
        setCountryVariableTypes(prev => prev.map(cvt => cvt.id === existingRecord.id ? { ...cvt, variableTypeId, variableTypeName, country: userCountry, isActive: newStatus } : cvt));
      } else {
        const res = await api.post('/country-variable-types', payload);
        const newId = res.data?.data?.id || res.data?.id;
        setCountryVariableTypes(prev => [...prev, { id: newId, variableTypeId, variableTypeName, country: userCountry, isActive: newStatus }]);
      }

      console.log(`🔄 Toggled variable type ${variableTypeName} to ${newStatus ? 'active' : 'inactive'} in ${userCountry}`);
    } catch (err) {
      console.error('Error toggling variable type:', err);
      setError(`Failed to update variable type: ${err.message}`);
    } finally {
      setUpdating(prev => {
        const newSet = new Set(prev);
        newSet.delete(variableTypeId);
        return newSet;
      });
    }
  };

  // Filter variable types based on search term
  const filteredVariableTypes = variableTypes.filter(variableType =>
    variableType.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    variableType.title?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    variableType.description?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    variableType.type?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  // Get activation stats
  const getActivationStats = () => {
    const total = filteredVariableTypes.length;
    const active = filteredVariableTypes.filter(vt => isVariableTypeActive(vt.id)).length;
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
          Variable Type Management
        </Typography>
        <Typography variant="body1" color="text.secondary">
          {isSuperAdmin 
            ? 'Super admins cannot modify country-specific settings' 
            : `Manage variable type availability in ${getCountryDisplayName(userCountry)}`
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
                Total Variable Types
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
            placeholder="Search variable types..."
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
            onClick={loadVariableTypes}
          >
            Refresh
          </Button>
        </Box>
      </Paper>

      {/* Variable Types Table */}
      <Paper>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Variable Type</TableCell>
                <TableCell>Type</TableCell>
                <TableCell>Description</TableCell>
                <TableCell>Status</TableCell>
                <TableCell align="center">Active in {getCountryDisplayName(userCountry)}</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filteredVariableTypes.map((variableType) => (
                <TableRow key={variableType.id} hover>
                  <TableCell>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                      <Avatar 
                        variant="rounded"
                        sx={{ width: 40, height: 40, bgcolor: 'primary.light' }}
                      >
                        <TuneRounded />
                      </Avatar>
                      <Box>
                        <Typography variant="subtitle2">
                          {variableType.name || variableType.title || 'Unnamed Variable Type'}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          ID: {variableType.id}
                        </Typography>
                      </Box>
                    </Box>
                  </TableCell>
                  <TableCell>
                    <Chip 
                      label={variableType.type || 'Unknown'}
                      size="small"
                      variant="outlined"
                      color="primary"
                    />
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2" noWrap sx={{ maxWidth: 200 }}>
                      {variableType.description || 'No description'}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    {isVariableTypeActive(variableType.id) ? (
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
                    <Tooltip title={isSuperAdmin ? "Super admins cannot modify country settings" : "Toggle variable type availability"}>
                      <span>
                        <FormControlLabel
                          control={
                            <Switch
                              checked={isVariableTypeActive(variableType.id)}
                              onChange={() => toggleVariableTypeActivation(variableType.id, variableType.name)}
                              disabled={isSuperAdmin || updating.has(variableType.id)}
                              color="primary"
                            />
                          }
                          label=""
                          sx={{ margin: 0 }}
                        />
                        {updating.has(variableType.id) && (
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

        {filteredVariableTypes.length === 0 && (
          <Box sx={{ p: 4, textAlign: 'center' }}>
            <Typography variant="body1" color="text.secondary">
              No variable types found matching your search criteria
            </Typography>
          </Box>
        )}
      </Paper>
    </Box>
  );
};

export default CountryVariableTypeManagement;
