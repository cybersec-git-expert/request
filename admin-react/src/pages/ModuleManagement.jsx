import React, { useState, useEffect } from 'react';
import {
  Container,
  Typography,
  Card,
  CardContent,
  CardActions,
  Grid,
  Switch,
  FormControlLabel,
  Button,
  Box,
  Chip,
  Alert,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  List,
  ListItem,
  ListItemText,
  ListItemIcon,
  Snackbar,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Divider
} from '@mui/material';
import {
  Settings as SettingsIcon,
  CheckCircle as CheckIcon,
  Cancel as CancelIcon,
  Warning as WarningIcon,
  Info as InfoIcon
} from '@mui/icons-material';
import useCountryFilter from '../hooks/useCountryFilter';
import api from '../services/apiClient';
import { BUSINESS_MODULES, CORE_DEPENDENCIES, canEnableModule, getModulesUsingDependency } from '../constants/businessModules';

const ModuleManagement = () => {
  const { getFilteredData, adminData, isSuperAdmin, userCountry } = useCountryFilter();
  const userRole = isSuperAdmin ? 'super_admin' : 'country_admin';
  const [countries, setCountries] = useState([]);
  const [selectedCountry, setSelectedCountry] = useState('');
  const [countryModules, setCountryModules] = useState({});
  const [countryDependencies, setCountryDependencies] = useState({});
  const [loading, setLoading] = useState(false);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
  const [confirmDialog, setConfirmDialog] = useState({ open: false, moduleId: '', action: '' });

  useEffect(() => {
    fetchCountries();
    if (userRole === 'country_admin' && userCountry) {
      setSelectedCountry(userCountry);
    }
  }, [userRole, userCountry]);

  useEffect(() => {
    if (selectedCountry) {
      fetchCountryModules(selectedCountry);
    }
  }, [selectedCountry]);

  const fetchCountries = async () => {
    try {
      const res = await api.get('/countries');
  const raw = res.data;
  const arr = Array.isArray(raw) ? raw : (Array.isArray(raw?.data) ? raw.data : []);
  const list = arr.map(c => ({ id: c.id || c.code, code: c.code, name: c.name }));
      setCountries(list);
    } catch (error) {
      console.error('Error fetching countries:', error);
      setSnackbar({ open: true, message: 'Error fetching countries', severity: 'error' });
    }
  };

  const fetchCountryModules = async (countryCode) => {
    try {
      setLoading(true);
      const res = await api.get(`/country-modules/${countryCode}`);
  const payload = res.data?.data || res.data;
  const existingModules = payload?.modules || payload?.data?.modules || {};
  const existingCore = payload?.core_dependencies || payload?.coreDependencies || {};

  // Merge defaults so new modules appear enabled per defaultEnabled if not explicitly stored
  const mergedModules = { ...Object.fromEntries(Object.values(BUSINESS_MODULES).map(m => [m.id, m.defaultEnabled])), ...existingModules };
  const mergedCore = { ...Object.fromEntries(Object.keys(CORE_DEPENDENCIES).map(k => [k, true])), ...existingCore };
  setCountryModules(mergedModules);
  setCountryDependencies(mergedCore);
    } catch (error) {
      console.error('Error fetching country modules:', error);
      setSnackbar({ open: true, message: 'Error fetching country modules', severity: 'error' });
    } finally { setLoading(false);} };

  const handleModuleToggle = (moduleId, enabled) => {
    if (!enabled) {
      // Check if other modules depend on this one
      const dependentModules = getModulesUsingDependency(moduleId);
      const enabledDependentModules = dependentModules.filter(depModule => 
        countryModules[BUSINESS_MODULES[depModule].id]
      );
      
      if (enabledDependentModules.length > 0) {
        setSnackbar({
          open: true,
          message: `Cannot disable ${BUSINESS_MODULES[moduleId.toUpperCase()].name}. Other modules depend on it: ${enabledDependentModules.map(m => BUSINESS_MODULES[m].name).join(', ')}`,
          severity: 'warning'
        });
        return;
      }
      
      setConfirmDialog({
        open: true,
        moduleId,
        action: 'disable',
        message: `Are you sure you want to disable ${BUSINESS_MODULES[moduleId.toUpperCase()].name}? This will hide this module from the mobile app for users in ${selectedCountry}.`
      });
    } else {
      // Check dependencies before enabling
      const dependencyCheck = canEnableModule(moduleId, 
        Object.keys(countryModules).filter(key => countryModules[key]), 
        Object.keys(countryDependencies).filter(key => countryDependencies[key])
      );
      
      if (!dependencyCheck.canEnable) {
        setSnackbar({
          open: true,
          message: `Cannot enable ${BUSINESS_MODULES[moduleId.toUpperCase()].name}. Missing dependency: ${dependencyCheck.missing}`,
          severity: 'error'
        });
        return;
      }
      
      setConfirmDialog({
        open: true,
        moduleId,
        action: 'enable',
        message: `Enable ${BUSINESS_MODULES[moduleId.toUpperCase()].name}? This will make this module available in the mobile app for users in ${selectedCountry}.`
      });
    }
  };

  const confirmModuleChange = async () => {
    try {
      const { moduleId, action } = confirmDialog;
      const newModules = {
        ...countryModules,
        [moduleId]: action === 'enable'
      };

      await saveCountryConfiguration(newModules, countryDependencies);
      setCountryModules(newModules);
      
      setSnackbar({
        open: true,
        message: `${BUSINESS_MODULES[moduleId.toUpperCase()].name} ${action}d successfully!`,
        severity: 'success'
      });
    } catch (error) {
      console.error('Error updating module:', error);
      setSnackbar({ open: true, message: 'Error updating module', severity: 'error' });
    } finally {
      setConfirmDialog({ open: false, moduleId: '', action: '' });
    }
  };

  const handleDependencyToggle = async (dependencyId, enabled) => {
    try {
      // Check if disabling a dependency that modules need
      if (!enabled) {
        const dependentModules = Object.keys(BUSINESS_MODULES).filter(key => {
          const module = BUSINESS_MODULES[key];
          return module.dependencies.includes(dependencyId) && countryModules[module.id];
        });

        if (dependentModules.length > 0) {
          setSnackbar({
            open: true,
            message: `Cannot disable ${CORE_DEPENDENCIES[dependencyId]}. Active modules depend on it: ${dependentModules.map(m => BUSINESS_MODULES[m].name).join(', ')}`,
            severity: 'warning'
          });
          return;
        }
      }

      const newDependencies = {
        ...countryDependencies,
        [dependencyId]: enabled
      };

      await saveCountryConfiguration(countryModules, newDependencies);
      setCountryDependencies(newDependencies);
      
      setSnackbar({
        open: true,
        message: `${CORE_DEPENDENCIES[dependencyId]} ${enabled ? 'enabled' : 'disabled'} successfully!`,
        severity: 'success'
      });
    } catch (error) {
      console.error('Error updating dependency:', error);
      setSnackbar({ open: true, message: 'Error updating dependency', severity: 'error' });
    }
  };

  const saveCountryConfiguration = async (modules, dependencies) => {
  const payload = { modules, coreDependencies: dependencies };
  await api.put(`/country-modules/${selectedCountry}`, payload);
  };

  const getModuleStatus = (moduleId) => {
    const enabled = countryModules[moduleId];
    if (!enabled) return { status: 'disabled', color: 'default', icon: <CancelIcon /> };
    
    const dependencyCheck = canEnableModule(moduleId,
      Object.keys(countryModules).filter(key => countryModules[key]),
      Object.keys(countryDependencies).filter(key => countryDependencies[key])
    );
    
    if (!dependencyCheck.canEnable) {
      return { status: 'error', color: 'error', icon: <WarningIcon /> };
    }
    
    return { status: 'enabled', color: 'success', icon: <CheckIcon /> };
  };

  return (
    <Container maxWidth="xl">
      <Box sx={{ mb: 4 }}>
        <Typography variant="h4" gutterBottom>
          📱 Business Modules Management
        </Typography>
        <Typography variant="body1" color="textSecondary" paragraph>
          Configure which business modules are available in the mobile app for each country.
          Modules control what features users can access and what types of listings they can create.
        </Typography>
      </Box>

      {/* Country Selection */}
      {userRole === 'super_admin' && (
        <Card sx={{ mb: 4 }}>
          <CardContent>
            <FormControl fullWidth>
              <InputLabel>Select Country</InputLabel>
              <Select
                value={selectedCountry}
                onChange={(e) => setSelectedCountry(e.target.value)}
                label="Select Country"
              >
                {countries.map((country) => (
                  <MenuItem key={country.code} value={country.code}>
                    {country.name} ({country.code})
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          </CardContent>
        </Card>
      )}

      {selectedCountry && (
        <>
          {/* Core Dependencies */}
          <Card sx={{ mb: 4 }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                🔧 Core System Dependencies
              </Typography>
              <Typography variant="body2" color="textSecondary" paragraph>
                These are core features that modules depend on. Disabling them may affect module functionality.
              </Typography>
              
              <Grid container spacing={2}>
                {Object.entries(CORE_DEPENDENCIES).map(([key, name]) => (
                  <Grid key={key} size={{ xs: 12, sm: 6, md: 4 }}>
                    <FormControlLabel
                      control={
                        <Switch
                          checked={Boolean(countryDependencies[key])}
                          onChange={(e) => handleDependencyToggle(key, e.target.checked)}
                        />
                      }
                      label={name}
                    />
                  </Grid>
                ))}
              </Grid>
            </CardContent>
          </Card>

          {/* Business Modules */}
          <Typography variant="h5" gutterBottom sx={{ mb: 3 }}>
            Business Modules for {countries.find(c => c.code === selectedCountry)?.name || selectedCountry}
          </Typography>
          
      <Grid container spacing={3}>
            {Object.keys(BUSINESS_MODULES).map((key) => {
              const module = BUSINESS_MODULES[key];
              const moduleStatus = getModuleStatus(module.id);
              const isEnabled = countryModules[module.id];
              
              return (
        <Grid key={module.id} size={{ xs: 12, md: 6, xl: 4 }}>
                  <Card 
                    sx={{ 
                      height: '100%',
                      border: isEnabled ? `2px solid ${module.color}` : '1px solid #e0e0e0',
                      opacity: isEnabled ? 1 : 0.7
                    }}
                  >
                    <CardContent>
                      <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                        <Typography variant="h4" sx={{ mr: 1 }}>
                          {module.icon}
                        </Typography>
                        <Box sx={{ flexGrow: 1 }}>
                          <Typography variant="h6">
                            {module.name}
                          </Typography>
                          <Chip
                            icon={moduleStatus.icon}
                            label={moduleStatus.status}
                            color={moduleStatus.color}
                            size="small"
                          />
                        </Box>
                      </Box>
                      
                      <Typography variant="body2" color="textSecondary" paragraph>
                        {module.description}
                      </Typography>
                      
                      <Typography variant="subtitle2" gutterBottom>
                        Features:
                      </Typography>
                      <List dense>
                        {module.features.slice(0, 4).map((feature, index) => (
                          <ListItem key={index} sx={{ py: 0, px: 1 }}>
                            <ListItemText 
                              primary={feature}
                              primaryTypographyProps={{ variant: 'body2' }}
                            />
                          </ListItem>
                        ))}
                        {module.features.length > 4 && (
                          <ListItem sx={{ py: 0, px: 1 }}>
                            <ListItemText 
                              primary={`... and ${module.features.length - 4} more`}
                              primaryTypographyProps={{ variant: 'body2', fontStyle: 'italic' }}
                            />
                          </ListItem>
                        )}
                      </List>
                      
                      {module.dependencies.length > 0 && (
                        <Box sx={{ mt: 2 }}>
                          <Typography variant="body2" color="textSecondary">
                            Dependencies:
                          </Typography>
                          <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5, mt: 0.5 }}>
                            {module.dependencies.map(dep => (
                              <Chip 
                                key={dep}
                                label={CORE_DEPENDENCIES[dep] || BUSINESS_MODULES[dep.toUpperCase()]?.name || dep}
                                size="small"
                                variant="outlined"
                                color={
                                  (CORE_DEPENDENCIES[dep] && countryDependencies[dep]) ||
                                  (BUSINESS_MODULES[dep.toUpperCase()] && countryModules[dep])
                                    ? 'success' : 'error'
                                }
                              />
                            ))}
                          </Box>
                        </Box>
                      )}
                    </CardContent>
                    
                    <CardActions>
                      <FormControlLabel
                        control={
                          <Switch
                            checked={Boolean(isEnabled)}
                            onChange={(e) => handleModuleToggle(module.id, e.target.checked)}
                            disabled={loading}
                          />
                        }
                        label={isEnabled ? "Enabled" : "Disabled"}
                      />
                    </CardActions>
                  </Card>
                </Grid>
              );
            })}
          </Grid>
        </>
      )}

      {/* Confirmation Dialog */}
      <Dialog open={confirmDialog.open} onClose={() => setConfirmDialog({ open: false, moduleId: '', action: '' })}>
        <DialogTitle>
          {confirmDialog.action === 'enable' ? 'Enable Module' : 'Disable Module'}
        </DialogTitle>
        <DialogContent>
          <Typography>
            {confirmDialog.message}
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmDialog({ open: false, moduleId: '', action: '' })}>
            Cancel
          </Button>
          <Button 
            onClick={confirmModuleChange} 
            variant="contained"
            color={confirmDialog.action === 'enable' ? 'primary' : 'error'}
          >
            {confirmDialog.action === 'enable' ? 'Enable' : 'Disable'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Snackbar */}
      <Snackbar
        open={snackbar.open}
        autoHideDuration={6000}
        onClose={() => setSnackbar({ ...snackbar, open: false })}
      >
        <Alert 
          severity={snackbar.severity} 
          onClose={() => setSnackbar({ ...snackbar, open: false })}
        >
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Container>
  );
};

export default ModuleManagement;
