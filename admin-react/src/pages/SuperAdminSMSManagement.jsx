/**
 * Super Admin SMS Management Dashboard
 * 
 * @description
 * Centralized dashboard for super administrators to manage SMS configurations
 * across all countries. Provides approval workflow, usage monitoring, and
 * cost tracking for all SMS providers.
 * 
 * @features
 * - View all countries' SMS configurations
 * - Approve/reject SMS configuration requests
 * - Monitor SMS usage and costs across countries
 * - Override or disable specific configurations
 * - Export usage reports and analytics
 * - Real-time SMS delivery monitoring
 * 
 * @workflow
 * 1. Country admin submits SMS configuration request
 * 2. Super admin reviews configuration details
 * 3. Super admin approves/rejects with comments
 * 4. Approved configurations become active
 * 5. Super admin monitors usage and costs
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
  CardActions,
  Button,
  Chip,
  Alert,
  CircularProgress,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  IconButton,
  Tooltip,
  TextField,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Tabs,
  Tab,
  Badge,
  LinearProgress,
  Accordion,
  AccordionSummary,
  AccordionDetails
} from '@mui/material';
import {
  CheckCircle,
  Cancel,
  Pending,
  Visibility,
  Edit,
  Delete,
  Analytics,
  MonetizationOn,
  Speed,
  Public,
  Phone,
  Warning,
  Error,
  Refresh,
  FileDownload,
  ExpandMore,
  Send,
  Block,
  Security
} from '@mui/icons-material';
import { DataGrid } from '@mui/x-data-grid';
import useCountryFilter from '../hooks/useCountryFilter';
import api from '../services/apiClient';

const SuperAdminSMSManagement = () => {
  const { adminData, isSuperAdmin } = useCountryFilter();
  
  // State Management
  const [currentTab, setCurrentTab] = useState(0);
  const [loading, setLoading] = useState(true);
  const [smsConfigurations, setSmsConfigurations] = useState([]);
  const [pendingRequests, setPendingRequests] = useState([]);
  const [usageStats, setUsageStats] = useState({});
  const [selectedConfig, setSelectedConfig] = useState(null);
  const [approvalDialog, setApprovalDialog] = useState(false);
  const [approvalAction, setApprovalAction] = useState('approve');
  const [approvalComments, setApprovalComments] = useState('');
  const [costAnalytics, setCostAnalytics] = useState({});

  // Redirect if not super admin
  useEffect(() => {
    if (!isSuperAdmin) {
      // Redirect to regular SMS config or dashboard
      window.location.href = '/sms-config';
      return;
    }
    loadSMSData();
  }, [isSuperAdmin]);

  // Load SMS configurations and analytics
  const loadSMSData = async () => {
    setLoading(true);
    try {
      // Load all SMS configurations from Firestore
      const configs = await fetchAllSMSConfigurations();
      const pending = await fetchPendingRequests();
      const usage = await fetchUsageStatistics();
      const costs = await fetchCostAnalytics();
      
      setSmsConfigurations(configs);
      setPendingRequests(pending);
      setUsageStats(usage);
      setCostAnalytics(costs);
    } catch (error) {
      console.error('Error loading SMS data:', error);
    } finally {
      setLoading(false);
    }
  };

  // Fetch all SMS configurations from REST API
  const fetchAllSMSConfigurations = async () => {
    try {
      const response = await api.get('/api/sms-configurations');
      return response.data || [];
    } catch (error) {
      console.error('Error fetching SMS configurations:', error);
      return [];
    }
  };

  const fetchPendingRequests = async () => {
    try {
      const response = await api.get('/api/sms-configuration-requests?status=pending');
      return response.data || [];
    } catch (error) {
      console.error('Error fetching pending requests:', error);
      return [];
    }
  };

  const fetchUsageStatistics = async () => {
    try {
      const response = await api.get('/api/sms-statistics');
      return response.data || {
        totalCountries: 0,
        activeConfigurations: 0,
        pendingApprovals: 0,
        totalMonthlySMS: 0,
        totalMonthlyCost: 0,
        averageCostPerSMS: 0,
        avgSuccessRate: 0
      };
    } catch (error) {
      console.error('Error fetching usage statistics:', error);
      return {
        totalCountries: 0,
        activeConfigurations: 0,
        pendingApprovals: 0,
        totalMonthlySMS: 0,
        totalMonthlyCost: 0,
        averageCostPerSMS: 0,
        avgSuccessRate: 0
      };
    }
  };

  const fetchCostAnalytics = async () => {
    try {
      const response = await api.get('/api/sms-cost-analytics');
      return response.data || {
        monthlyTrend: [],
        providerBreakdown: []
      };
    } catch (error) {
      console.error('Error fetching cost analytics:', error);
      return {
        monthlyTrend: [],
        providerBreakdown: []
      };
    }
  };

  // Handle approval/rejection
  const handleApprovalAction = async () => {
    try {
      setLoading(true);
      
      if (approvalAction === 'approve') {
        // Approve SMS configuration
        await approveSMSConfiguration(selectedConfig.id, approvalComments);
      } else {
        // Reject SMS configuration
        await rejectSMSConfiguration(selectedConfig.id, approvalComments);
      }
      
      // Refresh data
      await loadSMSData();
      setApprovalDialog(false);
      setApprovalComments('');
      setSelectedConfig(null);
    } catch (error) {
      console.error('Error processing approval:', error);
    } finally {
      setLoading(false);
    }
  };

  const approveSMSConfiguration = async (configId, comments) => {
    try {
      // TODO: Implement actual Firebase function call
      // await httpsCallable(functions, 'approveSMSConfiguration')({
      //   configId,
      //   comments,
      //   approvedBy: adminData.email
      // });
      
      console.log('Approving SMS config:', configId, comments);
      // Placeholder for actual implementation
    } catch (error) {
      console.error('Error approving SMS configuration:', error);
      throw error;
    }
  };

  const rejectSMSConfiguration = async (configId, comments) => {
    try {
      // TODO: Implement actual Firebase function call
      // await httpsCallable(functions, 'rejectSMSConfiguration')({
      //   configId,
      //   comments,
      //   rejectedBy: adminData.email
      // });
      
      console.log('Rejecting SMS config:', configId, comments);
      // Placeholder for actual implementation
    } catch (error) {
      console.error('Error rejecting SMS configuration:', error);
      throw error;
    }
  };

  const handleViewConfig = (config) => {
    setSelectedConfig(config);
    // Open detailed view dialog
  };

  const handleEditConfig = (config) => {
    setSelectedConfig(config);
    // Open edit dialog
  };

  const handleDisableConfig = async (configId) => {
    try {
      // Disable SMS configuration
      await disableSMSConfiguration(configId);
      await loadSMSData();
    } catch (error) {
      console.error('Error disabling configuration:', error);
    }
  };

  const disableSMSConfiguration = async (configId) => {
    try {
      // TODO: Implement actual Firebase function call
      // await httpsCallable(functions, 'disableSMSConfiguration')({
      //   configId,
      //   disabledBy: adminData.email
      // });
      
      console.log('Disabling SMS config:', configId);
      // Placeholder for actual implementation
    } catch (error) {
      console.error('Error disabling SMS configuration:', error);
      throw error;
    }
  };

  // Render tab content
  const renderTabContent = () => {
    switch (currentTab) {
      case 0:
        return renderOverviewTab();
      case 1:
        return renderConfigurationsTab();
      case 2:
        return renderPendingRequestsTab();
      case 3:
        return renderAnalyticsTab();
      default:
        return renderOverviewTab();
    }
  };

  const renderOverviewTab = () => (
    <Grid container spacing={3}>
      {/* Summary Cards */}
      <Grid item xs={12} md={3}>
        <Card>
          <CardContent>
            <Typography color="textSecondary" gutterBottom>
              Active Countries
            </Typography>
            <Typography variant="h4">
              {usageStats.activeConfigurations}
            </Typography>
            <Typography variant="body2">
              of {usageStats.totalCountries} total
            </Typography>
          </CardContent>
        </Card>
      </Grid>
      
      <Grid item xs={12} md={3}>
        <Card>
          <CardContent>
            <Typography color="textSecondary" gutterBottom>
              Monthly SMS Volume
            </Typography>
            <Typography variant="h4">
              {usageStats.totalMonthlySMS?.toLocaleString()}
            </Typography>
            <Typography variant="body2" color="success.main">
              98.9% success rate
            </Typography>
          </CardContent>
        </Card>
      </Grid>
      
      <Grid item xs={12} md={3}>
        <Card>
          <CardContent>
            <Typography color="textSecondary" gutterBottom>
              Monthly Cost
            </Typography>
            <Typography variant="h4">
              ${usageStats.totalMonthlyCost?.toFixed(2)}
            </Typography>
            <Typography variant="body2">
              ${usageStats.averageCostPerSMS?.toFixed(4)}/SMS
            </Typography>
          </CardContent>
        </Card>
      </Grid>
      
      <Grid item xs={12} md={3}>
        <Card>
          <CardContent>
            <Badge badgeContent={usageStats.pendingApprovals} color="warning">
              <Typography color="textSecondary" gutterBottom>
                Pending Requests
              </Typography>
            </Badge>
            <Typography variant="h4">
              {usageStats.pendingApprovals}
            </Typography>
            <Typography variant="body2" color="warning.main">
              Require approval
            </Typography>
          </CardContent>
        </Card>
      </Grid>

      {/* Recent Activity */}
      <Grid item xs={12}>
        <Paper sx={{ p: 2 }}>
          <Typography variant="h6" gutterBottom>
            Recent SMS Configuration Activity
          </Typography>
          <TableContainer>
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell>Country</TableCell>
                  <TableCell>Action</TableCell>
                  <TableCell>Provider</TableCell>
                  <TableCell>Date</TableCell>
                  <TableCell>Status</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {smsConfigurations.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={5} align="center">
                      <Typography color="textSecondary">
                        No SMS configuration activity yet
                      </Typography>
                    </TableCell>
                  </TableRow>
                ) : (
                  // TODO: Replace with actual recent activity data
                  <TableRow>
                    <TableCell colSpan={5} align="center">
                      <Typography color="textSecondary">
                        Recent activity will appear here
                      </Typography>
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </TableContainer>
        </Paper>
      </Grid>
    </Grid>
  );

  const renderConfigurationsTab = () => (
    <Paper sx={{ p: 2 }}>
      <Typography variant="h6" gutterBottom>
        SMS Configurations by Country
      </Typography>
      <TableContainer>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Country</TableCell>
              <TableCell>Provider</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Monthly Usage</TableCell>
              <TableCell>Cost/SMS</TableCell>
              <TableCell>Success Rate</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {smsConfigurations.map((config) => (
              <TableRow key={config.id}>
                <TableCell>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Typography variant="body2" fontWeight="bold">
                      {config.countryName}
                    </Typography>
                    <Chip label={config.countryCode} size="small" />
                  </Box>
                </TableCell>
                <TableCell>
                  <Chip 
                    label={config.provider.charAt(0).toUpperCase() + config.provider.slice(1)} 
                    variant="outlined" 
                    size="small" 
                  />
                </TableCell>
                <TableCell>
                  <Chip 
                    label={config.status.replace('_', ' ')} 
                    color={config.status === 'active' ? 'success' : 'warning'} 
                    size="small" 
                  />
                </TableCell>
                <TableCell>{config.monthlyUsage.toLocaleString()}</TableCell>
                <TableCell>${config.costPerSMS.toFixed(4)}</TableCell>
                <TableCell>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <LinearProgress 
                      variant="determinate" 
                      value={config.successRate} 
                      sx={{ width: 60 }} 
                    />
                    <Typography variant="body2">
                      {config.successRate}%
                    </Typography>
                  </Box>
                </TableCell>
                <TableCell>
                  <Box sx={{ display: 'flex', gap: 1 }}>
                    <Tooltip title="View Details">
                      <IconButton size="small" onClick={() => handleViewConfig(config)}>
                        <Visibility />
                      </IconButton>
                    </Tooltip>
                    <Tooltip title="Edit Configuration">
                      <IconButton size="small" onClick={() => handleEditConfig(config)}>
                        <Edit />
                      </IconButton>
                    </Tooltip>
                    <Tooltip title="Disable">
                      <IconButton size="small" onClick={() => handleDisableConfig(config.id)}>
                        <Block />
                      </IconButton>
                    </Tooltip>
                  </Box>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </Paper>
  );

  const renderPendingRequestsTab = () => (
    <Grid container spacing={3}>
      {pendingRequests.map((request) => (
        <Grid item xs={12} md={6} key={request.id}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 2 }}>
                <Typography variant="h6">
                  {request.countryName} SMS Configuration
                </Typography>
                <Chip label="Pending Approval" color="warning" size="small" />
              </Box>
              
              <Typography color="textSecondary" gutterBottom>
                <strong>Provider:</strong> {request.provider.charAt(0).toUpperCase() + request.provider.slice(1)}
              </Typography>
              
              <Typography color="textSecondary" gutterBottom>
                <strong>Requested by:</strong> {request.requestedBy}
              </Typography>
              
              <Typography color="textSecondary" gutterBottom>
                <strong>Estimated Cost:</strong> ${request.estimatedCost}/SMS
              </Typography>
              
              <Typography variant="body2" sx={{ mt: 2, mb: 2 }}>
                <strong>Reason:</strong> {request.reason}
              </Typography>
              
              <Typography variant="caption" color="textSecondary">
                Requested on {request.requestDate}
              </Typography>
            </CardContent>
            
            <CardActions>
              <Button 
                size="small" 
                color="success" 
                startIcon={<CheckCircle />}
                onClick={() => {
                  setSelectedConfig(request);
                  setApprovalAction('approve');
                  setApprovalDialog(true);
                }}
              >
                Approve
              </Button>
              <Button 
                size="small" 
                color="error" 
                startIcon={<Cancel />}
                onClick={() => {
                  setSelectedConfig(request);
                  setApprovalAction('reject');
                  setApprovalDialog(true);
                }}
              >
                Reject
              </Button>
              <Button size="small" startIcon={<Visibility />}>
                View Details
              </Button>
            </CardActions>
          </Card>
        </Grid>
      ))}
      
      {pendingRequests.length === 0 && (
        <Grid item xs={12}>
          <Paper sx={{ p: 4, textAlign: 'center' }}>
            <CheckCircle sx={{ fontSize: 64, color: 'success.main', mb: 2 }} />
            <Typography variant="h6" gutterBottom>
              No Pending Requests
            </Typography>
            <Typography color="textSecondary">
              All SMS configuration requests have been processed.
            </Typography>
          </Paper>
        </Grid>
      )}
    </Grid>
  );

  const renderAnalyticsTab = () => (
    <Grid container spacing={3}>
      <Grid item xs={12} md={6}>
        <Paper sx={{ p: 2 }}>
          <Typography variant="h6" gutterBottom>
            Cost Trend Analysis
          </Typography>
          {/* Placeholder for chart component */}
          <Box sx={{ height: 300, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Typography color="textSecondary">
              Chart: Monthly SMS costs across all countries
            </Typography>
          </Box>
        </Paper>
      </Grid>
      
      <Grid item xs={12} md={6}>
        <Paper sx={{ p: 2 }}>
          <Typography variant="h6" gutterBottom>
            Provider Performance
          </Typography>
          {/* Placeholder for chart component */}
          <Box sx={{ height: 300, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Typography color="textSecondary">
              Chart: Success rates by provider
            </Typography>
          </Box>
        </Paper>
      </Grid>
      
      <Grid item xs={12}>
        <Paper sx={{ p: 2 }}>
          <Typography variant="h6" gutterBottom>
            Cost Savings Analysis
          </Typography>
          <TableContainer>
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell>Country</TableCell>
                  <TableCell>Current Provider</TableCell>
                  <TableCell>Current Cost/SMS</TableCell>
                  <TableCell>Firebase Auth Cost/SMS</TableCell>
                  <TableCell>Monthly Savings</TableCell>
                  <TableCell>Annual Savings</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {smsConfigurations.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={6} align="center">
                      <Typography color="textSecondary">
                        No SMS configurations to analyze yet
                      </Typography>
                    </TableCell>
                  </TableRow>
                ) : (
                  smsConfigurations.map((config) => {
                    const firebaseAuthCost = 0.015; // Standard Firebase Auth cost
                    const monthlySavings = (firebaseAuthCost - config.costPerSMS) * config.monthlyUsage;
                    const annualSavings = monthlySavings * 12;
                    
                    return (
                      <TableRow key={config.id}>
                        <TableCell>{config.countryName}</TableCell>
                        <TableCell>
                          {config.provider.charAt(0).toUpperCase() + config.provider.slice(1)}
                        </TableCell>
                        <TableCell>${config.costPerSMS?.toFixed(4)}</TableCell>
                        <TableCell>$0.0150</TableCell>
                        <TableCell style={{ color: monthlySavings > 0 ? 'green' : 'red' }}>
                          ${monthlySavings > 0 ? '+' : ''}{monthlySavings.toFixed(2)}
                        </TableCell>
                        <TableCell style={{ color: annualSavings > 0 ? 'green' : 'red' }}>
                          ${annualSavings > 0 ? '+' : ''}{annualSavings.toFixed(0)}
                        </TableCell>
                      </TableRow>
                    );
                  })
                )}
              </TableBody>
            </Table>
          </TableContainer>
        </Paper>
      </Grid>
    </Grid>
  );

  if (!isSuperAdmin) {
    return null; // Component will redirect
  }

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: 400 }}>
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box>
      {/* Header */}
      <Box sx={{ mb: 3 }}>
        <Typography variant="h4" gutterBottom>
          SMS Management Dashboard
        </Typography>
        <Typography variant="body1" color="textSecondary">
          Centralized management for SMS configurations across all countries
        </Typography>
      </Box>

      {/* Tabs Navigation */}
      <Paper sx={{ mb: 3 }}>
        <Tabs 
          value={currentTab} 
          onChange={(e, newValue) => setCurrentTab(newValue)}
          variant="fullWidth"
        >
          <Tab 
            label={
              <Badge badgeContent={usageStats.pendingApprovals} color="warning">
                Overview
              </Badge>
            } 
          />
          <Tab label="Configurations" />
          <Tab 
            label={
              <Badge badgeContent={pendingRequests.length} color="error">
                Pending Requests
              </Badge>
            } 
          />
          <Tab label="Analytics" />
        </Tabs>
      </Paper>

      {/* Tab Content */}
      {renderTabContent()}

      {/* Approval Dialog */}
      <Dialog open={approvalDialog} onClose={() => setApprovalDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          {approvalAction === 'approve' ? 'Approve' : 'Reject'} SMS Configuration
        </DialogTitle>
        <DialogContent>
          {selectedConfig && (
            <Box sx={{ mb: 2 }}>
              <Typography variant="h6">
                {selectedConfig.countryName} - {selectedConfig.provider}
              </Typography>
              <Typography color="textSecondary">
                Requested by: {selectedConfig.requestedBy}
              </Typography>
            </Box>
          )}
          <TextField
            label="Comments"
            multiline
            rows={4}
            fullWidth
            value={approvalComments}
            onChange={(e) => setApprovalComments(e.target.value)}
            placeholder="Add comments about your decision..."
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setApprovalDialog(false)}>Cancel</Button>
          <Button 
            onClick={handleApprovalAction}
            color={approvalAction === 'approve' ? 'success' : 'error'}
            variant="contained"
          >
            {approvalAction === 'approve' ? 'Approve' : 'Reject'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default SuperAdminSMSManagement;
