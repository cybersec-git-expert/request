import React, { useState, useEffect, useCallback } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Button,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Chip,
  IconButton,
  Tabs,
  Tab,
  Grid,
  Alert,
  CircularProgress,
  Switch,
  FormControlLabel,
  Accordion,
  AccordionSummary,
  AccordionDetails,
  Divider,
  Tooltip
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  ExpandMore as ExpandMoreIcon,
  CheckCircle as CheckCircleIcon,
  Pending as PendingIcon,
  Block as BlockIcon,
  Analytics as AnalyticsIcon,
  LocalOffer as LocalOfferIcon,
  People as PeopleIcon,
  Approval as ApprovalIcon
} from '@mui/icons-material';
import { useAuth } from '../contexts/AuthContext';

// API service for subscription management
class SubscriptionAdminService {
  static baseUrl = process.env.REACT_APP_API_URL || 'http://localhost:3001/api';

  static async getPlans(country = null) {
    const params = country ? `?country=${country}` : '';
    const response = await fetch(`${this.baseUrl}/admin/subscription/plans${params}`, {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` }
    });
    if (!response.ok) throw new Error('Failed to fetch plans');
    return response.json();
  }

  static async createPlan(plan) {
    const response = await fetch(`${this.baseUrl}/admin/subscription/plans`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${localStorage.getItem('token')}`
      },
      body: JSON.stringify(plan)
    });
    if (!response.ok) throw new Error('Failed to create plan');
    return response.json();
  }

  static async updatePlan(code, plan) {
    const response = await fetch(`${this.baseUrl}/admin/subscription/plans/${code}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${localStorage.getItem('token')}`
      },
      body: JSON.stringify(plan)
    });
    if (!response.ok) throw new Error('Failed to update plan');
    return response.json();
  }

  static async setCountryPricing(code, pricing) {
    const response = await fetch(`${this.baseUrl}/admin/subscription/plans/${code}/pricing`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${localStorage.getItem('token')}`
      },
      body: JSON.stringify(pricing)
    });
    if (!response.ok) throw new Error('Failed to set pricing');
    return response.json();
  }

  static async approvePricing(code, country, active) {
    const response = await fetch(`${this.baseUrl}/admin/subscription/plans/${code}/pricing/${country}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${localStorage.getItem('token')}`
      },
      body: JSON.stringify({ is_active: active })
    });
    if (!response.ok) throw new Error('Failed to approve pricing');
    return response.json();
  }

  static async getPendingApprovals() {
    const response = await fetch(`${this.baseUrl}/admin/subscription/pending-approvals`, {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` }
    });
    if (!response.ok) throw new Error('Failed to fetch pending approvals');
    return response.json();
  }

  static async getAnalytics(country = null) {
    const params = country ? `?country=${country}` : '';
    const response = await fetch(`${this.baseUrl}/admin/subscription/analytics${params}`, {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` }
    });
    if (!response.ok) throw new Error('Failed to fetch analytics');
    return response.json();
  }

  static async getUserSubscriptions(filters = {}) {
    const params = new URLSearchParams(filters).toString();
    const response = await fetch(`${this.baseUrl}/admin/subscription/users?${params}`, {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` }
    });
    if (!response.ok) throw new Error('Failed to fetch user subscriptions');
    return response.json();
  }
}

