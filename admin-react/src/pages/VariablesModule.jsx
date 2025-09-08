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
  Chip,
  IconButton,
  Button,
  Grid,
  Card,
  CardContent,
  TextField,
  InputAdornment,
  Menu,
  MenuItem,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Alert,
  CircularProgress,
  Tooltip,
  Fab,
  FormControl,
  InputLabel,
  Select,
  Snackbar,
  Checkbox,
  FormControlLabel
} from '@mui/material';
import {
  Search,
  Visibility,
  Edit,
  Delete,
  FilterList,
  Refresh,
  Add,
  Tune,
  Category,
  DataObject,
  ToggleOn,
  ToggleOff
} from '@mui/icons-material';
// Migrated from Firestore to REST API
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter.jsx';

const VariablesModule = () => {
  const {
    getFilteredData,
    adminData,
    isSuperAdmin,
    getCountryDisplayName,
    userCountry
  } = useCountryFilter();

  const [variables, setVariables] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterAnchorEl, setFilterAnchorEl] = useState(null);
  const [selectedType, setSelectedType] = useState('all');
  const [selectedVariable, setSelectedVariable] = useState(null);
  const [viewDialogOpen, setViewDialogOpen] = useState(false);
  const [editDialogOpen, setEditDialogOpen] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    type: 'text',
    unit: '',
    isRequired: false,
    possibleValues: []
  });
  const [snackbar, setSnackbar] = useState({
    open: false,
    message: '',
    severity: 'success'
  });
  const [operationLoading, setOperationLoading] = useState(false);

  const typeColors = {
    text: 'primary',
    number: 'secondary',
    boolean: 'success',
    select: 'info',
    multiselect: 'warning',
    date: 'error'
  };

  const loadVariables = async () => {
    try {
      setLoading(true);
      setError(null);

      const data = await getFilteredData('custom_product_variables', adminData);
      setVariables(data || []);
      
      console.log(`📊 Loaded ${data?.length || 0} variables for ${isSuperAdmin ? 'super admin' : `country admin (${userCountry})`}`);
    } catch (err) {
      console.error('Error loading variables:', err);
      setError('Failed to load variables: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadVariables();
  }, [adminData]);

  const handleViewVariable = (variable) => {
    setSelectedVariable(variable);
    setViewDialogOpen(true);
  };

  const handleAddVariable = () => {
    setSelectedVariable(null);
    setFormData({
      name: '',
      description: '',
      type: 'text',
      unit: '',
      isRequired: false,
      possibleValues: []
    });
    setEditDialogOpen(true);
  };

  const handleEditVariable = (variable) => {
    setSelectedVariable(variable);
    setFormData({
      name: variable.name || '',
      description: variable.description || '',
      type: variable.type || 'text',
      unit: variable.unit || '',
      isRequired: variable.isRequired || false,
      possibleValues: variable.possibleValues || []
    });
    setEditDialogOpen(true);
  };

  const handleDeleteVariable = (variable) => {
    setSelectedVariable(variable);
    setDeleteDialogOpen(true);
  };

  const handleSaveVariable = async () => {
    try {
      setOperationLoading(true);
      
      const payload = {
        name: formData.name,
        description: formData.description,
        type: formData.type,
        unit: formData.unit,
        isRequired: formData.isRequired,
        possibleValues: formData.possibleValues,
        isActive: true,
        usageCount: selectedVariable?.usageCount || 0,
        updatedBy: adminData?.email || 'admin'
      };

      if (selectedVariable) {
        await api.put(`/custom-product-variables/${selectedVariable.id}`, payload);
        setSnackbar({ open: true, message: 'Variable updated successfully!', severity: 'success' });
      } else {
        await api.post('/custom-product-variables', { ...payload, createdBy: adminData?.email || 'admin' });
        setSnackbar({ open: true, message: 'Variable added successfully!', severity: 'success' });
      }

      setEditDialogOpen(false);
      loadVariables();
    } catch (error) {
      console.error('Error saving variable:', error);
      setSnackbar({
        open: true,
        message: 'Error saving variable: ' + error.message,
        severity: 'error'
      });
    } finally {
      setOperationLoading(false);
    }
  };

  const handleDeleteConfirm = async () => {
    try {
      setOperationLoading(true);
      
  await api.delete(`/custom-product-variables/${selectedVariable.id}`);
      setSnackbar({
        open: true,
        message: 'Variable deleted successfully!',
        severity: 'success'
      });
      setDeleteDialogOpen(false);
      loadVariables();
    } catch (error) {
      console.error('Error deleting variable:', error);
      setSnackbar({
        open: true,
        message: 'Error deleting variable: ' + error.message,
        severity: 'error'
      });
    } finally {
      setOperationLoading(false);
    }
  };

  const handleTypeFilter = (type) => {
    setSelectedType(type);
    setFilterAnchorEl(null);
  };

  const filteredVariables = variables.filter(variable => {
    const matchesSearch = !searchTerm || 
                         variable.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         variable.label?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         variable.category?.toLowerCase().includes(searchTerm.toLowerCase());

    const matchesType = selectedType === 'all' || variable.type === selectedType;

    return matchesSearch && matchesType;
  });

  // Calculate stats
  const totalVariables = variables.length;
  const activeVariables = variables.filter(v => v.isActive !== false).length;
  const inactiveVariables = totalVariables - activeVariables;

  const stats = [
    { label: 'Total Variables', value: totalVariables, color: 'primary' },
    { label: 'Active', value: activeVariables, color: 'success' },
    { label: 'Inactive', value: inactiveVariables, color: 'error' },
    { label: 'Types', value: [...new Set(variables.map(v => v.type))].length, color: 'info' }
  ];

  const uniqueTypes = [...new Set(variables.map(v => v.type).filter(Boolean))];

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box>
      {/* Header */}
      <Box mb={3}>
        <Typography variant="h4" component="h1" gutterBottom>
          Variables Management
        </Typography>
        <Typography variant="body1" color="text.secondary">
          {isSuperAdmin ? 'Manage all variable types across countries' : `Manage variables in ${getCountryDisplayName(userCountry)}`}
        </Typography>
      </Box>

      {/* Error Alert */}
      {error && (
        <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {/* Stats Cards */}
      <Grid container spacing={3} mb={3}>
        {stats.map((stat, index) => (
          <Grid item xs={12} sm={6} md={3} key={index}>
            <Card>
              <CardContent sx={{ textAlign: 'center' }}>
                <Typography variant="h3" color={`${stat.color}.main`} gutterBottom>
                  {stat.value}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  {stat.label}
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>

      {/* Controls */}
      <Paper sx={{ p: 2, mb: 3 }}>
        <Box display="flex" gap={2} alignItems="center" flexWrap="wrap">
          <TextField
            size="small"
            placeholder="Search variables..."
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
            startIcon={<FilterList />}
            onClick={(e) => setFilterAnchorEl(e.currentTarget)}
            color={selectedType !== 'all' ? 'primary' : 'inherit'}
          >
            FILTERS ({selectedType !== 'all' ? '1' : 'NONE'})
          </Button>
          
          <Button
            startIcon={<Refresh />}
            onClick={loadVariables}
          >
            REFRESH
          </Button>

          {isSuperAdmin && (
            <Button
              variant="contained"
              startIcon={<Add />}
              onClick={handleAddVariable}
              sx={{ ml: 'auto' }}
            >
              Add Variable
            </Button>
          )}
        </Box>
      </Paper>

      {/* Filter Menu */}
      <Menu
        anchorEl={filterAnchorEl}
        open={Boolean(filterAnchorEl)}
        onClose={() => setFilterAnchorEl(null)}
      >
        <MenuItem onClick={() => handleTypeFilter('all')}>
          <Typography variant="body2">All Types</Typography>
        </MenuItem>
        {uniqueTypes.map(type => (
          <MenuItem key={type} onClick={() => handleTypeFilter(type)}>
            <Typography variant="body2" sx={{ textTransform: 'capitalize' }}>
              {type}
            </Typography>
          </MenuItem>
        ))}
      </Menu>

      {/* Variables Table */}
      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Name</TableCell>
              <TableCell>Label</TableCell>
              <TableCell>Type</TableCell>
              <TableCell>Category</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Created</TableCell>
              <TableCell>Country</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredVariables.map((variable) => (
              <TableRow key={variable.id} hover>
                <TableCell>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <DataObject fontSize="small" color="action" />
                    <Typography variant="body2" fontWeight="medium">
                      {variable.name || 'Unnamed Variable'}
                    </Typography>
                  </Box>
                </TableCell>
                <TableCell>
                  <Typography variant="body2">
                    {Array.isArray(variable.values) && variable.values.length > 0
                      ? variable.values.join(', ')
                      : (Array.isArray(variable.possibleValues) && variable.possibleValues.length > 0
                          ? variable.possibleValues.join(', ')
                          : (variable.label || 'No Values'))}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Chip
                    label={variable.type || 'Unknown'}
                    color={typeColors[variable.type] || 'default'}
                    size="small"
                    sx={{ textTransform: 'capitalize' }}
                  />
                </TableCell>
                <TableCell>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Category fontSize="small" color="action" />
                    <Typography variant="body2">
                      {variable.category || 'Uncategorized'}
                    </Typography>
                  </Box>
                </TableCell>
                <TableCell>
                  {variable.isActive !== false ? (
                    <Chip icon={<ToggleOn />} label="Active" color="success" size="small" />
                  ) : (
                    <Chip icon={<ToggleOff />} label="Inactive" color="error" size="small" />
                  )}
                </TableCell>
                <TableCell>
                  <Typography variant="body2" color="text.secondary">
                    {variable.createdAt ? new Date(variable.createdAt.toDate ? variable.createdAt.toDate() : variable.createdAt).toLocaleDateString() : 'N/A'}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Chip label={variable.country || userCountry || 'N/A'} size="small" variant="outlined" />
                </TableCell>
                <TableCell>
                  <Box display="flex" gap={1}>
                    <Tooltip title="View Details">
                      <IconButton 
                        size="small" 
                        onClick={() => handleViewVariable(variable)}
                      >
                        <Visibility />
                      </IconButton>
                    </Tooltip>
                    {isSuperAdmin && (
                      <>
                        <Tooltip title="Edit">
                          <IconButton 
                            size="small" 
                            color="primary"
                            onClick={() => handleEditVariable(variable)}
                          >
                            <Edit />
                          </IconButton>
                        </Tooltip>
                        <Tooltip title="Delete">
                          <IconButton 
                            size="small" 
                            color="error"
                            onClick={() => handleDeleteVariable(variable)}
                          >
                            <Delete />
                          </IconButton>
                        </Tooltip>
                      </>
                    )}
                  </Box>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>

        {filteredVariables.length === 0 && (
          <Box p={4} textAlign="center">
            <Typography variant="body1" color="text.secondary">
              {variables.length === 0 ? 'No variables found' : 'No variables match your current filters'}
            </Typography>
          </Box>
        )}
      </TableContainer>

      {/* View Dialog */}
      <Dialog
        open={viewDialogOpen}
        onClose={() => setViewDialogOpen(false)}
        maxWidth="md"
        fullWidth
      >
        {selectedVariable && (
          <>
            <DialogTitle>
              Variable Details: {selectedVariable.name}
            </DialogTitle>
            <DialogContent>
              <Grid container spacing={2}>
                <Grid item xs={12} md={6}>
                  <Typography variant="body2" color="text.secondary">Name</Typography>
                  <Typography variant="body1" gutterBottom>{selectedVariable.name || 'N/A'}</Typography>
                </Grid>
                <Grid item xs={12} md={6}>
                  <Typography variant="body2" color="text.secondary">Label</Typography>
                  <Typography variant="body1" gutterBottom>{selectedVariable.label || 'N/A'}</Typography>
                </Grid>
                <Grid item xs={12} md={6}>
                  <Typography variant="body2" color="text.secondary">Type</Typography>
                  <Typography variant="body1" gutterBottom sx={{ textTransform: 'capitalize' }}>{selectedVariable.type || 'N/A'}</Typography>
                </Grid>
                <Grid item xs={12} md={6}>
                  <Typography variant="body2" color="text.secondary">Category</Typography>
                  <Typography variant="body1" gutterBottom>{selectedVariable.category || 'N/A'}</Typography>
                </Grid>
                {selectedVariable.options && (
                  <Grid item xs={12}>
                    <Typography variant="body2" color="text.secondary">Options</Typography>
                    <Typography variant="body1" gutterBottom>
                      {Array.isArray(selectedVariable.options) 
                        ? selectedVariable.options.join(', ') 
                        : JSON.stringify(selectedVariable.options)
                      }
                    </Typography>
                  </Grid>
                )}
                <Grid item xs={12}>
                  <Typography variant="body2" color="text.secondary">Description</Typography>
                  <Typography variant="body1" gutterBottom>
                    {selectedVariable.description || 'No description provided'}
                  </Typography>
                </Grid>
              </Grid>
            </DialogContent>
            <DialogActions>
              <Button onClick={() => setViewDialogOpen(false)}>Close</Button>
              {isSuperAdmin && (
                <Button variant="contained" color="primary" onClick={() => {
                  setViewDialogOpen(false);
                  handleEditVariable(selectedVariable);
                }}>
                  Edit Variable
                </Button>
              )}
            </DialogActions>
          </>
        )}
      </Dialog>

      {/* Edit/Add Dialog */}
      <Dialog
        open={editDialogOpen}
        onClose={() => setEditDialogOpen(false)}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>
          {selectedVariable ? 'Edit Variable' : 'Add Variable'}
        </DialogTitle>
        <DialogContent>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 2 }}>
            <TextField
              label="Variable Name"
              fullWidth
              value={formData.name}
              onChange={(e) => setFormData({...formData, name: e.target.value})}
              required
            />
            
            <TextField
              label="Description"
              fullWidth
              multiline
              rows={3}
              value={formData.description}
              onChange={(e) => setFormData({...formData, description: e.target.value})}
            />
            
            <FormControl fullWidth required>
              <InputLabel>Variable Type</InputLabel>
              <Select
                value={formData.type}
                label="Variable Type"
                onChange={(e) => setFormData({...formData, type: e.target.value})}
              >
                <MenuItem value="text">Text</MenuItem>
                <MenuItem value="number">Number</MenuItem>
                <MenuItem value="boolean">Boolean</MenuItem>
                <MenuItem value="select">Select</MenuItem>
                <MenuItem value="multiselect">Multi-select</MenuItem>
                <MenuItem value="date">Date</MenuItem>
              </Select>
            </FormControl>

            <TextField
              label="Unit (Optional)"
              fullWidth
              value={formData.unit}
              onChange={(e) => setFormData({...formData, unit: e.target.value})}
              placeholder="e.g., GB, inches, kg"
            />

            {(formData.type === 'select' || formData.type === 'multiselect') && (
              <TextField
                label="Possible Values (comma-separated)"
                fullWidth
                multiline
                rows={2}
                value={formData.possibleValues.join(', ')}
                onChange={(e) => setFormData({
                  ...formData, 
                  possibleValues: e.target.value.split(',').map(v => v.trim()).filter(v => v)
                })}
                placeholder="Option 1, Option 2, Option 3"
              />
            )}

            <FormControlLabel
              control={
                <Checkbox
                  checked={formData.isRequired}
                  onChange={(e) => setFormData({...formData, isRequired: e.target.checked})}
                />
              }
              label="Required Field"
            />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setEditDialogOpen(false)}>Cancel</Button>
          <Button 
            variant="contained" 
            onClick={handleSaveVariable}
            disabled={!formData.name || operationLoading}
          >
            {operationLoading ? <CircularProgress size={20} /> : (selectedVariable ? 'Update' : 'Add')}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog
        open={deleteDialogOpen}
        onClose={() => setDeleteDialogOpen(false)}
        maxWidth="sm"
      >
        <DialogTitle>Delete Variable</DialogTitle>
        <DialogContent>
          {selectedVariable && (
            <Alert severity="warning" sx={{ mb: 2 }}>
              Are you sure you want to delete "{selectedVariable.name}"?
              This action cannot be undone.
            </Alert>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDeleteDialogOpen(false)}>Cancel</Button>
          <Button 
            color="error" 
            variant="contained"
            onClick={handleDeleteConfirm}
            disabled={operationLoading}
          >
            {operationLoading ? <CircularProgress size={20} /> : 'Delete'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Snackbar for notifications */}
      <Snackbar
        open={snackbar.open}
        autoHideDuration={6000}
        onClose={() => setSnackbar({...snackbar, open: false})}
      >
        <Alert 
          onClose={() => setSnackbar({...snackbar, open: false})} 
          severity={snackbar.severity}
          sx={{ width: '100%' }}
        >
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default VariablesModule;
