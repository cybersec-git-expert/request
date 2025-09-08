import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  Button,
  Alert,
  CircularProgress
} from '@mui/material';
import {
  Business,
  CheckCircle,
  Pending,
  Cancel,
  Edit
} from '@mui/icons-material';
import useCountryFilter from '../hooks/useCountryFilter.jsx';

/**
 * Example: Updated Business Verification Page using Centralized Country Filtering
 * This replaces the old BusinessVerificationEnhanced.jsx with centralized filtering
 */
const BusinessVerificationCentralized = () => {
  const {
    getBusinesses,
    getCountryDisplayName,
    canEditData,
    isSuperAdmin,
    userCountry
  } = useCountryFilter();

  const [businesses, setBusinesses] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadBusinesses();
  }, []);

  const loadBusinesses = async () => {
    try {
      setLoading(true);
      setError(null);

      // This automatically filters by country based on admin role
      const businessData = await getBusinesses();
      setBusinesses(businessData);
    } catch (err) {
      console.error('Error loading businesses:', err);
      setError('Failed to load businesses. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (business) => {
    // Check if admin can edit this business
    if (canEditData(business.country)) {
      // Proceed with edit
      console.log('Edit business:', business.id);
      // Navigate to edit page or open modal
    } else {
      alert(`Access denied: You cannot edit businesses from ${business.country}`);
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'approved':
        return <CheckCircle color="success" />;
      case 'pending':
        return <Pending color="warning" />;
      case 'rejected':
        return <Cancel color="error" />;
      default:
        return <Pending color="default" />;
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'approved':
        return 'success';
      case 'pending':
        return 'warning';
      case 'rejected':
        return 'error';
      default:
        return 'default';
    }
  };

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return (
      <Box sx={{ p: 3 }}>
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
        <Button onClick={loadBusinesses} variant="contained">
          Retry
        </Button>
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3 }}>
      {/* Header */}
      <Box sx={{ mb: 3, display: 'flex', alignItems: 'center', gap: 2 }}>
        <Business color="primary" sx={{ fontSize: 32 }} />
        <Typography variant="h4" sx={{ fontWeight: 'bold' }}>
          Business Verification
        </Typography>
      </Box>

      {/* Country Info */}
      <Alert severity="info" sx={{ mb: 3 }}>
        <Typography variant="body2">
          <strong>Viewing data for:</strong> {getCountryDisplayName()}
          {!isSuperAdmin && (
            <>
              <br />
              <strong>Note:</strong> As a country admin, you can only see and manage 
              businesses from {userCountry}.
            </>
          )}
        </Typography>
      </Alert>

      {/* Statistics Cards */}
      <Box sx={{ mb: 3, display: 'flex', gap: 2, flexWrap: 'wrap' }}>
        <Card sx={{ minWidth: 200 }}>
          <CardContent>
            <Typography color="text.secondary" gutterBottom>
              Total Businesses
            </Typography>
            <Typography variant="h4" component="div">
              {businesses.length}
            </Typography>
          </CardContent>
        </Card>
        
        <Card sx={{ minWidth: 200 }}>
          <CardContent>
            <Typography color="text.secondary" gutterBottom>
              Approved
            </Typography>
            <Typography variant="h4" component="div" color="success.main">
              {businesses.filter(b => b.verificationStatus === 'approved').length}
            </Typography>
          </CardContent>
        </Card>
        
        <Card sx={{ minWidth: 200 }}>
          <CardContent>
            <Typography color="text.secondary" gutterBottom>
              Pending
            </Typography>
            <Typography variant="h4" component="div" color="warning.main">
              {businesses.filter(b => b.verificationStatus === 'pending').length}
            </Typography>
          </CardContent>
        </Card>
      </Box>

      {/* Business Table */}
      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Business Name</TableCell>
              <TableCell>Owner</TableCell>
              <TableCell>Country</TableCell>
              <TableCell>Category</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Created</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {businesses.map((business) => (
              <TableRow key={business.id}>
                <TableCell>
                  <Typography variant="body1" fontWeight="bold">
                    {business.businessName}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    {business.businessAddress}
                  </Typography>
                </TableCell>
                <TableCell>{business.ownerName}</TableCell>
                <TableCell>
                  <Chip 
                    label={business.country || business.countryName || 'N/A'} 
                    size="small"
                    color="primary"
                    variant="outlined"
                  />
                </TableCell>
                <TableCell>{business.category}</TableCell>
                <TableCell>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    {getStatusIcon(business.verificationStatus)}
                    <Chip
                      label={business.verificationStatus}
                      size="small"
                      color={getStatusColor(business.verificationStatus)}
                    />
                  </Box>
                </TableCell>
                <TableCell>
                  {business.createdAt?.toDate?.()?.toLocaleDateString() || 'N/A'}
                </TableCell>
                <TableCell>
                  <Button
                    size="small"
                    startIcon={<Edit />}
                    onClick={() => handleEdit(business)}
                    disabled={!canEditData(business.country)}
                    variant={canEditData(business.country) ? "outlined" : "text"}
                  >
                    {canEditData(business.country) ? 'Edit' : 'No Access'}
                  </Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      {businesses.length === 0 && (
        <Box sx={{ textAlign: 'center', mt: 4 }}>
          <Typography variant="h6" color="text.secondary">
            No businesses found in {getCountryDisplayName()}
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
            {isSuperAdmin 
              ? "There are no businesses in any country yet." 
              : `There are no businesses in ${userCountry} yet.`
            }
          </Typography>
        </Box>
      )}
    </Box>
  );
};

export default BusinessVerificationCentralized;
