import React, { useState } from 'react';
import {
  AppBar,
  Box,
  CssBaseline,
  Drawer,
  IconButton,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Toolbar,
  Typography,
  Divider,
  Avatar,
  Menu,
  MenuItem,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Button,
  CircularProgress,
  Alert
} from '@mui/material';
import {
  Menu as MenuIcon,
  Dashboard,
  Assignment,
  Reply,
  ShoppingCart,
  Business,
  BusinessCenter,
  Gavel,
  DirectionsCar,
  Category,
  BrandingWatermark,
  Tune,
  Person,
  Public,
  LocationCity,
  Payment,
  AdminPanelSettings,
  Lock,
  Logout,
  Settings,
  PriceCheck,
  Article,
  // Subscriptions icon removed
  LocalOffer,
  Message,
  StoreMallDirectory,
  Compare,
  Image
} from '@mui/icons-material';
import { Outlet, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import useCountryFilter from '../hooks/useCountryFilter';
import CountryFilterBadge from './CountryFilterBadge';
// Firebase password update removed; integrate backend password change API when available.

const drawerWidth = 280;

const Layout = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const { logout } = useAuth();
  const { adminData, isSuperAdmin } = useCountryFilter();
  
  const [mobileOpen, setMobileOpen] = useState(false);
  const [profileAnchorEl, setProfileAnchorEl] = useState(null);
  const [passwordDialogOpen, setPasswordDialogOpen] = useState(false);
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [passwordError, setPasswordError] = useState('');
  const [passwordData, setPasswordData] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: ''
  });

  const handleDrawerToggle = () => {
    setMobileOpen(!mobileOpen);
  };

  const handleNavigate = (path) => {
    navigate(path);
    setMobileOpen(false);
  };

  const handleProfileMenuOpen = (event) => {
    setProfileAnchorEl(event.currentTarget);
  };

  const handleMenuClose = () => {
    setProfileAnchorEl(null);
  };

  const handlePasswordDialog = () => {
    setPasswordDialogOpen(true);
    handleMenuClose();
  };

  const handleLogout = async () => {
    try {
      console.log('🚪 Layout: Starting logout...');
      handleMenuClose();
      await logout();
      console.log('✅ Layout: Logout successful, navigating to login...');
      navigate('/login', { replace: true });
      console.log('✅ Layout: Navigation completed');
    } catch (error) {
      console.error('❌ Layout: Logout error:', error);
      // Even if logout fails, try to navigate to login
      navigate('/login', { replace: true });
    }
  };

  const handlePasswordChange = async () => {
    setPasswordError('');
    
    if (!passwordData.currentPassword || !passwordData.newPassword) {
      setPasswordError('Please fill in all fields');
      return;
    }

    if (passwordData.newPassword !== passwordData.confirmPassword) {
      setPasswordError('New passwords do not match');
      return;
    }

    if (passwordData.newPassword.length < 6) {
      setPasswordError('New password must be at least 6 characters long');
      return;
    }

    setPasswordLoading(true);
    try {
  // TODO: implement backend password update endpoint e.g., POST /auth/change-password
  // await api.post('/auth/change-password',{ currentPassword: passwordData.currentPassword, newPassword: passwordData.newPassword });
      setPasswordDialogOpen(false);
      setPasswordData({ currentPassword: '', newPassword: '', confirmPassword: '' });
      // Show success message or notification here
    } catch (error) {
      setPasswordError(error.message || 'Failed to update password');
    } finally {
      setPasswordLoading(false);
    }
  };

  const menuItems = [
    { text: 'Dashboard', icon: <Dashboard />, path: '/', access: 'all' },
    { text: 'Requests', icon: <Assignment />, path: '/requests', access: 'all', permission: 'requestManagement' },
    { text: 'Responses', icon: <Reply />, path: '/responses', access: 'all', permission: 'responseManagement' },
    { text: 'Price Listings', icon: <PriceCheck />, path: '/price-listings', access: 'all', permission: 'priceListingManagement' },
    { text: 'Business Price Management', icon: <StoreMallDirectory />, path: '/business-price-management', access: 'all', permission: 'businessPriceManagement' },
    { text: 'Price Comparison', icon: <Compare />, path: '/price-comparison', access: 'all', permission: 'priceComparison' },
    { text: 'Divider' },
    { text: 'Products', icon: <ShoppingCart />, path: '/products', access: 'super_admin', permission: 'productManagement' },
    { text: 'Businesses', icon: <Business />, path: '/businesses', access: 'all', permission: 'businessManagement' },
    { text: 'Global Business Types', icon: <BusinessCenter />, path: '/business-types', access: 'super_admin', permission: 'businessManagement' },
  { text: 'Business Types', icon: <BusinessCenter />, path: '/country-business-types', access: 'country_admin', permission: 'countryBusinessTypeManagement' },
  // Removed: Business Type Benefits and Enhanced Business Benefits
    { text: 'Drivers', icon: <Gavel />, path: '/driver-verification', access: 'all', permission: 'driverVerification' },
    { text: 'Divider' },
    { text: 'Vehicle Types', icon: <Settings />, path: '/vehicles', access: 'super_admin', permission: 'vehicleManagement' },
    { text: 'Vehicle Types', icon: <Settings />, path: '/country-vehicle-types', access: 'country_admin', permission: 'countryVehicleTypeManagement' },
    { text: 'Vehicle Management', icon: <DirectionsCar />, path: '/vehicles-module', access: 'all', permission: 'vehicleManagement' },
    { text: 'Divider' },
    { text: 'Categories', icon: <Category />, path: '/categories', access: 'super_admin', permission: 'categoryManagement' },
    { text: 'Subcategories', icon: <Category />, path: '/subcategories', access: 'super_admin', permission: 'subcategoryManagement' },
    { text: 'Brands', icon: <BrandingWatermark />, path: '/brands', access: 'super_admin', permission: 'brandManagement' },
    { text: 'Variable Types', icon: <Tune />, path: '/variable-types', access: 'super_admin', permission: 'variableTypeManagement' },
    { text: 'Divider' },
    { text: 'Products', icon: <ShoppingCart />, path: '/country-products', access: 'country_admin', permission: 'countryProductManagement' },
    { text: 'Categories', icon: <Category />, path: '/country-categories', access: 'country_admin', permission: 'countryCategoryManagement' },
    { text: 'Subcategories', icon: <Category />, path: '/country-subcategories', access: 'country_admin', permission: 'countrySubcategoryManagement' },
    { text: 'Brands', icon: <BrandingWatermark />, path: '/country-brands', access: 'country_admin', permission: 'countryBrandManagement' },
    { text: 'Variable Types', icon: <Tune />, path: '/country-variable-types', access: 'country_admin', permission: 'countryVariableTypeManagement' },
    { text: 'Divider' },
  { text: 'Users', icon: <Person />, path: '/users', access: 'all', permission: 'userManagement' },
  { text: 'Subscription Management', icon: <PriceCheck />, path: '/subscription-management', access: 'all' },
    { text: 'Promo Codes', icon: <LocalOffer />, path: '/promo-codes', access: 'all', permission: 'promoCodeManagement' },
    { text: 'Page Management', icon: <Article />, path: '/pages', access: 'all', permission: 'countryPageManagement' },
    { text: 'Global Pages', icon: <Public />, path: '/centralized-pages', access: 'super_admin' },
  { text: 'Banners', icon: <Image />, path: '/banners', access: 'country_admin' },
  { text: 'Global Banners', icon: <Image />, path: '/global-banners', access: 'super_admin' },
    { text: 'Divider' },
    { text: 'Country Data', icon: <Public />, path: '/country-data', access: 'super_admin' },
    { text: 'City Management', icon: <LocationCity />, path: '/cities', access: 'all', permission: 'cityManagement' },
    { text: 'Module Management', icon: <Settings />, path: '/modules', access: 'all', permission: 'moduleManagement' },
    { text: 'Payment Methods', icon: <Payment />, path: '/payment-methods', access: 'all', permission: 'paymentMethodManagement' },
    { text: 'SMS Management', icon: <Message />, path: '/sms-management', access: 'super_admin' },
    { text: 'SMS Configuration', icon: <Message />, path: '/sms-config', access: 'country_admin', permission: 'smsConfiguration' },
    { text: 'Divider' },
    { text: 'Admin Management', icon: <AdminPanelSettings />, path: '/admin-management', access: 'super_admin', permission: 'adminUsersManagement' },
  ];

  const drawer = (
    <div>
      <Toolbar />
      <Divider />
      <List>
        {(() => {
          // First filter menu items based on permissions
          const filteredItems = menuItems.filter(item => {
            if (item.text === 'Divider') return false; // Initially exclude dividers
            
            // For super admin - show super_admin and all access items
            if (isSuperAdmin) {
              if (item.access === 'super_admin' || item.access === 'all') {
                // Super admins have access to everything, no permission check needed
                return true;
              }
              return false;
            }
            
            // For country admin - show only country_admin and all access items (excluding super_admin items)
            if (!isSuperAdmin) {
              if (item.access === 'super_admin') return false; // Explicitly exclude super admin items
              if (item.access === 'country_admin') {
                // For country admin items, check permissions
                if (item.permission) {
                  return adminData?.permissions?.[item.permission] === true;
                }
                return true;
              }
              if (item.access === 'all') {
                // For 'all' access items, check permissions
                if (item.permission) {
                  return adminData?.permissions?.[item.permission] === true;
                }
                return true;
              }
            }
            
            return false;
          });

          // Now intelligently add dividers only where needed
          const finalItems = [];
          let lastDividerIndex = -1;
          
          menuItems.forEach((item, originalIndex) => {
            if (item.text === 'Divider') {
              lastDividerIndex = originalIndex;
              return;
            }
            
            // Check if this item should be included
            const shouldInclude = filteredItems.some(filteredItem => 
              filteredItem.text === item.text && filteredItem.path === item.path
            );
            
            if (shouldInclude) {
              // Add divider if there were items before this section and we haven't added a divider yet
              if (lastDividerIndex > -1 && finalItems.length > 0 && 
                  finalItems[finalItems.length - 1].text !== 'Divider') {
                finalItems.push({ text: 'Divider' });
              }
              finalItems.push(item);
              lastDividerIndex = -1; // Reset after adding items
            }
          });

          return finalItems;
        })().map((item, index) => 
          item.text === 'Divider' ? (
            <Divider key={`divider-${index}`} sx={{ my: 1 }} />
          ) : (
            <ListItem key={item.text} disablePadding>
              <ListItemButton
                onClick={() => handleNavigate(item.path)}
                sx={{
                  backgroundColor: location.pathname === item.path ? 'action.selected' : 'transparent'
                }}
              >
                <ListItemIcon>{item.icon}</ListItemIcon>
                <ListItemText primary={item.text} />
              </ListItemButton>
            </ListItem>
          )
        )}
      </List>
    </div>
  );

  return (
    <Box sx={{ display: 'flex' }}>
      <CssBaseline />
      <AppBar
        position="fixed"
        sx={{
          width: { sm: `calc(100% - ${drawerWidth}px)` },
          ml: { sm: `${drawerWidth}px` },
        }}
      >
        <Toolbar>
          <IconButton
            color="inherit"
            aria-label="open drawer"
            edge="start"
            onClick={handleDrawerToggle}
            sx={{ mr: 2, display: { sm: 'none' } }}
          >
            <MenuIcon />
          </IconButton>
          <Typography variant="h6" noWrap component="div" sx={{ flexGrow: 1 }}>
            Request Marketplace Admin
          </Typography>
          
          {/* Country Filter Badge */}
          <CountryFilterBadge />
          
          {/* Profile Menu */}
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
            <Typography variant="body2" sx={{ display: { xs: 'none', sm: 'block' } }}>
              {adminData?.name || adminData?.email || 'Admin'}
            </Typography>
            <Avatar
              sx={{ bgcolor: 'secondary.main', cursor: 'pointer' }}
              onClick={handleProfileMenuOpen}
            >
              {(adminData?.name || adminData?.email || 'A')[0].toUpperCase()}
            </Avatar>
          </Box>
        </Toolbar>
      </AppBar>
      
      {/* Profile Menu Dropdown */}
      <Menu
        anchorEl={profileAnchorEl}
        open={Boolean(profileAnchorEl)}
        onClose={handleMenuClose}
        anchorOrigin={{
          vertical: 'bottom',
          horizontal: 'right',
        }}
        transformOrigin={{
          vertical: 'top',
          horizontal: 'right',
        }}
      >
        <MenuItem onClick={handlePasswordDialog}>
          <ListItemIcon>
            <Lock fontSize="small" />
          </ListItemIcon>
          Change Password
        </MenuItem>
        <MenuItem onClick={handleLogout}>
          <ListItemIcon>
            <Logout fontSize="small" />
          </ListItemIcon>
          Logout
        </MenuItem>
      </Menu>

      {/* Change Password Dialog */}
      <Dialog open={passwordDialogOpen} onClose={() => setPasswordDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Change Password</DialogTitle>
        <DialogContent>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 2 }}>
            {passwordError && <Alert severity="error">{passwordError}</Alert>}
            <TextField
              type="password"
              label="Current Password"
              value={passwordData.currentPassword}
              onChange={(e) => setPasswordData({...passwordData, currentPassword: e.target.value})}
              fullWidth
            />
            <TextField
              type="password"
              label="New Password"
              value={passwordData.newPassword}
              onChange={(e) => setPasswordData({...passwordData, newPassword: e.target.value})}
              fullWidth
            />
            <TextField
              type="password"
              label="Confirm New Password"
              value={passwordData.confirmPassword}
              onChange={(e) => setPasswordData({...passwordData, confirmPassword: e.target.value})}
              fullWidth
            />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPasswordDialogOpen(false)}>Cancel</Button>
          <Button onClick={handlePasswordChange} disabled={passwordLoading}>
            {passwordLoading ? <CircularProgress size={24} /> : 'Change Password'}
          </Button>
        </DialogActions>
      </Dialog>

      <Box
        component="nav"
        sx={{ width: { sm: drawerWidth }, flexShrink: { sm: 0 } }}
        aria-label="mailbox folders"
      >
        <Drawer
          variant="temporary"
          open={mobileOpen}
          onClose={handleDrawerToggle}
          ModalProps={{
            keepMounted: true,
          }}
          sx={{
            display: { xs: 'block', sm: 'none' },
            '& .MuiDrawer-paper': { boxSizing: 'border-box', width: drawerWidth },
          }}
        >
          {drawer}
        </Drawer>
        <Drawer
          variant="permanent"
          sx={{
            display: { xs: 'none', sm: 'block' },
            '& .MuiDrawer-paper': { boxSizing: 'border-box', width: drawerWidth },
          }}
          open
        >
          {drawer}
        </Drawer>
      </Box>
      <Box
        component="main"
        sx={{ flexGrow: 1, p: 3, width: { sm: `calc(100% - ${drawerWidth}px)` } }}
      >
        <Toolbar />
        <Outlet />
      </Box>
    </Box>
  );
};

export default Layout;
