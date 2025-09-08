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
  Snackbar
} from '@mui/material';
import {
  Search,
  Visibility,
  Edit,
  Delete,
  FilterList,
  Refresh,
  Add,
  Category,
  LocalOffer,
  Folder,
  FolderOpen
} from '@mui/icons-material';
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter.jsx';

const CategoriesModule = () => {
  const {
    getFilteredData,
    adminData,
    isSuperAdmin,
    getCountryDisplayName,
    userCountry
  } = useCountryFilter();

  const [categories, setCategories] = useState([]);
  const [subcategories, setSubcategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterAnchorEl, setFilterAnchorEl] = useState(null);
  const [selectedStatus, setSelectedStatus] = useState('all');
  const [selectedCategory, setSelectedCategory] = useState(null);
  const [viewDialogOpen, setViewDialogOpen] = useState(false);
  const [editDialogOpen, setEditDialogOpen] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    status: 'active',
    type: 'item',
    country: ''
  });
  const [snackbar, setSnackbar] = useState({
    open: false,
    message: '',
    severity: 'success'
  });
  const [operationLoading, setOperationLoading] = useState(false);

  const statusColors = {
    active: 'success',
    inactive: 'error',
    draft: 'warning'
  };

  const loadCategories = async () => {
    try {
      setLoading(true);
      setError(null);

      // Always request inactive too so local status filter works
      const [catsData, subcatsData] = await Promise.all([
        getFilteredData('categories', { includeInactive: true }),
        getFilteredData('subcategories', { includeInactive: true })
      ]);
      console.debug('[CategoriesModule] Raw categories fetch length=', Array.isArray(catsData)?catsData.length:'n/a', 'sampleInactive?', catsData?.filter(c=>c.is_active===false).map(c=>c.name));
      
      // Normalize status field for UI
      const normalized = (catsData || []).map(c => ({
        ...c,
        status: c.status || (c.is_active !== undefined ? (c.is_active ? 'active' : 'inactive') : (c.isActive !== false ? 'active' : 'inactive'))
      }));
      setCategories(normalized);
      setSubcategories(subcatsData || []);
      
    const act = normalized.filter(c=>c.status==='active').length;
    const inact = normalized.filter(c=>c.status==='inactive').length;
    console.log(`📊 Loaded categories total=${normalized.length} active=${act} inactive=${inact} (raw=${catsData?.length || 0}) subcategories=${subcatsData?.length || 0}`);
    } catch (err) {
      console.error('Error loading categories:', err);
      setError('Failed to load categories: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  // Load on mount and again when adminData becomes available/changes
  useEffect(() => { loadCategories(); }, [adminData]);
  // Remove second unconditional effect that caused duplicate / race loads

  const handleViewCategory = (category) => {
    setSelectedCategory(category);
    setViewDialogOpen(true);
  };

  const handleDeleteCategory = (category) => {
    setSelectedCategory(category);
    setDeleteDialogOpen(true);
  };

  const handleStatusFilter = (status) => {
    setSelectedStatus(status);
    setFilterAnchorEl(null);
  };

  const getSubcategoryCount = (categoryId) => {
    return subcategories.filter(sub => 
      (sub.categoryId || sub.category_id) === categoryId
    ).length;
  };

  const handleAddCategory = () => {
    setSelectedCategory(null);
    setFormData({
      name: '',
      description: '',
      status: 'active',
      type: 'item',
      country: isSuperAdmin ? '' : userCountry
    });
    setEditDialogOpen(true);
  };

  const handleEditCategory = (category) => {
    setSelectedCategory(category);
    setFormData({
      name: category.name || category.category || '',
      description: category.description || '',
      status: category.status || (category.isActive !== false ? 'active' : 'inactive'),
      type: category.type || 'item',
      country: category.country || userCountry
    });
    setEditDialogOpen(true);
  };

  const handleSaveCategory = async () => {
    try {
      setOperationLoading(true);
      
      // Backend expects: name, description (stored in metadata), type, isActive OR status
      const categoryPayload = {
        name: formData.name?.trim(),
        description: formData.description?.trim() || null,
        type: formData.type,
        // Provide both forms for safety while migrating
        isActive: formData.status === 'active',
        status: formData.status
      };

      console.debug('[CategoriesModule] Saving category', { mode: selectedCategory ? 'update' : 'create', id: selectedCategory?.id, payload: categoryPayload });

      if (selectedCategory) {
        await api.put(`/categories/${selectedCategory.id}`, {
          ...categoryPayload,
          updatedBy: adminData?.email || 'admin'
        });
        setSnackbar({
          open: true,
          message: 'Category updated successfully!',
          severity: 'success'
        });
      } else {
        await api.post('/categories', {
          ...categoryPayload,
          createdBy: adminData?.email || 'admin'
        });
        setSnackbar({
          open: true,
          message: 'Category added successfully!',
          severity: 'success'
        });
      }

      setEditDialogOpen(false);
      loadCategories();
    } catch (error) {
      console.error('Error saving category:', error);
      setSnackbar({
        open: true,
  message: 'Error saving category: ' + (error.response?.data?.error || error.message),
        severity: 'error'
      });
    } finally {
      setOperationLoading(false);
    }
  };

  const handleDeleteConfirm = async () => {
    try {
      setOperationLoading(true);
      
      // Check if category has subcategories
      const subcatCount = getSubcategoryCount(selectedCategory.id);
      if (subcatCount > 0) {
        setSnackbar({
          open: true,
          message: `Cannot delete category with ${subcatCount} subcategories. Delete subcategories first.`,
          severity: 'warning'
        });
        setDeleteDialogOpen(false);
        return;
      }

  await api.delete(`/categories/${selectedCategory.id}`);
      setSnackbar({
        open: true,
        message: 'Category deleted successfully!',
        severity: 'success'
      });
      setDeleteDialogOpen(false);
      loadCategories();
    } catch (error) {
      console.error('Error deleting category:', error);
      setSnackbar({
        open: true,
        message: 'Error deleting category: ' + error.message,
        severity: 'error'
      });
    } finally {
      setOperationLoading(false);
    }
  };

  const filteredCategories = categories.filter(category => {
    const matchesSearch = !searchTerm || 
                         (category.name || category.category)?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         category.description?.toLowerCase().includes(searchTerm.toLowerCase());

  const categoryStatus = category.status || (category.is_active !== undefined ? (category.is_active ? 'active' : 'inactive') : (category.isActive !== false ? 'active' : 'inactive'));
    const matchesStatus = selectedStatus === 'all' || categoryStatus === selectedStatus;

    return matchesSearch && matchesStatus;
  });

  // TEMP debug: print status distribution once after load
  useEffect(() => {
    if (categories.length) {
      const dist = categories.reduce((acc,c)=>{const s=c.status || (c.is_active!==undefined?(c.is_active?'active':'inactive'):(c.isActive!==false?'active':'inactive'));acc[s]=(acc[s]||0)+1;return acc;},{});
      console.debug('[CategoriesModule] Status distribution', dist);
    }
  }, [categories]);

  const formatDate = (timestamp) => {
    if (!timestamp) return 'N/A';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
  };

  const getCategoryStats = () => {
    const all = categories;
    const active = all.filter(c => c.status === 'active').length;
    const inactive = all.filter(c => c.status === 'inactive').length;
    const draft = all.filter(c => c.status === 'draft').length;
    return { total: all.length, active, inactive, draft };
  };

  const stats = getCategoryStats();

  useEffect(()=>{
    if(!loading){
      console.debug('[CategoriesModule] Stats after load', stats, 'categoriesLen=', categories.length);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loading, categories.length]);

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return (
      <Alert severity="error" action={
        <Button color="inherit" size="small" onClick={loadCategories}>
          Retry
        </Button>
      }>
        {error}
      </Alert>
    );
  }

  return (
    <Box>
      {/* Header */}
      <Box mb={3}>
        <Typography variant="h4" gutterBottom>
          Categories Management
        </Typography>
        <Typography variant="body2" color="text.secondary">
          {isSuperAdmin ? 'Manage all categories across countries' : `Manage categories in ${getCountryDisplayName(userCountry)}`}
        </Typography>
      </Box>

      {/* Stats Cards */}
      <Grid container spacing={3} mb={3}>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography color="text.secondary" gutterBottom variant="overline">
                    Total Categories
                  </Typography>
                  <Typography variant="h4">
                    {stats.total}
                  </Typography>
                </Box>
                <Category color="primary" sx={{ fontSize: 40, opacity: 0.3 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography color="text.secondary" gutterBottom variant="overline">
                    Active
                  </Typography>
                  <Typography variant="h4" color="success.main">
                    {stats.active}
                  </Typography>
                </Box>
                <Folder color="success" sx={{ fontSize: 40, opacity: 0.3 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography color="text.secondary" gutterBottom variant="overline">
                    Inactive
                  </Typography>
                  <Typography variant="h4" color="error.main">
                    {stats.inactive}
                  </Typography>
                </Box>
                <FolderOpen color="error" sx={{ fontSize: 40, opacity: 0.3 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography color="text.secondary" gutterBottom variant="overline">
                    Draft
                  </Typography>
                  <Typography variant="h4" color="warning.main">
                    {stats.draft}
                  </Typography>
                </Box>
                <LocalOffer color="warning" sx={{ fontSize: 40, opacity: 0.3 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Controls */}
      <Paper sx={{ p: 2, mb: 3 }}>
        <Box display="flex" gap={2} alignItems="center" flexWrap="wrap">
          <TextField
            placeholder="Search categories..."
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
          >
            FILTERS ({selectedStatus === 'all' ? 'NONE' : selectedStatus.toUpperCase()})
          </Button>
          <Button
            startIcon={<Refresh />}
            onClick={loadCategories}
          >
            REFRESH
          </Button>
          {isSuperAdmin && (
            <Button
              variant="contained"
              startIcon={<Add />}
              onClick={handleAddCategory}
            >
              Add Category
            </Button>
          )}
        </Box>
      </Paper>

      {/* Categories Table */}
      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Category</TableCell>
              <TableCell>Description</TableCell>
              <TableCell>Type</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Subcategories</TableCell>
              <TableCell>Created</TableCell>
              <TableCell>Country</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredCategories.map((category) => (
              <TableRow key={category.id} hover>
                <TableCell>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Category fontSize="small" color="action" />
                    <Typography variant="body2" fontWeight="medium">
                      {category.name || category.category || 'Unnamed Category'}
                    </Typography>
                  </Box>
                </TableCell>
                <TableCell>
                  <Typography variant="body2" noWrap sx={{ maxWidth: 200 }}>
                    {category.description || 'No description'}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Chip
                    label={category.type || 'item'}
                    color={category.type === 'service' ? 'secondary' : category.type === 'rent' ? 'info' : category.type === 'delivery' ? 'warning' : 'primary'}
                    size="small"
                    variant="outlined"
                  />
                </TableCell>
                <TableCell>
                  <Chip
                    label={category.status || (category.isActive !== false ? 'active' : 'inactive')}
                    color={statusColors[category.status || (category.isActive !== false ? 'active' : 'inactive')] || 'success'}
                    size="small"
                    variant="outlined"
                  />
                </TableCell>
                <TableCell>
                  <Chip
                    label={getSubcategoryCount(category.id)}
                    size="small"
                    variant="filled"
                    color="primary"
                  />
                </TableCell>
                <TableCell>
                  <Typography variant="body2">
                    {formatDate(category.createdAt)}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Chip
                    label={category.country || userCountry}
                    size="small"
                    variant="outlined"
                  />
                </TableCell>
                <TableCell>
                  <Box sx={{ display: 'flex', gap: 0.5 }}>
                    <Tooltip title="View Details">
                      <IconButton size="small" onClick={() => handleViewCategory(category)}>
                        <Visibility />
                      </IconButton>
                    </Tooltip>
                    {isSuperAdmin && (
                      <>
                        <Tooltip title="Edit">
                          <IconButton size="small" onClick={() => handleEditCategory(category)}>
                            <Edit />
                          </IconButton>
                        </Tooltip>
                        <Tooltip title="Delete">
                          <IconButton size="small" onClick={() => handleDeleteCategory(category)}>
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
      </TableContainer>

      {/* Filter Menu */}
      <Menu
        anchorEl={filterAnchorEl}
        open={Boolean(filterAnchorEl)}
        onClose={() => setFilterAnchorEl(null)}
      >
        <MenuItem onClick={() => handleStatusFilter('all')}>All Status</MenuItem>
        <MenuItem onClick={() => handleStatusFilter('active')}>Active</MenuItem>
        <MenuItem onClick={() => handleStatusFilter('inactive')}>Inactive</MenuItem>
        <MenuItem onClick={() => handleStatusFilter('draft')}>Draft</MenuItem>
      </Menu>

      {/* View Dialog */}
      <Dialog
        open={viewDialogOpen}
        onClose={() => setViewDialogOpen(false)}
        maxWidth="md"
        fullWidth
      >
        {selectedCategory && (
          <>
            <DialogTitle>
              Category Details: {selectedCategory.name || selectedCategory.category}
            </DialogTitle>
            <DialogContent>
              <Grid container spacing={2}>
                <Grid item xs={12} sm={6}>
                  <Typography variant="subtitle2" gutterBottom>Name</Typography>
                  <Typography variant="body2" paragraph>
                    {selectedCategory.name || selectedCategory.category}
                  </Typography>
                  
                  <Typography variant="subtitle2" gutterBottom>Type</Typography>
                  <Chip
                    label={selectedCategory.type || 'item'}
                    color={selectedCategory.type === 'service' ? 'secondary' : selectedCategory.type === 'rent' ? 'info' : selectedCategory.type === 'delivery' ? 'warning' : 'primary'}
                    size="small"
                    sx={{ mb: 2 }}
                  />
                  
                  <Typography variant="subtitle2" gutterBottom>Status</Typography>
                  <Chip
                    label={selectedCategory.status || 'active'}
                    color={statusColors[selectedCategory.status] || 'default'}
                    size="small"
                  />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <Typography variant="subtitle2" gutterBottom>Description</Typography>
                  <Typography variant="body2" paragraph>
                    {selectedCategory.description || 'No description available'}
                  </Typography>
                  
                  <Typography variant="subtitle2" gutterBottom>Country</Typography>
                  <Chip
                    label={selectedCategory.country || userCountry}
                    size="small"
                    variant="outlined"
                  />
                </Grid>
                <Grid item xs={12}>
                  <Typography variant="subtitle2" gutterBottom>Subcategories ({getSubcategoryCount(selectedCategory.id)})</Typography>
                  <Box display="flex" gap={1} flexWrap="wrap">
                    {subcategories
                      .filter(sub => (sub.categoryId || sub.category_id) === selectedCategory.id)
                      .map((sub, index) => (
                        <Chip 
                          key={index} 
                          label={sub.name || sub.subcategory} 
                          size="small" 
                          variant="outlined" 
                        />
                      ))
                    }
                    {getSubcategoryCount(selectedCategory.id) === 0 && (
                      <Typography variant="body2" color="text.secondary">No subcategories</Typography>
                    )}
                  </Box>
                </Grid>
              </Grid>
            </DialogContent>
            <DialogActions>
              <Button onClick={() => setViewDialogOpen(false)}>Close</Button>
            </DialogActions>
          </>
        )}
      </Dialog>

      {/* Floating Action Button */}
      {isSuperAdmin && (
        <Fab
          color="primary"
          aria-label="add category"
          sx={{ position: 'fixed', bottom: 16, right: 16 }}
          onClick={handleAddCategory}
        >
          <Add />
        </Fab>
      )}

      {/* Edit/Add Dialog */}
      <Dialog
        open={editDialogOpen}
        onClose={() => setEditDialogOpen(false)}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>
          {selectedCategory ? 'Edit Category' : 'Add Category'}
        </DialogTitle>
        <DialogContent>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 2 }}>
            <TextField
              label="Category Name"
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
              <InputLabel>Category Type</InputLabel>
              <Select
                value={formData.type}
                label="Category Type"
                onChange={(e) => setFormData({...formData, type: e.target.value})}
              >
                <MenuItem value="item">Item</MenuItem>
                <MenuItem value="service">Service</MenuItem>
                <MenuItem value="rent">Rent</MenuItem>
                <MenuItem value="delivery">Delivery</MenuItem>
              </Select>
            </FormControl>
            
            <FormControl fullWidth>
              <InputLabel>Status</InputLabel>
              <Select
                value={formData.status}
                label="Status"
                onChange={(e) => setFormData({...formData, status: e.target.value})}
              >
                <MenuItem value="active">Active</MenuItem>
                <MenuItem value="inactive">Inactive</MenuItem>
                <MenuItem value="draft">Draft</MenuItem>
              </Select>
            </FormControl>

            {isSuperAdmin && (
              <TextField
                label="Country"
                fullWidth
                value={formData.country}
                onChange={(e) => setFormData({...formData, country: e.target.value})}
                placeholder="Leave empty for global"
              />
            )}
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setEditDialogOpen(false)}>Cancel</Button>
          <Button 
            variant="contained" 
            onClick={handleSaveCategory}
            disabled={!formData.name || operationLoading}
          >
            {operationLoading ? <CircularProgress size={20} /> : (selectedCategory ? 'Update' : 'Add')}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog
        open={deleteDialogOpen}
        onClose={() => setDeleteDialogOpen(false)}
        maxWidth="sm"
      >
        <DialogTitle>Delete Category</DialogTitle>
        <DialogContent>
          {selectedCategory && (
            <>
              <Alert severity="warning" sx={{ mb: 2 }}>
                Are you sure you want to delete "{selectedCategory.name || selectedCategory.category}"?
              </Alert>
              <Typography variant="body2" color="text.secondary">
                This category has {getSubcategoryCount(selectedCategory.id)} subcategories.
                {getSubcategoryCount(selectedCategory.id) > 0 && ' You must delete all subcategories first.'}
              </Typography>
            </>
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

export default CategoriesModule;
