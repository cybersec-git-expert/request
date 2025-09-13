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
  LinearProgress,
  Divider
} from '@mui/material';
import {
  Add,
  Edit,
  Delete,
  Visibility,
  Check,
  Close,
  LocalOffer,
  Schedule,
  CheckCircle,
  Cancel,
  People,
  Analytics,
  Search,
  Star,
  Timer
} from '@mui/icons-material';
import api from '../services/apiClient';

const SubscriptionPromoCodes = () => {
  // State management
  const [promoCodes, setPromoCodes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState(false);
  const [editingPromoCode, setEditingPromoCode] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  
  // Analytics state
  const [analytics, setAnalytics] = useState({
    totalActive: 0,
    totalRedemptions: 0,
    totalUsers: 0
  });

  // Form state
  const [formData, setFormData] = useState({
    code: '',
    name: '',
    description: '',
    benefit_type: 'free_plan',
    benefit_duration_days: 30,
    benefit_plan_code: 'Pro',
    discount_percentage: null,
    max_uses: '',
    max_uses_per_user: 1,
    valid_from: '',
    valid_until: '',
    is_active: true
  });

  // Benefit types
  const benefitTypes = [
    { value: 'free_plan', label: 'Free Plan Access', icon: <Star /> },
    { value: 'discount', label: 'Subscription Discount', icon: <LocalOffer /> },
    { value: 'extension', label: 'Plan Extension', icon: <Timer /> }
  ];

  // Plan codes available
  const planCodes = ['Pro', 'Premium', 'Enterprise'];

  // Load promo codes
  const fetchPromoCodes = async () => {
    try {
      setLoading(true);
      const response = await api.get('/promo-codes/admin/list');
      if (response.data?.success) {
        setPromoCodes(response.data.codes || []);
        calculateAnalytics(response.data.codes || []);
      }
    } catch (error) {
      console.error('Error fetching promo codes:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPromoCodes();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const calculateAnalytics = (codes) => {
    const totalActive = codes.filter(code => 
      code.is_active && 
      new Date(code.valid_until || '9999-12-31') > new Date()
    ).length;
    
    const totalRedemptions = codes.reduce((sum, code) => sum + (code.current_uses || 0), 0);
    
    const uniqueUsers = new Set();
    codes.forEach(code => {
      if (code.redemptions) {
        code.redemptions.forEach(redemption => uniqueUsers.add(redemption.user_id));
      }
    });

    setAnalytics({
      totalActive,
      totalRedemptions,
      totalUsers: uniqueUsers.size
    });
  };

  // Filter promo codes
  const filteredPromoCodes = promoCodes.filter(promo => 
    !searchQuery || 
    promo.code?.toLowerCase().includes(searchQuery.toLowerCase()) ||
    promo.name?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  // Reset form
  const resetForm = () => {
    setFormData({
      code: '',
      name: '',
      description: '',
      benefit_type: 'free_plan',
      benefit_duration_days: 30,
      benefit_plan_code: 'Pro',
      discount_percentage: null,
      max_uses: '',
      max_uses_per_user: 1,
      valid_from: '',
      valid_until: '',
      is_active: true
    });
  };

  // Handle form submission
  const handleSubmit = async () => {
    try {
      const payload = {
        ...formData,
        benefit_duration_days: parseInt(formData.benefit_duration_days) || 30,
        discount_percentage: formData.benefit_type === 'discount' 
          ? parseFloat(formData.discount_percentage) 
          : null,
        max_uses: formData.max_uses ? parseInt(formData.max_uses) : null,
        max_uses_per_user: parseInt(formData.max_uses_per_user) || 1
      };

      if (editingPromoCode) {
        await api.put(`/promo-codes/admin/${editingPromoCode.id}`, payload);
      } else {
        await api.post('/promo-codes/admin/create', payload);
      }
      
      handleClose();
      await fetchPromoCodes();
    } catch (error) {
      console.error('Error saving promo code:', error);
    }
  };

  // Handle edit
  const handleEdit = (promoCode) => {
    setEditingPromoCode(promoCode);
    setFormData({
      code: promoCode.code || '',
      name: promoCode.name || '',
      description: promoCode.description || '',
      benefit_type: promoCode.benefit_type || 'free_plan',
      benefit_duration_days: promoCode.benefit_duration_days || 30,
      benefit_plan_code: promoCode.benefit_plan_code || 'Pro',
      discount_percentage: promoCode.discount_percentage || '',
      max_uses: promoCode.max_uses?.toString() || '',
      max_uses_per_user: promoCode.max_uses_per_user || 1,
      valid_from: promoCode.valid_from?.split('T')[0] || '',
      valid_until: promoCode.valid_until?.split('T')[0] || '',
      is_active: promoCode.is_active !== false
    });
    setOpen(true);
  };

  // Handle delete
  const handleDelete = async (promoCodeId) => {
    if (!window.confirm('Are you sure you want to delete this promo code?')) return;
    try {
      await api.delete(`/promo-codes/admin/${promoCodeId}`);
      await fetchPromoCodes();
    } catch (error) {
      console.error('Error deleting promo code:', error);
    }
  };

  // Handle open/close dialog
  const handleOpen = () => {
    resetForm();
    setEditingPromoCode(null);
    setOpen(true);
  };

  const handleClose = () => {
    setOpen(false);
    setEditingPromoCode(null);
    resetForm();
  };

  // Format date for display
  const formatDate = (dateString) => {
    if (!dateString) return 'No expiry';
    return new Date(dateString).toLocaleDateString();
  };

  // Get status chip
  const getStatusChip = (promoCode) => {
    const now = new Date();
    const validFrom = new Date(promoCode.valid_from || '1970-01-01');
    const validUntil = promoCode.valid_until ? new Date(promoCode.valid_until) : null;
    
    if (!promoCode.is_active) {
      return <Chip label="Inactive" color="default" size="small" />;
    }
    if (now < validFrom) {
      return <Chip label="Scheduled" color="info" size="small" />;
    }
    if (validUntil && now > validUntil) {
      return <Chip label="Expired" color="error" size="small" />;
    }
    if (promoCode.max_uses && promoCode.current_uses >= promoCode.max_uses) {
      return <Chip label="Limit Reached" color="warning" size="small" />;
    }
    return <Chip label="Active" color="success" size="small" />;
  };

  // Generate random promo code
  const generatePromoCode = () => {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let result = '';
    for (let i = 0; i < 8; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    setFormData(prev => ({ ...prev, code: result }));
  };

  if (loading) {
    return <LinearProgress />;
  }

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" gutterBottom>
        Subscription Promo Codes
      </Typography>

      {/* Analytics Cards */}
      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center">
                <CheckCircle color="success" sx={{ mr: 1 }} />
                <Box>
                  <Typography variant="h6">{analytics.totalActive}</Typography>
                  <Typography variant="body2" color="textSecondary">
                    Active Codes
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center">
                <LocalOffer color="primary" sx={{ mr: 1 }} />
                <Box>
                  <Typography variant="h6">{analytics.totalRedemptions}</Typography>
                  <Typography variant="body2" color="textSecondary">
                    Total Redemptions
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center">
                <People color="info" sx={{ mr: 1 }} />
                <Box>
                  <Typography variant="h6">{analytics.totalUsers}</Typography>
                  <Typography variant="body2" color="textSecondary">
                    Users Benefited
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Controls */}
      <Box display="flex" justifyContent="space-between" alignItems="center" sx={{ mb: 2 }}>
        <TextField
          label="Search Promo Codes"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          InputProps={{
            startAdornment: <Search sx={{ color: 'action.active', mr: 1 }} />
          }}
          sx={{ width: 300 }}
        />
        <Button
          variant="contained"
          startIcon={<Add />}
          onClick={handleOpen}
        >
          Create Promo Code
        </Button>
      </Box>

      {/* Promo Codes Table */}
      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Code</TableCell>
              <TableCell>Name</TableCell>
              <TableCell>Benefit</TableCell>
              <TableCell>Usage</TableCell>
              <TableCell>Valid Until</TableCell>
              <TableCell>Status</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredPromoCodes.map((promoCode) => (
              <TableRow key={promoCode.id}>
                <TableCell>
                  <Typography variant="body2" fontWeight="bold">
                    {promoCode.code}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Typography variant="body2">
                    {promoCode.name}
                  </Typography>
                  <Typography variant="caption" color="textSecondary">
                    {promoCode.description}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Box>
                    <Typography variant="body2">
                      {promoCode.benefit_type === 'free_plan' && 
                        `${promoCode.benefit_duration_days} days ${promoCode.benefit_plan_code}`}
                      {promoCode.benefit_type === 'discount' && 
                        `${promoCode.discount_percentage}% off`}
                      {promoCode.benefit_type === 'extension' && 
                        `+${promoCode.benefit_duration_days} days`}
                    </Typography>
                  </Box>
                </TableCell>
                <TableCell>
                  <Typography variant="body2">
                    {promoCode.current_uses || 0}
                    {promoCode.max_uses ? ` / ${promoCode.max_uses}` : ' / ∞'}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Typography variant="body2">
                    {formatDate(promoCode.valid_until)}
                  </Typography>
                </TableCell>
                <TableCell>
                  {getStatusChip(promoCode)}
                </TableCell>
                <TableCell align="right">
                  <Tooltip title="Edit">
                    <IconButton onClick={() => handleEdit(promoCode)}>
                      <Edit />
                    </IconButton>
                  </Tooltip>
                  <Tooltip title="Delete">
                    <IconButton onClick={() => handleDelete(promoCode.id)}>
                      <Delete />
                    </IconButton>
                  </Tooltip>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      {/* Create/Edit Dialog */}
      <Dialog open={open} onClose={handleClose} maxWidth="md" fullWidth>
        <DialogTitle>
          {editingPromoCode ? 'Edit Promo Code' : 'Create New Promo Code'}
        </DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            {/* Code */}
            <Grid item xs={12} md={8}>
              <TextField
                fullWidth
                label="Promo Code"
                value={formData.code}
                onChange={(e) => setFormData(prev => ({ ...prev, code: e.target.value.toUpperCase() }))}
                required
                helperText="Use uppercase letters and numbers only"
              />
            </Grid>
            <Grid item xs={12} md={4}>
              <Button 
                variant="outlined" 
                onClick={generatePromoCode}
                sx={{ height: '56px' }}
              >
                Generate
              </Button>
            </Grid>

            {/* Name and Description */}
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Display Name"
                value={formData.name}
                onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
                required
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Description"
                value={formData.description}
                onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
                multiline
                rows={2}
              />
            </Grid>

            {/* Benefit Type */}
            <Grid item xs={12} md={6}>
              <FormControl fullWidth>
                <InputLabel>Benefit Type</InputLabel>
                <Select
                  value={formData.benefit_type}
                  onChange={(e) => setFormData(prev => ({ ...prev, benefit_type: e.target.value }))}
                  label="Benefit Type"
                >
                  {benefitTypes.map((type) => (
                    <MenuItem key={type.value} value={type.value}>
                      <Box display="flex" alignItems="center">
                        {type.icon}
                        <Typography sx={{ ml: 1 }}>{type.label}</Typography>
                      </Box>
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>

            {/* Duration */}
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                label="Duration (Days)"
                type="number"
                value={formData.benefit_duration_days}
                onChange={(e) => setFormData(prev => ({ ...prev, benefit_duration_days: e.target.value }))}
                required
              />
            </Grid>

            {/* Plan Code (for free_plan type) */}
            {formData.benefit_type === 'free_plan' && (
              <Grid item xs={12} md={6}>
                <FormControl fullWidth>
                  <InputLabel>Plan Code</InputLabel>
                  <Select
                    value={formData.benefit_plan_code}
                    onChange={(e) => setFormData(prev => ({ ...prev, benefit_plan_code: e.target.value }))}
                    label="Plan Code"
                  >
                    {planCodes.map((plan) => (
                      <MenuItem key={plan} value={plan}>{plan}</MenuItem>
                    ))}
                  </Select>
                </FormControl>
              </Grid>
            )}

            {/* Discount Percentage (for discount type) */}
            {formData.benefit_type === 'discount' && (
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Discount Percentage"
                  type="number"
                  value={formData.discount_percentage}
                  onChange={(e) => setFormData(prev => ({ ...prev, discount_percentage: e.target.value }))}
                  required
                  inputProps={{ min: 1, max: 100 }}
                />
              </Grid>
            )}

            {/* Usage Limits */}
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                label="Max Total Uses"
                type="number"
                value={formData.max_uses}
                onChange={(e) => setFormData(prev => ({ ...prev, max_uses: e.target.value }))}
                helperText="Leave empty for unlimited"
              />
            </Grid>
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                label="Max Uses Per User"
                type="number"
                value={formData.max_uses_per_user}
                onChange={(e) => setFormData(prev => ({ ...prev, max_uses_per_user: e.target.value }))}
                required
                inputProps={{ min: 1 }}
              />
            </Grid>

            {/* Validity Dates */}
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                label="Valid From"
                type="date"
                value={formData.valid_from}
                onChange={(e) => setFormData(prev => ({ ...prev, valid_from: e.target.value }))}
                InputLabelProps={{ shrink: true }}
              />
            </Grid>
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                label="Valid Until"
                type="date"
                value={formData.valid_until}
                onChange={(e) => setFormData(prev => ({ ...prev, valid_until: e.target.value }))}
                InputLabelProps={{ shrink: true }}
                helperText="Leave empty for no expiry"
              />
            </Grid>

            {/* Active Toggle */}
            <Grid item xs={12}>
              <FormControlLabel
                control={
                  <Switch
                    checked={formData.is_active}
                    onChange={(e) => setFormData(prev => ({ ...prev, is_active: e.target.checked }))}
                  />
                }
                label="Active"
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleClose}>Cancel</Button>
          <Button onClick={handleSubmit} variant="contained">
            {editingPromoCode ? 'Update' : 'Create'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default SubscriptionPromoCodes;