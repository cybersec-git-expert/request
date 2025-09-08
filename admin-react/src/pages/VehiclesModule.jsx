/**
 * VehiclesModule - Administrative Panel for Vehicle Management
 * 
 * @description
 * This component provides a comprehensive interface for managing registered vehicles
 * in the Request Marketplace platform. It displays driver verification data that includes
 * vehicle information, allowing administrators to view, filter, and manage vehicles
 * across different countries and vehicle types.
 * 
 * @features
 * - Country-based filtering (Super Admin sees all, Country Admin sees only their country)
 * - Vehicle type filtering and search functionality
 * - Real-time statistics dashboard (Total, Active, Available vehicles)
 * - Detailed vehicle and driver information display
 * - Responsive table with vehicle images and driver avatars
 * - Modal dialog for detailed vehicle/driver view
 * - Permission-based access control
 * 
 * @data_sources
 * - `new_driver_verifications` collection: Contains driver data with embedded vehicle info
 * - `vehicle_types` collection: Vehicle type definitions and configurations
 * 
 * @permissions
 * - Super Admin: Full access to all vehicles across all countries
 * - Country Admin: Access only to vehicles in their assigned country
 * - Read-only access for viewing, editing reserved for super admins
 * 
 * @dependencies
 * - useCountryFilter: Custom hook for country-based data filtering
 * - Firebase Firestore: Backend database for vehicle and driver data
 * - Material-UI: UI component library for consistent design
 * 
 * @author Request Marketplace Team
 * @version 2.0.0
 * @since 2025-08-16
 */

import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Chip,
  IconButton,
  Button,
  Grid,
  Card,
  CardContent,
  TextField,
  InputAdornment,
  Menu,
  MenuItem,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Alert,
  CircularProgress,
  Tooltip,
  Fab,
  Avatar
} from '@mui/material';
import {
  Search,
  Visibility,
  Edit,
  Delete,
  FilterList,
  Refresh,
  Add,
  DirectionsCar,
  TwoWheeler,
  LocalShipping,
  Speed,
  Palette
} from '@mui/icons-material';
import useCountryFilter from '../hooks/useCountryFilter.jsx';

/**
 * VehiclesModule Component
 * 
 * Main React component for vehicle management interface
 * Handles vehicle display, filtering, and management operations
 */
