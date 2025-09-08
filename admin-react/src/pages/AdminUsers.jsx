import React, { useState, useEffect } from 'react';
import {
  Container,
  Typography,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Grid,
  Card,
  CardContent,
  Box,
  IconButton,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Chip,
  Alert,
  Switch,
  FormControlLabel,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Snackbar,
  CircularProgress
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  Person as PersonIcon,
  LockReset as LockResetIcon
} from '@mui/icons-material';
import api from '../services/apiClient';
import { useAuth } from '../contexts/AuthContext';
import { generateSecurePassword } from '../utils/passwordUtils';
import { sendCredentialsEmail } from '../utils/emailService';

const AdminUsers = () => {
  const { user, adminData, userRole, userCountry } = useAuth();
  
  const [adminUsers, setAdminUsers] = useState([]);
  const [countries, setCountries] = useState([]);
  const [open, setOpen] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [loading, setLoading] = useState(false);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
  const [generatedCredentials, setGeneratedCredentials] = useState(null);
  const [showCredentials, setShowCredentials] = useState(false);

  const [formData, setFormData] = useState({
    email: '',
    displayName: '',
    country: '', // Will be set based on user role
    role: 'country_admin',
    isActive: true,
    permissions: {
      // Request Management
      requestManagement: true,
      responseManagement: true,
  priceListingManagement: true,
      
      // Business Management
      productManagement: true,
      businessManagement: true,
  countryBusinessTypeManagement: false,
      driverVerification: true,
      
      // Vehicle Management
      vehicleManagement: false, // Only super admins by default
      countryVehicleTypeManagement: true, // Country admins can manage vehicle types in their country
      
      // City Management
      cityManagement: true, // Country admins can manage cities in their country
      
      // Data Management
      userManagement: true,
      subscriptionManagement: true,
      promoCodeManagement: true,
      
      // Product Catalog Management
      categoryManagement: true,
      subcategoryManagement: true,
      brandManagement: true,
      variableTypeManagement: true,
      
      // Module Management
      moduleManagement: true,
      
      // SMS Configuration
      smsConfiguration: true, // Country admins can configure SMS providers
      
      // Legal & Payment
      paymentMethodManagement: true, // Now available for country admin
      legalDocumentManagement: true, // Now available for country admin
      countryPageManagement: true, // Country-specific page management (needs approval to publish)
      
      // Admin Management
      adminUsersManagement: false // Only super admins should have this by default
    }
  });

  useEffect(() => {
    console.log('Admin Users Component - Auth State:');
    console.log('User:', user);
    console.log('AdminData:', adminData);
    console.log('User Role:', userRole);
    console.log('User Country:', userCountry);
    
    // Always fetch countries (needed for dropdown)
    fetchCountries();
    
    if (user && adminData) {
      fetchAdminUsers();
    }
  }, [user, adminData]);

  const fetchAdminUsers = async () => {
    try {
      const params = {};
      if (userRole !== 'super_admin') params.country = userCountry || 'LK';
      const res = await api.get('/admin-users', { params });
      const list = Array.isArray(res.data) ? res.data : (res.data?.data || []);
      setAdminUsers(list);
    } catch (error) {
      console.error('Error fetching admin users:', error);
      setSnackbar({ open: true, message: 'Error fetching admin users: ' + (error.response?.data?.message || error.message), severity: 'error' });
    }
  };

  const fetchCountries = async () => {
    try {
      console.log('🌍 Fetching countries...');
      const res = await api.get('/countries');
      console.log('🌍 Countries API response:', res.data);
      const list = Array.isArray(res.data) ? res.data : (res.data?.data || []);
      console.log('🌍 Countries list:', list);
      if (list.length === 0) throw new Error('No countries');
      
      // For admin user creation, show all countries (not just active ones)
      // Super admins need to assign country admins to any country
      const mappedCountries = list.map(c => ({ id: c.id || c.code, ...c }));
      console.log('🌍 Mapped countries for admin user creation:', mappedCountries);
      setCountries(mappedCountries);
    } catch (error) {
      console.error('Error fetching countries:', error);
      const fallbackCountries = [
        { id: 'LK', code: 'LK', name: 'Sri Lanka', isEnabled: true },
        { id: 'US', code: 'US', name: 'United States', isEnabled: true },
        { id: 'AE', code: 'AE', name: 'UAE', isEnabled: false },
        { id: 'GB', code: 'GB', name: 'United Kingdom', isEnabled: false }
      ];
      setCountries(fallbackCountries);
      setSnackbar({ open: true, message: 'Using fallback countries (fetch failed)', severity: 'warning' });
    }
  };

  const handleSubmit = async () => {
    // Validation
    if (!formData.displayName.trim()) {
      setSnackbar({ open: true, message: 'Please enter a display name', severity: 'error' });
      return;
    }
    if (!formData.email.trim()) {
      setSnackbar({ open: true, message: 'Please enter an email', severity: 'error' });
      return;
    }

    // Permission validation: Country admins cannot create super admins
    if (userRole === 'country_admin' && formData.role === 'super_admin') {
      setSnackbar({ 
        open: true, 
        message: 'Country admins cannot create super admin users', 
        severity: 'error' 
      });
      return;
    }
    
    // Determine country - super admin can choose, others use their assigned country
    const selectedCountry = userRole === 'super_admin' ? formData.country : (userCountry || 'LK');
    
    if (!selectedCountry) {
      setSnackbar({ open: true, message: 'Please select a country', severity: 'error' });
      return;
    }

    console.log('Form data before save:', formData);
    console.log('Selected country:', selectedCountry);
    console.log('User role:', userRole);
    console.log('User country:', userCountry);

    setLoading(true);
    try {
      if (editingUser) {
        // Update existing user
        const userData = {
          displayName: formData.displayName.trim(),
          email: formData.email.trim(),
          country: selectedCountry,
          role: formData.role || 'country_admin',
          isActive: formData.isActive !== undefined ? formData.isActive : true,
          permissions: {
            // Request Management
            requestManagement: formData.permissions?.requestManagement !== undefined ? formData.permissions.requestManagement : true,
            responseManagement: formData.permissions?.responseManagement !== undefined ? formData.permissions.responseManagement : true,
            priceListingManagement: formData.permissions?.priceListingManagement !== undefined ? formData.permissions.priceListingManagement : true,
            
            // Business Management
            productManagement: formData.permissions?.productManagement !== undefined ? formData.permissions.productManagement : true,
            businessManagement: formData.permissions?.businessManagement !== undefined ? formData.permissions.businessManagement : true,
            countryBusinessTypeManagement: formData.permissions?.countryBusinessTypeManagement !== undefined ? formData.permissions.countryBusinessTypeManagement : false,
            driverVerification: formData.permissions?.driverVerification !== undefined ? formData.permissions.driverVerification : true,
            
            // Vehicle Management
            vehicleManagement: formData.permissions?.vehicleManagement !== undefined ? formData.permissions.vehicleManagement : false,
            countryVehicleTypeManagement: formData.permissions?.countryVehicleTypeManagement !== undefined ? formData.permissions.countryVehicleTypeManagement : true,
            
            // City Management  
            cityManagement: formData.permissions?.cityManagement !== undefined ? formData.permissions.cityManagement : true,
            
            // User & Module Management
            userManagement: formData.permissions?.userManagement !== undefined ? formData.permissions.userManagement : true,
            subscriptionManagement: formData.permissions?.subscriptionManagement !== undefined ? formData.permissions.subscriptionManagement : true,
            promoCodeManagement: formData.permissions?.promoCodeManagement !== undefined ? formData.permissions.promoCodeManagement : true,
            moduleManagement: formData.permissions?.moduleManagement !== undefined ? formData.permissions.moduleManagement : true,
            
            // Product Catalog Management
            categoryManagement: formData.permissions?.categoryManagement !== undefined ? formData.permissions.categoryManagement : true,
            subcategoryManagement: formData.permissions?.subcategoryManagement !== undefined ? formData.permissions.subcategoryManagement : true,
            brandManagement: formData.permissions?.brandManagement !== undefined ? formData.permissions.brandManagement : true,
            variableTypeManagement: formData.permissions?.variableTypeManagement !== undefined ? formData.permissions.variableTypeManagement : true,
            
            // Legal & Payment (Super Admin Only)
            paymentMethodManagement: formData.permissions?.paymentMethodManagement !== undefined ? formData.permissions.paymentMethodManagement : false,
            legalDocumentManagement: formData.permissions?.legalDocumentManagement !== undefined ? formData.permissions.legalDocumentManagement : false,
            countryPageManagement: formData.permissions?.countryPageManagement !== undefined ? formData.permissions.countryPageManagement : true,
            
            // SMS Configuration
            smsConfiguration: formData.permissions?.smsConfiguration !== undefined ? formData.permissions.smsConfiguration : true,
            
            // Admin Management
            adminUsersManagement: formData.permissions?.adminUsersManagement !== undefined ? formData.permissions.adminUsersManagement : false
          },
          updatedAt: new Date()
        };

        console.log('Updating user:', editingUser.id);
  await api.put(`/admin-users/${editingUser.id}`, userData);
        console.log('User updated successfully');
        
        setSnackbar({ 
          open: true, 
          message: 'Admin user updated successfully!', 
          severity: 'success' 
        });
      } else {
        // Create new user with generated password
        const generatedPassword = generateSecurePassword();
        console.log('Generated password:', generatedPassword);

        // Check if email already exists in Firestore first
        console.log('🔍 Checking if email already exists in admin_users...');
  const emailCheck = await api.get('/admin-users', { params: { email: formData.email.toLowerCase().trim() } });
  const existing = Array.isArray(emailCheck.data) ? emailCheck.data : (emailCheck.data?.data || []);
  if (existing.length > 0) throw new Error('This email is already registered as an admin user.');

        const adminUserData = {
          displayName: formData.displayName.trim(),
          email: formData.email.toLowerCase().trim(),
          password: generatedPassword,
          country: selectedCountry,
          role: formData.role || 'country_admin',
          isActive: true,
          permissions: {
            // Request Management
            requestManagement: formData.permissions?.requestManagement !== undefined ? formData.permissions.requestManagement : true,
            responseManagement: formData.permissions?.responseManagement !== undefined ? formData.permissions.responseManagement : true,
            priceListingManagement: formData.permissions?.priceListingManagement !== undefined ? formData.permissions.priceListingManagement : true,
            
            // Business Management
            productManagement: formData.permissions?.productManagement !== undefined ? formData.permissions.productManagement : true,
            businessManagement: formData.permissions?.businessManagement !== undefined ? formData.permissions.businessManagement : true,
            countryBusinessTypeManagement: formData.permissions?.countryBusinessTypeManagement !== undefined ? formData.permissions.countryBusinessTypeManagement : false,
            driverVerification: formData.permissions?.driverVerification !== undefined ? formData.permissions.driverVerification : true,
            
            // Vehicle Management
            vehicleManagement: formData.permissions?.vehicleManagement !== undefined ? formData.permissions.vehicleManagement : false,
            countryVehicleTypeManagement: formData.permissions?.countryVehicleTypeManagement !== undefined ? formData.permissions.countryVehicleTypeManagement : true,
            
            // City Management
            cityManagement: formData.permissions?.cityManagement !== undefined ? formData.permissions.cityManagement : true,
            
            // User & Module Management
            userManagement: formData.permissions?.userManagement !== undefined ? formData.permissions.userManagement : true,
            subscriptionManagement: formData.permissions?.subscriptionManagement !== undefined ? formData.permissions.subscriptionManagement : true,
            promoCodeManagement: formData.permissions?.promoCodeManagement !== undefined ? formData.permissions.promoCodeManagement : true,
            moduleManagement: formData.permissions?.moduleManagement !== undefined ? formData.permissions.moduleManagement : true,
            
            // Product Catalog Management
            categoryManagement: formData.permissions?.categoryManagement !== undefined ? formData.permissions.categoryManagement : true,
            subcategoryManagement: formData.permissions?.subcategoryManagement !== undefined ? formData.permissions.subcategoryManagement : true,
            brandManagement: formData.permissions?.brandManagement !== undefined ? formData.permissions.brandManagement : true,
            variableTypeManagement: formData.permissions?.variableTypeManagement !== undefined ? formData.permissions.variableTypeManagement : true,
            
            // Legal & Payment (Super Admin Only)
            paymentMethodManagement: formData.permissions?.paymentMethodManagement !== undefined ? formData.permissions.paymentMethodManagement : false,
            legalDocumentManagement: formData.permissions?.legalDocumentManagement !== undefined ? formData.permissions.legalDocumentManagement : false,
            countryPageManagement: formData.permissions?.countryPageManagement !== undefined ? formData.permissions.countryPageManagement : true,
            
            // SMS Configuration
            smsConfiguration: formData.permissions?.smsConfiguration !== undefined ? formData.permissions.smsConfiguration : true,
            
            // Admin Management
            adminUsersManagement: formData.permissions?.adminUsersManagement !== undefined ? formData.permissions.adminUsersManagement : false
          }
        };

  console.log('Creating new admin user via REST...');
  const createRes = await api.post('/admin-users', adminUserData);
  const newUser = createRes.data?.data || createRes.data;
  console.log('Admin user created successfully with ID:', newUser?.id);

        // Store credentials to show in dialog
        setGeneratedCredentials({
          email: adminUserData.email,
          password: generatedPassword,
          displayName: adminUserData.displayName,
          role: adminUserData.role,
          country: adminUserData.country
        });

        // Send credentials via email
        try {
          const emailResult = await sendCredentialsEmail(adminUserData, generatedPassword);
          if (emailResult.success) {
            console.log('Credentials email sent successfully');
          } else {
            console.warn('Email sending failed:', emailResult.error);
          }
        } catch (emailError) {
          console.error('Error sending credentials email:', emailError);
        }

        // Show credentials dialog
        setShowCredentials(true);
        
        setSnackbar({ 
          open: true, 
          message: 'Admin user created successfully! Credentials have been generated.', 
          severity: 'success' 
        });
      }

      await fetchAdminUsers();
      if (!showCredentials) {
        handleClose();
      }
    } catch (error) {
      console.error('Error saving admin user:', error);
      
      let errorMessage = 'Failed to save admin user';
      if (error.code === 'auth/email-already-in-use') {
        errorMessage = 'This email is already registered in Firebase Authentication. Please use a different email address.';
      } else if (error.code === 'auth/invalid-email') {
        errorMessage = 'Please enter a valid email address.';
      } else if (error.code === 'auth/weak-password') {
        errorMessage = 'The generated password is too weak. Please try again.';
      } else if (error.message && error.message.includes('already registered')) {
        errorMessage = error.message;
      } else if (error.message) {
        errorMessage = error.message;
      }
      
      setSnackbar({ 
        open: true, 
        message: `❌ ${errorMessage}`, 
        severity: 'error' 
      });
    }
    setLoading(false);
  };

  const handleEdit = (user) => {
    setEditingUser(user);
    setFormData({
      displayName: user.displayName || '',
      email: user.email || '',
      country: user.country || '',
      role: user.role || 'country_admin',
      isActive: user.isActive !== undefined ? user.isActive : true,
      permissions: {
        // Request Management
        requestManagement: user.permissions?.requestManagement !== undefined ? user.permissions.requestManagement : (user.permissions?.paymentMethods !== undefined ? true : true),
        responseManagement: user.permissions?.responseManagement !== undefined ? user.permissions.responseManagement : true,
        priceListingManagement: user.permissions?.priceListingManagement !== undefined ? user.permissions.priceListingManagement : true,
        
        // Business Management
        productManagement: user.permissions?.productManagement !== undefined ? user.permissions.productManagement : true,
        businessManagement: user.permissions?.businessManagement !== undefined ? user.permissions.businessManagement : true,
  countryBusinessTypeManagement: user.permissions?.countryBusinessTypeManagement !== undefined ? user.permissions.countryBusinessTypeManagement : false,
        driverVerification: user.permissions?.driverVerification !== undefined ? user.permissions.driverVerification : (user.permissions?.driverManagement !== undefined ? user.permissions.driverManagement : true),
        
        // Vehicle Management
        vehicleManagement: user.permissions?.vehicleManagement !== undefined ? user.permissions.vehicleManagement : false,
        countryVehicleTypeManagement: user.permissions?.countryVehicleTypeManagement !== undefined ? user.permissions.countryVehicleTypeManagement : true,
        
        // City Management
        cityManagement: user.permissions?.cityManagement !== undefined ? user.permissions.cityManagement : true,
        
        // User & Module Management
        userManagement: user.permissions?.userManagement !== undefined ? user.permissions.userManagement : true,
        subscriptionManagement: user.permissions?.subscriptionManagement !== undefined ? user.permissions.subscriptionManagement : true,
        promoCodeManagement: user.permissions?.promoCodeManagement !== undefined ? user.permissions.promoCodeManagement : true,
        moduleManagement: user.permissions?.moduleManagement !== undefined ? user.permissions.moduleManagement : true,
        
        // Product Catalog Management
        categoryManagement: user.permissions?.categoryManagement !== undefined ? user.permissions.categoryManagement : true,
        subcategoryManagement: user.permissions?.subcategoryManagement !== undefined ? user.permissions.subcategoryManagement : true,
        brandManagement: user.permissions?.brandManagement !== undefined ? user.permissions.brandManagement : true,
        variableTypeManagement: user.permissions?.variableTypeManagement !== undefined ? user.permissions.variableTypeManagement : true,
        
        // Legal & Payment (backward compatibility)
        paymentMethodManagement: user.permissions?.paymentMethodManagement !== undefined ? user.permissions.paymentMethodManagement : (user.permissions?.paymentMethods !== undefined ? user.permissions.paymentMethods : false),
        legalDocumentManagement: user.permissions?.legalDocumentManagement !== undefined ? user.permissions.legalDocumentManagement : (user.permissions?.legalDocuments !== undefined ? user.permissions.legalDocuments : false),
        countryPageManagement: user.permissions?.countryPageManagement !== undefined ? user.permissions.countryPageManagement : (user.permissions?.contentManagement !== undefined ? user.permissions.contentManagement : true),
        
        // SMS Configuration
        smsConfiguration: user.permissions?.smsConfiguration !== undefined ? user.permissions.smsConfiguration : true,
        
        // Admin Management
        adminUsersManagement: user.permissions?.adminUsersManagement !== undefined ? user.permissions.adminUsersManagement : false
      }
    });
    setOpen(true);
  };

  const handleToggleActive = async (user) => {
    try {
      const newActiveStatus = !user.isActive;
      console.log(`Toggling user ${user.id} active status from ${user.isActive} to ${newActiveStatus}`);
      
  await api.put(`/admin-users/${user.id}/status`, { isActive: newActiveStatus });
      
      await fetchAdminUsers(); // Refresh the list
      setSnackbar({ 
        open: true, 
        message: `User ${newActiveStatus ? 'activated' : 'deactivated'} successfully!`, 
        severity: 'success' 
      });
    } catch (error) {
      console.error('Error toggling user active status:', error);
      setSnackbar({ 
        open: true, 
        message: 'Error updating user status: ' + error.message, 
        severity: 'error' 
      });
    }
  };

  const handleDelete = async (user) => {
    if (window.confirm(`Are you sure you want to delete user ${user.displayName || user.email}? This action cannot be undone.`)) {
      try {
        console.log(`Deleting user ${user.id}`);
  await api.delete(`/admin-users/${user.id}`);
        
        await fetchAdminUsers(); // Refresh the list
        setSnackbar({ 
          open: true, 
          message: 'User deleted successfully!', 
          severity: 'success' 
        });
      } catch (error) {
        console.error('Error deleting user:', error);
        setSnackbar({ 
          open: true, 
          message: 'Error deleting user: ' + error.message, 
          severity: 'error' 
        });
      }
    }
  };

  const handlePasswordReset = async (user) => {
    if (window.confirm(`Send password reset email to ${user.displayName || user.email}?`)) {
      try {
        await api.post(`/admin-users/${user.id}/password-reset`);
        setSnackbar({ open: true, message: `Password reset initiated for ${user.email}!`, severity: 'success' });
      } catch (error) {
        console.error('Error sending password reset:', error);
        setSnackbar({ open: true, message: 'Error sending password reset: ' + (error.response?.data?.message || error.message), severity: 'error' });
      }
    }
  };

  const handleClose = () => {
    setOpen(false);
    setEditingUser(null);
    setFormData({
      email: '',
      displayName: '',
      country: userRole === 'super_admin' ? '' : (userCountry || 'LK'), // Set default country for non-super admins
      role: 'country_admin',
      isActive: true,
      permissions: {
        paymentMethods: true,
        legalDocuments: true,
        businessManagement: true,
        driverManagement: true,
        vehicleManagement: false,
        adminUsersManagement: false
      }
    });
  };

  const handleInputChange = (field, value) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  const handlePermissionChange = (permission, value) => {
    setFormData(prev => ({
      ...prev,
      permissions: {
        ...prev.permissions,
        [permission]: value
      }
    }));
  };

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4" gutterBottom>
          Admin Users Management
        </Typography>
        <Box>
          <Button
            variant="outlined"
            onClick={fetchAdminUsers}
            sx={{ mr: 1 }}
          >
            Refresh
          </Button>
          {userRole === 'super_admin' && (
            <Button
              variant="outlined"
              startIcon={<LockResetIcon />}
              onClick={() => {
                if (window.confirm('Send password reset emails to all admin users?')) {
                  adminUsers.forEach(admin => {
                    api.post(`/admin-users/${admin.id}/password-reset`).catch(console.error);
                  });
                  setSnackbar({
                    open: true,
                    message: `Password reset emails sent to ${adminUsers.length} admin users!`,
                    severity: 'success'
                  });
                }
              }}
              sx={{ mr: 1 }}
            >
              Reset All Passwords
            </Button>
          )}
          {(userRole === 'super_admin' || userRole === 'country_admin') && (
            <Button
              variant="contained"
              startIcon={<AddIcon />}
              onClick={() => setOpen(true)}
              color="primary"
            >
              Add New Admin User
            </Button>
          )}
        </Box>
      </Box>

      {userRole !== 'super_admin' && (
        <Alert severity="info" sx={{ mb: 3 }}>
          <strong>Your Admin Role:</strong> {userRole === 'country_admin' ? 'Country Admin' : userRole} for <strong>{userCountry}</strong>
          <br />
          <strong>Permissions:</strong> You can create and manage Country Admin users for your assigned region.
          <br />
          <strong>Note:</strong> Only Super Admins can create other Super Admin users.
        </Alert>
      )}

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Name</TableCell>
              <TableCell>Email</TableCell>
              <TableCell>Country</TableCell>
              <TableCell>Role</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Permissions</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {adminUsers.map((adminUser) => (
              <TableRow key={adminUser.id}>
                <TableCell>{adminUser.displayName}</TableCell>
                <TableCell>{adminUser.email}</TableCell>
                <TableCell>
                  <Chip label={adminUser.country} size="small" color="primary" />
                </TableCell>
                <TableCell>
                  <Chip 
                    label={adminUser.role === 'super_admin' ? 'Super Admin' : 'Country Admin'} 
                    size="small" 
                    color={adminUser.role === 'super_admin' ? 'secondary' : 'default'}
                  />
                </TableCell>
                <TableCell>
                  <Switch
                    checked={adminUser.isActive}
                    onChange={() => handleToggleActive(adminUser)}
                    color="primary"
                    size="small"
                  />
                  <Chip 
                    label={adminUser.isActive ? 'Active' : 'Inactive'} 
                    size="small" 
                    color={adminUser.isActive ? 'success' : 'error'}
                    sx={{ ml: 1 }}
                  />
                </TableCell>
                <TableCell>
                  <Box display="flex" gap={0.5} flexWrap="wrap">
                    {/* Request Management */}
                    {adminUser.permissions?.requestManagement && (
                      <Chip label="Requests" size="small" variant="outlined" color="primary" />
                    )}
                    {adminUser.permissions?.responseManagement && (
                      <Chip label="Responses" size="small" variant="outlined" color="primary" />
                    )}
                    {adminUser.permissions?.priceListingManagement && (
                      <Chip label="Pricing" size="small" variant="outlined" color="primary" />
                    )}
                    
                    {/* Business Management */}
                    {adminUser.permissions?.productManagement && (
                      <Chip label="Products" size="small" variant="outlined" color="success" />
                    )}
                    {adminUser.permissions?.businessManagement && (
                      <Chip label="Business" size="small" variant="outlined" color="success" />
                    )}
                    {adminUser.permissions?.driverVerification && (
                      <Chip label="Drivers" size="small" variant="outlined" color="success" />
                    )}
                    
                    {/* Vehicle & User Management */}
                    {adminUser.permissions?.vehicleManagement && (
                      <Chip label="Vehicles" size="small" variant="outlined" color="info" />
                    )}
                    {adminUser.permissions?.userManagement && (
                      <Chip label="Users" size="small" variant="outlined" color="info" />
                    )}
                    {adminUser.permissions?.moduleManagement && (
                      <Chip label="Modules" size="small" variant="outlined" color="info" />
                    )}
                    
                    {/* Legacy Support */}
                    {adminUser.permissions?.paymentMethods && (
                      <Chip label="Payment" size="small" variant="outlined" color="warning" />
                    )}
                    {adminUser.permissions?.legalDocuments && (
                      <Chip label="Legal" size="small" variant="outlined" color="warning" />
                    )}
                    {adminUser.permissions?.driverManagement && (
                      <Chip label="Driver" size="small" variant="outlined" color="warning" />
                    )}
                    
                    {/* Legal & Payment Management */}
                    {adminUser.permissions?.paymentMethodManagement && (
                      <Chip label="Payment Mgmt" size="small" variant="outlined" color="secondary" />
                    )}
                    {adminUser.permissions?.legalDocumentManagement && (
                      <Chip label="Legal Mgmt" size="small" variant="outlined" color="secondary" />
                    )}
                    {adminUser.permissions?.countryPageManagement && (
                      <Chip label="Country Pages" size="small" variant="outlined" color="info" />
                    )}
                    
                    {/* Super Admin Only */}
                    {adminUser.permissions?.adminUsersManagement && (
                      <Chip label="Admin Users" size="small" variant="filled" color="error" />
                    )}
                  </Box>
                </TableCell>
                <TableCell>
                  <Box display="flex" gap={1}>
                    <IconButton 
                      onClick={() => handleEdit(adminUser)}
                      color="primary"
                      size="small"
                      title="Edit User"
                    >
                      <EditIcon />
                    </IconButton>
                    {userRole === 'super_admin' && (
                      <>
                        <IconButton 
                          onClick={() => handlePasswordReset(adminUser)}
                          color="warning"
                          size="small"
                          title="Send Password Reset Email"
                        >
                          <LockResetIcon />
                        </IconButton>
                        <IconButton 
                          onClick={() => handleDelete(adminUser)} 
                          color="error"
                          size="small"
                          title="Delete User"
                        >
                          <DeleteIcon />
                        </IconButton>
                      </>
                    )}
                  </Box>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      {/* Add/Edit Dialog */}
      <Dialog open={open} onClose={handleClose} maxWidth="md" fullWidth>
        <DialogTitle>
          {editingUser ? 'Edit Admin User' : 'Add Admin User'}
          {userRole === 'country_admin' && (
            <Typography variant="caption" display="block" color="textSecondary" sx={{ mt: 0.5 }}>
              As a Country Admin, you can only create Country Admins for your assigned region
            </Typography>
          )}
        </DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="Display Name"
                value={formData.displayName}
                onChange={(e) => handleInputChange('displayName', e.target.value)}
                required
              />
            </Grid>
            
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="Email"
                type="email"
                value={formData.email}
                onChange={(e) => handleInputChange('email', e.target.value)}
                required
              />
            </Grid>

            <Grid item xs={12} sm={6}>
              {userRole === 'super_admin' ? (
                <FormControl fullWidth required>
                  <InputLabel>Country</InputLabel>
                  <Select
                    value={formData.country}
                    label="Country"
                    onChange={(e) => handleInputChange('country', e.target.value)}
                  >
                    {(() => {
                      console.log('🔍 Rendering countries dropdown, countries state:', countries);
                      return countries.map((country) => (
                        <MenuItem key={country.id} value={country.code}>
                          {country.name} ({country.code})
                        </MenuItem>
                      ));
                    })()}
                  </Select>
                </FormControl>
              ) : (
                <TextField
                  fullWidth
                  label="Country"
                  value={`${userCountry || 'LK'} (Assigned Country)`}
                  disabled
                  helperText="Country admins are assigned to their specific country"
                />
              )}
            </Grid>

            <Grid item xs={12} sm={6}>
              <FormControl fullWidth>
                <InputLabel>Role</InputLabel>
                <Select
                  value={formData.role}
                  label="Role"
                  onChange={(e) => handleInputChange('role', e.target.value)}
                >
                  <MenuItem value="country_admin">Country Admin</MenuItem>
                  {userRole === 'super_admin' && (
                    <MenuItem value="super_admin">Super Admin</MenuItem>
                  )}
                </Select>
              </FormControl>
              {userRole !== 'super_admin' && (
                <Typography variant="caption" color="textSecondary" sx={{ mt: 0.5, display: 'block' }}>
                  Country admins can only create other country admins
                </Typography>
              )}
            </Grid>

            <Grid item xs={12}>
              <Typography variant="subtitle2" gutterBottom sx={{ mb: 2 }}>
                Permissions
              </Typography>
              {formData.role === 'super_admin' ? (
                <Alert severity="info">Super Admins have full access. Permissions cannot be customized.</Alert>
              ) : (
                <>
              {/* Request Management Section */}
              <Typography variant="body2" color="primary" gutterBottom sx={{ mt: 2, fontWeight: 'bold' }}>
                📋 Request Management
              </Typography>
              <Grid container spacing={1} sx={{ ml: 2, mb: 2 }}>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.requestManagement || false}
                        onChange={(e) => handlePermissionChange('requestManagement', e.target.checked)}
                      />
                    }
                    label="Requests"
                  />
                </Grid>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.responseManagement || false}
                        onChange={(e) => handlePermissionChange('responseManagement', e.target.checked)}
                      />
                    }
                    label="Responses"
                  />
                </Grid>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.priceListingManagement || false}
                        onChange={(e) => handlePermissionChange('priceListingManagement', e.target.checked)}
                      />
                    }
                    label="Price Listings"
                  />
                </Grid>
              </Grid>

              {/* Business Management Section */}
              <Typography variant="body2" color="primary" gutterBottom sx={{ fontWeight: 'bold' }}>
                🏢 Business Management
              </Typography>
              <Grid container spacing={1} sx={{ ml: 2, mb: 2 }}>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.productManagement || false}
                        onChange={(e) => handlePermissionChange('productManagement', e.target.checked)}
                      />
                    }
                    label="Products"
                  />
                </Grid>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.businessManagement || false}
                        onChange={(e) => handlePermissionChange('businessManagement', e.target.checked)}
                      />
                    }
                    label="Businesses"
                  />
                </Grid>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.countryBusinessTypeManagement || false}
                        onChange={(e) => handlePermissionChange('countryBusinessTypeManagement', e.target.checked)}
                      />
                    }
                    label="Business Types"
                  />
                </Grid>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.driverVerification || false}
                        onChange={(e) => handlePermissionChange('driverVerification', e.target.checked)}
                      />
                    }
                    label="Drivers"
                  />
                </Grid>
              </Grid>

              {/* Vehicle Management Section */}
              <Typography variant="body2" color="primary" gutterBottom sx={{ fontWeight: 'bold' }}>
                🚗 Vehicle Management
              </Typography>
              <Grid container spacing={1} sx={{ ml: 2, mb: 2 }}>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.vehicleManagement || false}
                        onChange={(e) => handlePermissionChange('vehicleManagement', e.target.checked)}
                      />
                    }
                    label="Vehicle Management"
                  />
                </Grid>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.countryVehicleTypeManagement || false}
                        onChange={(e) => handlePermissionChange('countryVehicleTypeManagement', e.target.checked)}
                      />
                    }
                    label="Vehicle Types"
                  />
                </Grid>
              </Grid>

              {/* City Management Section */}
              <Typography variant="body2" color="primary" gutterBottom sx={{ fontWeight: 'bold' }}>
                🏙️ City Management
              </Typography>
              <Grid container spacing={1} sx={{ ml: 2, mb: 2 }}>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.cityManagement || false}
                        onChange={(e) => handlePermissionChange('cityManagement', e.target.checked)}
                      />
                    }
                    label="City Management"
                  />
                </Grid>
              </Grid>

              {/* User & Module Management Section */}
              <Typography variant="body2" color="primary" gutterBottom sx={{ fontWeight: 'bold' }}>
                👥 User & Module Management
              </Typography>
              <Grid container spacing={1} sx={{ ml: 2, mb: 2 }}>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.userManagement || false}
                        onChange={(e) => handlePermissionChange('userManagement', e.target.checked)}
                      />
                    }
                    label="Users"
                  />
                </Grid>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.promoCodeManagement || false}
                        onChange={(e) => handlePermissionChange('promoCodeManagement', e.target.checked)}
                      />
                    }
                    label="Promo Codes"
                  />
                </Grid>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.moduleManagement || false}
                        onChange={(e) => handlePermissionChange('moduleManagement', e.target.checked)}
                      />
                    }
                    label="Module Management"
                  />
                </Grid>
              </Grid>

              {/* Product Catalog Management Section */}
              <Typography variant="body2" color="primary" gutterBottom sx={{ fontWeight: 'bold' }}>
                📦 Product Catalog Management
              </Typography>
              <Grid container spacing={1} sx={{ ml: 2, mb: 2 }}>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.categoryManagement || false}
                        onChange={(e) => handlePermissionChange('categoryManagement', e.target.checked)}
                      />
                    }
                    label="Categories"
                  />
                </Grid>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.subcategoryManagement || false}
                        onChange={(e) => handlePermissionChange('subcategoryManagement', e.target.checked)}
                      />
                    }
                    label="Subcategories"
                  />
                </Grid>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.brandManagement || false}
                        onChange={(e) => handlePermissionChange('brandManagement', e.target.checked)}
                      />
                    }
                    label="Brands"
                  />
                </Grid>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.variableTypeManagement || false}
                        onChange={(e) => handlePermissionChange('variableTypeManagement', e.target.checked)}
                      />
                    }
                    label="Variable Types"
                  />
                </Grid>
              </Grid>

              {/* Legal & Payment Section */}
              <Typography variant="body2" color="primary" gutterBottom sx={{ fontWeight: 'bold' }}>
                💼 Legal & Content Management
              </Typography>
              <Grid container spacing={1} sx={{ ml: 2, mb: 2 }}>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.paymentMethodManagement || false}
                        onChange={(e) => handlePermissionChange('paymentMethodManagement', e.target.checked)}
                      />
                    }
                    label="Payment Methods"
                  />
                </Grid>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.subscriptionManagement || false}
                        onChange={(e) => handlePermissionChange('subscriptionManagement', e.target.checked)}
                      />
                    }
                    label="Subscription Management"
                  />
                </Grid>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.legalDocumentManagement || false}
                        onChange={(e) => handlePermissionChange('legalDocumentManagement', e.target.checked)}
                      />
                    }
                    label="Legal Documents"
                  />
                </Grid>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.countryPageManagement || false}
                        onChange={(e) => handlePermissionChange('countryPageManagement', e.target.checked)}
                      />
                    }
                    label="Country Page Management"
                  />
                </Grid>
              </Grid>

              {/* SMS Configuration Section */}
              <Typography variant="body2" color="primary" gutterBottom sx={{ fontWeight: 'bold' }}>
                💬 SMS Configuration
              </Typography>
              <Grid container spacing={1} sx={{ ml: 2, mb: 2 }}>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.smsConfiguration || false}
                        onChange={(e) => handlePermissionChange('smsConfiguration', e.target.checked)}
                      />
                    }
                    label="SMS Configuration Management"
                  />
                </Grid>
              </Grid>

              {/* Admin Management Section */}
              <Typography variant="body2" color="primary" gutterBottom sx={{ fontWeight: 'bold' }}>
                ⚙️ Admin Management (Super Admin Only)
              </Typography>
              <Grid container spacing={1} sx={{ ml: 2, mb: 2 }}>
                <Grid item xs={12} sm={6} md={4}>
                  <FormControlLabel
                    control={
                      <Switch
                        size="small"
                        checked={formData.permissions?.adminUsersManagement || false}
                        onChange={(e) => handlePermissionChange('adminUsersManagement', e.target.checked)}
                        disabled={formData.role !== 'super_admin'}
                      />
                    }
                    label="Admin Users Management"
                  />
                </Grid>
              </Grid>
              </>
              )}
            </Grid>

            <Grid item xs={12}>
              <FormControlLabel
                control={
                  <Switch
                    checked={formData.isActive}
                    onChange={(e) => handleInputChange('isActive', e.target.checked)}
                  />
                }
                label="Active (can access admin panel)"
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleClose} disabled={loading}>Cancel</Button>
          <Button 
            onClick={handleSubmit} 
            variant="contained"
            disabled={loading}
          >
            {loading ? (
              <>
                <CircularProgress size={20} sx={{ mr: 1 }} />
                Saving...
              </>
            ) : 'Save'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Credentials Display Dialog */}
      <Dialog 
        open={showCredentials} 
        onClose={() => {
          setShowCredentials(false);
          setGeneratedCredentials(null);
          handleClose();
        }}
        maxWidth="md" 
        fullWidth
      >
        <DialogTitle sx={{ backgroundColor: '#e3f2fd' }}>
          🎉 Admin User Created Successfully!
        </DialogTitle>
        <DialogContent sx={{ mt: 2 }}>
          {generatedCredentials && (
            <>
              <Alert severity="success" sx={{ mb: 3 }}>
                <strong>New admin user has been created!</strong> The login credentials have been generated and sent via email.
              </Alert>

              <Box sx={{ backgroundColor: '#f5f5f5', border: '1px solid #ddd', borderRadius: 2, p: 3, mb: 3 }}>
                <Typography variant="h6" gutterBottom color="primary">
                  🔐 Login Credentials
                </Typography>
                <Grid container spacing={2}>
                  <Grid item xs={12} sm={6}>
                    <Typography variant="body2" color="textSecondary">Name</Typography>
                    <Typography variant="body1" sx={{ fontWeight: 'bold', mb: 1 }}>
                      {generatedCredentials.displayName}
                    </Typography>
                  </Grid>
                  <Grid item xs={12} sm={6}>
                    <Typography variant="body2" color="textSecondary">Role</Typography>
                    <Typography variant="body1" sx={{ fontWeight: 'bold', mb: 1 }}>
                      {generatedCredentials.role === 'super_admin' ? 'Super Admin' : 'Country Admin'}
                    </Typography>
                  </Grid>
                  <Grid item xs={12}>
                    <Typography variant="body2" color="textSecondary">Email</Typography>
                    <Typography variant="body1" sx={{ fontWeight: 'bold', mb: 1, fontFamily: 'monospace' }}>
                      {generatedCredentials.email}
                    </Typography>
                  </Grid>
                  <Grid item xs={12}>
                    <Typography variant="body2" color="textSecondary">Password</Typography>
                    <Box sx={{ 
                      backgroundColor: '#fff', 
                      border: '1px solid #2196F3', 
                      borderRadius: 1, 
                      p: 2,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between'
                    }}>
                      <Typography variant="h6" sx={{ fontFamily: 'monospace', color: '#2196F3' }}>
                        {generatedCredentials.password}
                      </Typography>
                      <Button 
                        size="small" 
                        variant="outlined"
                        onClick={() => {
                          navigator.clipboard.writeText(generatedCredentials.password);
                          setSnackbar({ 
                            open: true, 
                            message: 'Password copied to clipboard!', 
                            severity: 'success' 
                          });
                        }}
                      >
                        📋 Copy
                      </Button>
                    </Box>
                  </Grid>
                </Grid>
              </Box>

              <Alert severity="warning" sx={{ mb: 2 }}>
                <Typography variant="subtitle2" gutterBottom>
                  🔒 Important Security Notes:
                </Typography>
                <ul style={{ margin: 0, paddingLeft: '20px' }}>
                  <li>These credentials have been sent to the user's email</li>
                  <li>Ask the user to change their password after first login</li>
                  <li>Keep these credentials secure and do not share them</li>
                  <li>The user can access the admin panel at: <code>{window.location.origin}</code></li>
                </ul>
              </Alert>
            </>
          )}
        </DialogContent>
        <DialogActions>
          <Button 
            onClick={() => {
              setShowCredentials(false);
              setGeneratedCredentials(null);
              handleClose();
            }}
            variant="contained"
            color="primary"
          >
            Done
          </Button>
        </DialogActions>
      </Dialog>

      <Snackbar 
        open={snackbar.open} 
        autoHideDuration={6000} 
        onClose={() => setSnackbar({ ...snackbar, open: false })}
      >
        <Alert 
          severity={snackbar.severity} 
          sx={{ width: '100%' }}
          onClose={() => setSnackbar({ ...snackbar, open: false })}
        >
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Container>
  );
};

export default AdminUsers;
