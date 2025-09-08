/**
 * SMS Configuration Module - Country-wise SMS API Management
 * 
 * @description
 * This component allows country administrators to configure their own SMS API
 * providers for cost-effective OTP authentication. Each country can set up
 * their preferred SMS gateway, reducing costs compared to Firebase Auth.
 * 
 * @features
 * - Country-specific SMS provider configuration
 * - Support for multiple SMS gateways (Twilio, AWS SNS, Vonage, local providers)
 * - Test SMS functionality before saving configuration
 * - Secure credential storage with encryption
 * - Cost tracking and usage statistics
 * - Fallback configuration for reliability
 * 
 * @cost_benefits
 * - Local SMS providers: $0.01-0.03 per SMS
 * - Twilio: $0.0075 per SMS
 * - Firebase Auth: $0.01-0.02 per verification + base costs
 * - Estimated savings: 50-80% on authentication costs
 * 
 * @security
 * - API credentials encrypted before storage
 * - Rate limiting and usage monitoring
 * - IP whitelisting for API access
 * - Audit logging for configuration changes
 * 
 * @author Request Marketplace Team
 * @version 1.0.0
 * @since 2025-08-16
 */

import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Paper,
  Grid,
  Card,
  CardContent,
  TextField,
  Button,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Switch,
  FormControlLabel,
  Chip,
  Alert,
  CircularProgress,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Accordion,
  AccordionSummary,
  AccordionDetails,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  IconButton,
  Tooltip,
  Divider,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
  LinearProgress
} from '@mui/material';
import {
  Save,
  Science,
  Security,
  MonetizationOn,
  Speed,
  Visibility,
  VisibilityOff,
  ExpandMore,
  Send,
  CheckCircle,
  Error,
  Warning,
  Info,
  Refresh,
  Analytics,
  Settings,
  Phone,
  Public,
  LocalOffer
} from '@mui/icons-material';
import useCountryFilter from '../hooks/useCountryFilter.jsx';
import api from '../services/apiClient.js';

/**
 * SMS Provider Templates
 * Pre-configured templates for popular SMS providers
 */
const SMS_PROVIDERS = {
  twilio: {
    name: 'Twilio',
    description: 'Global SMS service with high reliability',
    cost: '$0.0075/SMS',
    fields: [
      { key: 'accountSid', label: 'Account SID', type: 'text', required: true },
      { key: 'authToken', label: 'Auth Token', type: 'password', required: true },
      { key: 'fromNumber', label: 'From Number', type: 'text', required: true, placeholder: '+1234567890' }
    ],
    testEndpoint: 'https://api.twilio.com/2010-04-01/Accounts/{accountSid}/Messages.json',
    documentation: 'https://www.twilio.com/docs/sms'
  },
  aws_sns: {
    name: 'AWS SNS',
    description: 'Amazon Simple Notification Service',
    cost: '$0.0075/SMS',
    fields: [
      { key: 'accessKeyId', label: 'Access Key ID', type: 'text', required: true },
      { key: 'secretAccessKey', label: 'Secret Access Key', type: 'password', required: true },
      { key: 'region', label: 'AWS Region', type: 'text', required: true, placeholder: 'us-east-1' }
    ],
    testEndpoint: 'https://sns.{region}.amazonaws.com/',
    documentation: 'https://docs.aws.amazon.com/sns/'
  },
  vonage: {
    name: 'Vonage (Nexmo)',
    description: 'Global communications APIs',
    cost: '$0.0072/SMS',
    fields: [
      { key: 'apiKey', label: 'API Key', type: 'text', required: true },
      { key: 'apiSecret', label: 'API Secret', type: 'password', required: true },
      { key: 'brandName', label: 'Brand Name', type: 'text', required: false, placeholder: 'YourApp' }
    ],
    testEndpoint: 'https://rest.nexmo.com/sms/json',
    documentation: 'https://developer.vonage.com/messaging/sms'
  },
  local_provider: {
    name: 'Custom/Local Provider',
    description: 'Configure your local SMS gateway',
    cost: 'Variable',
    fields: [
      { key: 'apiUrl', label: 'API URL', type: 'text', required: true, placeholder: 'https://api.sms-provider.com/send' },
      { key: 'apiKey', label: 'API Key', type: 'password', required: true },
      { key: 'username', label: 'Username', type: 'text', required: false },
      { key: 'password', label: 'Password', type: 'password', required: false },
      { key: 'senderId', label: 'Sender ID', type: 'text', required: false, placeholder: 'YourApp' }
    ],
    testEndpoint: 'Variable',
    documentation: 'Custom provider documentation'
  },
  hutch_mobile: {
    name: 'Hutch Mobile (Sri Lanka)',
    description: 'Sri Lanka Hutch Mobile network SMS gateway',
    cost: '$0.008-0.015/SMS',
    fields: [
      { key: 'apiUrl', label: 'API URL', type: 'text', required: true, placeholder: 'https://webbsms.hutch.lk/' },
      { key: 'username', label: 'Username', type: 'text', required: true },
      { key: 'password', label: 'Password', type: 'password', required: true },
      { key: 'senderId', label: 'Sender ID', type: 'text', required: false, placeholder: 'HUTCH' },
      { key: 'messageType', label: 'Message Type', type: 'select', options: ['text', 'unicode'], required: false, defaultValue: 'text' }
    ],
    testEndpoint: 'https://webbsms.hutch.lk/',
    documentation: 'Hutch Mobile SMS API Documentation',
    countrySpecific: 'LK'
  }
};

