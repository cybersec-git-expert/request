import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Button,
  Card,
  CardContent,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  IconButton,
  Chip,
  Alert,
  LinearProgress,
  Switch,
  FormControlLabel,
  Grid,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  List,
  ListItem,
  ListItemText,
  ListItemSecondaryAction
} from '@mui/material';
import {
  Add,
  Edit,
  Delete,
  Settings,
  Search,
  Close
} from '@mui/icons-material';
// Migrated off Firestore to REST API
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter';

const Variables = () => {
  const { getFilteredData, adminData, isSuperAdmin, userCountry } = useCountryFilter();
  const [variables, setVariables] = useState([]);
  const [filteredVariables, setFilteredVariables] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openDialog, setOpenDialog] = useState(false);
  const [editingVariable, setEditingVariable] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    type: 'text',
    unit: '',
    possibleValues: [],
    isRequired: false,
    isActive: true
  });
  const [newOption, setNewOption] = useState('');

  const variableTypes = [
    { value: 'text', label: 'Text Input (e.g., Model Number, Brand)' },
    { value: 'number', label: 'Number Input (e.g., Weight, Height, Width)' },
    { value: 'select', label: 'Dropdown Single Choice (e.g., Color, Size)' },
    { value: 'dropdown', label: 'Dropdown (Multiple Options)' },
    { value: 'multiselect', label: 'Multiple Selection (e.g., Features)' },
    { value: 'boolean', label: 'Yes/No Toggle (e.g., Waterproof, Wireless)' },
    { value: 'color', label: 'Color Picker' }
  ];

  useEffect(() => {
    loadData();
  }, []);

  useEffect(() => {
    filterVariables();
  }, [variables, searchTerm, categoryFilter]);

  const loadData = async () => {
    try {
      setLoading(true);
      
      // Load variables using country filter system
  const res = await api.get('/custom-product-variables');
  const variablesData = Array.isArray(res.data) ? res.data : res.data?.data || [];
      console.log('Loaded variables:', variablesData);
      setVariables(variablesData || []);
    } catch (error) {
      console.error('Error loading data:', error);
    } finally {
      setLoading(false);
    }
  };

  const filterVariables = () => {
    let filtered = variables;

    if (searchTerm) {
      filtered = filtered.filter(variable =>
        variable.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        variable.unit?.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    setFilteredVariables(filtered);
  };

  const handleOpenDialog = (variable = null) => {
    if (variable) {
      setEditingVariable(variable.id);
      setFormData({
        name: variable.name || '',
        type: variable.type || 'text',
        possibleValues: variable.possibleValues || variable.options || [],
        unit: variable.unit || '',
        isRequired: variable.isRequired || false,
        isActive: variable.isActive !== false
      });
    } else {
      setEditingVariable(null);
      setFormData({
        name: '',
        type: 'text',
        possibleValues: [],
        unit: '',
        isRequired: false,
        isActive: true
      });
    }
    setNewOption('');
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setEditingVariable(null);
    setNewOption('');
  };

  const addOption = () => {
    if (newOption.trim()) {
      setFormData(prev => ({
        ...prev,
        possibleValues: [...prev.possibleValues, newOption.trim()]
      }));
      setNewOption('');
    }
  };

  const removeOption = (index) => {
    setFormData(prev => ({
      ...prev,
      possibleValues: prev.possibleValues.filter((_, i) => i !== index)
    }));
  };

  const handleSave = async () => {
    try {
      const payload = {
        name: formData.name,
        type: formData.type,
        unit: formData.unit,
        possibleValues: formData.possibleValues,
        isRequired: formData.isRequired,
        isActive: formData.isActive,
        description: formData.description,
        updatedBy: adminData?.email
      };
      if (editingVariable) {
        await api.put(`/custom-product-variables/${editingVariable}`, payload);
      } else {
        await api.post('/custom-product-variables', { ...payload, createdBy: adminData?.email });
      }
      handleCloseDialog();
      await loadData();
    } catch (error) {
      console.error('Error saving variable:', error);
      alert('Error saving variable: ' + (error.response?.data?.message || error.message));
    }
  };

  const handleDelete = async (variableId, variableName) => {
    if (!window.confirm(`Are you sure you want to delete "${variableName}"?`)) return;
    try {
      await api.delete(`/custom-product-variables/${variableId}`);
      await loadData();
    } catch (error) {
      console.error('Error deleting variable:', error);
      alert('Error deleting variable: ' + (error.response?.data?.message || error.message));
    }
  };

  const toggleVariableStatus = async (variable) => {
    try {
      await api.put(`/custom-product-variables/${variable.id}/status`, { isActive: !variable.isActive });
      await loadData();
    } catch (error) {
      console.error('Error updating variable status:', error);
    }
  };

  if (loading) {
    return (
      <Box sx={{ p: 3 }}>
        <LinearProgress />
        <Typography sx={{ mt: 2 }}>Loading variables...</Typography>
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3 }}>
      {/* Header */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4" component="h1">
          Product Attributes
        </Typography>
        <Button
          variant="contained"
          startIcon={<Add />}
          onClick={() => handleOpenDialog()}
        >
          Add Attribute
        </Button>
      </Box>

      <Alert severity="info" sx={{ mb: 3 }}>
        <strong>Product Attributes:</strong> Define characteristics that customers can select when viewing products.
        <br />
        • <strong>Examples:</strong> Color (Black, White, Red), Size (S, M, L, XL), Storage (64GB, 128GB, 256GB), Screen Size (5.5", 6.1", 6.7")
        <br />
        • <strong>Types:</strong> Dropdown (multiple options), Text (free input), Number (numeric values), Boolean (yes/no)
        <br />
        • Product attributes are available for all categories and can be used by any product type
      </Alert>

      {/* Filters */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={12} md={4}>
              <TextField
                fullWidth
                placeholder="Search attributes..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                InputProps={{
                  startAdornment: <Search sx={{ mr: 1, color: 'text.secondary' }} />
                }}
              />
            </Grid>
            <Grid item xs={12} md={8}>
              <Typography variant="body2" color="text.secondary">
                {filteredVariables.length} attributes found
              </Typography>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Variables Table */}
      <Card>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Attribute</TableCell>
                <TableCell>Type</TableCell>
                <TableCell>Required</TableCell>
                <TableCell>Status</TableCell>
                <TableCell>Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filteredVariables.map((variable) => (
                <TableRow key={variable.id}>
                  <TableCell>
                    <Box>
                      <Typography variant="subtitle2">{variable.name}</Typography>
                      {variable.unit && (
                        <Typography variant="caption" color="text.secondary">
                          Unit: {variable.unit}
                        </Typography>
                      )}
                      {(variable.options || variable.possibleValues) && (variable.options || variable.possibleValues).length > 0 && (
                        <Typography variant="caption" color="text.secondary" display="block">
                          Options: {(variable.options || variable.possibleValues).slice(0, 3).join(', ')}
                          {(variable.options || variable.possibleValues).length > 3 && ` (+${(variable.options || variable.possibleValues).length - 3} more)`}
                        </Typography>
                      )}
                    </Box>
                  </TableCell>
                  <TableCell>
                    <Chip
                      label={variableTypes.find(t => t.value === variable.type)?.label || variable.type}
                      size="small"
                      color="primary"
                      variant="outlined"
                    />
                  </TableCell>
                  <TableCell>
                    <Chip
                      label={variable.isRequired ? 'Required' : 'Optional'}
                      size="small"
                      color={variable.isRequired ? 'warning' : 'default'}
                    />
                  </TableCell>
                  <TableCell>
                    <Switch
                      checked={variable.isActive !== false}
                      onChange={() => toggleVariableStatus(variable)}
                      size="small"
                    />
                    <Typography variant="caption" display="block">
                      {variable.isActive !== false ? 'Active' : 'Inactive'}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <IconButton onClick={() => handleOpenDialog(variable)} size="small">
                      <Edit />
                    </IconButton>
                    <IconButton 
                      onClick={() => handleDelete(variable.id, variable.name)} 
                      size="small" 
                      color="error"
                    >
                      <Delete />
                    </IconButton>
                  </TableCell>
                </TableRow>
              ))}
              {filteredVariables.length === 0 && (
                <TableRow>
                  <TableCell colSpan={6} align="center" sx={{ py: 4 }}>
                    <Typography color="text.secondary">
                      No variables found. {searchTerm || categoryFilter ? 'Try adjusting your filters.' : 'Create your first variable.'}
                    </Typography>
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Card>

      {/* Variable Dialog */}
      <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="md" fullWidth>
        <DialogTitle>
          {editingVariable ? 'Edit Attribute' : 'Create New Attribute'}
        </DialogTitle>
        <DialogContent dividers>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
            {/* Basic Information */}
            <Grid container spacing={2}>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Attribute Name"
                  value={formData.name}
                  onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
                  required
                  placeholder="e.g., Color, Size, Storage, Screen Size"
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <FormControl fullWidth required>
                  <InputLabel>Attribute Type</InputLabel>
                  <Select
                    value={formData.type}
                    onChange={(e) => setFormData(prev => ({ ...prev, type: e.target.value }))}
                  >
                    {variableTypes.map(type => (
                      <MenuItem key={type.value} value={type.value}>
                        {type.label}
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              </Grid>
            </Grid>

            {/* Description */}
            <TextField
              fullWidth
              label="Description"
              value={formData.description}
              onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
              multiline
              rows={2}
              placeholder="e.g., Available colors for this product, Different storage capacities, Screen size options"
            />

            {/* Unit */}
            <TextField
              fullWidth
              label="Unit (optional)"
              value={formData.unit}
              onChange={(e) => setFormData(prev => ({ ...prev, unit: e.target.value }))}
              placeholder="kg, cm, inches, etc."
            />

            {/* Options for select types */}
            {(formData.type === 'select' || formData.type === 'multiselect') && (
              <Box>
                <Typography variant="subtitle2" gutterBottom>
                  Options
                </Typography>
                <Grid container spacing={1} alignItems="center">
                  <Grid item xs={10}>
                    <TextField
                      fullWidth
                      size="small"
                      placeholder="Add option..."
                      value={newOption}
                      onChange={(e) => setNewOption(e.target.value)}
                      onKeyPress={(e) => e.key === 'Enter' && addOption()}
                    />
                  </Grid>
                  <Grid item xs={2}>
                    <Button fullWidth onClick={addOption} disabled={!newOption.trim()}>
                      Add
                    </Button>
                  </Grid>
                </Grid>
                
                {formData.possibleValues.length > 0 && (
                  <List dense sx={{ mt: 1, maxHeight: 200, overflow: 'auto' }}>
                    {formData.possibleValues.map((option, index) => (
                      <ListItem key={index}>
                        <ListItemText primary={option} />
                        <ListItemSecondaryAction>
                          <IconButton size="small" onClick={() => removeOption(index)}>
                            <Close fontSize="small" />
                          </IconButton>
                        </ListItemSecondaryAction>
                      </ListItem>
                    ))}
                  </List>
                )}
              </Box>
            )}

            {/* Settings */}
            <Box>
              <FormControlLabel
                control={
                  <Switch
                    checked={formData.isRequired}
                    onChange={(e) => setFormData(prev => ({ ...prev, isRequired: e.target.checked }))}
                  />
                }
                label="Required field (businesses must fill this)"
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
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog}>Cancel</Button>
          <Button 
            onClick={handleSave} 
            variant="contained"
            disabled={!formData.name || !formData.type}
          >
            {editingVariable ? 'Update' : 'Create'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default Variables;
