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
  Box,
  IconButton,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Chip,
  Alert,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Switch,
  FormControlLabel,
  Snackbar,
  Checkbox,
  FormGroup,
  Tooltip
} from '@mui/material';
import {
  Delete as DeleteIcon,
  Edit as EditIcon,
  Add as AddIcon,
  Visibility as VisibilityIcon,
  VisibilityOff as VisibilityOffIcon,
  Save as SaveIcon,
  Cancel as CancelIcon
} from '@mui/icons-material';
import api from '../services/apiClient';
import DynamicBusinessTypeService from '../services/dynamicBusinessTypeService';
import { useAuth } from '../contexts/AuthContext';

const CountryBusinessTypesManagement = () => {
  const [businessTypes, setBusinessTypes] = useState([]);
  const [countries, setCountries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [availableModules, setAvailableModules] = useState([]);
  const [dynamicCapabilities, setDynamicCapabilities] = useState({});
  const [dynamicModules, setDynamicModules] = useState({});
  const [editingId, setEditingId] = useState(null);
  const [editingModules, setEditingModules] = useState([]);
  const [editingCapabilities, setEditingCapabilities] = useState({});
  const { user, adminData, userRole, userCountry } = useAuth();
  const isSuperAdmin = userRole === 'super_admin';
  const hasPermission = isSuperAdmin || user?.permissions?.countryBusinessTypeManagement;
  const [selectedCountry, setSelectedCountry] = useState(userCountry || 'LK');
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingType, setEditingType] = useState(null);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    icon: '',
    display_order: 0,
    country_code: userCountry || 'LK',
    is_active: true
  });

  // Common business type icons
  const iconSuggestions = [
    '🛍️', '🔧', '🏠', '🍽️', '🚚', '🏢', '💼', '🏪', '🎯', '🌟',
    '💻', '📱', '🏥', '🎓', '🚗', '✈️', '🏭', '🎨', '📚', '🎵'
  ];

  useEffect(() => {
    if (!hasPermission) return;
    // For super admins, allow selecting any country (load countries list)
    // For country admins, bind to their assigned country and hide selector
    if (isSuperAdmin) {
      fetchCountries();
    } else {
      // Ensure selectedCountry matches logged-in admin's country
      if (userCountry && selectedCountry !== userCountry) {
        setSelectedCountry(userCountry);
      }
    }
    fetchBusinessTypes();
  }, [selectedCountry, isSuperAdmin, userCountry, hasPermission]);

  useEffect(() => {
    // Load available modules and dynamic data
    loadAvailableModules();
  }, []);

  useEffect(() => {
    // Load dynamic capabilities and modules for current business types
    if (businessTypes.length > 0) {
      loadDynamicData();
    }
  }, [businessTypes, selectedCountry]);

  const loadAvailableModules = async () => {
    try {
      const modules = await DynamicBusinessTypeService.getAvailableModules();
      setAvailableModules(modules);
    } catch (error) {
      console.error('Error loading available modules:', error);
    }
  };

  const loadDynamicData = async () => {
    const capabilities = {};
    const modules = {};

    for (const businessType of businessTypes) {
      try {
        // Load capabilities
        const caps = await DynamicBusinessTypeService.getBusinessTypeCapabilities(
          businessType.id,
          selectedCountry
        );
        if (caps) {
          capabilities[businessType.id] = caps;
        }

        // Load modules
        const mods = await DynamicBusinessTypeService.getBusinessTypeModules(
          businessType.id,
          selectedCountry
        );
        modules[businessType.id] = mods;
      } catch (error) {
        console.error(`Error loading data for business type ${businessType.id}:`, error);
      }
    }

    setDynamicCapabilities(capabilities);
    setDynamicModules(modules);
  };

  const getModulesForBusinessTypeDynamic = (businessType) => {
    // Try dynamic first, fallback to static
    const dynamicMods = dynamicModules[businessType.id];
    if (dynamicMods && dynamicMods.length > 0) {
      return availableModules.filter(module => dynamicMods.includes(module.id));
    }
    
    // Fallback to static
    return DynamicBusinessTypeService.getModulesForBusinessTypeName(businessType.name, availableModules);
  };

  const getCapabilitiesForBusinessTypeDynamic = (businessType) => {
    // Try dynamic first, fallback to static
    const dynamicCaps = dynamicCapabilities[businessType.id];
    if (dynamicCaps) {
      return dynamicCaps;
    }
    
    // Fallback to static
    return DynamicBusinessTypeService.getCapabilitiesForBusinessTypeName(businessType.name);
  };

  const handleEditModules = (businessType) => {
    setEditingId(businessType.id);
    setEditingModules(getModulesForBusinessTypeDynamic(businessType));
    setEditingCapabilities(getCapabilitiesForBusinessTypeDynamic(businessType));
  };

  const handleCancelEdit = () => {
    setEditingId(null);
    setEditingModules([]);
    setEditingCapabilities({});
  };

  const handleSaveEdit = async (businessTypeId) => {
    try {
      setLoading(true);
      
      // Update modules
      const moduleIds = editingModules.map(m => m.id);
      await DynamicBusinessTypeService.updateBusinessTypeModules(businessTypeId, selectedCountry, moduleIds);
      
      // Update capabilities
      await DynamicBusinessTypeService.updateBusinessTypeCapabilities(businessTypeId, editingCapabilities);
      
      // Reload dynamic data
      await loadDynamicData();
      
      // Clear editing state
      handleCancelEdit();
      
      setSnackbar({
        open: true,
        message: 'Business type updated successfully',
        severity: 'success'
      });
    } catch (error) {
      console.error('Error updating business type:', error);
      setSnackbar({
        open: true,
        message: 'Error updating business type',
        severity: 'error'
      });
    } finally {
      setLoading(false);
    }
  };

  const handleModuleToggle = (module) => {
    const isSelected = editingModules.some(m => m.id === module.id);
    if (isSelected) {
      setEditingModules(editingModules.filter(m => m.id !== module.id));
    } else {
      setEditingModules([...editingModules, module]);
    }
  };

  const handleCapabilityToggle = (capabilityKey) => {
    setEditingCapabilities({
      ...editingCapabilities,
      [capabilityKey]: !editingCapabilities[capabilityKey]
    });
  };

  const fetchCountries = async () => {
    try {
      const { data } = await api.get('/countries');
      if (data?.success) setCountries(data.data || []);
    } catch (error) {
      console.error('Error fetching countries:', error);
    }
  };

  const fetchBusinessTypes = async () => {
    try {
      setLoading(true);
      // Use admin endpoint to get full details; backend restricts country automatically for non-super admins
      const params = isSuperAdmin && selectedCountry ? { country_code: selectedCountry } : undefined;
      const { data } = await api.get(`/business-types/admin`, { params });
      if (data?.success) {
        setBusinessTypes(data.data || []);
      } else {
        setSnackbar({ open: true, message: data?.message || 'Failed to fetch business types', severity: 'error' });
      }
    } catch (error) {
      console.error('Error fetching business types:', error);
      setSnackbar({ open: true, message: 'Failed to fetch business types', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    try {
  const url = editingType 
        ? `/business-types/admin/${editingType.id}`
        : '/business-types/admin';
  const boundCountry = isSuperAdmin ? selectedCountry : (userCountry || selectedCountry);
  const payload = { ...formData, country_code: boundCountry };
      const { data } = editingType
        ? await api.put(url, payload)
        : await api.post(url, payload);
      
      if (data?.success) {
        setSnackbar({ open: true, message: editingType ? 'Business type updated successfully' : 'Business type created successfully', severity: 'success' });
        setIsDialogOpen(false);
        setEditingType(null);
        setFormData({
          name: '',
          description: '',
          icon: '',
          display_order: 0,
          country_code: boundCountry,
          is_active: true
        });
        fetchBusinessTypes();
      } else {
        setSnackbar({ open: true, message: data?.message || 'Operation failed', severity: 'error' });
      }
    } catch (error) {
      console.error('Error saving business type:', error);
      setSnackbar({ open: true, message: 'Failed to save business type', severity: 'error' });
    }
  };

  const handleEdit = (businessType) => {
    setEditingType(businessType);
    setFormData({
      name: businessType.name,
      description: businessType.description || '',
      icon: businessType.icon || '',
      display_order: businessType.display_order || 0,
  country_code: businessType.country_code,
      is_active: businessType.is_active
    });
    setIsDialogOpen(true);
  };

  const handleDelete = async (id) => {
    if (!confirm('Are you sure you want to delete this business type?')) {
      return;
    }

    try {
      const { data } = await api.delete(`/business-types/admin/${id}`);
      
      if (data?.success) {
        setSnackbar({ open: true, message: 'Business type deleted successfully', severity: 'success' });
        fetchBusinessTypes();
      } else {
        setSnackbar({ open: true, message: data?.message || 'Failed to delete business type', severity: 'error' });
      }
    } catch (error) {
      console.error('Error deleting business type:', error);
      setSnackbar({ open: true, message: 'Failed to delete business type', severity: 'error' });
    }
  };

  const toggleStatus = async (id, currentStatus) => {
    try {
      const { data } = await api.put(`/business-types/admin/${id}`, {
        is_active: !currentStatus
      });
      
      if (data?.success) {
        setSnackbar({ open: true, message: 'Business type status updated successfully', severity: 'success' });
        fetchBusinessTypes();
      } else {
        setSnackbar({ open: true, message: data?.message || 'Failed to update status', severity: 'error' });
      }
    } catch (error) {
      console.error('Error updating status:', error);
      setSnackbar({ open: true, message: 'Failed to update status', severity: 'error' });
    }
  };

  const resetForm = () => {
    setEditingType(null);
    setFormData({
      name: '',
      description: '',
      icon: '',
      display_order: 0,
      country_code: selectedCountry,
      is_active: true
    });
  };

  if (!hasPermission) {
    return (
      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Typography variant="h4" component="h1" gutterBottom>
          Country Business Types Management
        </Typography>
        <Alert severity="warning">You don't have permission to access this page.</Alert>
      </Container>
    );
  }

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Box>
          <Typography variant="h4" component="h1" gutterBottom>
            Country Business Types Management
          </Typography>
          <Typography variant="body1" color="text.secondary">
            Manage business types for your country
          </Typography>
        </Box>
        
        <Box sx={{ display: 'flex', gap: 2 }}>
          {isSuperAdmin ? (
            <FormControl sx={{ minWidth: 220 }}>
              <InputLabel>Country</InputLabel>
              <Select
                value={selectedCountry}
                label="Country"
                onChange={(e) => setSelectedCountry(e.target.value)}
              >
                {countries.map((country) => (
                  <MenuItem key={country.code} value={country.code}>
                    {country.name} ({country.code})
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          ) : (
            <Chip
              label={`Country: ${userCountry || selectedCountry}`}
              color="default"
              variant="outlined"
            />
          )}

          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={() => setIsDialogOpen(true)}
          >
            Add Business Type
          </Button>
        </Box>
      </Box>

      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Business Types for {isSuperAdmin ? (countries.find(c => c.code === selectedCountry)?.name || selectedCountry) : (userCountry || selectedCountry)}
          </Typography>
          
          {loading ? (
            <Box sx={{ textAlign: 'center', py: 4 }}>
              <Typography>Loading...</Typography>
            </Box>
          ) : (
            <TableContainer component={Paper} sx={{ mt: 2 }}>
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>Icon</TableCell>
                    <TableCell>Name</TableCell>
                    <TableCell>Description</TableCell>
                    <TableCell>Order</TableCell>
                    <TableCell>Status</TableCell>
                    <TableCell>Modules</TableCell>
                    <TableCell>Capabilities</TableCell>
                    <TableCell>Actions</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {businessTypes.map((type) => (
                    <TableRow key={type.id}>
                      <TableCell sx={{ fontSize: '2rem' }}>{type.icon || '📋'}</TableCell>
                      <TableCell sx={{ fontWeight: 'medium' }}>{type.name}</TableCell>
                      <TableCell sx={{ maxWidth: 300 }}>
                        <Typography variant="body2" noWrap>
                          {type.description || '-'}
                        </Typography>
                      </TableCell>
                      <TableCell>{type.display_order || 0}</TableCell>
                      <TableCell>
                        <Chip 
                          label={type.is_active ? 'Active' : 'Inactive'}
                          color={type.is_active ? 'success' : 'default'}
                          size="small"
                        />
                      </TableCell>
                      <TableCell>
                        {editingId === type.id ? (
                          <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                            {availableModules.map((m) => (
                              <Chip
                                key={m.id}
                                label={m.name}
                                size="small"
                                clickable
                                onClick={() => handleModuleToggle(m)}
                                sx={{
                                  backgroundColor: editingModules.some(em => em.id === m.id) ? m.color : '#f5f5f5',
                                  color: editingModules.some(em => em.id === m.id) ? '#fff' : '#666',
                                  border: editingModules.some(em => em.id === m.id) ? 'none' : '1px solid #ddd'
                                }}
                              />
                            ))}
                          </Box>
                        ) : (
                          <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                            {getModulesForBusinessTypeDynamic(type).map((m) => (
                              <Chip
                                key={m.id}
                                label={m.name}
                                size="small"
                                sx={{
                                  backgroundColor: m.color,
                                  color: '#fff',
                                }}
                              />
                            ))}
                            {getModulesForBusinessTypeDynamic(type).length === 0 && (
                              <Typography variant="caption" color="text.secondary">No mapped modules</Typography>
                            )}
                          </Box>
                        )}
                      </TableCell>
                      <TableCell>
                        {editingId === type.id ? (
                          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 0.5 }}>
                            {[
                              { key: 'managePrices', label: 'Manage Prices', color: 'secondary' },
                              { key: 'respondItem', label: 'Respond Item', color: 'default' },
                              { key: 'respondService', label: 'Respond Service', color: 'default' },
                              { key: 'respondRent', label: 'Respond Rent', color: 'default' },
                              { key: 'respondTours', label: 'Respond Tours', color: 'default' },
                              { key: 'respondEvents', label: 'Respond Events', color: 'default' },
                              { key: 'respondConstruction', label: 'Respond Construction', color: 'default' },
                              { key: 'respondEducation', label: 'Respond Education', color: 'default' },
                              { key: 'respondHiring', label: 'Respond Job', color: 'default' },
                              { key: 'respondDelivery', label: 'Respond Delivery', color: 'success' },
                              { key: 'respondRide', label: 'Respond Ride', color: 'warning' }
                            ].map(capability => (
                              <FormControlLabel
                                key={capability.key}
                                control={
                                  <Checkbox
                                    checked={editingCapabilities[capability.key] || false}
                                    onChange={() => handleCapabilityToggle(capability.key)}
                                    size="small"
                                  />
                                }
                                label={<Typography variant="caption">{capability.label}</Typography>}
                                sx={{ m: 0 }}
                              />
                            ))}
                          </Box>
                        ) : (
                          (() => {
                            const cap = getCapabilitiesForBusinessTypeDynamic(type);
                            const chips = [];
                            if (cap.managePrices) chips.push(<Chip key="cap-prices" label="Manage Prices" size="small" color="secondary" />);
                            if (cap.respondItem) chips.push(<Chip key="cap-item" label="Respond Item" size="small" />);
                            if (cap.respondService) chips.push(<Chip key="cap-service" label="Respond Service" size="small" />);
                            if (cap.respondRent) chips.push(<Chip key="cap-rent" label="Respond Rent" size="small" />);
                            if (cap.respondTours) chips.push(<Chip key="cap-tours" label="Respond Tours" size="small" />);
                            if (cap.respondEvents) chips.push(<Chip key="cap-events" label="Respond Events" size="small" />);
                            if (cap.respondConstruction) chips.push(<Chip key="cap-construction" label="Respond Construction" size="small" />);
                            if (cap.respondEducation) chips.push(<Chip key="cap-education" label="Respond Education" size="small" />);
                            if (cap.respondHiring) chips.push(<Chip key="cap-hiring" label="Respond Job" size="small" />);
                            if (cap.respondDelivery) chips.push(<Chip key="cap-respond-delivery" label="Respond Delivery" size="small" color="success" />);
                            if (cap.respondRide) chips.push(<Chip key="cap-respond-ride" label="Respond Ride" size="small" color="warning" />);
                            return (
                              <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                                {chips.length ? chips : <Typography variant="caption" color="text.secondary">No capabilities</Typography>}
                              </Box>
                            );
                          })()
                        )}
                      </TableCell>
                      <TableCell>
                        <Box sx={{ display: 'flex', gap: 1 }}>
                          {editingId === type.id ? (
                            <>
                              <Tooltip title="Save Changes">
                                <IconButton
                                  size="small"
                                  onClick={() => handleSaveEdit(type.id)}
                                  color="success"
                                >
                                  <SaveIcon />
                                </IconButton>
                              </Tooltip>
                              <Tooltip title="Cancel Edit">
                                <IconButton
                                  size="small"
                                  onClick={handleCancelEdit}
                                  color="default"
                                >
                                  <CancelIcon />
                                </IconButton>
                              </Tooltip>
                            </>
                          ) : (
                            <>
                              <Tooltip title="Edit Business Type Settings">
                                <IconButton
                                  size="small"
                                  onClick={() => handleEditModules(type)}
                                  color="primary"
                                >
                                  <EditIcon />
                                </IconButton>
                              </Tooltip>
                              <IconButton
                                size="small"
                                onClick={() => toggleStatus(type.id, type.is_active)}
                                color={type.is_active ? 'warning' : 'success'}
                              >
                                {type.is_active ? <VisibilityOffIcon /> : <VisibilityIcon />}
                              </IconButton>
                              <IconButton
                                size="small"
                                onClick={() => handleDelete(type.id)}
                                color="error"
                              >
                                <DeleteIcon />
                              </IconButton>
                            </>
                          )}
                        </Box>
                      </TableCell>
                    </TableRow>
                  ))}
                  {businessTypes.length === 0 && (
                    <TableRow>
                      <TableCell colSpan={8} sx={{ textAlign: 'center', py: 4 }}>
                        <Typography color="text.secondary">
                          No business types found for this country
                        </Typography>
                      </TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </CardContent>
      </Card>

      {/* Add/Edit Dialog */}
      <Dialog 
        open={isDialogOpen} 
        onClose={() => {
          setIsDialogOpen(false);
          resetForm();
        }}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>
          {editingType ? 'Edit Business Type' : 'Add New Business Type'}
        </DialogTitle>
        <form onSubmit={handleSubmit}>
          <DialogContent>
            <Grid container spacing={2}>
              <Grid item xs={12}>
                <TextField
                  fullWidth
                  label="Name"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="e.g., Product Seller"
                  required
                />
              </Grid>

              <Grid item xs={12}>
                <TextField
                  fullWidth
                  label="Description"
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  placeholder="Brief description of this business type"
                  multiline
                  rows={3}
                />
              </Grid>

              <Grid item xs={8}>
                <TextField
                  fullWidth
                  label="Icon"
                  value={formData.icon}
                  onChange={(e) => setFormData({ ...formData, icon: e.target.value })}
                  placeholder="Choose an emoji"
                />
              </Grid>
              <Grid item xs={4}>
                <Box 
                  sx={{ 
                    fontSize: '2rem', 
                    textAlign: 'center', 
                    p: 2, 
                    border: 1, 
                    borderColor: 'grey.300', 
                    borderRadius: 1,
                    minHeight: 56,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center'
                  }}
                >
                  {formData.icon || '📋'}
                </Box>
              </Grid>

              <Grid item xs={12}>
                <Box sx={{ mb: 2 }}>
                  <Typography variant="body2" color="text.secondary" gutterBottom>
                    Suggested icons:
                  </Typography>
                  <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                    {iconSuggestions.map((icon) => (
                      <Button
                        key={icon}
                        onClick={() => setFormData({ ...formData, icon })}
                        sx={{ 
                          minWidth: 'auto', 
                          p: 1, 
                          fontSize: '1.2rem',
                          border: formData.icon === icon ? 2 : 1,
                          borderColor: formData.icon === icon ? 'primary.main' : 'grey.300'
                        }}
                      >
                        {icon}
                      </Button>
                    ))}
                  </Box>
                </Box>
              </Grid>

              <Grid item xs={12}>
                <TextField
                  fullWidth
                  type="number"
                  label="Display Order"
                  value={formData.display_order}
                  onChange={(e) => setFormData({ ...formData, display_order: parseInt(e.target.value) })}
                  inputProps={{ min: 0 }}
                />
              </Grid>

              {/* Preview mapped modules for the entered name */}
              <Grid item xs={12}>
                <Typography variant="subtitle2" gutterBottom>Mapped Modules</Typography>
                <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                  {getModulesForBusinessTypeDynamic({name: formData.name}).map((m) => (
                    <Chip
                      key={m.id}
                      label={m.name}
                      size="small"
                      sx={{ backgroundColor: m.color, color: '#fff' }}
                    />
                  ))}
                  {getModulesForBusinessTypeDynamic({name: formData.name}).length === 0 && (
                    <Typography variant="caption" color="text.secondary">No mapped modules</Typography>
                  )}
                </Box>
              </Grid>

              {/* Capabilities preview */}
              <Grid item xs={12}>
                <Typography variant="subtitle2" gutterBottom>Capabilities</Typography>
                {(() => {
                  const cap = getCapabilitiesForBusinessTypeDynamic({name: formData.name});
                  const chips = [];
                  if (cap.managePrices) chips.push(<Chip key="cap-prices" label="Manage Prices" size="small" color="secondary" />);
                  if (cap.respondItem) chips.push(<Chip key="cap-item" label="Respond Item" size="small" />);
                  if (cap.respondService) chips.push(<Chip key="cap-service" label="Respond Service" size="small" />);
                  if (cap.respondRent) chips.push(<Chip key="cap-rent" label="Respond Rent" size="small" />);
                  if (cap.respondDelivery) chips.push(<Chip key="cap-respond-delivery" label="Respond Delivery" size="small" color="success" />);
                  if (cap.respondRide) chips.push(<Chip key="cap-respond-ride" label="Respond Ride" size="small" color="warning" />);
                  if (cap.respondTours) chips.push(<Chip key="cap-tours" label="Respond Tours" size="small" />);
                  if (cap.respondEvents) chips.push(<Chip key="cap-events" label="Respond Events" size="small" />);
                  if (cap.respondConstruction) chips.push(<Chip key="cap-construction" label="Respond Construction" size="small" />);
                  if (cap.respondEducation) chips.push(<Chip key="cap-education" label="Respond Education" size="small" />);
                  if (cap.respondHiring) chips.push(<Chip key="cap-hiring" label="Respond Job" size="small" />);
                  // no general 'Respond Common' chip; show granular modules only
                  return (
                    <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                      {chips.length ? chips : <Typography variant="caption" color="text.secondary">No capabilities</Typography>}
                    </Box>
                  );
                })()}
              </Grid>
            </Grid>
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setIsDialogOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" variant="contained">
              {editingType ? 'Update' : 'Create'}
            </Button>
          </DialogActions>
        </form>
      </Dialog>

      {/* Snackbar for notifications */}
      <Snackbar
        open={snackbar.open}
        autoHideDuration={6000}
        onClose={() => setSnackbar({ ...snackbar, open: false })}
      >
        <Alert 
          onClose={() => setSnackbar({ ...snackbar, open: false })} 
          severity={snackbar.severity}
          variant="filled"
        >
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Container>
  );
};

export default CountryBusinessTypesManagement;
