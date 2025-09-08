import React, { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Grid,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Chip,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  IconButton,
  Tooltip,
  Alert,
  Switch,
  FormControlLabel,
  Tab,
  Tabs,
  Divider,
  Badge,
  LinearProgress,
  InputAdornment
} from '@mui/material';
import {
  Add,
  Edit,
  Delete,
  Visibility,
  Check,
  Close,
  LocalOffer,
  TrendingUp,
  Schedule,
  CheckCircle,
  Cancel,
  Pending,
  Percent,
  MonetizationOn,
  CalendarToday,
  People,
  Analytics,
  FilterList,
  Search
} from '@mui/icons-material';
// Migrated from Firestore to REST API
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter';

const PromoCodes = () => {
  const { 
    adminData, 
    filteredCountries, 
    userCountry, 
    isSuperAdmin, 
    getCountryDisplayName 
  } = useCountryFilter();

  // State management
  const [activeTab, setActiveTab] = useState(0);
  const [promoCodes, setPromoCodes] = useState([]);
  const [filteredPromoCodes, setFilteredPromoCodes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState(false);
  const [editingPromoCode, setEditingPromoCode] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [countryFilter, setCountryFilter] = useState('all');
  
  // Analytics state
  const [analytics, setAnalytics] = useState({
    totalActive: 0,
    totalPending: 0,
    totalUsed: 0,
    totalSavings: 0
  });

  // Form state
  const [formData, setFormData] = useState({
    code: '',
    title: '',
    description: '',
    type: 'percentageDiscount',
    value: '',
    maxUses: '',
    maxUsesPerUser: 1,
    minOrderValue: '',
    countries: isSuperAdmin ? [] : [userCountry],
    startDate: '',
    endDate: '',
    isActive: true,
    status: 'pendingApproval',
    requiresApproval: !isSuperAdmin
  });

  // Promo code types
  const promoTypes = [
    { value: 'percentageDiscount', label: 'Percentage Discount (%)', icon: <Percent /> },
    { value: 'fixedDiscount', label: 'Fixed Amount Discount', icon: <MonetizationOn /> },
    { value: 'freeTrialExtension', label: 'Free Trial Extension', icon: <Schedule /> },
    { value: 'freeShipping', label: 'Free Shipping', icon: <LocalOffer /> }
  ];

  // Status configurations
  const statusConfig = {
    pendingApproval: { color: 'warning', icon: <Pending />, label: 'Pending Approval' },
    active: { color: 'success', icon: <CheckCircle />, label: 'Active' },
    rejected: { color: 'error', icon: <Cancel />, label: 'Rejected' },
    disabled: { color: 'default', icon: <Cancel />, label: 'Disabled' },
    expired: { color: 'default', icon: <Schedule />, label: 'Expired' }
  };

  // Load promo codes
  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true);
        const params = {};
        if (!isSuperAdmin) params.country = userCountry;
        const res = await api.get('/promo-codes', { params });
        const list = Array.isArray(res.data) ? res.data : res.data?.data || [];
        setPromoCodes(list);
      } catch (e) {
        console.error('Error fetching promo codes', e);
      } finally { setLoading(false); }
    };
    fetchData();
  }, [isSuperAdmin, userCountry]);

  // Filter promo codes based on search, status, and country
  useEffect(() => {
    let filtered = promoCodes;

    // Search filter
    if (searchQuery) {
      filtered = filtered.filter(promo => 
        promo.code?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        promo.title?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        promo.description?.toLowerCase().includes(searchQuery.toLowerCase())
      );
    }

    // Status filter
    if (statusFilter !== 'all') {
      filtered = filtered.filter(promo => promo.status === statusFilter);
    }

    // Country filter (for super admin)
    if (isSuperAdmin && countryFilter !== 'all') {
      filtered = filtered.filter(promo => promo.countries?.includes(countryFilter));
    }

    // Tab-based filtering
    switch (activeTab) {
      case 0: // My Promo Codes / All Codes
        break;
      case 1: // Pending Approval (Super Admin) / Active (Country Admin)
        if (isSuperAdmin) {
          filtered = filtered.filter(promo => promo.status === 'pendingApproval');
        } else {
          filtered = filtered.filter(promo => promo.status === 'active');
        }
        break;
      case 2: // Active Codes / Analytics
        if (isSuperAdmin) {
          filtered = filtered.filter(promo => promo.status === 'active');
        }
        break;
      case 3: // Analytics (Super Admin only)
        break;
      default:
        break;
    }

    setFilteredPromoCodes(filtered);
  }, [promoCodes, searchQuery, statusFilter, countryFilter, activeTab, isSuperAdmin]);

  // Calculate analytics
  useEffect(() => {
    const totalActive = promoCodes.filter(p => p.status === 'active').length;
    const totalPending = promoCodes.filter(p => p.status === 'pendingApproval').length;
    const totalUsed = promoCodes.reduce((sum, p) => sum + (p.usedCount || 0), 0);
    const totalSavings = promoCodes.reduce((sum, p) => sum + (p.totalSavings || 0), 0);

    setAnalytics({ totalActive, totalPending, totalUsed, totalSavings });
  }, [promoCodes]);

  // Reset form
  const resetForm = () => {
    setFormData({
      code: '',
      title: '',
      description: '',
      type: 'percentageDiscount',
      value: '',
      maxUses: '',
      maxUsesPerUser: 1,
      minOrderValue: '',
      countries: isSuperAdmin ? [] : [userCountry],
      startDate: '',
      endDate: '',
      isActive: true,
      status: 'pendingApproval',
      requiresApproval: !isSuperAdmin
    });
  };

  // Handle form submission
  const handleSubmit = async () => {
    try {
      const payload = {
        code: formData.code,
        title: formData.title,
        description: formData.description,
        type: formData.type,
        value: parseFloat(formData.value) || 0,
        maxUses: formData.maxUses ? parseInt(formData.maxUses) : undefined,
        maxUsesPerUser: parseInt(formData.maxUsesPerUser) || 1,
        minOrderValue: formData.minOrderValue ? parseFloat(formData.minOrderValue) : 0,
        countries: formData.countries,
        startDate: formData.startDate || undefined,
        endDate: formData.endDate || undefined,
        isActive: formData.isActive,
        status: isSuperAdmin ? 'active' : 'pendingApproval',
        requiresApproval: !isSuperAdmin,
        createdBy: adminData?.id || adminData?.uid,
        createdByName: adminData?.name || adminData?.email,
        createdByCountry: userCountry
      };
      if (editingPromoCode) {
        await api.put(`/promo-codes/${editingPromoCode.id}`, payload);
      } else {
        await api.post('/promo-codes', payload);
      }
      handleClose();
      // reload list
      const res = await api.get('/promo-codes', { params: !isSuperAdmin ? { country: userCountry } : {} });
      const list = Array.isArray(res.data) ? res.data : res.data?.data || [];
      setPromoCodes(list);
    } catch (error) {
      console.error('Error saving promo code:', error);
    }
  };

  // Handle approval/rejection (Super Admin only)
  const handleApproval = async (promoCodeId, action, rejectionReason = '') => {
    try {
      await api.put(`/promo-codes/${promoCodeId}/status`, { status: action, rejectionReason });
      const res = await api.get('/promo-codes', { params: !isSuperAdmin ? { country: userCountry } : {} });
      const list = Array.isArray(res.data) ? res.data : res.data?.data || [];
      setPromoCodes(list);
    } catch (error) { console.error('Error updating promo code status:', error); }
  };

  // Handle edit
  const handleEdit = (promoCode) => {
    setEditingPromoCode(promoCode);
    setFormData({
      code: promoCode.code || '',
      title: promoCode.title || '',
      description: promoCode.description || '',
      type: promoCode.type || 'percentageDiscount',
      value: promoCode.value?.toString() || '',
      maxUses: promoCode.maxUses?.toString() || '',
      maxUsesPerUser: promoCode.maxUsesPerUser || 1,
      minOrderValue: promoCode.minOrderValue?.toString() || '',
      countries: promoCode.countries || [],
      startDate: promoCode.startDate || '',
      endDate: promoCode.endDate || '',
      isActive: promoCode.isActive !== false,
      status: promoCode.status,
      requiresApproval: promoCode.requiresApproval !== false
    });
    setOpen(true);
  };

  // Handle delete
  const handleDelete = async (promoCodeId) => {
    if (!window.confirm('Are you sure you want to delete this promo code?')) return;
    try {
      await api.delete(`/promo-codes/${promoCodeId}`);
      const res = await api.get('/promo-codes', { params: !isSuperAdmin ? { country: userCountry } : {} });
      const list = Array.isArray(res.data) ? res.data : res.data?.data || [];
      setPromoCodes(list);
    } catch (error) { console.error('Error deleting promo code:', error); }
  };

  // Handle close dialog
  const handleClose = () => {
    setOpen(false);
    setEditingPromoCode(null);
    resetForm();
  };

  // Generate promo code
  const generatePromoCode = () => {
    const prefix = userCountry?.toUpperCase() || 'PROMO';
    const suffix = Math.random().toString(36).substring(2, 8).toUpperCase();
    setFormData({ ...formData, code: `${prefix}${suffix}` });
  };

  // Render analytics cards
  const renderAnalyticsCards = () => (
    <Grid container spacing={3} sx={{ mb: 3 }}>
      <Grid item xs={12} sm={6} md={3}>
        <Card>
          <CardContent>
            <Box display="flex" alignItems="center">
              <CheckCircle color="success" sx={{ mr: 1 }} />
              <Box>
                <Typography variant="h4">{analytics.totalActive}</Typography>
                <Typography variant="body2" color="textSecondary">Active Codes</Typography>
              </Box>
            </Box>
          </CardContent>
        </Card>
      </Grid>
      <Grid item xs={12} sm={6} md={3}>
        <Card>
          <CardContent>
            <Box display="flex" alignItems="center">
              <Pending color="warning" sx={{ mr: 1 }} />
              <Box>
                <Typography variant="h4">{analytics.totalPending}</Typography>
                <Typography variant="body2" color="textSecondary">Pending Approval</Typography>
              </Box>
            </Box>
          </CardContent>
        </Card>
      </Grid>
      <Grid item xs={12} sm={6} md={3}>
        <Card>
          <CardContent>
            <Box display="flex" alignItems="center">
              <People color="info" sx={{ mr: 1 }} />
              <Box>
                <Typography variant="h4">{analytics.totalUsed}</Typography>
                <Typography variant="body2" color="textSecondary">Times Used</Typography>
              </Box>
            </Box>
          </CardContent>
        </Card>
      </Grid>
      <Grid item xs={12} sm={6} md={3}>
        <Card>
          <CardContent>
            <Box display="flex" alignItems="center">
              <TrendingUp color="primary" sx={{ mr: 1 }} />
              <Box>
                <Typography variant="h4">${analytics.totalSavings.toFixed(2)}</Typography>
                <Typography variant="body2" color="textSecondary">Total Savings</Typography>
              </Box>
            </Box>
          </CardContent>
        </Card>
      </Grid>
    </Grid>
  );

  // Render promo codes table
  const renderPromoCodesTable = () => (
    <TableContainer component={Paper}>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>Code</TableCell>
            <TableCell>Title</TableCell>
            <TableCell>Type</TableCell>
            <TableCell>Value</TableCell>
            <TableCell>Countries</TableCell>
            <TableCell>Status</TableCell>
            <TableCell>Usage</TableCell>
            <TableCell>Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {filteredPromoCodes.map((promo) => (
            <TableRow key={promo.id}>
              <TableCell>
                <Typography variant="body2" fontWeight="bold">
                  {promo.code}
                </Typography>
              </TableCell>
              <TableCell>
                <Typography variant="body2">{promo.title}</Typography>
                <Typography variant="caption" color="textSecondary">
                  {promo.description}
                </Typography>
              </TableCell>
              <TableCell>
                <Chip
                  icon={promoTypes.find(t => t.value === promo.type)?.icon}
                  label={promoTypes.find(t => t.value === promo.type)?.label || promo.type}
                  size="small"
                  variant="outlined"
                />
              </TableCell>
              <TableCell>
                {promo.type === 'percentageDiscount' ? `${promo.value}%` : 
                 promo.type === 'fixedDiscount' ? `$${promo.value}` :
                 promo.type === 'freeTrialExtension' ? `${promo.value} days` :
                 'Free'}
              </TableCell>
              <TableCell>
                <Box display="flex" flexWrap="wrap" gap={0.5}>
                  {promo.countries?.map(country => (
                    <Chip
                      key={country}
                      label={getCountryDisplayName(country)}
                      size="small"
                      variant="outlined"
                    />
                  ))}
                </Box>
              </TableCell>
              <TableCell>
                <Chip
                  icon={statusConfig[promo.status]?.icon}
                  label={statusConfig[promo.status]?.label}
                  color={statusConfig[promo.status]?.color}
                  size="small"
                />
              </TableCell>
              <TableCell>
                <Typography variant="body2">
                  {promo.usedCount || 0}
                  {promo.maxUses ? ` / ${promo.maxUses}` : ''}
                </Typography>
                {promo.maxUses && (
                  <LinearProgress
                    variant="determinate"
                    value={(promo.usedCount || 0) / promo.maxUses * 100}
                    sx={{ mt: 1 }}
                  />
                )}
              </TableCell>
              <TableCell>
                <Box display="flex" gap={1}>
                  {/* Edit button - only for pending/draft codes or super admin */}
                  {(promo.status === 'pendingApproval' || isSuperAdmin) && (
                    <Tooltip title="Edit">
                      <IconButton size="small" onClick={() => handleEdit(promo)}>
                        <Edit />
                      </IconButton>
                    </Tooltip>
                  )}
                  
                  {/* Approval buttons - Super Admin only for pending codes */}
                  {isSuperAdmin && promo.status === 'pendingApproval' && (
                    <>
                      <Tooltip title="Approve">
                        <IconButton 
                          size="small" 
                          color="success"
                          onClick={() => handleApproval(promo.id, 'active')}
                        >
                          <Check />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Reject">
                        <IconButton 
                          size="small" 
                          color="error"
                          onClick={() => {
                            const reason = prompt('Rejection reason:');
                            if (reason) handleApproval(promo.id, 'rejected', reason);
                          }}
                        >
                          <Close />
                        </IconButton>
                      </Tooltip>
                    </>
                  )}
                  
                  {/* Delete button - only for draft/rejected codes */}
                  {(promo.status === 'pendingApproval' || promo.status === 'rejected') && (
                    <Tooltip title="Delete">
                      <IconButton size="small" color="error" onClick={() => handleDelete(promo.id)}>
                        <Delete />
                      </IconButton>
                    </Tooltip>
                  )}
                </Box>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <LinearProgress sx={{ width: '100%' }} />
      </Box>
    );
  }

  return (
    <Box sx={{ flexGrow: 1 }}>
      {/* Header */}
      <Box display="flex" justifyContent="between" alignItems="center" mb={3}>
        <Typography variant="h4" gutterBottom>
          🎫 Promo Code Management
        </Typography>
        <Typography variant="body1" color="textSecondary">
          {isSuperAdmin ? 
            'Manage promotional codes with approval workflow' : 
            `Create and manage promo codes for ${getCountryDisplayName(userCountry)}`
          }
        </Typography>
      </Box>

      {/* Info Alert for Country Admins */}
      {!isSuperAdmin && (
        <Alert severity="info" sx={{ mb: 3 }}>
          <Typography variant="body2">
            <strong>Country Admin Access:</strong> You can create promo codes for {getCountryDisplayName(userCountry)}. 
            All promo codes require super admin approval before becoming active.
          </Typography>
        </Alert>
      )}

      {/* Analytics Cards */}
      {renderAnalyticsCards()}

      {/* Action Buttons and Filters */}
      <Box display="flex" justifyContent="between" alignItems="center" mb={3} flexWrap="wrap" gap={2}>
        <Box display="flex" gap={2} alignItems="center" flexWrap="wrap">
          <Button
            variant="contained"
            startIcon={<Add />}
            onClick={() => setOpen(true)}
          >
            Create Promo Code
          </Button>
          
          {/* Search */}
          <TextField
            size="small"
            placeholder="Search promo codes..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <Search />
                </InputAdornment>
              )
            }}
            sx={{ minWidth: 200 }}
          />
        </Box>

        <Box display="flex" gap={2} alignItems="center" flexWrap="wrap">
          {/* Status Filter */}
          <FormControl size="small" sx={{ minWidth: 120 }}>
            <InputLabel>Status</InputLabel>
            <Select
              value={statusFilter}
              label="Status"
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <MenuItem value="all">All Status</MenuItem>
              <MenuItem value="pendingApproval">Pending</MenuItem>
              <MenuItem value="active">Active</MenuItem>
              <MenuItem value="rejected">Rejected</MenuItem>
              <MenuItem value="disabled">Disabled</MenuItem>
              <MenuItem value="expired">Expired</MenuItem>
            </Select>
          </FormControl>

          {/* Country Filter - Super Admin Only */}
          {isSuperAdmin && (
            <FormControl size="small" sx={{ minWidth: 120 }}>
              <InputLabel>Country</InputLabel>
              <Select
                value={countryFilter}
                label="Country"
                onChange={(e) => setCountryFilter(e.target.value)}
              >
                <MenuItem value="all">All Countries</MenuItem>
                {filteredCountries.map(country => (
                  <MenuItem key={country.code} value={country.code}>
                    {country.name}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          )}
        </Box>
      </Box>

      {/* Tabs */}
      <Card>
        <Tabs 
          value={activeTab} 
          onChange={(e, newValue) => setActiveTab(newValue)}
          variant="scrollable"
          scrollButtons="auto"
        >
          <Tab 
            label={isSuperAdmin ? "All Promo Codes" : "My Promo Codes"} 
            icon={<LocalOffer />} 
          />
          <Tab 
            label={isSuperAdmin ? "Pending Approval" : "Active Codes"}
            icon={isSuperAdmin ? <Pending /> : <CheckCircle />}
            {...(isSuperAdmin && analytics.totalPending > 0 && {
              iconPosition: 'start',
              icon: <Badge badgeContent={analytics.totalPending} color="warning"><Pending /></Badge>
            })}
          />
          {isSuperAdmin && (
            <Tab label="Active Codes" icon={<CheckCircle />} />
          )}
          {isSuperAdmin && (
            <Tab label="Analytics" icon={<Analytics />} />
          )}
        </Tabs>

        <CardContent>
          {/* Tab Content */}
          {activeTab < 3 && renderPromoCodesTable()}
          
          {/* Analytics Tab Content */}
          {activeTab === 3 && isSuperAdmin && (
            <Box>
              <Typography variant="h6" gutterBottom>
                📊 Detailed Analytics
              </Typography>
              <Typography variant="body2" color="textSecondary">
                Comprehensive promo code analytics and reporting coming soon...
              </Typography>
            </Box>
          )}
        </CardContent>
      </Card>

      {/* Create/Edit Dialog */}
      <Dialog open={open} onClose={handleClose} maxWidth="md" fullWidth>
        <DialogTitle>
          {editingPromoCode ? 'Edit Promo Code' : 'Create New Promo Code'}
        </DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            {/* Promo Code */}
            <Grid item xs={12} sm={8}>
              <TextField
                fullWidth
                label="Promo Code *"
                value={formData.code}
                onChange={(e) => setFormData({ ...formData, code: e.target.value.toUpperCase() })}
                placeholder="e.g., WELCOME2025"
              />
            </Grid>
            <Grid item xs={12} sm={4}>
              <Button 
                fullWidth 
                variant="outlined" 
                onClick={generatePromoCode}
                sx={{ height: '56px' }}
              >
                Generate Code
              </Button>
            </Grid>

            {/* Title */}
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Title *"
                value={formData.title}
                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                placeholder="e.g., Welcome Discount"
              />
            </Grid>

            {/* Description */}
            <Grid item xs={12}>
              <TextField
                fullWidth
                multiline
                rows={3}
                label="Description"
                value={formData.description}
                onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                placeholder="Describe the promo code benefits..."
              />
            </Grid>

            {/* Type and Value */}
            <Grid item xs={12} sm={6}>
              <FormControl fullWidth>
                <InputLabel>Discount Type *</InputLabel>
                <Select
                  value={formData.type}
                  label="Discount Type *"
                  onChange={(e) => setFormData({ ...formData, type: e.target.value })}
                >
                  {promoTypes.map(type => (
                    <MenuItem key={type.value} value={type.value}>
                      <Box display="flex" alignItems="center" gap={1}>
                        {type.icon}
                        {type.label}
                      </Box>
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label={
                  formData.type === 'percentageDiscount' ? 'Discount Percentage' :
                  formData.type === 'fixedDiscount' ? 'Discount Amount' :
                  formData.type === 'freeTrialExtension' ? 'Extension Days' :
                  'Value'
                }
                type="number"
                value={formData.value}
                onChange={(e) => setFormData({ ...formData, value: e.target.value })}
                InputProps={{
                  endAdornment: (
                    <InputAdornment position="end">
                      {formData.type === 'percentageDiscount' ? '%' :
                       formData.type === 'fixedDiscount' ? '$' :
                       formData.type === 'freeTrialExtension' ? 'days' : ''}
                    </InputAdornment>
                  )
                }}
              />
            </Grid>

            {/* Usage Limits */}
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="Max Total Uses"
                type="number"
                value={formData.maxUses}
                onChange={(e) => setFormData({ ...formData, maxUses: e.target.value })}
                placeholder="Leave empty for unlimited"
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="Max Uses Per User"
                type="number"
                value={formData.maxUsesPerUser}
                onChange={(e) => setFormData({ ...formData, maxUsesPerUser: parseInt(e.target.value) || 1 })}
              />
            </Grid>

            {/* Minimum Order Value */}
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="Minimum Order Value"
                type="number"
                value={formData.minOrderValue}
                onChange={(e) => setFormData({ ...formData, minOrderValue: e.target.value })}
                InputProps={{
                  startAdornment: <InputAdornment position="start">$</InputAdornment>
                }}
                placeholder="0.00"
              />
            </Grid>

            {/* Countries */}
            <Grid item xs={12} sm={6}>
              <FormControl fullWidth>
                <InputLabel>Countries</InputLabel>
                <Select
                  multiple
                  value={formData.countries}
                  label="Countries"
                  onChange={(e) => setFormData({ ...formData, countries: e.target.value })}
                  disabled={!isSuperAdmin}
                  renderValue={(selected) => (
                    <Box display="flex" flexWrap="wrap" gap={0.5}>
                      {selected.map(country => (
                        <Chip key={country} label={getCountryDisplayName(country)} size="small" />
                      ))}
                    </Box>
                  )}
                >
                  {filteredCountries.map(country => (
                    <MenuItem key={country.code} value={country.code}>
                      {country.name}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>

            {/* Date Range */}
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="Start Date"
                type="datetime-local"
                value={formData.startDate}
                onChange={(e) => setFormData({ ...formData, startDate: e.target.value })}
                InputLabelProps={{ shrink: true }}
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="End Date"
                type="datetime-local"
                value={formData.endDate}
                onChange={(e) => setFormData({ ...formData, endDate: e.target.value })}
                InputLabelProps={{ shrink: true }}
              />
            </Grid>

            {/* Status Info */}
            {!isSuperAdmin && (
              <Grid item xs={12}>
                <Alert severity="info">
                  <Typography variant="body2">
                    <strong>Approval Required:</strong> This promo code will be submitted for super admin approval. 
                    It will become active only after approval.
                  </Typography>
                </Alert>
              </Grid>
            )}
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleClose}>Cancel</Button>
          <Button 
            variant="contained" 
            onClick={handleSubmit}
            disabled={!formData.code || !formData.title || !formData.value}
          >
            {editingPromoCode ? 'Update' : 'Create'} Promo Code
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default PromoCodes;
