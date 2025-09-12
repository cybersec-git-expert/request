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
import api from '../services/apiClient';

// Country to currency mapping
const COUNTRY_CURRENCY_MAP = {
  US: 'USD', CA: 'CAD', GB: 'GBP', LK: 'LKR', IN: 'INR', EU: 'EUR', AU: 'AUD', NZ: 'NZD',
  SG: 'SGD', MY: 'MYR', TH: 'THB', PH: 'PHP', PK: 'PKR', CN: 'CNY', JP: 'JPY', KR: 'KRW',
  AE: 'AED', SA: 'SAR', KW: 'KWD', QA: 'QAR', BH: 'BHD', OM: 'OMR', ZA: 'ZAR', NG: 'NGN',
  KE: 'KES', UG: 'UGX', TZ: 'TZS', RW: 'RWF', BI: 'BIF', GH: 'GHS', ET: 'ETB', EG: 'EGP',
  BR: 'BRL', AR: 'ARS', MX: 'MXN', CL: 'CLP', CO: 'COP', PE: 'PEN', VE: 'VES',
  FR: 'EUR', DE: 'EUR', ES: 'EUR', IT: 'EUR', IE: 'EUR', NL: 'EUR', BE: 'EUR', PT: 'EUR',
  SE: 'SEK', NO: 'NOK', DK: 'DKK', FI: 'EUR', IS: 'ISK', CH: 'CHF', PL: 'PLN', CZ: 'CZK',
  HU: 'HUF', RO: 'RON', BG: 'BGN', GR: 'EUR', TR: 'TRY', RU: 'RUB', UA: 'UAH',
};

// Function to get currency for a country code
const getCurrencyForCountry = (countryCode) => {
  if (!countryCode || countryCode === '') {
    return 'USD'; // Default fallback
  }
  return COUNTRY_CURRENCY_MAP[countryCode.toUpperCase()] || 'USD';
};

// API service for subscription management
class SubscriptionAdminService {
  static async getPlans(country = null) {
    const params = country ? `?country=${country}` : '';
    const response = await api.get(`/admin/subscription/plans${params}`);
    return response.data;
  }

  static async createPlan(plan) {
    // Only send template data (no pricing fields)
    const templateData = {
      code: plan.code,
      name: plan.name,
      description: plan.description,
      features: plan.features || []
    };
    const response = await api.post('/admin/subscription/plans', templateData);
    return response.data;
  }

  static async updatePlan(code, plan) {
    const response = await api.put(`/admin/subscription/plans/${code}`, plan);
    return response.data;
  }

  static async setCountryPricing(code, pricing) {
    const response = await api.post(`/admin/subscription/plans/${code}/pricing`, pricing);
    return response.data;
  }

  static async approvePricing(code, country, active) {
    const response = await api.put(`/admin/subscription/plans/${code}/pricing/${country}`, { is_active: active });
    return response.data;
  }

  static async getPendingApprovals() {
    const response = await api.get('/admin/subscription/pending-approvals');
    return response.data;
  }

  static async getAnalytics(country = null) {
    const params = country ? `?country=${country}` : '';
    const response = await api.get(`/admin/subscription/analytics${params}`);
    return response.data;
  }