function TabPanel({ children, value, index, ...other }) {
  return (
    <div
      role="tabpanel"
      hidden={value !== index}
      id={`subscription-tabpanel-${index}`}
      aria-labelledby={`subscription-tab-${index}`}
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

export default function SimpleSubscriptionAdmin() {
  const { user, isSuperAdmin, isCountryAdmin } = useAuth();
  const [tabValue, setTabValue] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Plans management
  const [plans, setPlans] = useState([]);
  const [planDialog, setPlanDialog] = useState(false);
  const [editingPlan, setEditingPlan] = useState(null);
  const [planForm, setPlanForm] = useState({
    code: '',
    name: '',
    description: '',
    price: 0,
    currency: 'USD',
    response_limit: 3,
    features: []
  });

  // Country pricing management
  const [countryPricingDialog, setCountryPricingDialog] = useState(false);
  const [selectedPlan, setSelectedPlan] = useState(null);
  const [pricingForm, setPricingForm] = useState({
    country_code: '',
    price: 0
  });

  // Pending approvals
  const [pendingApprovals, setPendingApprovals] = useState([]);

  // Analytics
  const [analytics, setAnalytics] = useState(null);

  // User subscriptions
  const [userSubscriptions, setUserSubscriptions] = useState([]);

  const loadPlansCallback = useCallback(async () => {
    try {
      setLoading(true);
      const country = isCountryAdmin ? user?.country_code : null;
      const result = await SubscriptionAdminService.getPlans(country);
      setPlans(result.data || []);
    } catch (err) {
      setError('Failed to load plans: ' + err.message);
    } finally {
      setLoading(false);
    }
  }, [isCountryAdmin, user?.country_code]);

  const loadPendingApprovalsCallback = useCallback(async () => {
    try {
      const result = await SubscriptionAdminService.getPendingApprovals();
      setPendingApprovals(result.data || []);
    } catch (err) {
      console.error('Failed to load pending approvals:', err);
    }
  }, []);

  const loadAnalyticsCallback = useCallback(async () => {
    try {
      const country = isCountryAdmin ? user?.country_code : null;
      const result = await SubscriptionAdminService.getAnalytics(country);
      setAnalytics(result.data || {});
    } catch (err) {
      console.error('Failed to load analytics:', err);
    }
  }, [isCountryAdmin, user?.country_code]);

  useEffect(() => {
    if (isSuperAdmin || isCountryAdmin) {
      loadPlansCallback();
      if (isSuperAdmin) {
        loadPendingApprovalsCallback();
      }
      loadAnalyticsCallback();
    }
  }, [isSuperAdmin, isCountryAdmin, loadPlansCallback, loadPendingApprovalsCallback, loadAnalyticsCallback]);

  const loadUserSubscriptions = async () => {
    try {
      setLoading(true);
      const filters = {};
      if (isCountryAdmin) filters.country = user?.country_code;
      const result = await SubscriptionAdminService.getUserSubscriptions(filters);
      setUserSubscriptions(result.data || []);
    } catch (err) {
      setError('Failed to load user subscriptions: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleCreatePlan = async () => {
    try {
      setLoading(true);
      if (editingPlan) {
        await SubscriptionAdminService.updatePlan(editingPlan.code, planForm);
        setSuccess('Plan updated successfully');
      } else {
        await SubscriptionAdminService.createPlan(planForm);
        setSuccess('Plan created successfully');
      }
      setPlanDialog(false);
      setEditingPlan(null);
      resetPlanForm();
      loadPlansCallback();
    } catch (err) {
      setError('Failed to save plan: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSetCountryPricing = async () => {
    try {
      setLoading(true);
      await SubscriptionAdminService.setCountryPricing(selectedPlan.code, pricingForm);
      setSuccess('Pricing submitted for approval');
      setCountryPricingDialog(false);
      setSelectedPlan(null);
      setPricingForm({ country_code: '', price: 0 });
      loadPlansCallback();
    } catch (err) {
      setError('Failed to set pricing: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleApprovePricing = async (code, country, active) => {
    try {
      await SubscriptionAdminService.approvePricing(code, country, active);
      setSuccess(`Pricing ${active ? 'approved' : 'rejected'} successfully`);
      loadPendingApprovalsCallback();
      loadPlansCallback();
    } catch (err) {
      setError('Failed to update approval: ' + err.message);
    }
  };

  const openPlanDialog = (plan = null) => {
    if (plan) {
      setEditingPlan(plan);
      setPlanForm({
        code: plan.code,
        name: plan.name,
        description: plan.description || '',
        price: plan.price,
        currency: plan.currency,
        response_limit: plan.response_limit,
        features: plan.features || []
      });
    } else {
      setEditingPlan(null);
      resetPlanForm();
    }
    setPlanDialog(true);
  };

  const openCountryPricingDialog = (plan) => {
    setSelectedPlan(plan);
    setPricingForm({
      country_code: isCountryAdmin ? user?.country_code : '',
      price: plan.price
    });
    setCountryPricingDialog(true);
  };

  const resetPlanForm = () => {
    setPlanForm({
      code: '',
      name: '',
      description: '',
      price: 0,
      currency: 'USD',
      response_limit: 3,
      features: []
    });
  };

  const getStatusChip = (status, isActive) => {
    if (status === 'pending' || !isActive) {
      return <Chip icon={<PendingIcon />} label="Pending" color="warning" size="small" />;
    }
    return <Chip icon={<CheckCircleIcon />} label="Active" color="success" size="small" />;
  };

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" gutterBottom>
        Subscription Management
      </Typography>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>
          {error}
        </Alert>
      )}

      {success && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccess('')}>
          {success}
        </Alert>
      )}

      <Box sx={{ borderBottom: 1, borderColor: 'divider', mb: 3 }}>
        <Tabs value={tabValue} onChange={(e, v) => setTabValue(v)}>
          <Tab icon={<LocalOfferIcon />} label="Plans" />
          {isSuperAdmin && <Tab icon={<ApprovalIcon />} label="Approvals" />}
          <Tab icon={<AnalyticsIcon />} label="Analytics" />
          <Tab icon={<PeopleIcon />} label="Users" onClick={loadUserSubscriptions} />
        </Tabs>
      </Box>

      {/* Plans Tab */}
      <TabPanel value={tabValue} index={0}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 3 }}>
          <Typography variant="h6">Subscription Plans</Typography>
          {isSuperAdmin && (
            <Button
              variant="contained"
              startIcon={<AddIcon />}
              onClick={() => openPlanDialog()}
            >
              Create Plan
            </Button>
          )}
        </Box>

        {loading ? (
          <CircularProgress />
        ) : (
          <Grid container spacing={3}>
            {plans.map((plan) => (
              <Grid item xs={12} md={6} lg={4} key={plan.code}>
                <Card>
                  <CardContent>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 2 }}>
                      <Typography variant="h6" color="primary">
                        {plan.name}
                      </Typography>
                      {getStatusChip('active', plan.is_active)}
                    </Box>

                    <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                      {plan.description}
                    </Typography>

                    <Box sx={{ display: 'flex', alignItems: 'baseline', mb: 2 }}>
                      <Typography variant="h4" color="primary">
                        {plan.currency} {plan.price}
                      </Typography>
                      <Typography variant="body2" color="text.secondary" sx={{ ml: 1 }}>
                        {plan.price === 0 ? '' : '/month'}
                      </Typography>
                    </Box>

                    <Chip
                      label={plan.response_limit === -1 ? 'Unlimited responses' : `${plan.response_limit} responses/month`}
                      variant="outlined"
                      sx={{ mb: 2 }}
                    />

                    <Box sx={{ mt: 2 }}>
                      {isSuperAdmin && (
                        <IconButton onClick={() => openPlanDialog(plan)} size="small">
                          <EditIcon />
                        </IconButton>
                      )}
                      {isCountryAdmin && (
                        <Button
                          size="small"
                          variant="outlined"
                          onClick={() => openCountryPricingDialog(plan)}
                          sx={{ ml: 1 }}
                        >
                          Set Local Price
                        </Button>
                      )}
                    </Box>

                    {/* Country Pricing Display */}
                    {plan.country_pricing && plan.country_pricing.length > 0 && (
                      <Accordion sx={{ mt: 2 }}>
                        <AccordionSummary expandIcon={<ExpandMoreIcon />}>
                          <Typography variant="body2">Country Pricing</Typography>
                        </AccordionSummary>
                        <AccordionDetails>
                          {plan.country_pricing.map((pricing) => (
                            <Box key={pricing.country_code} sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', py: 0.5 }}>
                              <Typography variant="body2">
                                {pricing.country_code}: {pricing.currency} {pricing.price}
                              </Typography>
                              {getStatusChip('status', pricing.is_active)}
                              {isSuperAdmin && pricing.pending_approval && (
                                <Box>
                                  <IconButton
                                    size="small"
                                    color="success"
                                    onClick={() => handleApprovePricing(plan.code, pricing.country_code, true)}
                                  >
                                    <CheckCircleIcon />
                                  </IconButton>
                                  <IconButton
                                    size="small"
                                    color="error"
                                    onClick={() => handleApprovePricing(plan.code, pricing.country_code, false)}
                                  >
                                    <BlockIcon />
                                  </IconButton>
                                </Box>
                              )}
                            </Box>
                          ))}
                        </AccordionDetails>
                      </Accordion>
                    )}
                  </CardContent>
                </Card>
              </Grid>
            ))}
          </Grid>
        )}
      </TabPanel>

      {/* Pending Approvals Tab */}
      {isSuperAdmin && (
        <TabPanel value={tabValue} index={1}>
          <Typography variant="h6" gutterBottom>
            Pending Pricing Approvals
          </Typography>

          <TableContainer component={Paper}>
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell>Plan</TableCell>
                  <TableCell>Country</TableCell>
                  <TableCell>Price</TableCell>
                  <TableCell>Submitted</TableCell>
                  <TableCell>Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {pendingApprovals.map((approval) => (
                  <TableRow key={`${approval.plan_code}-${approval.country_code}`}>
                    <TableCell>{approval.plan_name}</TableCell>
                    <TableCell>{approval.country_name || approval.country_code}</TableCell>
                    <TableCell>{approval.currency} {approval.price}</TableCell>
                    <TableCell>{new Date(approval.updated_at).toLocaleDateString()}</TableCell>
                    <TableCell>
                      <IconButton
                        color="success"
                        onClick={() => handleApprovePricing(approval.plan_code, approval.country_code, true)}
                      >
                        <CheckCircleIcon />
                      </IconButton>
                      <IconButton
                        color="error"
                        onClick={() => handleApprovePricing(approval.plan_code, approval.country_code, false)}
                      >
                        <BlockIcon />
                      </IconButton>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        </TabPanel>
      )}

      {/* Analytics Tab */}
      <TabPanel value={tabValue} index={isSuperAdmin ? 2 : 1}>
        <Typography variant="h6" gutterBottom>
          Subscription Analytics
        </Typography>

        {analytics && (
          <Grid container spacing={3}>
            {analytics.plan_statistics && analytics.plan_statistics.map((stat) => (
              <Grid item xs={12} md={6} lg={4} key={stat.plan_code}>
                <Card>
                  <CardContent>
                    <Typography variant="h6" color="primary">
                      {stat.plan_name}
                    </Typography>
                    <Typography variant="h4" sx={{ my: 1 }}>
                      {stat.total_users}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Total Users
                    </Typography>
                    <Divider sx={{ my: 1 }} />
                    <Typography variant="body2">
                      Verified: {stat.verified_users}
                    </Typography>
                    <Typography variant="body2">
                      Price: ${stat.price}
                    </Typography>
                  </CardContent>
                </Card>
              </Grid>
            ))}
          </Grid>
        )}
      </TabPanel>

      {/* User Subscriptions Tab */}
      <TabPanel value={tabValue} index={isSuperAdmin ? 3 : 2}>
        <Typography variant="h6" gutterBottom>
          User Subscriptions
        </Typography>

        <TableContainer component={Paper}>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>User</TableCell>
                <TableCell>Plan</TableCell>
                <TableCell>Usage</TableCell>
                <TableCell>Status</TableCell>
                <TableCell>Country</TableCell>
                <TableCell>Last Updated</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {userSubscriptions.map((subscription) => (
                <TableRow key={subscription.id}>
                  <TableCell>
                    <Box>
                      <Typography variant="body2">
                        {subscription.first_name} {subscription.last_name}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        {subscription.email}
                      </Typography>
                    </Box>
                  </TableCell>
                  <TableCell>
                    <Chip label={subscription.plan_name} variant="outlined" />
                  </TableCell>
                  <TableCell>
                    {subscription.response_limit === -1 ? (
                      <Typography variant="body2">Unlimited</Typography>
                    ) : (
                      <Typography variant="body2">
                        {subscription.responses_used_this_month}/{subscription.response_limit}
                      </Typography>
                    )}
                  </TableCell>
                  <TableCell>
                    {subscription.is_verified_business ? (
                      <Chip icon={<CheckCircleIcon />} label="Verified" color="success" size="small" />
                    ) : (
                      <Chip label="Unverified" color="default" size="small" />
                    )}
                  </TableCell>
                  <TableCell>{subscription.country_code}</TableCell>
                  <TableCell>{new Date(subscription.updated_at).toLocaleDateString()}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      </TabPanel>

      {/* Plan Creation/Edit Dialog */}
      <Dialog open={planDialog} onClose={() => setPlanDialog(false)} maxWidth="md" fullWidth>
        <DialogTitle>
          {editingPlan ? 'Edit Subscription Plan' : 'Create Subscription Plan'}
        </DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                label="Plan Code"
                value={planForm.code}
                onChange={(e) => setPlanForm({...planForm, code: e.target.value})}
                disabled={!!editingPlan}
              />
            </Grid>
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                label="Plan Name"
                value={planForm.name}
                onChange={(e) => setPlanForm({...planForm, name: e.target.value})}
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Description"
                multiline
                rows={2}
                value={planForm.description}
                onChange={(e) => setPlanForm({...planForm, description: e.target.value})}
              />
            </Grid>
            <Grid item xs={12} md={4}>
              <TextField
                fullWidth
                label="Price"
                type="number"
                value={planForm.price}
                onChange={(e) => setPlanForm({...planForm, price: parseFloat(e.target.value) || 0})}
              />
            </Grid>
            <Grid item xs={12} md={4}>
              <FormControl fullWidth>
                <InputLabel>Currency</InputLabel>
                <Select
                  value={planForm.currency}
                  onChange={(e) => setPlanForm({...planForm, currency: e.target.value})}
                >
                  <MenuItem value="USD">USD</MenuItem>
                  <MenuItem value="LKR">LKR</MenuItem>
                  <MenuItem value="EUR">EUR</MenuItem>
                  <MenuItem value="GBP">GBP</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={4}>
              <TextField
                fullWidth
                label="Response Limit (-1 for unlimited)"
                type="number"
                value={planForm.response_limit}
                onChange={(e) => setPlanForm({...planForm, response_limit: parseInt(e.target.value) || 0})}
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPlanDialog(false)}>Cancel</Button>
          <Button onClick={handleCreatePlan} variant="contained" disabled={loading}>
            {editingPlan ? 'Update' : 'Create'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Country Pricing Dialog */}
      <Dialog open={countryPricingDialog} onClose={() => setCountryPricingDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          Set Country Pricing for {selectedPlan?.name}
        </DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Country Code"
                value={pricingForm.country_code}
                onChange={(e) => setPricingForm({...pricingForm, country_code: e.target.value.toUpperCase()})}
                disabled={isCountryAdmin}
                helperText="2-letter ISO country code (e.g., LK, US, GB)"
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Local Price"
                type="number"
                value={pricingForm.price}
                onChange={(e) => setPricingForm({...pricingForm, price: parseFloat(e.target.value) || 0})}
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setCountryPricingDialog(false)}>Cancel</Button>
          <Button onClick={handleSetCountryPricing} variant="contained" disabled={loading}>
            Submit for Approval
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
