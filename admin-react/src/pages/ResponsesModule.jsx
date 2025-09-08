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
  Avatar,
  Divider
} from '@mui/material';
import {
  Search,
  Visibility,
  FilterList,
  Refresh,
  Reply,
  AccessTime,
  AttachMoney,
  Person,
  Assignment,
  Check,
  Close
} from '@mui/icons-material';
import useCountryFilter from '../hooks/useCountryFilter.jsx';

const ResponsesModule = () => {
  const {
    getFilteredData,
    adminData,
    isSuperAdmin,
    getCountryDisplayName,
    userCountry
  } = useCountryFilter();

  const [responses, setResponses] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterAnchorEl, setFilterAnchorEl] = useState(null);
  const [selectedStatus, setSelectedStatus] = useState('all');
  const [selectedResponse, setSelectedResponse] = useState(null);
  const [viewDialogOpen, setViewDialogOpen] = useState(false);

  const statusColors = {
    accepted: 'success',
    pending: 'warning',
    rejected: 'error'
  };

  const loadResponses = async () => {
    try {
      setLoading(true);
      setError(null);

      const raw = await getFilteredData('responses', adminData);
      const arr = Array.isArray(raw) ? raw : (Array.isArray(raw?.responses) ? raw.responses : []);
      const mapped = arr.map(r => {
        const status = r.raw_status || (r.accepted ? 'accepted' : 'pending');
        const metadata = r.metadata || {};
        return {
          id: r.id,
          requestId: r.request_id || r.requestId,
          responderId: r.user_id || r.userId,
          responderName: r.responder_name || r.user_name || metadata.responder_name,
          responderEmail: r.responder_email || metadata.responder_email,
          responderPhone: r.responder_phone || metadata.responder_phone,
          requesterName: r.requester_name,
          requesterEmail: r.requester_email,
            requesterPhone: r.requester_phone,
          message: r.message,
          price: r.price,
          currency: r.currency || r.country_default_currency,
          images: r.image_urls || r.images,
          createdAt: r.created_at || r.createdAt,
          updatedAt: r.updated_at || r.updatedAt,
          country: r.country_code || r.country,
          accepted: r.accepted === true || (r.accepted_response_id && (r.accepted_response_id === r.id)),
          status,
          availableFrom: r.available_from || r.availableFrom || metadata.available_from || metadata.availableFrom,
          availableUntil: r.available_until || r.availableUntil || metadata.available_until || metadata.availableUntil,
          additionalInfo: metadata
        };
      });
      setResponses(mapped);
      console.log(`📊 Loaded ${mapped.length} responses for ${isSuperAdmin ? 'super admin' : `country admin (${userCountry})`}`);
    } catch (err) {
      console.error('Error loading responses:', err);
      setError('Failed to load responses: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadResponses();
  }, [adminData]);

  const handleViewResponse = (response) => {
    setSelectedResponse(response);
    setViewDialogOpen(true);
  };

  const handleStatusFilter = (status) => {
    setSelectedStatus(status);
    setFilterAnchorEl(null);
  };

  const filteredResponses = responses.filter(response => {
    const matchesSearch = response.message?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         response.responderId?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         response.requestId?.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesStatus = selectedStatus === 'all' || 
                         (selectedStatus === 'accepted' && response.isAccepted === true) ||
                         (selectedStatus === 'pending' && response.isAccepted === false && !response.rejectionReason) ||
                         (selectedStatus === 'rejected' && response.rejectionReason);
    
    return matchesSearch && matchesStatus;
  });

  const formatDate = (dateValue) => {
    if (!dateValue) return 'N/A';
    
    let date;
    if (dateValue.toDate) {
      date = dateValue.toDate();
    } else if (dateValue instanceof Date) {
      date = dateValue;
    } else {
      date = new Date(dateValue);
    }
    
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
  };

  const formatCurrency = (amount, currency) => {
    if (!amount) return 'N/A';
    return `${currency || 'LKR'} ${amount.toLocaleString()}`;
  };

  const getResponseStatus = (response) => {
    if (response.accepted || response.status === 'accepted') return 'accepted';
    if (response.status === 'rejected') return 'rejected';
    return 'pending';
  };

  const getResponseStats = () => {
    return {
      total: filteredResponses.length,
  accepted: filteredResponses.filter(r => getResponseStatus(r) === 'accepted').length,
  pending: filteredResponses.filter(r => getResponseStatus(r) === 'pending').length,
  rejected: filteredResponses.filter(r => getResponseStatus(r) === 'rejected').length,
    };
  };

  const stats = getResponseStats();

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3 }}>
      {/* Header */}
      <Box sx={{ mb: 3 }}>
        <Typography variant="h4" gutterBottom>
          Responses Management
        </Typography>
        <Typography variant="body1" color="text.secondary">
          {isSuperAdmin ? 'Manage all responses across countries' : `Manage responses in ${getCountryDisplayName(userCountry)}`}
        </Typography>
      </Box>

      {/* Error Alert */}
      {error && (
        <Alert severity="error" sx={{ mb: 3 }}>
          {error}
        </Alert>
      )}

      {/* Stats Cards */}
      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom variant="h6">
                Total Responses
              </Typography>
              <Typography variant="h4">
                {stats.total}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
  <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom variant="h6">
                Accepted
              </Typography>
              <Typography variant="h4" color="success.main">
                {stats.accepted}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
  <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom variant="h6">
                Pending
              </Typography>
              <Typography variant="h4" color="warning.main">
                {stats.pending}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
  <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom variant="h6">
                Rejected
              </Typography>
              <Typography variant="h4" color="error.main">
                {stats.rejected}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Search and Filter Bar */}
      <Paper sx={{ p: 2, mb: 3 }}>
        <Box sx={{ display: 'flex', gap: 2, alignItems: 'center', flexWrap: 'wrap' }}>
          <TextField
            placeholder="Search responses..."
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
            Status ({selectedStatus !== 'all' ? 'Filtered' : 'All'})
          </Button>

          <Button
            variant="outlined"
            startIcon={<Refresh />}
            onClick={loadResponses}
          >
            Refresh
          </Button>
        </Box>
      </Paper>

      {/* Filter Menu */}
      <Menu
        anchorEl={filterAnchorEl}
        open={Boolean(filterAnchorEl)}
        onClose={() => setFilterAnchorEl(null)}
      >
        <MenuItem onClick={() => handleStatusFilter('all')} selected={selectedStatus === 'all'}>All Status</MenuItem>
        <MenuItem onClick={() => handleStatusFilter('accepted')} selected={selectedStatus === 'accepted'}>Accepted</MenuItem>
        <MenuItem onClick={() => handleStatusFilter('pending')} selected={selectedStatus === 'pending'}>Pending</MenuItem>
        <MenuItem onClick={() => handleStatusFilter('rejected')} selected={selectedStatus === 'rejected'}>Rejected</MenuItem>
      </Menu>

      {/* Responses Table */}
      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Response</TableCell>
              <TableCell>Request ID</TableCell>
              <TableCell>Responder</TableCell>
              <TableCell>Requester</TableCell>
              <TableCell>Price</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Available Date</TableCell>
              <TableCell>Created</TableCell>
              <TableCell>Country</TableCell>
              <TableCell align="center">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredResponses.map((response) => (
              <TableRow key={response.id} hover>
                <TableCell>
                  <Box>
                    <Typography variant="subtitle2" noWrap sx={{ maxWidth: 200 }}>
                      {response.message ? response.message.substring(0, 50) + '...' : 'No message'}
                    </Typography>
                    {response.images && response.images.length > 0 && (
                      <Typography variant="caption" color="primary">
                        📎 {response.images.length} image(s)
                      </Typography>
                    )}
                  </Box>
                </TableCell>
                <TableCell>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Assignment fontSize="small" color="action" />
                    <Typography variant="body2" noWrap>
                      {response.requestId ? response.requestId.substring(0, 8) + '...' : 'N/A'}
                    </Typography>
                  </Box>
                </TableCell>
                <TableCell>
                  <Box sx={{ display: 'flex', flexDirection:'column', gap: 0.25 }}>
                    <Box sx={{ display:'flex', alignItems:'center', gap:1 }}>
                      <Person fontSize="small" color="action" />
                      <Typography variant="body2" noWrap title={response.responderId}>
                        {response.responderName || 'Unknown'}
                      </Typography>
                    </Box>
                    <Typography variant="caption" color="text.secondary" noWrap>
                      {response.responderEmail || response.responderId?.substring(0,12) || ''}
                    </Typography>
                    {response.responderPhone && (
                      <Typography variant="caption" color="text.secondary" noWrap>
                        {response.responderPhone}
                      </Typography>
                    )}
                  </Box>
                </TableCell>
                <TableCell>
                  <Box sx={{ display: 'flex', flexDirection:'column', gap: 0.25 }}>
                    <Box sx={{ display:'flex', alignItems:'center', gap:1 }}>
                      <Person fontSize="small" color="action" />
                      <Typography variant="body2" noWrap>
                        {response.requesterName || 'Unknown'}
                      </Typography>
                    </Box>
                    <Typography variant="caption" color="text.secondary" noWrap>
                      {response.requesterEmail || ''}
                    </Typography>
                  </Box>
                </TableCell>
                <TableCell>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <AttachMoney fontSize="small" color="action" />
                    <Typography variant="body2">
                      {formatCurrency(response.price, response.currency)}
                    </Typography>
                  </Box>
                </TableCell>
                <TableCell>
                  <Chip 
                    label={getResponseStatus(response).toUpperCase()}
                    color={statusColors[getResponseStatus(response)] || 'default'}
                    size="small"
                    icon={
                      getResponseStatus(response) === 'accepted' ? <Check /> :
                      getResponseStatus(response) === 'rejected' ? <Close /> : <Reply />
                    }
                  />
                </TableCell>
                <TableCell>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <AccessTime fontSize="small" color="action" />
                    <Typography variant="body2">
                      {formatDate(response.availableFrom) || 'Not specified'}
                    </Typography>
                  </Box>
                </TableCell>
                <TableCell>
                  <Typography variant="body2">
                    {formatDate(response.createdAt)}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Chip 
                    label={getCountryDisplayName(response.country)}
                    size="small"
                    variant="outlined"
                  />
                </TableCell>
                <TableCell align="center">
                  <Tooltip title="View Details">
                    <IconButton
                      size="small"
                      onClick={() => handleViewResponse(response)}
                      color="primary"
                    >
                      <Visibility fontSize="small" />
                    </IconButton>
                  </Tooltip>
                </TableCell>
              </TableRow>
            ))}
            {filteredResponses.length === 0 && (
              <TableRow>
                <TableCell colSpan={9} align="center">
                  <Typography variant="body1" color="text.secondary">
                    No responses found
                  </Typography>
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>

      {/* View Response Dialog */}
      <Dialog
        open={viewDialogOpen}
        onClose={() => setViewDialogOpen(false)}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>
          Response Details
        </DialogTitle>
        <DialogContent>
          {selectedResponse && (
            <Box sx={{ pt: 1 }}>
              <Grid container spacing={2}>
                <Grid size={12}>
                  <Typography variant="subtitle2">Message:</Typography>
                  <Typography variant="body2" sx={{ mb: 2, p: 2, bgcolor: 'grey.50', borderRadius: 1 }}>
                    {selectedResponse.message || 'No message provided'}
                  </Typography>
                </Grid>
                
                <Grid size={6}>
                  <Typography variant="subtitle2">Request ID:</Typography>
                  <Typography variant="body2">{selectedResponse.requestId || 'N/A'}</Typography>
                </Grid>
                
                <Grid size={6}>
                  <Typography variant="subtitle2">Responder:</Typography>
                  <Typography variant="body2">
                    {selectedResponse.responderName || 'Unknown'}
                    {selectedResponse.responderEmail && ` | ${selectedResponse.responderEmail}`}
                    {selectedResponse.responderPhone && ` | ${selectedResponse.responderPhone}`}
                  </Typography>
                </Grid>
                <Grid size={6}>
                  <Typography variant="subtitle2">Requester:</Typography>
                  <Typography variant="body2">
                    {selectedResponse.requesterName || 'Unknown'}
                    {selectedResponse.requesterEmail && ` | ${selectedResponse.requesterEmail}`}
                    {selectedResponse.requesterPhone && ` | ${selectedResponse.requesterPhone}`}
                  </Typography>
                </Grid>
                
                <Grid size={6}>
                  <Typography variant="subtitle2">Price:</Typography>
                  <Typography variant="body2">
                    {formatCurrency(selectedResponse.price, selectedResponse.currency)}
                  </Typography>
                </Grid>
                
                <Grid size={6}>
                  <Typography variant="subtitle2">Status:</Typography>
                  <Chip 
                    label={getResponseStatus(selectedResponse).toUpperCase()}
                    color={statusColors[getResponseStatus(selectedResponse)] || 'default'}
                    size="small"
                  />
                </Grid>
                
                <Grid size={6}>
                  <Typography variant="subtitle2">Country:</Typography>
                  <Typography variant="body2">
                    {getCountryDisplayName(selectedResponse.country)}
                  </Typography>
                </Grid>
                
                <Grid size={6}>
                  <Typography variant="subtitle2">Available From:</Typography>
                  <Typography variant="body2">{formatDate(selectedResponse.availableFrom) || 'Not specified'}</Typography>
                </Grid>
                
                <Grid size={6}>
                  <Typography variant="subtitle2">Available Until:</Typography>
                  <Typography variant="body2">{formatDate(selectedResponse.availableUntil) || 'Not specified'}</Typography>
                </Grid>
                
                <Grid size={6}>
                  <Typography variant="subtitle2">Created:</Typography>
                  <Typography variant="body2">{formatDate(selectedResponse.createdAt)}</Typography>
                </Grid>

                {selectedResponse.rejectionReason && (
                  <Grid size={12}>
                    <Divider sx={{ my: 2 }} />
                    <Typography variant="subtitle2" color="error">Rejection Reason:</Typography>
                    <Typography variant="body2" color="error" sx={{ p: 2, bgcolor: 'error.light', borderRadius: 1 }}>
                      {selectedResponse.rejectionReason}
                    </Typography>
                  </Grid>
                )}

                {selectedResponse.images && selectedResponse.images.length > 0 && (
                  <Grid size={12}>
                    <Divider sx={{ my: 2 }} />
                    <Typography variant="subtitle2" sx={{ mb: 1 }}>Images:</Typography>
                    <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                      {selectedResponse.images.slice(0, 4).map((image, index) => (
                        <Avatar 
                          key={index}
                          src={image} 
                          alt={`Image ${index + 1}`}
                          variant="rounded"
                          sx={{ width: 80, height: 80 }}
                        />
                      ))}
                    </Box>
                  </Grid>
                )}

                {selectedResponse.additionalInfo && Object.keys(selectedResponse.additionalInfo).length > 0 && (
                  <Grid size={12}>
                    <Divider sx={{ my: 2 }} />
                    <Typography variant="subtitle2" sx={{ mb: 1 }}>Additional Information:</Typography>
                    <Box sx={{ p: 2, bgcolor: 'grey.50', borderRadius: 1 }}>
                      {Object.entries(selectedResponse.additionalInfo).map(([key, value]) => (
                        <Typography key={key} variant="body2">
                          <strong>{key}:</strong> {String(value)}
                        </Typography>
                      ))}
                    </Box>
                  </Grid>
                )}
              </Grid>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setViewDialogOpen(false)}>Close</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default ResponsesModule;
