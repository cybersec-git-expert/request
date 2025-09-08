import React, { useState, useEffect } from 'react';
import {
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  FormControlLabel,
  Grid,
  IconButton,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Switch,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
  Alert,
  CircularProgress,
  Stack,
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  Visibility as VisibilityIcon,
  VisibilityOff as VisibilityOffIcon,
  LocationCity as LocationCityIcon,
} from '@mui/icons-material';
// Migrated off Firestore to REST API
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter';

const Cities = () => {
  const { getFilteredData, adminData, isSuperAdmin, userCountry } = useCountryFilter();
  
  // Permission check
  const hasCityManagementPermission = adminData?.permissions?.cityManagement || isSuperAdmin;
  
  const [cities, setCities] = useState([]);
  const [filteredCities, setFilteredCities] = useState([]);
  const [loading, setLoading] = useState(true);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingCity, setEditingCity] = useState(null);
  const [deleteConfirmOpen, setDeleteConfirmOpen] = useState(false);
  const [cityToDelete, setCityToDelete] = useState(null);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Form state
  const [formData, setFormData] = useState({
    name: '',
    countryCode: '',
    isActive: true,
    population: '',
    coordinates: {
      lat: '',
      lng: ''
    },
    description: ''
  });

  useEffect(() => {
    loadCities();
  }, []);

  const loadCities = async () => {
    try {
      setLoading(true);
      const res = await api.get('/cities');
      const data = Array.isArray(res.data) ? res.data : res.data?.data || [];
      // Normalize timestamps (server returns snake_case, adaptCity already sets createdAt; ensure it's a string/date not Firestore obj)
      const normalized = data.map(c => ({
        ...c,
        createdAt: c.createdAt && c.createdAt.toDate ? c.createdAt.toDate().toISOString() : c.createdAt,
        updatedAt: c.updatedAt && c.updatedAt.toDate ? c.updatedAt.toDate().toISOString() : c.updatedAt,
      }));
      const filteredData = (!isSuperAdmin && userCountry)
        ? normalized.filter(c => c.countryCode === userCountry)
        : normalized;
      const citiesData = filteredData.sort((a, b) => (a.name || '').localeCompare(b.name || ''));
      setCities(citiesData);
      setFilteredCities(citiesData);
      if (citiesData.length === 0 && userCountry === 'LK') setSuccess('No cities found. Consider adding default Sri Lankan cities.');
    } catch (error) {
      console.error('Error loading cities:', error);
      setError('Failed to load cities');
    } finally {
      setLoading(false);
    }
  };

  const handleOpenDialog = (city = null) => {
    if (city) {
      setEditingCity(city);
      setFormData({
        name: city.name || '',
        countryCode: city.countryCode || userCountry,
        isActive: city.isActive !== false,
        population: city.population || '',
        coordinates: {
          lat: city.coordinates?.lat || '',
          lng: city.coordinates?.lng || ''
        },
        description: city.description || ''
      });
    } else {
      setEditingCity(null);
      setFormData({
        name: '',
        countryCode: userCountry,
        isActive: true,
        population: '',
        coordinates: {
          lat: '',
          lng: ''
        },
        description: ''
      });
    }
    setDialogOpen(true);
  };

  const handleCloseDialog = () => {
    setDialogOpen(false);
    setEditingCity(null);
    setError('');
  };

  const handleSubmit = async () => {
    try {
      if (!formData.name.trim()) {
        setError('City name is required');
        return;
      }

      // Validate if user can manage this country
      if (!isSuperAdmin && formData.countryCode !== userCountry) {
        setError('You can only manage cities in your assigned country');
        return;
      }

      const payload = {
        name: formData.name.trim(),
        countryCode: formData.countryCode,
        isActive: formData.isActive,
        population: formData.population ? parseInt(formData.population) : undefined,
        coordinates: {
          lat: formData.coordinates.lat ? parseFloat(formData.coordinates.lat) : undefined,
          lng: formData.coordinates.lng ? parseFloat(formData.coordinates.lng) : undefined
        },
        description: formData.description.trim(),
        updatedBy: adminData?.email || adminData?.role || 'admin'
      };
      if (editingCity) {
        await api.put(`/cities/${editingCity.id}`, payload);
        setSuccess('City updated successfully');
      } else {
        await api.post('/cities', { ...payload, createdBy: adminData?.email || adminData?.role || 'admin' });
        setSuccess('City added successfully');
      }

      handleCloseDialog();
      loadCities();
    } catch (error) {
      console.error('Error saving city:', error);
      setError('Failed to save city');
    }
  };

  const handleDeleteClick = (city) => {
    setCityToDelete(city);
    setDeleteConfirmOpen(true);
  };

  const handleDeleteConfirm = async () => {
    try {
  await api.delete(`/cities/${cityToDelete.id}`);
      setSuccess('City deleted successfully');
      setDeleteConfirmOpen(false);
      setCityToDelete(null);
      loadCities();
    } catch (error) {
      console.error('Error deleting city:', error);
      setError('Failed to delete city');
    }
  };

  const handleInputChange = (field, value) => {
    if (field.includes('.')) {
      const [parent, child] = field.split('.');
      setFormData(prev => ({
        ...prev,
        [parent]: {
          ...prev[parent],
          [child]: value
        }
      }));
    } else {
      setFormData(prev => ({
        ...prev,
        [field]: value
      }));
    }
  };

  const getCountryName = (countryCode) => {
    const countries = {
      'LK': 'Sri Lanka',
      'IN': 'India',
      'US': 'United States',
      'UK': 'United Kingdom',
      'AU': 'Australia'
    };
    return countries[countryCode] || countryCode;
  };

  const activeCitiesCount = filteredCities.filter(city => city.isActive).length;
  const totalCitiesCount = filteredCities.length;

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <Typography>Loading cities...</Typography>
      </Box>
    );
  }

  return (
    <Box p={3}>
      {!hasCityManagementPermission && (
        <Alert severity="error" sx={{ mb: 3 }}>
          You don't have permission to access City Management. Contact your administrator to get access.
        </Alert>
      )}
      
      {hasCityManagementPermission && (
        <>
          {/* Header */}
          <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Box>
          <Typography variant="h4" gutterBottom>
            Cities Management
          </Typography>
          <Typography variant="subtitle1" color="text.secondary">
            {isSuperAdmin 
              ? 'Manage cities across all countries' 
              : `Manage cities in ${getCountryName(userCountry)}`
            }
          </Typography>
        </Box>
        <Box display="flex" gap={1}>
          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={() => handleOpenDialog()}
          >
            Add City
          </Button>
        </Box>
      </Box>

      {/* Statistics Cards */}
      <Grid container spacing={3} mb={3}>
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" gap={2}>
                <LocationCityIcon color="primary" sx={{ fontSize: 40 }} />
                <Box>
                  <Typography variant="h4" fontWeight="bold">
                    {activeCitiesCount}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Active Cities
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" gap={2}>
                <LocationCityIcon color="secondary" sx={{ fontSize: 40 }} />
                <Box>
                  <Typography variant="h4" fontWeight="bold">
                    {totalCitiesCount}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Total Cities
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Alerts */}
      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>
          {error}
        </Alert>
      )}
      {success && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccess('')}>
          {success}
        </Alert>
      )}

      {/* Cities Table */}
      <Paper>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>City Name</TableCell>
                {isSuperAdmin && <TableCell>Country</TableCell>}
                <TableCell>Status</TableCell>
                <TableCell>Population</TableCell>
                <TableCell>Created</TableCell>
                <TableCell align="center">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filteredCities.map((city) => (
                <TableRow key={city.id} hover>
                  <TableCell>
                    <Box>
                      <Typography variant="subtitle2" fontWeight="medium">
                        {city.name}
                      </Typography>
                      {city.description && (
                        <Typography variant="body2" color="text.secondary">
                          {city.description}
                        </Typography>
                      )}
                    </Box>
                  </TableCell>
                  {isSuperAdmin && (
                    <TableCell>
                      <Chip
                        label={getCountryName(city.countryCode)}
                        size="small"
                        variant="outlined"
                      />
                    </TableCell>
                  )}
                  <TableCell>
                    <Chip
                      label={city.isActive ? 'Active' : 'Inactive'}
                      color={city.isActive ? 'success' : 'default'}
                      size="small"
                    />
                  </TableCell>
                  <TableCell>
                    {city.population ? city.population.toLocaleString() : 'N/A'}
                  </TableCell>
                  <TableCell>
                    {city.createdAt ? (()=>{
                      const raw = city.createdAt;
                      const d = raw && raw.toDate ? raw.toDate() : new Date(raw);
                      if (isNaN(d.getTime())) return 'N/A';
                      return d.toLocaleDateString();
                    })() : 'N/A'}
                  </TableCell>
                  <TableCell align="center">
                    <IconButton
                      size="small"
                      onClick={() => handleOpenDialog(city)}
                      color="primary"
                    >
                      <EditIcon />
                    </IconButton>
                    <IconButton
                      size="small"
                      onClick={() => handleDeleteClick(city)}
                      color="error"
                    >
                      <DeleteIcon />
                    </IconButton>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>

      {/* Add/Edit Dialog */}
      <Dialog open={dialogOpen} onClose={handleCloseDialog} maxWidth="md" fullWidth>
        <DialogTitle>
          {editingCity ? 'Edit City' : 'Add New City'}
        </DialogTitle>
        <DialogContent>
          <Box sx={{ pt: 1 }}>
            <Grid container spacing={3}>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="City Name *"
                  value={formData.name}
                  onChange={(e) => handleInputChange('name', e.target.value)}
                  margin="normal"
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Country Code"
                  value={formData.countryCode}
                  onChange={(e) => handleInputChange('countryCode', e.target.value)}
                  margin="normal"
                  disabled={!isSuperAdmin}
                  helperText={!isSuperAdmin ? 'You can only manage cities in your country' : ''}
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Population"
                  type="number"
                  value={formData.population}
                  onChange={(e) => handleInputChange('population', e.target.value)}
                  margin="normal"
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <FormControlLabel
                  control={
                    <Switch
                      checked={formData.isActive}
                      onChange={(e) => handleInputChange('isActive', e.target.checked)}
                    />
                  }
                  label="Active"
                  sx={{ mt: 2 }}
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Latitude"
                  type="number"
                  value={formData.coordinates.lat}
                  onChange={(e) => handleInputChange('coordinates.lat', e.target.value)}
                  margin="normal"
                  inputProps={{ step: 'any' }}
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Longitude"
                  type="number"
                  value={formData.coordinates.lng}
                  onChange={(e) => handleInputChange('coordinates.lng', e.target.value)}
                  margin="normal"
                  inputProps={{ step: 'any' }}
                />
              </Grid>
              <Grid item xs={12}>
                <TextField
                  fullWidth
                  label="Description"
                  multiline
                  rows={3}
                  value={formData.description}
                  onChange={(e) => handleInputChange('description', e.target.value)}
                  margin="normal"
                />
              </Grid>
            </Grid>
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog}>Cancel</Button>
          <Button onClick={handleSubmit} variant="contained">
            {editingCity ? 'Update' : 'Add'} City
          </Button>
        </DialogActions>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog
        open={deleteConfirmOpen}
        onClose={() => setDeleteConfirmOpen(false)}
      >
        <DialogTitle>Confirm Delete</DialogTitle>
        <DialogContent>
          <Typography>
            Are you sure you want to delete the city "{cityToDelete?.name}"?
            This action cannot be undone.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDeleteConfirmOpen(false)}>Cancel</Button>
          <Button onClick={handleDeleteConfirm} color="error" variant="contained">
            Delete
          </Button>
        </DialogActions>
      </Dialog>
      </>
      )}
    </Box>
  );
};

export default Cities;