  static async getUserSubscriptions(filters = {}) {
    const params = new URLSearchParams(filters).toString();
    const response = await api.get(`/admin/subscription/users?${params}`);
    return response.data;
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
  const { user, isSuperAdmin, isCountryAdmin, isAuthenticated, userCountry } = useAuth();
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
    price: 0,
    currency: 'USD',
    response_limit: 3
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
      console.log('Loading plans for user:', { role: user?.role, isSuperAdmin, isCountryAdmin });
      const country = isCountryAdmin ? user?.country_code : null;
      console.log('Calling getPlans with country:', country);
      const result = await SubscriptionAdminService.getPlans(country);
      console.log('Plans loaded successfully:', result);
      setPlans(result.data || []);
    } catch (err) {
      console.error('Failed to load plans:', err);
      setError('Failed to load plans: ' + err.message);
    } finally {
      setLoading(false);
    }
  }, [isCountryAdmin, user?.country_code, isSuperAdmin, user?.role]);

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

  // Check authentication and permissions
  if (!isAuthenticated) {
    return (
      <Box sx={{ p: 3 }}>
        <Alert severity="error">
          Please log in to access the subscription management system.
        </Alert>
      </Box>
    );
  }

  if (!isSuperAdmin && !isCountryAdmin) {
    return (
      <Box sx={{ p: 3 }}>
        <Alert severity="error">
          You don't have permission to access the subscription management system.
        </Alert>
      </Box>
    );
  }

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
      setPricingForm({ country_code: '', price: 0, currency: 'USD', response_limit: 3 });
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
    
    // Debug: Log user object to see available fields
    console.log('User object in openCountryPricingDialog:', user);
    console.log('User country_code:', user?.country_code);
    console.log('User country:', user?.country);
    
    // For country admins, auto-set country code and currency, for super admins allow editing
    if (isCountryAdmin) {
      // Try multiple sources for country code, with LK as fallback for testing
      const userCountryCode = user?.country_code || user?.country || userCountry || 'LK';
      console.log('Using country code:', userCountryCode);
      const currency = getCurrencyForCountry(userCountryCode);
      console.log('Mapped currency:', currency);
      
      setPricingForm({
        country_code: userCountryCode,
        price: 0,
        currency: currency, // Use the mapping function
        response_limit: 3
      });
    } else {
      setPricingForm({
        country_code: '',
        price: 0,
        currency: 'USD',
        response_limit: 3
      });
    }
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
      
      {/* Debug Info */}
      <Alert severity="info" sx={{ mb: 2 }}>
        <Typography variant="body2">
          Debug Info - User: {user?.email || 'Not logged in'} | Role: {user?.role || 'None'} | 
          Is Super Admin: {isSuperAdmin ? 'Yes' : 'No'} | Is Country Admin: {isCountryAdmin ? 'Yes' : 'No'}
        </Typography>
      </Alert>

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
          {editingPlan ? 'Edit Plan Template' : 'Create Plan Template'}
        </DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Create a plan template that country admins can customize with local pricing and limits.
          </Typography>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                label="Plan Code"
                value={planForm.code}
                onChange={(e) => setPlanForm({...planForm, code: e.target.value})}
                disabled={!!editingPlan}
                helperText="Unique identifier (e.g., basic, pro, enterprise)"
              />
            </Grid>
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                label="Plan Name"
                value={planForm.name}
                onChange={(e) => setPlanForm({...planForm, name: e.target.value})}
                helperText="Display name for the plan"
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Description"
                multiline
                rows={3}
                value={planForm.description}
                onChange={(e) => setPlanForm({...planForm, description: e.target.value})}
                helperText="Brief description of what this plan offers"
              />
            </Grid>
            <Grid item xs={12}>
              <Typography variant="body2" color="text.secondary">
                Note: Pricing, currency, and response limits will be set by country admins and require approval.
              </Typography>
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPlanDialog(false)}>Cancel</Button>
          <Button onClick={handleCreatePlan} variant="contained" disabled={loading}>
            {editingPlan ? 'Update Template' : 'Create Template'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Country Pricing Dialog */}
      <Dialog open={countryPricingDialog} onClose={() => setCountryPricingDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          Set Country Pricing for {selectedPlan?.name}
        </DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            {isCountryAdmin 
              ? `Set the price and response limits for ${selectedPlan?.name} in your country (${user?.country_code}). Your country code and currency are automatically set.`
              : 'Set the price, currency, and response limits for any country. This will be submitted for super admin approval.'
            }
          </Typography>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Country Code"
                value={pricingForm.country_code}
                onChange={(e) => {
                  const newCountryCode = e.target.value.toUpperCase();
                  setPricingForm({
                    ...pricingForm, 
                    country_code: newCountryCode,
                    // Auto-update currency for super admins when country changes
                    currency: !isCountryAdmin ? getCurrencyForCountry(newCountryCode) : pricingForm.currency
                  });
                }}
                disabled={isCountryAdmin} // Country admins cannot change their country
                helperText={isCountryAdmin ? "Your country code (auto-set)" : "2-letter ISO country code (e.g., LK, US, GB)"}
              />
            </Grid>
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                label="Local Price"
                type="number"
                value={pricingForm.price}
                onChange={(e) => setPricingForm({...pricingForm, price: parseFloat(e.target.value) || 0})}
                helperText="Price in local currency"
              />
            </Grid>
            <Grid item xs={12} md={6}>
              <FormControl fullWidth>
                <InputLabel>Currency</InputLabel>
                <Select
                  value={pricingForm.currency}
                  onChange={(e) => setPricingForm({...pricingForm, currency: e.target.value})}
                  disabled={isCountryAdmin} // Country admins use their country's currency
                >
                  <MenuItem value="USD">USD - US Dollar</MenuItem>
                  <MenuItem value="EUR">EUR - Euro</MenuItem>
                  <MenuItem value="GBP">GBP - British Pound</MenuItem>
                  <MenuItem value="LKR">LKR - Sri Lankan Rupee</MenuItem>
                  <MenuItem value="INR">INR - Indian Rupee</MenuItem>
                  <MenuItem value="AUD">AUD - Australian Dollar</MenuItem>
                  <MenuItem value="CAD">CAD - Canadian Dollar</MenuItem>
                  <MenuItem value="SGD">SGD - Singapore Dollar</MenuItem>
                  <MenuItem value="MYR">MYR - Malaysian Ringgit</MenuItem>
                  <MenuItem value="THB">THB - Thai Baht</MenuItem>
                  <MenuItem value="PHP">PHP - Philippine Peso</MenuItem>
                  <MenuItem value="AED">AED - UAE Dirham</MenuItem>
                  <MenuItem value="SAR">SAR - Saudi Riyal</MenuItem>
                  <MenuItem value="PKR">PKR - Pakistani Rupee</MenuItem>
                  <MenuItem value="BRL">BRL - Brazilian Real</MenuItem>
                  <MenuItem value="JPY">JPY - Japanese Yen</MenuItem>
                  <MenuItem value="CNY">CNY - Chinese Yuan</MenuItem>
                  <MenuItem value="ZAR">ZAR - South African Rand</MenuItem>
                </Select>
                {isCountryAdmin && (
                  <Typography variant="caption" color="text.secondary" sx={{ mt: 0.5 }}>
                    Your country's currency (auto-set)
                  </Typography>
                )}
              </FormControl>
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Response Limit"
                type="number"
                value={pricingForm.response_limit}
                onChange={(e) => setPricingForm({...pricingForm, response_limit: parseInt(e.target.value) || 0})}
                helperText="Number of responses per month (-1 for unlimited)"
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
