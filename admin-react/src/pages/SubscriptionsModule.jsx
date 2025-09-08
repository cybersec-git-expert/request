import React, { useState, useEffect } from 'react';
import {
  Box,
  Paper,
  Typography,
  Tabs,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Button,
  Chip,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Alert,
  CircularProgress,
  Grid,
  Card,
  CardContent,
  CardActions,
  IconButton
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  Visibility as ViewIcon,
  Person as PersonIcon,
  Business as BusinessIcon,
  DirectionsCar as CarIcon,
  TrendingUp as TrendingUpIcon
} from '@mui/icons-material';
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter';

function TabPanel(props) {
  const { children, value, index, ...other } = props;

  return (
    <div
      role="tabpanel"
      hidden={value !== index}
      id={`simple-tabpanel-${index}`}
      aria-labelledby={`simple-tab-${index}`}
      {...other}
    >
      {value === index && (
        <Box sx={{ p: 3 }}>
          {children}
        </Box>
      )}
    </div>
  );
}

const SubscriptionsModule = () => {
  const [tabValue, setTabValue] = useState(0);
  const [subscriptions, setSubscriptions] = useState([]);
  const [subscriptionPlans, setSubscriptionPlans] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingSubscription, setEditingSubscription] = useState(null);
  const [stats, setStats] = useState({
    totalSubscriptions: 0,
    activeSubscriptions: 0,
    trialSubscriptions: 0,
    totalRevenue: 0
  });

  const { adminData, countryCode, isSuperAdmin } = useCountryFilter();

  const [formData, setFormData] = useState({
    planName: '',
    type: 'individual',
    monthlyPrice: 0,
    yearlyPrice: 0,
    features: [],
    isActive: true,
    countryCode: countryCode || 'LK'
  });

  useEffect(() => {
    fetchSubscriptions();
    fetchSubscriptionPlans();
    calculateStats();
  }, [countryCode]);

  const fetchSubscriptions = async () => {
    setLoading(true);
    try {
      const params = {};
      if (!isSuperAdmin && countryCode) params.country = countryCode;
      const { data } = await api.get('/user-subscriptions', { params });
      setSubscriptions(Array.isArray(data) ? data : data?.items || []);
    } catch (error) {
      setError('Failed to fetch subscriptions');
      console.error('Error fetching subscriptions:', error);
    }
    setLoading(false);
  };

  const fetchSubscriptionPlans = async () => {
    try {
      const params = {};
      if (!isSuperAdmin && countryCode) params.country = countryCode;
      const { data } = await api.get('/subscription-plans', { params });
      setSubscriptionPlans(Array.isArray(data) ? data : data?.items || []);
    } catch (error) {
      setError('Failed to fetch subscription plans');
      console.error('Error fetching subscription plans:', error);
    }
  };

  const calculateStats = async () => {
    try {
      const params = {};
      if (!isSuperAdmin && countryCode) params.country = countryCode;
      const { data } = await api.get('/subscription-stats', { params });
      setStats({
        totalSubscriptions: data?.totalSubscriptions || 0,
        activeSubscriptions: data?.activeSubscriptions || 0,
        trialSubscriptions: data?.trialSubscriptions || 0,
        totalRevenue: data?.totalRevenue || 0
      });
    } catch (error) {
      console.error('Error calculating stats:', error);
    }
  };

  const handleCreatePlan = async () => {
    setLoading(true);
    try {
      const planData = {
        ...formData,
        countryCode: countryCode || 'LK'
      };
      await api.post('/subscription-plans', planData);
      setSuccess('Subscription plan created successfully');
      setDialogOpen(false);
      resetForm();
      fetchSubscriptionPlans();
    } catch (error) {
      setError('Failed to create subscription plan');
      console.error('Error creating plan:', error);
    }
    setLoading(false);
  };

  const handleUpdatePlan = async () => {
    setLoading(true);
    try {
      await api.put(`/subscription-plans/${editingSubscription.id}`, formData);
      setSuccess('Subscription plan updated successfully');
      setDialogOpen(false);
      resetForm();
      fetchSubscriptionPlans();
    } catch (error) {
      setError('Failed to update subscription plan');
      console.error('Error updating plan:', error);
    }
    setLoading(false);
  };

  const handleDeletePlan = async (planId) => {
    if (window.confirm('Are you sure you want to delete this subscription plan?')) {
      try {
        await api.delete(`/subscription-plans/${planId}`);
        setSuccess('Subscription plan deleted successfully');
        fetchSubscriptionPlans();
      } catch (error) {
        setError('Failed to delete subscription plan');
        console.error('Error deleting plan:', error);
      }
    }
  };

  const resetForm = () => {
    setFormData({
      planName: '',
      type: 'individual',
      monthlyPrice: 0,
      yearlyPrice: 0,
      features: [],
      isActive: true,
      countryCode: countryCode || 'LK'
    });
    setEditingSubscription(null);
  };

  const openCreateDialog = () => {
    resetForm();
    setDialogOpen(true);
  };

  const openEditDialog = (plan) => {
    setFormData({
      planName: plan.planName || '',
      type: plan.type || 'individual',
      monthlyPrice: plan.monthlyPrice || 0,
      yearlyPrice: plan.yearlyPrice || 0,
      features: plan.features || [],
      isActive: plan.isActive !== false,
      countryCode: plan.countryCode || countryCode
    });
    setEditingSubscription(plan);
    setDialogOpen(true);
  };

  const getStatusChip = (status) => {
    const statusConfig = {
      active: { color: 'success', label: 'Active' },
      trial: { color: 'info', label: 'Trial' },
      expired: { color: 'error', label: 'Expired' },
      cancelled: { color: 'default', label: 'Cancelled' }
    };
    
    const config = statusConfig[status] || statusConfig.cancelled;
    return <Chip label={config.label} color={config.color} size="small" />;
  };

  const getTypeIcon = (type) => {
    switch (type) {
      case 'individual': return <PersonIcon />;
      case 'business': return <BusinessIcon />;
      case 'driver': return <CarIcon />;
      default: return <PersonIcon />;
    }
  };

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Subscription Management
      </Typography>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {success && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccess(null)}>
          {success}
        </Alert>
      )}

      {/* Statistics Cards */}
      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center">
                <PersonIcon sx={{ mr: 2, color: 'primary.main' }} />
                <Box>
                  <Typography variant="h6">{stats.totalSubscriptions}</Typography>
                  <Typography variant="body2" color="textSecondary">
                    Total Subscriptions
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center">
                <TrendingUpIcon sx={{ mr: 2, color: 'success.main' }} />
                <Box>
                  <Typography variant="h6">{stats.activeSubscriptions}</Typography>
                  <Typography variant="body2" color="textSecondary">
                    Active Subscriptions
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center">
                <ViewIcon sx={{ mr: 2, color: 'info.main' }} />
                <Box>
                  <Typography variant="h6">{stats.trialSubscriptions}</Typography>
                  <Typography variant="body2" color="textSecondary">
                    Trial Subscriptions
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center">
                <BusinessIcon sx={{ mr: 2, color: 'warning.main' }} />
                <Box>
                  <Typography variant="h6">${stats.totalRevenue}</Typography>
                  <Typography variant="body2" color="textSecondary">
                    Monthly Revenue
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      <Paper sx={{ width: '100%' }}>
        <Box sx={{ borderBottom: 1, borderColor: 'divider' }}>
          <Tabs value={tabValue} onChange={(e, newValue) => setTabValue(newValue)}>
            <Tab label="Subscription Plans" />
            <Tab label="User Subscriptions" />
          </Tabs>
        </Box>

        {/* Subscription Plans Tab */}
        <TabPanel value={tabValue} index={0}>
          <Box sx={{ mb: 2, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <Typography variant="h6">Subscription Plans</Typography>
            <Button
              variant="contained"
              startIcon={<AddIcon />}
              onClick={openCreateDialog}
            >
              Create Plan
            </Button>
          </Box>

          {loading ? (
            <CircularProgress />
          ) : (
            <TableContainer>
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>Plan Name</TableCell>
                    <TableCell>Type</TableCell>
                    <TableCell>Monthly Price</TableCell>
                    <TableCell>Yearly Price</TableCell>
                    <TableCell>Status</TableCell>
                    <TableCell>Actions</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {subscriptionPlans.map((plan) => (
                    <TableRow key={plan.id}>
                      <TableCell>
                        <Box display="flex" alignItems="center">
                          {getTypeIcon(plan.type)}
                          <Box ml={1}>
                            <Typography variant="subtitle2">{plan.planName}</Typography>
                          </Box>
                        </Box>
                      </TableCell>
                      <TableCell>
                        <Chip label={plan.type} size="small" />
                      </TableCell>
                      <TableCell>${plan.monthlyPrice || 0}</TableCell>
                      <TableCell>${plan.yearlyPrice || 0}</TableCell>
                      <TableCell>
                        {getStatusChip(plan.isActive ? 'active' : 'inactive')}
                      </TableCell>
                      <TableCell>
                        <IconButton onClick={() => openEditDialog(plan)} size="small">
                          <EditIcon />
                        </IconButton>
                        <IconButton onClick={() => handleDeletePlan(plan.id)} size="small">
                          <DeleteIcon />
                        </IconButton>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </TabPanel>

        {/* User Subscriptions Tab */}
        <TabPanel value={tabValue} index={1}>
          <Typography variant="h6" sx={{ mb: 2 }}>User Subscriptions</Typography>

          {loading ? (
            <CircularProgress />
          ) : (
            <TableContainer>
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>User</TableCell>
                    <TableCell>Plan</TableCell>
                    <TableCell>Type</TableCell>
                    <TableCell>Status</TableCell>
                    <TableCell>Start Date</TableCell>
                    <TableCell>End Date</TableCell>
                    <TableCell>Country</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {subscriptions.map((subscription) => (
                    <TableRow key={subscription.id}>
                      <TableCell>{subscription.userId || 'N/A'}</TableCell>
                      <TableCell>{subscription.planId || 'N/A'}</TableCell>
                      <TableCell>
                        <Box display="flex" alignItems="center">
                          {getTypeIcon(subscription.type)}
                          <Box ml={1}>
                            <Chip label={subscription.type} size="small" />
                          </Box>
                        </Box>
                      </TableCell>
                      <TableCell>{getStatusChip(subscription.status)}</TableCell>
                      <TableCell>
                        {subscription.trialStartDate 
                          ? new Date(subscription.trialStartDate).toLocaleDateString()
                          : 'N/A'}
                      </TableCell>
                      <TableCell>
                        {subscription.trialEndDate 
                          ? new Date(subscription.trialEndDate).toLocaleDateString()
                          : 'N/A'}
                      </TableCell>
                      <TableCell>{subscription.countryCode || 'N/A'}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </TabPanel>
      </Paper>

      {/* Create/Edit Plan Dialog */}
      <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          {editingSubscription ? 'Edit Subscription Plan' : 'Create Subscription Plan'}
        </DialogTitle>
        <DialogContent>
          <Box sx={{ pt: 1 }}>
            <TextField
              fullWidth
              label="Plan Name"
              value={formData.planName}
              onChange={(e) => setFormData({ ...formData, planName: e.target.value })}
              sx={{ mb: 2 }}
            />

            <FormControl fullWidth sx={{ mb: 2 }}>
              <InputLabel>Type</InputLabel>
              <Select
                value={formData.type}
                label="Type"
                onChange={(e) => setFormData({ ...formData, type: e.target.value })}
              >
                <MenuItem value="individual">Individual</MenuItem>
                <MenuItem value="business">Business</MenuItem>
                <MenuItem value="driver">Driver</MenuItem>
              </Select>
            </FormControl>

            <TextField
              fullWidth
              label="Monthly Price"
              type="number"
              value={formData.monthlyPrice}
              onChange={(e) => setFormData({ ...formData, monthlyPrice: parseFloat(e.target.value) })}
              sx={{ mb: 2 }}
            />

            <TextField
              fullWidth
              label="Yearly Price"
              type="number"
              value={formData.yearlyPrice}
              onChange={(e) => setFormData({ ...formData, yearlyPrice: parseFloat(e.target.value) })}
              sx={{ mb: 2 }}
            />

            <TextField
              fullWidth
              label="Country Code"
              value={formData.countryCode}
              onChange={(e) => setFormData({ ...formData, countryCode: e.target.value })}
              disabled={!isSuperAdmin}
            />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDialogOpen(false)}>Cancel</Button>
          <Button
            onClick={editingSubscription ? handleUpdatePlan : handleCreatePlan}
            variant="contained"
            disabled={loading}
          >
            {loading ? <CircularProgress size={24} /> : (editingSubscription ? 'Update' : 'Create')}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default SubscriptionsModule;