const SMSConfigurationModule = () => {
  // === HOOKS AND CONTEXT ===
  const {
    getFilteredData,
    adminData,
    isSuperAdmin,
    getCountryDisplayName,
    userCountry
  } = useCountryFilter();

  // === STATE MANAGEMENT ===
  const [smsConfig, setSmsConfig] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  
  // Configuration form state
  const [selectedProvider, setSelectedProvider] = useState('twilio');
  const [providerConfig, setProviderConfig] = useState({});
  const [isEnabled, setIsEnabled] = useState(false);
  const [showCredentials, setShowCredentials] = useState({});
  
  // Test SMS state
  const [testDialogOpen, setTestDialogOpen] = useState(false);
  const [testPhoneNumber, setTestPhoneNumber] = useState('');
  const [testMessage, setTestMessage] = useState('Your verification code is: 123456');
  
  // Statistics state
  const [statistics, setStatistics] = useState({
    totalSent: 0,
    successRate: 0,
    costSavings: 0,
    lastMonth: { sent: 0, cost: 0 }
  });

  // === LIFECYCLE MANAGEMENT ===
  useEffect(() => {
    // Redirect super admin to SMS Management dashboard
    if (isSuperAdmin) {
      window.location.href = '/sms-management';
      return;
    }
    
    loadSMSConfiguration();
    loadStatistics();
  }, [adminData, isSuperAdmin]);

  // === DATA LOADING FUNCTIONS ===
  /**
   * Load existing SMS configuration for the country
   */
  const loadSMSConfiguration = async () => {
    try {
      setLoading(true);
      setError(null);
      // Fetch provider configs from backend
      const res = await api.get(`/sms/config/${userCountry}`);
      const list = res.data?.data || [];
      // choose active provider or first
      const active = list.find(p => p.is_active) || list[0];
      if (active) {
        setSmsConfig(active);
        setSelectedProvider(active.provider);
        setProviderConfig(active.config || {});
        setIsEnabled(active.is_active);
      } else {
        setSmsConfig(null);
        setSelectedProvider('twilio');
        setProviderConfig({});
        setIsEnabled(false);
      }
    } catch (error) {
      console.error('Error loading SMS configuration:', error);
      setError('Failed to load SMS configuration');
    } finally {
      setLoading(false);
    }
  };

  /**
   * Load SMS usage statistics
   */
  const loadStatistics = async () => {
    try {
      const res = await api.get(`/sms/statistics/${userCountry}`);
      if (res.data?.data) setStatistics(res.data.data);
    } catch (error) {
      console.error('Error loading SMS statistics:', error);
    }
  };

  // === EVENT HANDLERS ===
  /**
   * Handle provider selection change
   */
  const handleProviderChange = (providerId) => {
    setSelectedProvider(providerId);
    setProviderConfig({}); // Reset configuration when changing provider
    setShowCredentials({}); // Reset visibility state
  };

  /**
   * Handle configuration field changes
   */
  const handleConfigChange = (field, value) => {
    setProviderConfig(prev => ({
      ...prev,
      [field]: value
    }));
  };

  /**
   * Toggle credential visibility
   */
  const toggleCredentialVisibility = (field) => {
    setShowCredentials(prev => ({
      ...prev,
      [field]: !prev[field]
    }));
  };

  /**
   * Save SMS configuration
   */
  const handleSaveConfiguration = async () => {
    try {
      setSaving(true);
      setError(null);

      // Validate required fields
      const provider = SMS_PROVIDERS[selectedProvider];
      const requiredFields = provider.fields.filter(field => field.required);
      
      for (const field of requiredFields) {
        if (!providerConfig[field.key]) {
          throw new Error(`${field.label} is required`);
        }
      }

  // Persist via API
  const saveRes = await api.put(`/sms/config/${userCountry}/${selectedProvider}`, { config: providerConfig, is_active: isEnabled, exclusive: true });
  setSmsConfig(saveRes.data?.data);
      setSuccess('SMS configuration saved successfully!');
      
      setTimeout(() => setSuccess(null), 5000);
    } catch (error) {
      console.error('Error saving SMS configuration:', error);
      setError(error.message || 'Failed to save SMS configuration');
    } finally {
      setSaving(false);
    }
  };

  /**
   * Test SMS sending
   */
  const handleTestSMS = async () => {
    try {
      setTesting(true);
      setError(null);

      if (!testPhoneNumber || !testMessage) {
        throw new Error('Phone number and message are required for testing');
      }

      // Validate phone number format
      const phoneRegex = /^\+[1-9]\d{1,14}$/;
      if (!phoneRegex.test(testPhoneNumber)) {
        throw new Error('Please enter a valid phone number with country code (e.g., +1234567890)');
      }

  const sendRes = await api.post('/sms/send-otp', {
    phoneNumber: testPhoneNumber,
    countryCode: userCountry,
    purpose: 'login',
  });
  if (!sendRes.data?.success) throw new Error('Send failed');
  setSuccess(`Test SMS queued via ${sendRes.data?.data?.provider || 'unknown'}`);
      setTestDialogOpen(false);
  loadStatistics();
      
      setTimeout(() => setSuccess(null), 5000);
    } catch (error) {
      console.error('Error sending test SMS:', error);
      setError(error.message || 'Failed to send test SMS');
    } finally {
      setTesting(false);
    }
  };

  // === RENDER HELPERS ===
  /**
   * Render provider configuration form
   */
  const renderProviderConfigForm = () => {
    const provider = SMS_PROVIDERS[selectedProvider];
    
    return (
      <Card sx={{ mt: 2 }}>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            {provider.name} Configuration
          </Typography>
          <Typography variant="body2" color="text.secondary" paragraph>
            {provider.description} - Estimated cost: {provider.cost}
          </Typography>
          
          <Grid container spacing={3}>
            {provider.fields.map((field) => (
              <Grid item xs={12} md={6} key={field.key}>
                {field.type === 'select' ? (
                  <TextField
                    fullWidth
                    select
                    label={field.label}
                    value={providerConfig[field.key] || field.defaultValue || ''}
                    onChange={(e) => handleConfigChange(field.key, e.target.value)}
                    required={field.required}
                  >
                    {field.options.map((option) => (
                      <MenuItem key={option} value={option}>
                        {option}
                      </MenuItem>
                    ))}
                  </TextField>
                ) : (
                  <TextField
                    fullWidth
                    label={field.label}
                    placeholder={field.placeholder}
                    type={field.type === 'password' && !showCredentials[field.key] ? 'password' : 'text'}
                    value={providerConfig[field.key] || ''}
                    onChange={(e) => handleConfigChange(field.key, e.target.value)}
                    required={field.required}
                    InputProps={field.type === 'password' ? {
                      endAdornment: (
                        <IconButton
                          onClick={() => toggleCredentialVisibility(field.key)}
                          edge="end"
                        >
                          {showCredentials[field.key] ? <VisibilityOff /> : <Visibility />}
                        </IconButton>
                      )
                    } : undefined}
                  />
                )}
              </Grid>
            ))}
          </Grid>
          
          <Box sx={{ mt: 2, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <Button
              href={provider.documentation}
              target="_blank"
              startIcon={<Info />}
              size="small"
            >
              View Documentation
            </Button>
            <FormControlLabel
              control={
                <Switch
                  checked={isEnabled}
                  onChange={(e) => setIsEnabled(e.target.checked)}
                />
              }
              label="Enable SMS Service"
            />
          </Box>
        </CardContent>
      </Card>
    );
  };

  /**
   * Render statistics cards
   */
  const renderStatistics = () => (
    <Grid container spacing={3} sx={{ mb: 3 }}>
      <Grid item xs={12} sm={6} md={3}>
        <Card>
          <CardContent>
            <Box display="flex" alignItems="center" justifyContent="space-between">
              <Box>
                <Typography color="text.secondary" gutterBottom variant="overline">
                  Total SMS Sent
                </Typography>
                <Typography variant="h4">
                  {statistics.totalSent.toLocaleString()}
                </Typography>
              </Box>
              <Send color="primary" sx={{ fontSize: 40, opacity: 0.3 }} />
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
                  Success Rate
                </Typography>
                <Typography variant="h4" color="success.main">
                  {statistics.successRate}%
                </Typography>
              </Box>
              <CheckCircle color="success" sx={{ fontSize: 40, opacity: 0.3 }} />
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
                  Cost Savings
                </Typography>
                <Typography variant="h4" color="success.main">
                  ${statistics.costSavings}
                </Typography>
              </Box>
              <MonetizationOn color="success" sx={{ fontSize: 40, opacity: 0.3 }} />
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
                  Last Month
                </Typography>
                <Typography variant="h4">
                  {statistics.lastMonth.sent}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Cost: ${statistics.lastMonth.cost}
                </Typography>
              </Box>
              <Analytics color="info" sx={{ fontSize: 40, opacity: 0.3 }} />
            </Box>
          </CardContent>
        </Card>
      </Grid>
    </Grid>
  );

  // === LOADING AND ERROR STATES ===
  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  // === MAIN COMPONENT RENDER ===
  return (
    <Box>
      {/* === HEADER SECTION === */}
      <Box mb={3}>
        <Typography variant="h4" gutterBottom>
          SMS Configuration
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Configure your country's SMS provider for cost-effective OTP authentication
          {!isSuperAdmin && ` - ${getCountryDisplayName(userCountry)}`}
        </Typography>
      </Box>

      {/* === SUCCESS/ERROR ALERTS === */}
      {success && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccess(null)}>
          {success}
        </Alert>
      )}
      
      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {/* === STATISTICS DASHBOARD === */}
      {renderStatistics()}

      {/* === PROVIDER SELECTION === */}
      <Paper sx={{ p: 3, mb: 3 }}>
        <Typography variant="h6" gutterBottom>
          SMS Provider Selection
        </Typography>
        
        <FormControl fullWidth sx={{ mb: 3 }}>
          <InputLabel>SMS Provider</InputLabel>
          <Select
            value={selectedProvider}
            onChange={(e) => handleProviderChange(e.target.value)}
            label="SMS Provider"
          >
            {Object.entries(SMS_PROVIDERS).map(([key, provider]) => (
              <MenuItem key={key} value={key}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', width: '100%' }}>
                  <span>{provider.name}</span>
                  <Chip label={provider.cost} size="small" />
                </Box>
              </MenuItem>
            ))}
          </Select>
        </FormControl>

        {/* === PROVIDER CONFIGURATION FORM === */}
        {renderProviderConfigForm()}

        {/* === ACTION BUTTONS === */}
        <Box sx={{ mt: 3, display: 'flex', gap: 2 }}>
          <Button
            variant="contained"
            startIcon={<Save />}
            onClick={handleSaveConfiguration}
            disabled={saving}
          >
            {saving ? <CircularProgress size={20} /> : 'Save Configuration'}
          </Button>
          
          <Button
            variant="outlined"
            startIcon={<Science />}
            onClick={() => setTestDialogOpen(true)}
            disabled={!isEnabled || Object.keys(providerConfig).length === 0}
          >
            Test SMS
          </Button>
          
          <Button
            startIcon={<Refresh />}
            onClick={loadSMSConfiguration}
          >
            Refresh
          </Button>
        </Box>
      </Paper>

      {/* === COST COMPARISON SECTION === */}
      <Accordion>
        <AccordionSummary expandIcon={<ExpandMore />}>
          <Typography variant="h6">Cost Comparison & Benefits</Typography>
        </AccordionSummary>
        <AccordionDetails>
          <Grid container spacing={3}>
            <Grid item xs={12} md={6}>
              <Typography variant="subtitle1" gutterBottom>
                <MonetizationOn sx={{ mr: 1, verticalAlign: 'middle' }} />
                Cost Comparison (per 1000 SMS)
              </Typography>
              <List>
                <ListItem>
                  <ListItemText 
                    primary="Firebase Auth" 
                    secondary="$10-20 + base costs"
                  />
                  <Chip label="Expensive" color="error" size="small" />
                </ListItem>
                <ListItem>
                  <ListItemText 
                    primary="Twilio" 
                    secondary="$7.50"
                  />
                  <Chip label="Standard" color="warning" size="small" />
                </ListItem>
                <ListItem>
                  <ListItemText 
                    primary="Local Providers" 
                    secondary="$1-3"
                  />
                  <Chip label="Cheapest" color="success" size="small" />
                </ListItem>
              </List>
            </Grid>
            
            <Grid item xs={12} md={6}>
              <Typography variant="subtitle1" gutterBottom>
                <Security sx={{ mr: 1, verticalAlign: 'middle' }} />
                Security & Reliability
              </Typography>
              <List>
                <ListItem>
                  <ListItemIcon>
                    <CheckCircle color="success" />
                  </ListItemIcon>
                  <ListItemText primary="Encrypted credential storage" />
                </ListItem>
                <ListItem>
                  <ListItemIcon>
                    <CheckCircle color="success" />
                  </ListItemIcon>
                  <ListItemText primary="Rate limiting and monitoring" />
                </ListItem>
                <ListItem>
                  <ListItemIcon>
                    <CheckCircle color="success" />
                  </ListItemIcon>
                  <ListItemText primary="Fallback provider support" />
                </ListItem>
                <ListItem>
                  <ListItemIcon>
                    <CheckCircle color="success" />
                  </ListItemIcon>
                  <ListItemText primary="Usage analytics and reporting" />
                </ListItem>
              </List>
            </Grid>
          </Grid>
        </AccordionDetails>
      </Accordion>

      {/* === TEST SMS DIALOG === */}
      <Dialog open={testDialogOpen} onClose={() => setTestDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Test SMS Configuration</DialogTitle>
        <DialogContent>
          <TextField
            fullWidth
            label="Test Phone Number"
            placeholder="+1234567890"
            value={testPhoneNumber}
            onChange={(e) => setTestPhoneNumber(e.target.value)}
            sx={{ mb: 2, mt: 1 }}
            helperText="Include country code (e.g., +1 for US)"
          />
          
          <TextField
            fullWidth
            label="Test Message"
            multiline
            rows={3}
            value={testMessage}
            onChange={(e) => setTestMessage(e.target.value)}
            helperText="Test message to send"
          />
          
          <Alert severity="info" sx={{ mt: 2 }}>
            This will send a real SMS using your configured provider. Make sure your configuration is correct.
          </Alert>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setTestDialogOpen(false)}>Cancel</Button>
          <Button 
            onClick={handleTestSMS} 
            variant="contained" 
            disabled={testing}
            startIcon={testing ? <CircularProgress size={20} /> : <Send />}
          >
            {testing ? 'Sending...' : 'Send Test SMS'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default SMSConfigurationModule;
