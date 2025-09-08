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
  Avatar
} from '@mui/material';
import {
  Add,
  Edit,
  Delete,
  Business,
  Search
} from '@mui/icons-material';
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter';

const Brands = () => {
  const { getFilteredData, adminData, isSuperAdmin, userCountry } = useCountryFilter();
  const [brands, setBrands] = useState([]);
  const [filteredBrands, setFilteredBrands] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openDialog, setOpenDialog] = useState(false);
  const [editingBrand, setEditingBrand] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    website: '',
    logoUrl: '',
    isActive: true
  });

  useEffect(() => {
    loadBrands();
  }, []);

  useEffect(() => {
    filterBrands();
  }, [brands, searchTerm]);

    const loadBrands = async () => {
    try {
      setLoading(true);
      const data = await getFilteredData('brands', adminData);
      const brandsData = data || [];
      setBrands(brandsData);
    } catch (error) {
      console.error('Error loading brands:', error);
    } finally {
      setLoading(false);
    }
  };

  const filterBrands = () => {
    let filtered = brands;

    if (searchTerm) {
      filtered = filtered.filter(brand =>
        brand.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        brand.description?.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    setFilteredBrands(filtered);
  };

  const handleOpenDialog = (brand = null) => {
    if (brand) {
      setEditingBrand(brand.id);
      setFormData({
        name: brand.name || '',
        description: brand.description || '',
        website: brand.website || '',
        logoUrl: brand.logoUrl || '',
        isActive: brand.isActive !== false
      });
    } else {
      setEditingBrand(null);
      setFormData({
        name: '',
        description: '',
        website: '',
        logoUrl: '',
        isActive: true
      });
    }
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setEditingBrand(null);
  };

  const handleSave = async () => {
    try {
      const brandPayload = {
        ...formData,
        updatedBy: adminData?.email
      };

      if (editingBrand) {
        await api.put(`/brands/${editingBrand}`, brandPayload);
        console.log('Brand updated successfully');
      } else {
        await api.post('/brands', {
          ...brandPayload,
          createdBy: adminData?.email
        });
        console.log('Brand created successfully');
      }

      handleCloseDialog();
      loadBrands();
    } catch (error) {
      console.error('Error saving brand:', error);
      alert('Error saving brand: ' + (error.response?.data?.message || error.message));
    }
  };

  const handleDelete = async (brandId, brandName) => {
    if (window.confirm(`Are you sure you want to delete "${brandName}"?`)) {
      try {
        await api.delete(`/brands/${brandId}`);
        loadBrands();
      } catch (error) {
        console.error('Error deleting brand:', error);
        alert('Error deleting brand: ' + (error.response?.data?.message || error.message));
      }
    }
  };

  const toggleBrandStatus = async (brand) => {
    try {
      await api.put(`/brands/${brand.id}/status`, {
        isActive: !brand.isActive,
        updatedBy: adminData?.email
      });
      loadBrands();
    } catch (error) {
      console.error('Error updating brand status:', error);
      alert('Error updating status: ' + (error.response?.data?.message || error.message));
    }
  };

  if (loading) {
    return (
      <Box sx={{ p: 3 }}>
        <LinearProgress />
        <Typography sx={{ mt: 2 }}>Loading brands...</Typography>
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3 }}>
      {/* Header */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4" component="h1">
          Brand Management
        </Typography>
        <Button
          variant="contained"
          startIcon={<Add />}
          onClick={() => handleOpenDialog()}
        >
          Add Brand
        </Button>
      </Box>

      <Alert severity="info" sx={{ mb: 3 }}>
        <strong>Brand Management:</strong> Brands are used globally for product categorization.
        <br />
        • Brands help customers identify and filter products
        <br />
        • All brands are available to businesses worldwide when creating product listings
      </Alert>

      {/* Search */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                placeholder="Search brands..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                InputProps={{
                  startAdornment: <Search sx={{ mr: 1, color: 'text.secondary' }} />
                }}
              />
            </Grid>
            <Grid item xs={12} md={6}>
              <Typography variant="body2" color="text.secondary">
                {filteredBrands.length} brands found
              </Typography>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Brands Table */}
      <Card>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Logo</TableCell>
                <TableCell>Brand</TableCell>
                <TableCell>Website</TableCell>
                <TableCell>Status</TableCell>
                <TableCell>Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filteredBrands.map((brand) => (
                <TableRow key={brand.id}>
                  <TableCell>
                    <Avatar
                      src={brand.logoUrl}
                      variant="rounded"
                      sx={{ width: 40, height: 40 }}
                    >
                      <Business />
                    </Avatar>
                  </TableCell>
                  <TableCell>
                    <Box>
                      <Typography variant="subtitle2">{brand.name}</Typography>
                      {brand.description && (
                        <Typography variant="caption" color="text.secondary">
                          {brand.description}
                        </Typography>
                      )}
                    </Box>
                  </TableCell>
                  <TableCell>
                    {brand.website ? (
                      <a
                        href={brand.website}
                        target="_blank"
                        rel="noopener noreferrer"
                        style={{ textDecoration: 'none' }}
                      >
                        <Typography variant="body2" color="primary">
                          {brand.website}
                        </Typography>
                      </a>
                    ) : (
                      <Typography variant="body2" color="text.secondary">
                        No website
                      </Typography>
                    )}
                  </TableCell>
                  <TableCell>
                    <Switch
                      checked={brand.isActive !== false}
                      onChange={() => toggleBrandStatus(brand)}
                      size="small"
                    />
                    <Typography variant="caption" display="block">
                      {brand.isActive !== false ? 'Active' : 'Inactive'}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <IconButton onClick={() => handleOpenDialog(brand)} size="small">
                      <Edit />
                    </IconButton>
                    <IconButton 
                      onClick={() => handleDelete(brand.id, brand.name)} 
                      size="small" 
                      color="error"
                    >
                      <Delete />
                    </IconButton>
                  </TableCell>
                </TableRow>
              ))}
              {filteredBrands.length === 0 && (
                <TableRow>
                  <TableCell colSpan={5} align="center" sx={{ py: 4 }}>
                    <Typography color="text.secondary">
                      No brands found. {searchTerm ? 'Try adjusting your search.' : 'Create your first brand.'}
                    </Typography>
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Card>

      {/* Brand Dialog */}
      <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="sm" fullWidth>
        <DialogTitle>
          {editingBrand ? 'Edit Brand' : 'Create New Brand'}
        </DialogTitle>
        <DialogContent dividers>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <TextField
              fullWidth
              label="Brand Name"
              value={formData.name}
              onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
              required
            />
            
            <TextField
              fullWidth
              label="Description"
              multiline
              rows={2}
              value={formData.description}
              onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
            />
            
            <TextField
              fullWidth
              label="Website URL"
              value={formData.website}
              onChange={(e) => setFormData(prev => ({ ...prev, website: e.target.value }))}
              placeholder="https://example.com"
            />
            
            <TextField
              fullWidth
              label="Logo URL"
              value={formData.logoUrl}
              onChange={(e) => setFormData(prev => ({ ...prev, logoUrl: e.target.value }))}
              placeholder="https://example.com/logo.png"
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
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog}>Cancel</Button>
          <Button 
            onClick={handleSave} 
            variant="contained"
            disabled={!formData.name}
          >
            {editingBrand ? 'Update' : 'Create'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default Brands;
