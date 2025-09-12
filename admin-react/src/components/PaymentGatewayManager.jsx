import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Paper,
  Grid,
  Card,
  CardContent,
  CardActions,
  Button,
  Switch,
  FormControlLabel,
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
  Alert,
  Accordion,
  AccordionSummary,
  AccordionDetails,
  IconButton,
  Tooltip
} from '@mui/material';
import {
  ExpandMore as ExpandMoreIcon,
  Settings as SettingsIcon,
  CheckCircle as CheckCircleIcon,
  Cancel as CancelIcon,
  Add as AddIcon,
  Edit as EditIcon
} from '@mui/icons-material';
import authService from '../services/authService';
import api from '../services/apiClient';

const PaymentGatewayManager = () => {
  const [gateways, setGateways] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [configDialog, setConfigDialog] = useState(false);
  const [selectedGateway, setSelectedGateway] = useState(null);
  const [configuration, setConfiguration] = useState({});
  const [userCountry, setUserCountry] = useState('');

  useEffect(() => {
    loadUserInfo();
  }, []);

  useEffect(() => {
    if (userCountry) {
      loadGateways();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userCountry]);

  const loadUserInfo = async () => {
    try {
      // Check if user is already loaded
      if (authService.user) {
        setUserCountry(authService.user.country || 'LK');
        return;
      }
      
      // Fetch fresh profile data
      const userInfo = await authService.fetchProfile();
      if (userInfo) {
        setUserCountry(userInfo.country || 'LK');
      } else {
        setError('Failed to load user information');
      }
    } catch (error) {
      console.error('Error loading user info:', error);
      setError('Failed to load user information');
    }
  };

  const loadGateways = async () => {
    try {
      setLoading(true);
      const response = await api.get(`/admin/payment-gateways/gateways/${userCountry}`);
      
      if (response.data.success) {
        setGateways(response.data.gateways);
      } else {
        setError(response.data.error || 'Failed to load payment gateways');
      }
    } catch (error) {
      console.error('Error loading gateways:', error);
      setError('Failed to load payment gateways');
    } finally {
      setLoading(false);
    }
  };

  const handleConfigureGateway = (gateway) => {
    setSelectedGateway(gateway);
    setConfiguration({});
    
    // Initialize configuration with empty values based on gateway fields
    if (gateway.configuration_fields) {
      const fields = typeof gateway.configuration_fields === 'string' 
        ? JSON.parse(gateway.configuration_fields) 
        : gateway.configuration_fields;
      const initialConfig = {};
      Object.keys(fields).forEach(key => {
        initialConfig[key] = '';
      });
      setConfiguration(initialConfig);
    }
    
    setConfigDialog(true);
  };

  const handleEditGateway = async (gateway) => {
    try {
      const response = await api.get(`/admin/payment-gateways/gateways/${userCountry}/${gateway.id}/config`);

      if (response.data.success) {
        setSelectedGateway(gateway);
        setConfiguration(response.data.gateway.configuration);
        setConfigDialog(true);
      } else {
        setError(response.data.error || 'Failed to load gateway configuration');
      }
    } catch (error) {
      console.error('Error loading gateway config:', error);
      setError('Failed to load gateway configuration');
    }
  };

  const handleSaveConfiguration = async () => {
    try {
      const response = await api.post(`/admin/payment-gateways/gateways/${userCountry}/configure`, {
        gatewayId: selectedGateway.id,
        configuration: configuration,
        isPrimary: selectedGateway.is_primary
      });

      if (response.data.success) {
        setSuccess('Payment gateway configured successfully');
        setConfigDialog(false);
        loadGateways();
      } else {
        setError(response.data.error || 'Failed to configure payment gateway');
      }
    } catch (error) {
      console.error('Error saving configuration:', error);
      setError('Failed to save configuration');
    }
  };

  const handleToggleGateway = async (gateway, isActive) => {
    try {
      const response = await api.patch(`/admin/payment-gateways/gateways/${userCountry}/${gateway.id}/toggle`, {
        isActive
      });

      if (response.data.success) {
        setSuccess(`Gateway ${isActive ? 'activated' : 'deactivated'} successfully`);
        loadGateways();
      } else {
        setError(response.data.error || 'Failed to update gateway status');
      }
    } catch (error) {
      console.error('Error toggling gateway:', error);
      setError('Failed to update gateway status');
    }
  };

  const handleConfigurationChange = (field, value) => {
    setConfiguration(prev => ({
      ...prev,
      [field]: value
    }));
  };

  const renderConfigurationFields = () => {
    if (!selectedGateway?.configuration_fields) return null;

    const fields = typeof selectedGateway.configuration_fields === 'string' 
      ? JSON.parse(selectedGateway.configuration_fields) 
      : selectedGateway.configuration_fields;
    
    return Object.entries(fields).map(([fieldKey, fieldConfig]) => {
      if (fieldConfig.type === 'select') {
        return (
          <FormControl fullWidth margin="normal" key={fieldKey}>
            <InputLabel>{fieldConfig.label}</InputLabel>
            <Select
              value={configuration[fieldKey] || ''}
              onChange={(e) => handleConfigurationChange(fieldKey, e.target.value)}
              required={fieldConfig.required}
            >
              {fieldConfig.options.map(option => (
                <MenuItem key={option} value={option}>
                  {option}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
        );
      } else {
        return (
          <TextField
            key={fieldKey}
            fullWidth
            margin="normal"
            label={fieldConfig.label}
            type={fieldConfig.type === 'password' ? 'password' : 'text'}
            value={configuration[fieldKey] || ''}
            onChange={(e) => handleConfigurationChange(fieldKey, e.target.value)}
            required={fieldConfig.required}
            placeholder={fieldConfig.type === 'password' && configuration[fieldKey] === '••••••••' ? 'Leave blank to keep current value' : ''}
          />
        );
      }
    });
  };

  const getGatewayStatus = (gateway) => {
    if (!gateway.configured) {
      return { label: 'Not Configured', color: 'default', icon: <CancelIcon /> };
    } else if (gateway.is_active) {
      return { label: 'Active', color: 'success', icon: <CheckCircleIcon /> };
    } else {
      return { label: 'Inactive', color: 'warning', icon: <CancelIcon /> };
    }
  };

  if (loading) {
    return (
      <Box sx={{ p: 3 }}>
        <Typography>Loading payment gateways...</Typography>
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" gutterBottom>
        Payment Gateway Management
      </Typography>
      <Typography variant="subtitle1" color="text.secondary" gutterBottom>
        Configure payment methods for {userCountry}
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

      <Grid container spacing={3}>
        {gateways.map((gateway) => {
          const status = getGatewayStatus(gateway);
          
          return (
            <Grid item xs={12} md={6} lg={4} key={gateway.id}>
              <Card>
                <CardContent>
                  <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', mb: 2 }}>
                    <Typography variant="h6">{gateway.name}</Typography>
                    <Chip
                      icon={status.icon}
                      label={status.label}
                      color={status.color}
                      size="small"
                    />
                  </Box>
                  
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                    {gateway.description}
                  </Typography>

                  {gateway.is_primary && (
                    <Chip label="Primary Gateway" color="primary" size="small" sx={{ mb: 2 }} />
                  )}

                  {gateway.configured && (
                    <Typography variant="caption" color="text.secondary">
                      Configured on: {new Date(gateway.configured_at).toLocaleDateString()}
                    </Typography>
                  )}
                </CardContent>
                
                <CardActions>
                  {!gateway.configured ? (
                    <Button
                      size="small"
                      startIcon={<AddIcon />}
                      onClick={() => handleConfigureGateway(gateway)}
                    >
                      Configure
                    </Button>
                  ) : (
                    <>
                      <Button
                        size="small"
                        startIcon={<EditIcon />}
                        onClick={() => handleEditGateway(gateway)}
                      >
                        Edit
                      </Button>
                      <FormControlLabel
                        control={
                          <Switch
                            checked={gateway.is_active}
                            onChange={(e) => handleToggleGateway(gateway, e.target.checked)}
                            size="small"
                          />
                        }
                        label="Active"
                        sx={{ ml: 1 }}
                      />
                    </>
                  )}
                </CardActions>
              </Card>
            </Grid>
          );
        })}
      </Grid>

      {/* Configuration Dialog */}
      <Dialog open={configDialog} onClose={() => setConfigDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          Configure {selectedGateway?.name}
        </DialogTitle>
        <DialogContent>
          <Box sx={{ pt: 1 }}>
            {renderConfigurationFields()}
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfigDialog(false)}>Cancel</Button>
          <Button onClick={handleSaveConfiguration} variant="contained">
            Save Configuration
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default PaymentGatewayManager;
