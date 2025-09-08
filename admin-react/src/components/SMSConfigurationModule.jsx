import React, { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Grid,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  TextField,
  Button,
  Switch,
  FormControlLabel,
  Alert,
  Tabs,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  CircularProgress
} from '@mui/material';
import {
  Send as SendIcon,
  Test as TestIcon,
  Save as SaveIcon,
  Analytics as AnalyticsIcon,
  Settings as SettingsIcon,
  Phone as PhoneIcon,
  CheckCircle as CheckCircleIcon,
  Error as ErrorIcon,
  Visibility as VisibilityIcon,
  VisibilityOff as VisibilityOffIcon
} from '@mui/icons-material';
import { apiClient } from '../services/api';

/**
 * 📱 SMS Configuration Module
 * Comprehensive SMS provider management for different countries
 */
const SMSConfigurationModule = () => {
  const [currentTab, setCurrentTab] = useState(0);
  const [selectedCountry, setSelectedCountry] = useState('LK');
  const [configurations, setConfigurations] = useState({});
  const [testResults, setTestResults] = useState({});
  const [loading, setLoading] = useState(false);
  const [showCredentials, setShowCredentials] = useState({});
  const [testDialogOpen, setTestDialogOpen] = useState(false);
  const [testPhoneNumber, setTestPhoneNumber] = useState('');
  const [analytics, setAnalytics] = useState({});

  // Available countries
  const countries = [
    { code: 'LK', name: 'Sri Lanka', flag: '🇱🇰' },
    { code: 'IN', name: 'India', flag: '🇮🇳' },
    { code: 'US', name: 'United States', flag: '🇺🇸' },
    { code: 'UK', name: 'United Kingdom', flag: '🇬🇧' },
    { code: 'AE', name: 'United Arab Emirates', flag: '🇦🇪' }
  ];

  // Available providers
  const providers = [
    { 
      id: 'twilio', 
      name: 'Twilio', 
      description: 'Global, reliable SMS service',
      costPerSMS: 0.0075,
      icon: '📞'
    },
    { 
      id: 'aws', 
      name: 'AWS SNS', 
      description: 'Amazon Web Services SMS',
      costPerSMS: 0.0075,
      icon: '☁️'
    },
    { 
      id: 'vonage', 
      name: 'Vonage', 
      description: 'Competitive pricing SMS',
      costPerSMS: 0.005,
      icon: '📱'
    },
    { 
      id: 'local', 
      name: 'Local Provider', 
      description: 'Country-specific SMS provider',
      costPerSMS: 0.003,
      icon: '🏠'
    }
  ];

  useEffect(() => {
    loadConfigurations();
    loadAnalytics();
  }, []);

  const loadConfigurations = async () => {
    try {
      setLoading(true);
      const response = await apiClient.get('/api/admin/sms-configurations');
      if (response.data.success) {
        const configsMap = {};
        response.data.data.forEach(config => {
          configsMap[config.country_code] = config;
        });
        setConfigurations(configsMap);
      }
    } catch (error) {
      console.error('Error loading SMS configurations:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadAnalytics = async () => {
    try {
      const response = await apiClient.get(`/api/admin/sms-analytics?country=${selectedCountry}`);
      if (response.data.success) {
        setAnalytics(response.data.data);
      }
    } catch (error) {
      console.error('Error loading SMS analytics:', error);
    }
  };

  const handleProviderChange = (provider) => {
    setConfigurations(prev => ({
      ...prev,
      [selectedCountry]: {
        ...prev[selectedCountry],
        active_provider: provider
      }
    }));
  };

  const handleConfigChange = (provider, field, value) => {
    setConfigurations(prev => ({
      ...prev,
      [selectedCountry]: {
        ...prev[selectedCountry],
        [`${provider}_config`]: {
          ...prev[selectedCountry]?.[`${provider}_config`],
          [field]: value
        }
      }
    }));
  };

  const saveConfiguration = async () => {
    try {
      setLoading(true);
      const config = configurations[selectedCountry];
      
      const response = await apiClient.post('/api/admin/sms-configurations', {
        countryCode: selectedCountry,
        activeProvider: config.active_provider,
        twilioConfig: config.twilio_config,
        awsConfig: config.aws_config,
        vonageConfig: config.vonage_config,
        localConfig: config.local_config,
        isActive: config.is_active
      });

      if (response.data.success) {
        alert('Configuration saved successfully!');
        loadConfigurations();
      }
    } catch (error) {
      console.error('Error saving configuration:', error);
      alert('Failed to save configuration: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const testProvider = async (provider) => {
    if (!testPhoneNumber) {
      alert('Please enter a test phone number');
      return;
    }

    try {
      setLoading(true);
      const response = await apiClient.post('/api/admin/test-sms-provider', {
        countryCode: selectedCountry,
        provider: provider,
        testNumber: testPhoneNumber
      });

      setTestResults(prev => ({
        ...prev,
        [provider]: response.data
      }));

      setTestDialogOpen(false);
    } catch (error) {
      console.error('Error testing provider:', error);
      setTestResults(prev => ({
        ...prev,
        [provider]: {
          success: false,
          error: error.message
        }
      }));
    } finally {
      setLoading(false);
    }
  };

  const renderProviderConfiguration = (provider) => {
    const config = configurations[selectedCountry]?.[`${provider.id}_config`] || {};
    const isActive = configurations[selectedCountry]?.active_provider === provider.id;
    const testResult = testResults[provider.id];

    return (
      <Card sx={{ mb: 2, border: isActive ? '2px solid #1976d2' : '1px solid #e0e0e0' }}>
        <CardContent>
          <Box display="flex" justifyContent="space-between" alignItems="center" mb={2}>
            <Box display="flex" alignItems="center" gap={1}>
              <span style={{ fontSize: '24px' }}>{provider.icon}</span>
              <Typography variant="h6">{provider.name}</Typography>
              {isActive && <Chip label="Active" color="primary" size="small" />}
            </Box>
            <Box>
              <Button
                variant="outlined"
                startIcon={<TestIcon />}
                onClick={() => {
                  setTestDialogOpen(true);
                  // Set the provider to test
                }}
                disabled={loading}
                sx={{ mr: 1 }}
              >
                Test
              </Button>
              <Button
                variant={isActive ? "contained" : "outlined"}
                onClick={() => handleProviderChange(provider.id)}
                disabled={loading}
              >
                {isActive ? "Active" : "Activate"}
              </Button>
            </Box>
          </Box>

          <Typography variant="body2" color="text.secondary" mb={2}>
            {provider.description} • ${provider.costPerSMS}/SMS
          </Typography>

          {testResult && (
            <Alert 
              severity={testResult.success ? "success" : "error"} 
              sx={{ mb: 2 }}
            >
              {testResult.success 
                ? `Test successful! Message ID: ${testResult.messageId}` 
                : `Test failed: ${testResult.error}`
              }
            </Alert>
          )}

          {provider.id === 'twilio' && (
            <Grid container spacing={2}>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Account SID"
                  value={config.accountSid || ''}
                  onChange={(e) => handleConfigChange('twilio', 'accountSid', e.target.value)}
                  type={showCredentials.twilio ? 'text' : 'password'}
                  InputProps={{
                    endAdornment: (
                      <IconButton
                        onClick={() => setShowCredentials(prev => ({
                          ...prev,
                          twilio: !prev.twilio
                        }))}
                      >
                        {showCredentials.twilio ? <VisibilityOffIcon /> : <VisibilityIcon />}
                      </IconButton>
                    )
                  }}
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Auth Token"
                  value={config.authToken || ''}
                  onChange={(e) => handleConfigChange('twilio', 'authToken', e.target.value)}
                  type={showCredentials.twilio ? 'text' : 'password'}
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="From Number"
                  value={config.fromNumber || ''}
                  onChange={(e) => handleConfigChange('twilio', 'fromNumber', e.target.value)}
                  placeholder="+1234567890"
                />
              </Grid>
            </Grid>
          )}

          {provider.id === 'aws' && (
            <Grid container spacing={2}>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Access Key ID"
                  value={config.accessKeyId || ''}
                  onChange={(e) => handleConfigChange('aws', 'accessKeyId', e.target.value)}
                  type={showCredentials.aws ? 'text' : 'password'}
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Secret Access Key"
                  value={config.secretAccessKey || ''}
                  onChange={(e) => handleConfigChange('aws', 'secretAccessKey', e.target.value)}
                  type={showCredentials.aws ? 'text' : 'password'}
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Region"
                  value={config.region || ''}
                  onChange={(e) => handleConfigChange('aws', 'region', e.target.value)}
                  placeholder="us-east-1"
                />
              </Grid>
            </Grid>
          )}

          {provider.id === 'vonage' && (
            <Grid container spacing={2}>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="API Key"
                  value={config.apiKey || ''}
                  onChange={(e) => handleConfigChange('vonage', 'apiKey', e.target.value)}
                  type={showCredentials.vonage ? 'text' : 'password'}
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="API Secret"
                  value={config.apiSecret || ''}
                  onChange={(e) => handleConfigChange('vonage', 'apiSecret', e.target.value)}
                  type={showCredentials.vonage ? 'text' : 'password'}
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Brand Name"
                  value={config.brandName || ''}
                  onChange={(e) => handleConfigChange('vonage', 'brandName', e.target.value)}
                  placeholder="RequestApp"
                />
              </Grid>
            </Grid>
          )}

          {provider.id === 'local' && (
            <Grid container spacing={2}>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="API Endpoint"
                  value={config.endpoint || ''}
                  onChange={(e) => handleConfigChange('local', 'endpoint', e.target.value)}
                  placeholder="https://api.local-sms.com/send"
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="API Key"
                  value={config.apiKey || ''}
                  onChange={(e) => handleConfigChange('local', 'apiKey', e.target.value)}
                  type={showCredentials.local ? 'text' : 'password'}
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <FormControl fullWidth>
                  <InputLabel>HTTP Method</InputLabel>
                  <Select
                    value={config.method || 'POST'}
                    onChange={(e) => handleConfigChange('local', 'method', e.target.value)}
                  >
                    <MenuItem value="POST">POST</MenuItem>
                    <MenuItem value="GET">GET</MenuItem>
                  </Select>
                </FormControl>
              </Grid>
            </Grid>
          )}
        </CardContent>
      </Card>
    );
  };

  const renderAnalytics = () => (
    <Grid container spacing={3}>
      <Grid item xs={12} md={4}>
        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              📊 This Month
            </Typography>
            <Typography variant="h4" color="primary">
              ${analytics.currentMonth?.totalCost || 0}
            </Typography>
            <Typography variant="body2">
              {analytics.currentMonth?.totalSent || 0} SMS sent
            </Typography>
          </CardContent>
        </Card>
      </Grid>
      
      <Grid item xs={12} md={4}>
        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              💰 Cost per SMS
            </Typography>
            <Typography variant="h4" color="success.main">
              ${analytics.currentMonth?.costPerSMS || 0}
            </Typography>
            <Typography variant="body2">
              Average cost
            </Typography>
          </CardContent>
        </Card>
      </Grid>
      
      <Grid item xs={12} md={4}>
        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              💾 Savings vs Firebase
            </Typography>
            <Typography variant="h4" color="error.main">
              -{((1 - (analytics.currentMonth?.costPerSMS || 0) / 0.06) * 100).toFixed(1)}%
            </Typography>
            <Typography variant="body2">
              Cost reduction
            </Typography>
          </CardContent>
        </Card>
      </Grid>

      <Grid item xs={12}>
        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              📈 Recent Activity
            </Typography>
            <TableContainer>
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>Date</TableCell>
                    <TableCell>Provider</TableCell>
                    <TableCell>SMS Count</TableCell>
                    <TableCell>Cost</TableCell>
                    <TableCell>Success Rate</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {(analytics.recentActivity || []).map((activity, index) => (
                    <TableRow key={index}>
                      <TableCell>{activity.date}</TableCell>
                      <TableCell>{activity.provider}</TableCell>
                      <TableCell>{activity.count}</TableCell>
                      <TableCell>${activity.cost}</TableCell>
                      <TableCell>
                        <Chip 
                          label={`${activity.successRate}%`}
                          color={activity.successRate > 95 ? "success" : "warning"}
                          size="small"
                        />
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </CardContent>
        </Card>
      </Grid>
    </Grid>
  );

  return (
    <Box p={3}>
      <Typography variant="h4" gutterBottom>
        📱 SMS Configuration System
      </Typography>
      
      <Typography variant="body1" color="text.secondary" mb={3}>
        Configure SMS providers for different countries. Save 50-80% on SMS costs compared to Firebase Auth.
      </Typography>

      {/* Country Selection */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <FormControl sx={{ minWidth: 200 }}>
            <InputLabel>Select Country</InputLabel>
            <Select
              value={selectedCountry}
              onChange={(e) => setSelectedCountry(e.target.value)}
            >
              {countries.map(country => (
                <MenuItem key={country.code} value={country.code}>
                  {country.flag} {country.name}
                </MenuItem>
              ))}
            </Select>
          </FormControl>

          {configurations[selectedCountry] && (
            <FormControlLabel
              control={
                <Switch
                  checked={configurations[selectedCountry]?.is_active || false}
                  onChange={(e) => setConfigurations(prev => ({
                    ...prev,
                    [selectedCountry]: {
                      ...prev[selectedCountry],
                      is_active: e.target.checked
                    }
                  }))}
                />
              }
              label="Enable SMS for this country"
              sx={{ ml: 3 }}
            />
          )}
        </CardContent>
      </Card>

      {/* Tabs */}
      <Tabs value={currentTab} onChange={(e, newValue) => setCurrentTab(newValue)} sx={{ mb: 3 }}>
        <Tab icon={<SettingsIcon />} label="Provider Setup" />
        <Tab icon={<AnalyticsIcon />} label="Analytics" />
      </Tabs>

      {/* Provider Configuration Tab */}
      {currentTab === 0 && (
        <Box>
          {providers.map(provider => renderProviderConfiguration(provider))}
          
          <Box display="flex" justifyContent="center" mt={3}>
            <Button
              variant="contained"
              startIcon={<SaveIcon />}
              onClick={saveConfiguration}
              disabled={loading}
              size="large"
            >
              Save Configuration
            </Button>
          </Box>
        </Box>
      )}

      {/* Analytics Tab */}
      {currentTab === 1 && renderAnalytics()}

      {/* Test Dialog */}
      <Dialog open={testDialogOpen} onClose={() => setTestDialogOpen(false)}>
        <DialogTitle>Test SMS Provider</DialogTitle>
        <DialogContent>
          <TextField
            fullWidth
            label="Test Phone Number"
            value={testPhoneNumber}
            onChange={(e) => setTestPhoneNumber(e.target.value)}
            placeholder="+94771234567"
            sx={{ mt: 2 }}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setTestDialogOpen(false)}>Cancel</Button>
          <Button 
            onClick={() => testProvider(configurations[selectedCountry]?.active_provider)}
            variant="contained"
            disabled={loading}
          >
            {loading ? <CircularProgress size={20} /> : 'Send Test SMS'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default SMSConfigurationModule;
