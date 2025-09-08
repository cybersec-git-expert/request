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
  Avatar,
  ImageList,
  ImageListItem
} from '@mui/material';
import {
  Search,
  Visibility,
  CheckCircle,
  Cancel,
  FilterList,
  Refresh,
  DirectionsCar,
  Person,
  AccessTime,
  Verified,
  Pending,
  Error as ErrorIcon
} from '@mui/icons-material';
import useCountryFilter from '../hooks/useCountryFilter.jsx';
import { DataLookupService } from '../services/DataLookupService.js';

const DriverVerificationModule = () => {
  const {
    getFilteredData,
    adminData,
    isSuperAdmin,
    getCountryDisplayName,
    userCountry
  } = useCountryFilter();

  const [drivers, setDrivers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterAnchorEl, setFilterAnchorEl] = useState(null);
  const [selectedStatus, setSelectedStatus] = useState('all');
  const [selectedDriver, setSelectedDriver] = useState(null);
  const [viewDialogOpen, setViewDialogOpen] = useState(false);
  const [userDataMap, setUserDataMap] = useState(new Map());

  const statusColors = {
    pending: 'warning',
    approved: 'success',
    rejected: 'error',
    suspended: 'default'
  };

  const loadDrivers = async () => {
    try {
      setLoading(true);
      setError(null);

      const data = await getFilteredData('new_driver_verifications', adminData);
      setDrivers(data || []);
      
      // Fetch user data for all drivers
      if (data && data.length > 0) {
        const uniqueUserIds = [...new Set(data.map(driver => driver.userId).filter(Boolean))];
        const userData = await DataLookupService.getMultipleUsers(uniqueUserIds);
        
        const userMap = new Map();
        uniqueUserIds.forEach((userId, index) => {
          if (userData[index]) {
            userMap.set(userId, userData[index]);
          }
        });
        setUserDataMap(userMap);
      }
      
      console.log(`📊 Loaded ${data?.length || 0} driver verifications for ${isSuperAdmin ? 'super admin' : `country admin (${userCountry})`}`);
    } catch (err) {
      console.error('Error loading driver verifications:', err);
      setError('Failed to load driver verifications: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadDrivers();
  }, [adminData]);

  const handleViewDriver = (driver) => {
    setSelectedDriver(driver);
    setViewDialogOpen(true);
  };

  const handleStatusFilter = (status) => {
    setSelectedStatus(status);
    setFilterAnchorEl(null);
  };

  const filteredDrivers = drivers.filter(driver => {
    const matchesSearch = !searchTerm || 
                         driver.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         driver.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         driver.licenseNumber?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         DataLookupService.formatUserDisplayName(userDataMap.get(driver.userId))
                           ?.toLowerCase().includes(searchTerm.toLowerCase());

    const matchesStatus = selectedStatus === 'all' || driver.verificationStatus === selectedStatus;

    return matchesSearch && matchesStatus;
  });

  const getStatusCounts = () => {
    const counts = drivers.reduce((acc, driver) => {
      const status = driver.verificationStatus || 'pending';
      acc[status] = (acc[status] || 0) + 1;
      return acc;
    }, {});

    return {
      total: drivers.length,
      pending: counts.pending || 0,
      approved: counts.approved || 0,
      rejected: counts.rejected || 0
    };
  };

  const statusCounts = getStatusCounts();

  const formatDate = (timestamp) => {
    if (!timestamp) return 'N/A';
    
    let date;
    if (timestamp?.toDate) {
      date = timestamp.toDate();
    } else if (timestamp?.seconds) {
      date = new Date(timestamp.seconds * 1000);
    } else {
      date = new Date(timestamp);
    }
    
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return (
      <Alert severity="error" sx={{ m: 2 }}>
        {error}
        <Button onClick={loadDrivers} sx={{ ml: 2 }}>
          Retry
        </Button>
      </Alert>
    );
  }

  return (
    <Box sx={{ p: 3 }}>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Box>
          <Typography variant="h4" gutterBottom>
            Driver Verification Management
          </Typography>
          <Typography variant="body2" color="text.secondary">
            {isSuperAdmin ? 'Manage driver verifications across all countries' : `Manage driver verifications in ${getCountryDisplayName(userCountry)}`}
          </Typography>
        </Box>
        <Button
          variant="contained"
          startIcon={<Refresh />}
          onClick={loadDrivers}
        >
          Refresh
        </Button>
      </Box>

      {/* Stats Cards */}
      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography variant="h4" color="primary">
                    {statusCounts.total}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Total Applications
                  </Typography>
                </Box>
                <DirectionsCar color="primary" sx={{ fontSize: 40 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography variant="h4" color="warning.main">
                    {statusCounts.pending}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Pending Review
                  </Typography>
                </Box>
                <Pending color="warning" sx={{ fontSize: 40 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography variant="h4" color="success.main">
                    {statusCounts.approved}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Approved
                  </Typography>
                </Box>
                <Verified color="success" sx={{ fontSize: 40 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography variant="h4" color="error.main">
                    {statusCounts.rejected}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Rejected
                  </Typography>
                </Box>
                <ErrorIcon color="error" sx={{ fontSize: 40 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Search and Filter Bar */}
      <Box display="flex" gap={2} mb={3}>
        <TextField
          placeholder="Search drivers..."
          variant="outlined"
          size="small"
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

        <Button
          variant="outlined"
          startIcon={<FilterList />}
          onClick={(e) => setFilterAnchorEl(e.currentTarget)}
        >
          FILTERS ({selectedStatus === 'all' ? 'NONE' : selectedStatus.toUpperCase()})
        </Button>

        <Menu
          anchorEl={filterAnchorEl}
          open={Boolean(filterAnchorEl)}
          onClose={() => setFilterAnchorEl(null)}
        >
          <MenuItem onClick={() => handleStatusFilter('all')}>
            All Status
          </MenuItem>
          <MenuItem onClick={() => handleStatusFilter('pending')}>
            Pending
          </MenuItem>
          <MenuItem onClick={() => handleStatusFilter('approved')}>
            Approved
          </MenuItem>
          <MenuItem onClick={() => handleStatusFilter('rejected')}>
            Rejected
          </MenuItem>
        </Menu>

        <Button
          variant="contained"
          startIcon={<Refresh />}
          onClick={loadDrivers}
        >
          REFRESH
        </Button>
      </Box>

      {/* Drivers Table */}
      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Driver</TableCell>
              <TableCell>License</TableCell>
              <TableCell>Phone</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Applied</TableCell>
              <TableCell>Country</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredDrivers.map((driver) => (
              <TableRow key={driver.id} hover>
                <TableCell>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Avatar sx={{ width: 32, height: 32 }}>
                      {driver.name?.charAt(0) || 'D'}
                    </Avatar>
                    <Box>
                      <Typography variant="body2" fontWeight="medium">
                        {DataLookupService.formatUserDisplayName(userDataMap.get(driver.userId)) || driver.name || 'Unknown Driver'}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        {driver.email || 'No email'}
                      </Typography>
                    </Box>
                  </Box>
                </TableCell>
                
                <TableCell>
                  <Typography variant="body2">
                    {driver.licenseNumber || 'N/A'}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    Exp: {driver.licenseExpiry ? formatDate(driver.licenseExpiry) : 'N/A'}
                  </Typography>
                </TableCell>

                <TableCell>
                  <Typography variant="body2">
                    {driver.phoneNumber || 'N/A'}
                  </Typography>
                </TableCell>

                <TableCell>
                  <Chip
                    label={driver.verificationStatus || 'pending'}
                    color={statusColors[driver.verificationStatus] || 'default'}
                    size="small"
                    variant="filled"
                  />
                </TableCell>

                <TableCell>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <AccessTime fontSize="small" color="action" />
                    <Typography variant="body2">
                      {formatDate(driver.createdAt || driver.submittedAt)}
                    </Typography>
                  </Box>
                </TableCell>

                <TableCell>
                  <Chip
                    label={driver.country || userCountry}
                    size="small"
                    variant="outlined"
                  />
                </TableCell>

                <TableCell>
                  <Tooltip title="View Details">
                    <IconButton
                      size="small"
                      onClick={() => handleViewDriver(driver)}
                    >
                      <Visibility />
                    </IconButton>
                  </Tooltip>
                  {driver.verificationStatus === 'pending' && (
                    <>
                      <Tooltip title="Approve">
                        <IconButton
                          size="small"
                          color="success"
                          onClick={() => {
                            // Handle approve
                            console.log('Approve driver:', driver.id);
                          }}
                        >
                          <CheckCircle />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Reject">
                        <IconButton
                          size="small"
                          color="error"
                          onClick={() => {
                            // Handle reject
                            console.log('Reject driver:', driver.id);
                          }}
                        >
                          <Cancel />
                        </IconButton>
                      </Tooltip>
                    </>
                  )}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>

        {filteredDrivers.length === 0 && (
          <Box textAlign="center" py={4}>
            <Typography variant="body1" color="text.secondary">
              No driver verifications found
            </Typography>
          </Box>
        )}
      </TableContainer>

      {/* View Driver Dialog */}
      <Dialog
        open={viewDialogOpen}
        onClose={() => setViewDialogOpen(false)}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>
          Driver Verification Details
        </DialogTitle>
        <DialogContent>
          {selectedDriver && (
            <Box>
              <Grid container spacing={2}>
                <Grid item xs={12} md={6}>
                  <Typography variant="subtitle2" gutterBottom>
                    Personal Information
                  </Typography>
                  <Typography variant="body2">
                    <strong>Name:</strong> {selectedDriver.name || 'N/A'}
                  </Typography>
                  <Typography variant="body2">
                    <strong>Email:</strong> {selectedDriver.email || 'N/A'}
                  </Typography>
                  <Typography variant="body2">
                    <strong>Phone:</strong> {selectedDriver.phoneNumber || 'N/A'}
                  </Typography>
                  <Typography variant="body2">
                    <strong>Country:</strong> {selectedDriver.country || 'N/A'}
                  </Typography>
                </Grid>

                <Grid item xs={12} md={6}>
                  <Typography variant="subtitle2" gutterBottom>
                    License Information
                  </Typography>
                  <Typography variant="body2">
                    <strong>License Number:</strong> {selectedDriver.licenseNumber || 'N/A'}
                  </Typography>
                  <Typography variant="body2">
                    <strong>License Expiry:</strong> {formatDate(selectedDriver.licenseExpiry)}
                  </Typography>
                  <Typography variant="body2">
                    <strong>Status:</strong> {selectedDriver.verificationStatus || 'pending'}
                  </Typography>
                  <Typography variant="body2">
                    <strong>Applied:</strong> {formatDate(selectedDriver.createdAt || selectedDriver.submittedAt)}
                  </Typography>
                </Grid>

                {selectedDriver.documents && selectedDriver.documents.length > 0 && (
                  <Grid item xs={12}>
                    <Typography variant="subtitle2" gutterBottom>
                      Documents
                    </Typography>
                    <ImageList cols={3} gap={8}>
                      {selectedDriver.documents.map((doc, index) => (
                        <ImageListItem key={index}>
                          <img
                            src={doc}
                            alt={`Document ${index + 1}`}
                            loading="lazy"
                            style={{ height: 200, objectFit: 'cover' }}
                          />
                        </ImageListItem>
                      ))}
                    </ImageList>
                  </Grid>
                )}
              </Grid>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setViewDialogOpen(false)}>
            Close
          </Button>
          {selectedDriver?.verificationStatus === 'pending' && (
            <>
              <Button
                variant="contained"
                color="success"
                startIcon={<CheckCircle />}
                onClick={() => {
                  // Handle approve
                  console.log('Approve driver:', selectedDriver.id);
                  setViewDialogOpen(false);
                }}
              >
                Approve
              </Button>
              <Button
                variant="contained"
                color="error"
                startIcon={<Cancel />}
                onClick={() => {
                  // Handle reject
                  console.log('Reject driver:', selectedDriver.id);
                  setViewDialogOpen(false);
                }}
              >
                Reject
              </Button>
            </>
          )}
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default DriverVerificationModule;
