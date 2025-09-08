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
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  Alert,
  Snackbar
} from '@mui/material';
import {
  Delete as DeleteIcon,
  Edit as EditIcon,
  Add as AddIcon,
  Visibility as VisibilityIcon,
  VisibilityOff as VisibilityOffIcon,
  ContentCopy as CopyIcon
} from '@mui/icons-material';
import api from '../services/apiClient';
// TODO: Expose and edit per-country capability toggles via a dedicated UI; global templates may later include default caps.
import { getModulesForBusinessType, getCapabilitiesForBusinessType } from '../constants/businessModules';

const GlobalBusinessTypesManagement = () => {
  const [businessTypes, setBusinessTypes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingType, setEditingType] = useState(null);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
  const [migrationStatus, setMigrationStatus] = useState(null);
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    icon: '',
    display_order: 0,
    is_active: true
  });

  // Common business type icons
  const iconSuggestions = [
    '🛍️', '🔧', '🏠', '🍽️', '🚚', '🏢', '💼', '🏪', '🎯', '🌟',
    '💻', '📱', '🏥', '🎓', '🚗', '✈️', '🏭', '🎨', '📚', '🎵'
  ];

  useEffect(() => {
    checkMigrationStatus();
    fetchGlobalBusinessTypes();
  }, []);

  const checkMigrationStatus = async () => {
    try {
      const { data } = await api.get('/business-types/migration-status');
      if (data?.success) setMigrationStatus(data.data);
    } catch (error) {
      console.error('Error checking migration status:', error);
    }
  };

  const fetchGlobalBusinessTypes = async () => {
    try {
      setLoading(true);
      const { data } = await api.get('/business-types/global');
      if (data?.success) {
        setBusinessTypes(data.data || []);
      } else {
        setSnackbar({ open: true, message: data?.message || 'Failed to fetch global business types', severity: 'error' });
      }
    } catch (error) {
      console.error('Error fetching global business types:', error);
      let errorMessage = 'Failed to fetch global business types';
      
      if (error?.message?.includes('non-JSON response')) {
        errorMessage = 'Server error: Please check if the database migration has been run. The system may need to be updated to support global business types.';
      }
      
      setSnackbar({ 
        open: true, 
        message: errorMessage, 
        severity: 'error' 
      });
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    try {
      const url = editingType 
        ? `/business-types/global/${editingType.id}`
        : '/business-types/global';
      const { data } = editingType
        ? await api.put(url, formData)
        : await api.post(url, formData);
      
      if (data?.success) {
        setSnackbar({ 
          open: true, 
          message: editingType ? 'Global business type updated successfully' : 'Global business type created successfully', 
          severity: 'success' 
        });
        setIsDialogOpen(false);
        setEditingType(null);
        resetForm();
        fetchGlobalBusinessTypes();
      } else {
        setSnackbar({ open: true, message: data?.message || 'Operation failed', severity: 'error' });
      }
    } catch (error) {
      console.error('Error saving global business type:', error);
      setSnackbar({ open: true, message: 'Failed to save global business type', severity: 'error' });
    }
  };

  const handleEdit = (businessType) => {
    setEditingType(businessType);
    setFormData({
      name: businessType.name,
      description: businessType.description || '',
      icon: businessType.icon || '',
      display_order: businessType.display_order || 0,
      is_active: businessType.is_active
    });
    setIsDialogOpen(true);
  };

  const handleDelete = async (id) => {
    if (!confirm('Are you sure you want to delete this global business type? This will affect all countries.')) {
      return;
    }

    try {
      const { data } = await api.delete(`/business-types/global/${id}`);
      
      if (data?.success) {
        setSnackbar({ open: true, message: 'Global business type deleted successfully', severity: 'success' });
        fetchGlobalBusinessTypes();
      } else {
        setSnackbar({ open: true, message: data?.message || 'Failed to delete global business type', severity: 'error' });
      }
    } catch (error) {
      console.error('Error deleting global business type:', error);
      setSnackbar({ open: true, message: 'Failed to delete global business type', severity: 'error' });
    }
  };

  const toggleStatus = async (id, currentStatus) => {
    try {
      const { data } = await api.put(`/business-types/global/${id}`, {
        is_active: !currentStatus
      });
      
      if (data?.success) {
        setSnackbar({ open: true, message: 'Global business type status updated successfully', severity: 'success' });
        fetchGlobalBusinessTypes();
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
      is_active: true
    });
  };

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Box>
          <Typography variant="h4" component="h1" gutterBottom>
            Global Business Types Management
          </Typography>
          <Typography variant="body1" color="text.secondary">
            Manage global business types that countries can use as templates
          </Typography>
          <Alert severity="info" sx={{ mt: 2 }}>
            <Typography variant="body2">
              <strong>Super Admin Only:</strong> These global business types serve as templates that country admins can adopt and customize for their regions.
            </Typography>
          </Alert>
          
          {migrationStatus && migrationStatus.needsMigration && (
            <Alert severity="warning" sx={{ mt: 1 }}>
              <Typography variant="body2">
                <strong>Migration Required:</strong> The database needs to be updated to support the new global business types system. 
                Please run the migration script: <code>node {migrationStatus.migrationFile}</code>
              </Typography>
            </Alert>
          )}
        </Box>
        
        <Button
          variant="contained"
          startIcon={<AddIcon />}
          onClick={() => setIsDialogOpen(true)}
        >
          Add Global Business Type
        </Button>
      </Box>

      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Global Business Types Templates
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
                    <TableCell>Usage</TableCell>
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
                        <Chip 
                          label={`${type.country_usage || 0} countries`}
                          color="primary"
                          size="small"
                          variant="outlined"
                        />
                      </TableCell>
                      <TableCell>
                        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                          {getModulesForBusinessType(type.name).map((m) => (
                            <Chip
                              key={m.id}
                              label={m.name}
                              size="small"
                              sx={{ backgroundColor: m.color, color: '#fff' }}
                            />
                          ))}
                          {getModulesForBusinessType(type.name).length === 0 && (
                            <Typography variant="caption" color="text.secondary">No mapped modules</Typography>
                          )}
                        </Box>
                      </TableCell>
                      <TableCell>
                        {(() => {
                          const cap = getCapabilitiesForBusinessType(type.name);
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
                          return (
                            <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                              {chips.length ? chips : <Typography variant="caption" color="text.secondary">No capabilities</Typography>}
                            </Box>
                          );
                        })()}
                      </TableCell>
                      <TableCell>
                        <Box sx={{ display: 'flex', gap: 1 }}>
                          <IconButton
                            size="small"
                            onClick={() => toggleStatus(type.id, type.is_active)}
                            color={type.is_active ? 'warning' : 'success'}
                          >
                            {type.is_active ? <VisibilityOffIcon /> : <VisibilityIcon />}
                          </IconButton>
                          <IconButton
                            size="small"
                            onClick={() => handleEdit(type)}
                            color="primary"
                          >
                            <EditIcon />
                          </IconButton>
                          <IconButton
                            size="small"
                            onClick={() => handleDelete(type.id)}
                            color="error"
                          >
                            <DeleteIcon />
                          </IconButton>
                        </Box>
                      </TableCell>
                    </TableRow>
                  ))}
          {businessTypes.length === 0 && (
                    <TableRow>
                      <TableCell colSpan={9} sx={{ textAlign: 'center', py: 4 }}>
                        <Typography color="text.secondary">
                          No global business types found
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
          {editingType ? 'Edit Global Business Type' : 'Add New Global Business Type'}
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
                  {getModulesForBusinessType(formData.name).map((m) => (
                    <Chip
                      key={m.id}
                      label={m.name}
                      size="small"
                      sx={{ backgroundColor: m.color, color: '#fff' }}
                    />
                  ))}
                  {getModulesForBusinessType(formData.name).length === 0 && (
                    <Typography variant="caption" color="text.secondary">No mapped modules</Typography>
                  )}
                </Box>
              </Grid>

              {/* Capabilities preview */}
              <Grid item xs={12}>
                <Typography variant="subtitle2" gutterBottom>Capabilities</Typography>
                {(() => {
                  const cap = getCapabilitiesForBusinessType(formData.name);
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

export default GlobalBusinessTypesManagement;
