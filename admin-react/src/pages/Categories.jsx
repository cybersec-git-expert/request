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
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Grid,
  Chip,
  Alert,
  LinearProgress,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  IconButton,
  Switch,
  FormControlLabel
} from '@mui/material';
import { 
  Add, 
  Edit, 
  Delete, 
  Category as CategoryIcon,
  ShoppingCart,
  Build
} from '@mui/icons-material';
// Migrated off Firebase: using REST API client
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter';

const Categories = () => {
  const { 
    adminData, 
    isSuperAdmin, 
    userCountry, 
    getCategories: getCountryFilteredCategories,
    getSubcategories: getCountryFilteredSubcategories,
    getCountryDisplayName,
    canEditData 
  } = useCountryFilter();
  
  const [categories, setCategories] = useState([]);
  const [subcategories, setSubcategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openDialog, setOpenDialog] = useState(false);
  const [openSubcategoryDialog, setOpenSubcategoryDialog] = useState(false);
  const [editingCategory, setEditingCategory] = useState(null);
  const [editingSubcategory, setEditingSubcategory] = useState(null);
  const [categoryFormData, setCategoryFormData] = useState({
    name: '',
    description: '',
    applicableFor: 'Item',
    isActive: true
  });
  const [subcategoryFormData, setSubcategoryFormData] = useState({
    name: '',
    description: '',
    categoryId: '',
    isActive: true
  });

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      await Promise.all([loadCategories(), loadSubcategories()]);
    } catch (error) {
      console.error('Error loading data:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadCategories = async () => {
    try {
      // Use country-filtered service
      const data = await getCountryFilteredCategories();
      const categoriesArray = Array.isArray(data) ? data : data?.data || [];
      setCategories(categoriesArray.sort((a, b) => (a.name || '').localeCompare(b.name || '')));
      console.log(`📂 Loaded ${categoriesArray.length} categories for ${getCountryDisplayName()}`);
    } catch (error) {
      console.error('Error loading categories:', error);
    }
  };

  const loadSubcategories = async () => {
    try {
      // Use country-filtered service
      const data = await getCountryFilteredSubcategories();
      const subcategoriesArray = Array.isArray(data) ? data : data?.data || [];
      setSubcategories(subcategoriesArray.sort((a, b) => (a.name || '').localeCompare(b.name || '')));
      console.log(`📁 Loaded ${subcategoriesArray.length} subcategories for ${getCountryDisplayName()}`);
    } catch (error) {
      console.error('Error loading subcategories:', error);
    }
  };

  const handleOpenCategoryDialog = (category = null) => {
    if (category) {
      setEditingCategory(category.id);
      setCategoryFormData({
        name: category.name || category.category || category.title || '',
        description: category.description || '',
        applicableFor: category.applicableFor || category.type || 'Item',
        isActive: category.isActive !== false
      });
    } else {
      setEditingCategory(null);
      setCategoryFormData({
        name: '',
        description: '',
        applicableFor: 'Item',
        isActive: true
      });
    }
    setOpenDialog(true);
  };

  const handleOpenSubcategoryDialog = (subcategory = null, parentCategoryId = null) => {
    if (subcategory) {
      setEditingSubcategory(subcategory.id);
      setSubcategoryFormData({
        name: subcategory.name || subcategory.subcategory || subcategory.title || '',
        description: subcategory.description || '',
        categoryId: subcategory.categoryId || subcategory.category_id || subcategory.parentCategoryId || subcategory.parentId || '',
        isActive: subcategory.isActive !== false
      });
    } else {
      setEditingSubcategory(null);
      setSubcategoryFormData({
        name: '',
        description: '',
        categoryId: parentCategoryId || '',
        isActive: true
      });
    }
    setOpenSubcategoryDialog(true);
  };

  const handleSaveCategory = async () => {
    try {
      const payload = {
        name: categoryFormData.name,
        description: categoryFormData.description,
        applicableFor: categoryFormData.applicableFor,
        type: categoryFormData.applicableFor?.toLowerCase() || 'item',
        isActive: categoryFormData.isActive,
        updatedBy: adminData?.email
      };
      if (editingCategory) {
        await api.put(`/categories/${editingCategory}`, payload);
      } else {
        await api.post('/categories', { ...payload, createdBy: adminData?.email });
      }
      setOpenDialog(false);
      await loadCategories();
    } catch (error) {
      console.error('Error saving category:', error);
      alert('Error saving category: ' + (error.response?.data?.message || error.message));
    }
  };

  const handleSaveSubcategory = async () => {
    try {
      const payload = {
        name: subcategoryFormData.name,
        description: subcategoryFormData.description,
        categoryId: subcategoryFormData.categoryId,
        isActive: subcategoryFormData.isActive,
        updatedBy: adminData?.email
      };
      if (editingSubcategory) {
        await api.put(`/subcategories/${editingSubcategory}`, payload);
      } else {
        await api.post('/subcategories', { ...payload, createdBy: adminData?.email });
      }
      setOpenSubcategoryDialog(false);
      await loadSubcategories();
    } catch (error) {
      console.error('Error saving subcategory:', error);
      alert('Error saving subcategory: ' + (error.response?.data?.message || error.message));
    }
  };

  const handleDeleteCategory = async (categoryId, categoryName) => {
    if (!confirm(`Are you sure you want to delete "${categoryName}"? This action cannot be undone.`)) return;
    try {
      await api.delete(`/categories/${categoryId}`);
      await loadCategories();
    } catch (error) {
      console.error('Error deleting category:', error);
      alert('Error deleting category: ' + (error.response?.data?.message || error.message));
    }
  };

  const handleDeleteSubcategory = async (subcategoryId, subcategoryName) => {
    if (!confirm(`Are you sure you want to delete subcategory "${subcategoryName}"? This action cannot be undone.`)) return;
    try {
      await api.delete(`/subcategories/${subcategoryId}`);
      await loadSubcategories();
    } catch (error) {
      console.error('Error deleting subcategory:', error);
      alert('Error deleting subcategory: ' + (error.response?.data?.message || error.message));
    }
  };

  const getCategoryName = (categoryId) => {
    if (!categoryId) return 'No Category';
    const category = categories.find(cat => cat.id === categoryId);
    if (!category) {
      console.log('Category not found for ID:', categoryId);
      console.log('Available category IDs:', categories.map(c => c.id));
      return `Unknown (${categoryId})`;
    }
    return category.name || category.category || category.title || 'Unknown';
  };

  const getSubcategoriesForCategory = (categoryId) => {
    const filtered = subcategories.filter(sub => {
      // Check multiple possible field names for categoryId
      return sub.categoryId === categoryId || 
             sub.category_id === categoryId || 
             sub.parentCategoryId === categoryId ||
             sub.parentId === categoryId;
    });
    if (categoryId && filtered.length === 0) {
      console.log('No subcategories found for category:', categoryId);
      console.log('Available subcategory categoryIds:', subcategories.map(s => s.categoryId || s.category_id || s.parentCategoryId));
    }
    return filtered;
  };

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Categories & Subcategories
      </Typography>
      
      <Alert severity="info" sx={{ mb: 3 }}>
        <strong>Category Management:</strong> Categories are used globally. 
        <br />
        • <strong>Item Categories</strong> (🛒): Used for physical products in the marketplace
        <br />
        • <strong>Service Categories</strong> (🔧): Used for service requests and bookings
        <br />
        • <strong>Rent Categories</strong> (🏠): Used for rental items and properties
        <br />
        • <strong>Delivery Categories</strong> (🚚): Used for delivery and logistics services
        <br />
        • <strong>Transport Categories</strong> (🚗): Used for transportation services
      </Alert>

      {loading && <LinearProgress sx={{ mb: 2 }} />}

      <Grid container spacing={3}>
        {/* Categories Section */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Box display="flex" justifyContent="space-between" alignItems="center" mb={2}>
                <Box display="flex" alignItems="center" gap={2}>
                  <CategoryIcon />
                  <Typography variant="h6">Categories ({categories.length})</Typography>
                </Box>
                <Button
                  variant="contained"
                  startIcon={<Add />}
                  onClick={() => handleOpenCategoryDialog()}
                >
                  Add Category
                </Button>
              </Box>

              <TableContainer>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Name</TableCell>
                      <TableCell>Type</TableCell>
                      <TableCell>Subcategories</TableCell>
                      <TableCell>Status</TableCell>
                      <TableCell>Actions</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {categories.map((category) => (
                      <TableRow key={category.id}>
                        <TableCell>
                          <Box>
                            <Typography variant="subtitle2">
                              {category.name || category.category || category.title || 'Unnamed Category'}
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                              {category.description}
                            </Typography>
                          </Box>
                        </TableCell>
                        <TableCell>
                          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <Chip 
                              icon={category.applicableFor === 'Item' ? <ShoppingCart /> : <Build />}
                              label={category.applicableFor || category.type || 'Unknown'}
                              size="small"
                              color={category.applicableFor === 'Item' || category.type === 'item' ? 'primary' : 'secondary'}
                            />
                            <Typography variant="caption" color="text.secondary">
                              {(() => {
                                const type = category.applicableFor || category.type || '';
                                switch(type.toLowerCase()) {
                                  case 'item': return 'For Products';
                                  case 'service': return 'For Services';
                                  case 'rent': return 'For Rentals';
                                  case 'delivery': return 'For Delivery';
                                  case 'transport': return 'For Transport';
                                  default: return 'Unknown Type';
                                }
                              })()}
                            </Typography>
                          </Box>
                        </TableCell>
                        <TableCell>
                          <Chip 
                            label={getSubcategoriesForCategory(category.id).length}
                            size="small"
                            color="default"
                          />
                        </TableCell>
                        <TableCell>
                          <Chip 
                            label={category.isActive !== false ? 'Active' : 'Inactive'}
                            size="small"
                            color={category.isActive !== false ? 'success' : 'default'}
                            variant={category.isActive !== false ? 'filled' : 'outlined'}
                          />
                        </TableCell>
                        <TableCell>
                          <IconButton 
                            size="small" 
                            onClick={() => handleOpenCategoryDialog(category)}
                            color="primary"
                          >
                            <Edit />
                          </IconButton>
                          <IconButton 
                            size="small" 
                            onClick={() => handleOpenSubcategoryDialog(null, category.id)}
                            color="success"
                            title="Add Subcategory"
                          >
                            <Add />
                          </IconButton>
                          <IconButton 
                            size="small" 
                            onClick={() => handleDeleteCategory(category.id, category.name)}
                            color="error"
                          >
                            <Delete />
                          </IconButton>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>

              {categories.length === 0 && !loading && (
                <Box textAlign="center" py={4}>
                  <Typography variant="body2" color="text.secondary" mb={2}>
                    No categories found
                  </Typography>
                  <Button variant="outlined" startIcon={<Add />} onClick={() => handleOpenCategoryDialog()}>
                    Create First Category
                  </Button>
                </Box>
              )}
            </CardContent>
          </Card>
        </Grid>

        {/* Subcategories Section */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Box display="flex" justifyContent="space-between" alignItems="center" mb={2}>
                <Box display="flex" alignItems="center" gap={2}>
                  <CategoryIcon />
                  <Typography variant="h6">Subcategories ({subcategories.length})</Typography>
                </Box>
                <Button
                  variant="contained"
                  startIcon={<Add />}
                  onClick={() => handleOpenSubcategoryDialog()}
                  disabled={categories.length === 0}
                >
                  Add Subcategory
                </Button>
              </Box>

              <TableContainer>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Name</TableCell>
                      <TableCell>Category</TableCell>
                      <TableCell>Status</TableCell>
                      <TableCell>Actions</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {subcategories.map((subcategory) => (
                      <TableRow key={subcategory.id}>
                        <TableCell>
                          <Box>
                            <Typography variant="subtitle2">
                              {subcategory.name || subcategory.subcategory || subcategory.title || 'Unnamed Subcategory'}
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                              {subcategory.description}
                            </Typography>
                          </Box>
                        </TableCell>
                        <TableCell>
                          <Box>
                            <Chip 
                              label={getCategoryName(
                                subcategory.categoryId || 
                                subcategory.category_id || 
                                subcategory.parentCategoryId || 
                                subcategory.parentId
                              )}
                              size="small"
                              color="primary"
                              variant="outlined"
                            />
                            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.5 }}>
                              {(() => {
                                const parentCategory = categories.find(cat => 
                                  cat.id === (subcategory.categoryId || subcategory.category_id || subcategory.parentCategoryId || subcategory.parentId)
                                );
                                return parentCategory 
                                  ? `${parentCategory.applicableFor || parentCategory.type || 'Unknown'} Category`
                                  : 'Unknown Category';
                              })()}
                            </Typography>
                          </Box>
                        </TableCell>
                        <TableCell>
                          <Chip 
                            label={subcategory.isActive !== false ? 'Active' : 'Inactive'}
                            size="small"
                            color={subcategory.isActive !== false ? 'success' : 'default'}
                            variant={subcategory.isActive !== false ? 'filled' : 'outlined'}
                          />
                        </TableCell>
                        <TableCell>
                          <IconButton 
                            size="small" 
                            onClick={() => handleOpenSubcategoryDialog(subcategory)}
                            color="primary"
                          >
                            <Edit />
                          </IconButton>
                          <IconButton 
                            size="small" 
                            onClick={() => handleDeleteSubcategory(subcategory.id, subcategory.name)}
                            color="error"
                          >
                            <Delete />
                          </IconButton>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>

              {subcategories.length === 0 && !loading && (
                <Box textAlign="center" py={4}>
                  <Typography variant="body2" color="text.secondary" mb={2}>
                    No subcategories found
                  </Typography>
                  <Button 
                    variant="outlined" 
                    startIcon={<Add />} 
                    onClick={() => handleOpenSubcategoryDialog()}
                    disabled={categories.length === 0}
                  >
                    Create First Subcategory
                  </Button>
                </Box>
              )}
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Category Dialog */}
      <Dialog open={openDialog} onClose={() => setOpenDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          {editingCategory ? 'Edit Category' : 'Add Category'}
        </DialogTitle>
        <DialogContent>
          <Box display="flex" flexDirection="column" gap={3} pt={2}>
            <TextField
              fullWidth
              label="Category Name"
              value={categoryFormData.name}
              onChange={(e) => setCategoryFormData(prev => ({ ...prev, name: e.target.value }))}
              required
            />

            <TextField
              fullWidth
              multiline
              rows={2}
              label="Description"
              value={categoryFormData.description}
              onChange={(e) => setCategoryFormData(prev => ({ ...prev, description: e.target.value }))}
            />

            <FormControl fullWidth>
              <InputLabel>Applicable For</InputLabel>
              <Select
                value={categoryFormData.applicableFor}
                onChange={(e) => setCategoryFormData(prev => ({ ...prev, applicableFor: e.target.value }))}
              >
                <MenuItem value="Item">Item (Products)</MenuItem>
                <MenuItem value="Service">Service (Requests)</MenuItem>
                <MenuItem value="Rent">Rent (Rental Items)</MenuItem>
                <MenuItem value="Delivery">Delivery (Services)</MenuItem>
                <MenuItem value="Transport">Transport (Services)</MenuItem>
              </Select>
            </FormControl>

            <FormControlLabel
              control={
                <Switch
                  checked={categoryFormData.isActive}
                  onChange={(e) => setCategoryFormData(prev => ({ ...prev, isActive: e.target.checked }))}
                />
              }
              label="Active"
            />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenDialog(false)}>Cancel</Button>
          <Button 
            onClick={handleSaveCategory} 
            variant="contained"
            disabled={!categoryFormData.name}
          >
            {editingCategory ? 'Update' : 'Create'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Subcategory Dialog */}
      <Dialog open={openSubcategoryDialog} onClose={() => setOpenSubcategoryDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          {editingSubcategory ? 'Edit Subcategory' : 'Add Subcategory'}
        </DialogTitle>
        <DialogContent>
          <Box display="flex" flexDirection="column" gap={3} pt={2}>
            <FormControl fullWidth>
              <InputLabel>Parent Category</InputLabel>
              <Select
                value={subcategoryFormData.categoryId}
                onChange={(e) => setSubcategoryFormData(prev => ({ ...prev, categoryId: e.target.value }))}
                required
              >
                {categories.map(category => (
                  <MenuItem key={category.id} value={category.id}>
                    {category.name || category.category || category.title || 'Unnamed'} ({category.applicableFor || category.type || 'Unknown'})
                  </MenuItem>
                ))}
              </Select>
            </FormControl>

            <TextField
              fullWidth
              label="Subcategory Name"
              value={subcategoryFormData.name}
              onChange={(e) => setSubcategoryFormData(prev => ({ ...prev, name: e.target.value }))}
              required
            />

            <TextField
              fullWidth
              multiline
              rows={2}
              label="Description"
              value={subcategoryFormData.description}
              onChange={(e) => setSubcategoryFormData(prev => ({ ...prev, description: e.target.value }))}
            />

            <FormControlLabel
              control={
                <Switch
                  checked={subcategoryFormData.isActive}
                  onChange={(e) => setSubcategoryFormData(prev => ({ ...prev, isActive: e.target.checked }))}
                />
              }
              label="Active"
            />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenSubcategoryDialog(false)}>Cancel</Button>
          <Button 
            onClick={handleSaveSubcategory} 
            variant="contained"
            disabled={!subcategoryFormData.name || !subcategoryFormData.categoryId}
          >
            {editingSubcategory ? 'Update' : 'Create'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default Categories;