const VehiclesModule = () => {
  // === HOOKS AND CONTEXT ===
  /**
   * Country filtering hook - provides country-based data access control
   * @returns {Object} Country filtering utilities and admin data
   */
  const {
    getFilteredData,    // Function to get country-filtered data
    adminData,          // Current admin user data
    isSuperAdmin,       // Boolean: true if super admin
    getCountryDisplayName, // Function to format country names
    userCountry         // Current user's assigned country
  } = useCountryFilter();

  // === STATE MANAGEMENT ===
  /**
   * Component state variables for managing UI and data
   */
  const [vehicles, setVehicles] = useState([]);              // Array of vehicle data with driver info
  const [vehicleTypes, setVehicleTypes] = useState([]);      // Array of available vehicle types
  const [vehicleTypesMap, setVehicleTypesMap] = useState({}); // ID-to-name mapping for vehicle types
  const [loading, setLoading] = useState(true);              // Loading state for async operations
  const [error, setError] = useState(null);                  // Error state for error handling
  const [searchTerm, setSearchTerm] = useState('');          // Search input value
  const [filterAnchorEl, setFilterAnchorEl] = useState(null); // Anchor element for filter menu
  const [selectedType, setSelectedType] = useState('all');   // Currently selected vehicle type filter
  const [selectedVehicle, setSelectedVehicle] = useState(null); // Vehicle selected for detail view
  const [viewDialogOpen, setViewDialogOpen] = useState(false); // Dialog open/close state

  // === UI CONFIGURATION ===
  /**
   * Color scheme mapping for different vehicle types
   * Used for consistent visual representation across the interface
   */
  const typeColors = {
    car: 'primary',
    bike: 'success', 
    truck: 'warning',
    van: 'info',
    bus: 'secondary'
  };

  /**
   * Icon mapping for different vehicle types
   * Provides visual cues for quick vehicle type identification
   */
  const typeIcons = {
    car: <DirectionsCar />,
    bike: <TwoWheeler />,
    truck: <LocalShipping />,
    van: <DirectionsCar />,
    bus: <LocalShipping />
  };

  // === CORE DATA LOADING FUNCTION ===
  /**
   * Loads vehicles and vehicle types data from Firebase
   * 
   * @async
   * @function loadVehicles
   * @description
   * This function performs a two-step data loading process:
   * 1. Load vehicle types to create a mapping for display names
   * 2. Load driver verification data that contains embedded vehicle information
   * 
   * The function implements country-based filtering through the useCountryFilter hook,
   * ensuring admins only see data relevant to their permissions.
   * 
   * @data_structure
   * Vehicle data is extracted from driver verification documents with the following mapping:
   * - Driver Info: fullName, phoneNumber, email, status, country
   * - Vehicle Info: vehicleNumber, vehicleType, vehicleModel, vehicleColor, vehicleYear, vehicleImageUrls
   * 
   * @error_handling
   * Comprehensive error handling with user-friendly error messages and retry functionality
   */
  const loadVehicles = async () => {
    try {
      setLoading(true);
      setError(null);

      // === STEP 1: Load Vehicle Types ===
      // Load vehicle types first to create ID-to-name mapping
      const vehicleTypesData = await getFilteredData('vehicle_types', adminData);
      setVehicleTypes(vehicleTypesData || []);
      
      // Create a mapping of vehicle type IDs to display names
      // This allows us to show user-friendly names instead of IDs
      const typesMap = {};
      if (vehicleTypesData) {
        vehicleTypesData.forEach(type => {
          typesMap[type.id] = type.name || type.type_name || 'Unknown';
        });
      }
      setVehicleTypesMap(typesMap);

      // === STEP 2: Load Driver Verification Data ===
      // Driver verifications contain embedded vehicle information
      // This is the primary source of vehicle data in the system
      const driversData = await getFilteredData('new_driver_verifications', adminData);
      
      if (driversData) {
        // === DATA TRANSFORMATION ===
        // Transform driver verification data into vehicle-centric format
        // This mapping ensures we have all necessary information for display
        const vehiclesWithDrivers = driversData.map(driver => {
          return {
            // === UNIQUE IDENTIFIER ===
            id: driver.id,
            
            // === DRIVER INFORMATION ===
            // Using correct field names based on Firebase schema analysis
            driverName: driver.fullName || `${driver.firstName || ''} ${driver.lastName || ''}`.trim() || 'N/A',
            driverPhone: driver.phoneNumber || driver.phone || 'N/A', 
            driverEmail: driver.email || 'N/A',
            status: driver.status || 'pending',
            country: driver.country || userCountry,
            
            // === VEHICLE INFORMATION ===
            // Mapping vehicle fields from driver verification data
            vehicleNumber: driver.vehicleNumber || 'N/A',                    // License plate number
            vehicleType: typesMap[driver.vehicleType] || driver.vehicleType || 'Unknown', // Human-readable type name
            vehicleTypeId: driver.vehicleType,                               // Keep original ID for filtering
            vehicleBrand: driver.vehicleBrand || 'N/A',                     // Vehicle manufacturer
            vehicleModel: driver.vehicleModel || '',                         // Vehicle model
            vehicleColor: driver.vehicleColor || 'N/A',                     // Vehicle color
            vehicleYear: driver.vehicleYear || 'N/A',                       // Manufacturing year
            vehicleImages: driver.vehicleImageUrls ? Object.values(driver.vehicleImageUrls) : [] // Array of image URLs
          };
        });
        
        setVehicles(vehiclesWithDrivers);
        
        setVehicles(vehiclesWithDrivers);
      } else {
        // No data available - set empty array
        setVehicles([]);
      }
      
    } catch (error) {
      // === ERROR HANDLING ===
      console.error('Error loading vehicles:', error);
      setError('Failed to load vehicles');
      setVehicles([]);
    } finally {
      // === CLEANUP ===
      // Always stop loading regardless of success/failure
      setLoading(false);
    }
  };

  // === LIFECYCLE MANAGEMENT ===
  /**
   * Effect hook to load data when admin data changes
   * Ensures data is refreshed when user permissions or country assignments change
   */
  useEffect(() => {
    loadVehicles();
  }, [adminData]);

  // === EVENT HANDLERS ===
  /**
   * Opens the vehicle detail dialog
   * @param {Object} vehicle - The vehicle object to display in detail
   */
  const handleViewVehicle = (vehicle) => {
    setSelectedVehicle(vehicle);
    setViewDialogOpen(true);
  };

  /**
   * Handles vehicle type filter selection
   * @param {string} type - The vehicle type ID or 'all' for no filter
   */
  const handleTypeFilter = (type) => {
    setSelectedType(type);
    setFilterAnchorEl(null);
  };

  // === FILTERING LOGIC ===
  /**
   * Applies search and type filters to the vehicle list
   * 
   * @returns {Array} Filtered array of vehicles based on current search and filter criteria
   * 
   * @filtering_criteria
   * - Search: Matches driver name, vehicle model, vehicle number, or vehicle color
   * - Type: Filters by vehicle type ID or type name (case-insensitive)
   * - Both filters work together (AND operation)
   */
  const filteredVehicles = vehicles.filter(vehicle => {
    // === SEARCH FILTER ===
    // Check if search term matches any of the searchable fields
    const matchesSearch = !searchTerm || 
                         vehicle.driverName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         vehicle.vehicleModel?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         vehicle.vehicleNumber?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         vehicle.vehicleColor?.toLowerCase().includes(searchTerm.toLowerCase());

    // === TYPE FILTER ===
    // Check if vehicle matches selected type (exact ID match or name contains filter)
    const matchesType = selectedType === 'all' || 
                       vehicle.vehicleTypeId === selectedType ||
                       vehicle.vehicleType?.toLowerCase().includes(selectedType.toLowerCase());

    return matchesSearch && matchesType;
  });

  // === UTILITY FUNCTIONS ===
  /**
   * Formats timestamp for display
   * @param {Object|string|number} timestamp - Firebase timestamp or Date string/number
   * @returns {string} Formatted date and time string
   */
  const formatDate = (timestamp) => {
    if (!timestamp) return 'N/A';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
  };

  // === STATISTICS CALCULATION ===
  /**
   * Calculates vehicle statistics for dashboard display
   * 
   * @returns {Object} Statistics object containing vehicle counts and type breakdown
   * 
   * @statistics_included
   * - total: Total number of filtered vehicles
   * - active: Number of approved/active vehicles
   * - available: Number of currently available vehicles
   * - vehicleTypeStats: Array of type-specific counts with colors
   */
  const getVehicleStats = () => {
    const totalVehicles = filteredVehicles.length;
    const activeVehicles = filteredVehicles.filter(v => v.isActive).length;
    const availableVehicles = filteredVehicles.filter(v => v.availability).length;
    
    // === VEHICLE TYPE BREAKDOWN ===
    // Calculate count for each vehicle type with appropriate colors
    const vehicleTypeStats = vehicleTypes.map(vType => {
      const matchingVehicles = vehicles.filter(v => v.vehicleType === vType.id);
      return {
        name: vType.name,
        count: matchingVehicles.length,
        // Dynamic color assignment based on vehicle type name
        color: vType.name.toLowerCase().includes('car') ? 'primary' : 
               vType.name.toLowerCase().includes('bike') ? 'success' : 
               vType.name.toLowerCase().includes('van') ? 'info' : 
               vType.name.toLowerCase().includes('truck') ? 'warning' : 'secondary'
      };
    });

    return {
      total: totalVehicles,
      active: activeVehicles,
      available: availableVehicles,
      vehicleTypeStats
    };
  };

  // Calculate current statistics
  const stats = getVehicleStats();

  // === LOADING STATE ===
  /**
   * Loading spinner display while data is being fetched
   */
  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  // === ERROR STATE ===
  /**
   * Error display with retry functionality
   */
  if (error) {
    return (
      <Alert severity="error" action={
        <Button color="inherit" size="small" onClick={loadVehicles}>
          Retry
        </Button>
      }>
        {error}
      </Alert>
    );
  }

  // === MAIN COMPONENT RENDER ===
  return (
    <Box>
      {/* === HEADER SECTION === */}
      {/* Page title and description with permission-based messaging */}
      <Box mb={3}>
        <Typography variant="h4" gutterBottom>
          Vehicle Management
        </Typography>
        <Typography variant="body2" color="text.secondary">
          {isSuperAdmin ? 'View all registered vehicles across countries by vehicle type' : `View registered vehicles in ${getCountryDisplayName(userCountry)} by vehicle type`}
        </Typography>
      </Box>

      {/* === STATISTICS DASHBOARD === */}
      {/* Three-card layout showing key vehicle metrics */}
      <Grid container spacing={3} mb={3}>
        {/* Total Vehicles Card */}
        <Grid item xs={12} sm={6} md={4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography color="text.secondary" gutterBottom variant="overline">
                    Total Vehicles
                  </Typography>
                  <Typography variant="h4">
                    {stats.total}
                  </Typography>
                </Box>
                <DirectionsCar color="primary" sx={{ fontSize: 40, opacity: 0.3 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>
        
        {/* Active Vehicles Card */}
        <Grid item xs={12} sm={6} md={4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography color="text.secondary" gutterBottom variant="overline">
                    Active Vehicles
                  </Typography>
                  <Typography variant="h4" color="success.main">
                    {stats.active}
                  </Typography>
                </Box>
                <DirectionsCar color="success" sx={{ fontSize: 40, opacity: 0.3 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>
        
        {/* Available Vehicles Card */}
        <Grid item xs={12} sm={6} md={4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography color="text.secondary" gutterBottom variant="overline">
                    Available Now
                  </Typography>
                  <Typography variant="h4" color="info.main">
                    {stats.available}
                  </Typography>
                </Box>
                <Speed color="info" sx={{ fontSize: 40, opacity: 0.3 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* === CONTROLS SECTION === */}
      {/* Search, filter, and action controls */}
      <Paper sx={{ p: 2, mb: 3 }}>
        <Box display="flex" gap={2} alignItems="center" flexWrap="wrap">
          {/* Search Input */}
          <TextField
            placeholder="Search vehicles..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <Search />
                </InputAdornment>
              ),
            }}
            sx={{ minWidth: 300 }}
          />
          {/* Filter Button */}
          <Button
            startIcon={<FilterList />}
            onClick={(e) => setFilterAnchorEl(e.currentTarget)}
          >
            FILTERS ({selectedType === 'all' ? 'NONE' : selectedType.toUpperCase()})
          </Button>
          {/* Refresh Button */}
          <Button
            startIcon={<Refresh />}
            onClick={loadVehicles}
          >
            REFRESH
          </Button>
          {/* Add Vehicle Button (Super Admin Only) */}
          {isSuperAdmin && (
            <Button
              variant="contained"
              startIcon={<Add />}
            >
              Add Vehicle
            </Button>
          )}
        </Box>
      </Paper>

      {/* === VEHICLES DATA TABLE === */}
      {/* Main table displaying vehicle and driver information */}
      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Driver</TableCell>
              <TableCell>Vehicle</TableCell>
              <TableCell>Brand/Model</TableCell>
              <TableCell>Type</TableCell>
              <TableCell>Color</TableCell>
              <TableCell>Year</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Country</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredVehicles.map((vehicle) => (
              <TableRow key={vehicle.id} hover>
                {/* Driver Information Column */}
                <TableCell>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                    <Avatar sx={{ bgcolor: 'primary.main' }}>
                      {vehicle.driverName?.charAt(0) || 'D'}
                    </Avatar>
                    <Box>
                      <Typography variant="subtitle2" fontWeight="medium">
                        {vehicle.driverName || 'N/A'}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        {vehicle.driverPhone || 'No phone'}
                      </Typography>
                    </Box>
                  </Box>
                </TableCell>
                
                {/* Vehicle Information Column */}
                <TableCell>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                    {/* Vehicle Image or Default Icon */}
                    {vehicle.vehicleImages?.[0] ? (
                      <Avatar
                        src={vehicle.vehicleImages[0]}
                        alt="Vehicle"
                        variant="rounded"
                        sx={{ width: 40, height: 40 }}
                      />
                    ) : (
                      <Avatar variant="rounded" sx={{ width: 40, height: 40, bgcolor: 'grey.300' }}>
                        <DirectionsCar />
                      </Avatar>
                    )}
                    <Box>
                      <Typography variant="subtitle2" fontWeight="medium">
                        {vehicle.vehicleNumber || 'N/A'}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        {vehicle.vehicleType || 'Unknown type'}
                      </Typography>
                    </Box>
                  </Box>
                </TableCell>
                
                {/* Vehicle Model Column */}
                <TableCell>
                  <Typography variant="body2">
                    {vehicle.vehicleModel || 'N/A'}
                  </Typography>
                </TableCell>
                
                {/* Vehicle Type Column */}
                <TableCell>
                  <Chip
                    label={vehicle.vehicleType || 'Unknown'}
                    size="small"
                    variant="outlined"
                    color="primary"
                  />
                </TableCell>
                
                {/* Vehicle Color Column */}
                <TableCell>
                  <Typography variant="body2">
                    {vehicle.vehicleColor || 'N/A'}
                  </Typography>
                </TableCell>
                
                {/* Vehicle Year Column */}
                <TableCell>
                  <Typography variant="body2">
                    {vehicle.vehicleYear || 'N/A'}
                  </Typography>
                </TableCell>
                
                {/* Status Column */}
                <TableCell>
                  <Chip
                    label={vehicle.status === 'approved' ? 'Active' : 'Pending'}
                    size="small"
                    color={vehicle.status === 'approved' ? 'success' : 'warning'}
                    variant="outlined"
                  />
                </TableCell>
                
                {/* Country Column */}
                <TableCell>
                  <Chip
                    label={vehicle.country || userCountry}
                    size="small"
                    variant="outlined"
                  />
                </TableCell>
                
                {/* Actions Column */}
                <TableCell>
                  <Box sx={{ display: 'flex', gap: 0.5 }}>
                    {/* View Details Button */}
                    <Tooltip title="View Details">
                      <IconButton size="small" onClick={() => handleViewVehicle(vehicle)}>
                        <Visibility />
                      </IconButton>
                    </Tooltip>
                    {/* Edit/Delete Buttons (Super Admin Only) */}
                    {isSuperAdmin && (
                      <>
                        <Tooltip title="Edit">
                          <IconButton size="small">
                            <Edit />
                          </IconButton>
                        </Tooltip>
                        <Tooltip title="Delete">
                          <IconButton size="small">
                            <Delete />
                          </IconButton>
                        </Tooltip>
                      </>
                    )}
                  </Box>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      {/* === FILTER MENU === */}
      {/* Dropdown menu for vehicle type filtering */}
      <Menu
        anchorEl={filterAnchorEl}
        open={Boolean(filterAnchorEl)}
        onClose={() => setFilterAnchorEl(null)}
      >
        <MenuItem onClick={() => handleTypeFilter('all')}>All Types</MenuItem>
        {vehicleTypes.map((type) => (
          <MenuItem key={type.id} onClick={() => handleTypeFilter(type.id)}>
            {type.name || type.type_name || 'Unknown'}
          </MenuItem>
        ))}
      </Menu>

      {/* === VEHICLE DETAIL DIALOG === */}
      {/* Modal for detailed vehicle and driver information */}
      <Dialog
        open={viewDialogOpen}
        onClose={() => setViewDialogOpen(false)}
        maxWidth="md"
        fullWidth
      >
        {selectedVehicle && (
          <>
            <DialogTitle>
              Driver & Vehicle Details: {selectedVehicle.driverName}
            </DialogTitle>
            <DialogContent>
              <Grid container spacing={3}>
                {/* === LEFT COLUMN: DRIVER INFORMATION === */}
                <Grid item xs={12} sm={6}>
                  <Typography variant="h6" gutterBottom color="primary">Driver Information</Typography>
                  
                  <Typography variant="subtitle2" gutterBottom>Full Name</Typography>
                  <Typography variant="body2" paragraph>
                    {selectedVehicle.driverName || 'N/A'}
                  </Typography>
                  
                  <Typography variant="subtitle2" gutterBottom>Phone Number</Typography>
                  <Typography variant="body2" paragraph>
                    {selectedVehicle.driverPhone || 'N/A'}
                  </Typography>

                  <Typography variant="subtitle2" gutterBottom>Email</Typography>
                  <Typography variant="body2" paragraph>
                    {selectedVehicle.driverEmail || 'N/A'}
                  </Typography>

                  <Typography variant="subtitle2" gutterBottom>Country</Typography>
                  <Typography variant="body2" paragraph>
                    {selectedVehicle.country || 'N/A'}
                  </Typography>

                  <Typography variant="subtitle2" gutterBottom>Status</Typography>
                  <Chip
                    label={selectedVehicle.status === 'approved' ? 'Approved' : 'Pending'}
                    color={selectedVehicle.status === 'approved' ? 'success' : 'warning'}
                    size="small"
                    sx={{ mb: 2 }}
                  />
                </Grid>
                
                {/* === RIGHT COLUMN: VEHICLE INFORMATION === */}
                <Grid item xs={12} sm={6}>
                  <Typography variant="h6" gutterBottom color="primary">Vehicle Information</Typography>
                  
                  <Typography variant="subtitle2" gutterBottom>Vehicle Number</Typography>
                  <Typography variant="body2" paragraph>
                    {selectedVehicle.vehicleNumber || 'N/A'}
                  </Typography>
                  
                  <Typography variant="subtitle2" gutterBottom>Type</Typography>
                  <Chip
                    label={selectedVehicle.vehicleType || 'Unknown'}
                    color="primary"
                    size="small"
                    sx={{ mb: 2 }}
                  />

                  <Typography variant="subtitle2" gutterBottom>Brand & Model</Typography>
                  <Typography variant="body2" paragraph>
                    {selectedVehicle.vehicleBrand || 'N/A'} {selectedVehicle.vehicleModel || ''}
                  </Typography>

                  <Typography variant="subtitle2" gutterBottom>Year & Color</Typography>
                  <Typography variant="body2" paragraph>
                    {selectedVehicle.vehicleYear || 'N/A'} • {selectedVehicle.vehicleColor || 'N/A'}
                  </Typography>

                  {/* Vehicle Images Gallery */}
                  {selectedVehicle.vehicleImages && selectedVehicle.vehicleImages.length > 0 && (
                    <>
                      <Typography variant="subtitle2" gutterBottom>Vehicle Images</Typography>
                      <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap', mb: 2 }}>
                        {selectedVehicle.vehicleImages.map((image, index) => (
                          <img
                            key={index}
                            src={image}
                            alt={`Vehicle ${index + 1}`}
                            style={{ 
                              width: 80, 
                              height: 80, 
                              objectFit: 'cover', 
                              borderRadius: 8,
                              border: '1px solid #ddd'
                            }}
                          />
                        ))}
                      </Box>
                    </>
                  )}
                </Grid>
              </Grid>
            </DialogContent>
            <DialogActions>
              <Button onClick={() => setViewDialogOpen(false)}>Close</Button>
            </DialogActions>
          </>
        )}
      </Dialog>

      {/* === FLOATING ACTION BUTTON === */}
      {/* Quick add vehicle button for super admins */}
      {isSuperAdmin && (
        <Fab
          color="primary"
          aria-label="add vehicle"
          sx={{ position: 'fixed', bottom: 16, right: 16 }}
        >
          <Add />
        </Fab>
      )}
    </Box>
  );
};

export default VehiclesModule;
