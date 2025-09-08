import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Grid,
  Card,
  CardContent,
  Chip,
  LinearProgress,
  Alert,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  IconButton
} from '@mui/material';
import {
  ShoppingCart,
  Business,
  DirectionsCar,
  Person,
  TrendingUp,
  Public,
  Refresh,
  Info
} from '@mui/icons-material';
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter.jsx';

const Dashboard = () => {
  const {
    getCountryStats,
    getCountryDisplayName,
    adminData,
    isSuperAdmin,
    userCountry
  } = useCountryFilter();

  const [stats, setStats] = useState({
    products: 0,
    businesses: 0,
    drivers: 0,
    adminUsers: 0,
    requests: 0,
    responses: 0,
    priceListings: 0,
    users: 0,
    loading: true
  });

  const [recentActivity, setRecentActivity] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadDashboardData();
  }, [adminData]);

  const loadDashboardData = async () => {
    try {
      setError(null);
      setStats(prev => ({ ...prev, loading: true }));

      const [productsRes, statsRes, adminsRes] = await Promise.all([
        api.get('/products/master/count'),
        api.get('/dashboard/stats', { params: isSuperAdmin ? {} : { country: userCountry }}),
        api.get('/admin-users/count', { params: isSuperAdmin ? {} : { country: userCountry }})
      ]);
      const countryStats = statsRes.data || {};
      const productsCount = productsRes.data?.count ?? productsRes.data ?? 0;
      const adminUsersCount = adminsRes.data?.count ?? adminsRes.data ?? 0;
      setStats({
        products: productsCount,
        businesses: countryStats.businesses?.total || 0,
        drivers: countryStats.drivers?.total || 0,
        adminUsers: adminUsersCount,
        requests: countryStats.requests?.total || 0,
        responses: countryStats.responses?.total || 0,
        priceListings: countryStats.priceListings?.total || 0,
        users: countryStats.users?.total || 0,
        loading: false
      });
      loadRecentActivity(countryStats);

    } catch (error) {
      console.error('Error loading dashboard:', error);
      setError('Failed to load dashboard data. Please try again.');
      setStats(prev => ({ ...prev, loading: false }));
    }
  };

  const loadRecentActivity = async (countryStats) => {
    try {
      const activity = [];
      
      // Add recent business applications
      if (countryStats.businesses?.pending > 0) {
        activity.push({
          type: 'business',
          message: `${countryStats.businesses.pending} businesses awaiting verification`,
          time: 'Today',
          priority: 'high'
        });
      }

      // Add recent driver applications
      if (countryStats.drivers?.pending > 0) {
        activity.push({
          type: 'driver',
          message: `${countryStats.drivers.pending} drivers awaiting verification`,
          time: 'Today',
          priority: 'high'
        });
      }

      // Add active requests info
      if (countryStats.requests?.active > 0) {
        activity.push({
          type: 'request',
          message: `${countryStats.requests.active} active requests in the system`,
          time: 'Recent',
          priority: 'medium'
        });
      }

      setRecentActivity(activity);
    } catch (error) {
      console.error('Error loading recent activity:', error);
    }
  };

  const StatCard = ({ title, value, icon, color = 'primary', subtitle }) => (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
          {icon}
          <Typography variant="h6" sx={{ ml: 1, fontWeight: 'bold' }}>
            {title}
          </Typography>
        </Box>
        <Typography variant="h3" color={color} sx={{ fontWeight: 'bold' }}>
          {stats.loading ? '-' : value}
        </Typography>
        {subtitle && (
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
            {subtitle}
          </Typography>
        )}
        {stats.loading && <LinearProgress sx={{ mt: 2 }} />}
      </CardContent>
    </Card>
  );

  if (error) {
    return (
      <Box sx={{ p: 3 }}>
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
        <IconButton onClick={loadDashboardData} color="primary">
          <Refresh />
        </IconButton>
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3 }}>
      {/* Header */}
      <Box sx={{ mb: 4, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Box>
          <Typography variant="h4" gutterBottom sx={{ fontWeight: 'bold' }}>
            Dashboard
          </Typography>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
            <Chip 
              icon={<Public />} 
              label={getCountryDisplayName()} 
              color="primary" 
              variant="outlined"
            />
            <Chip 
              label={isSuperAdmin ? 'Super Admin' : 'Country Admin'} 
              color={isSuperAdmin ? 'secondary' : 'default'}
              size="small"
            />
          </Box>
        </Box>
        <IconButton onClick={loadDashboardData} disabled={stats.loading} color="primary">
          <Refresh />
        </IconButton>
      </Box>

      {/* Country Access Info */}
      <Alert 
        severity="info" 
        icon={<Info />}
        sx={{ mb: 3 }}
      >
        <Typography variant="body2">
          <strong>Data Scope:</strong> {isSuperAdmin 
            ? 'You have access to global data across all countries.' 
            : `You have access to data from ${userCountry} only.`
          }
        </Typography>
      </Alert>

      {/* Statistics Cards */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Products"
            value={stats.products}
            icon={<ShoppingCart color="primary" />}
            color="primary.main"
            subtitle="Global product catalog"
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Businesses"
            value={stats.businesses}
            icon={<Business color="success" />}
            color="success.main"
            subtitle={isSuperAdmin ? "All countries" : `In ${userCountry}`}
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Drivers"
            value={stats.drivers}
            icon={<DirectionsCar color="info" />}
            color="info.main"
            subtitle={isSuperAdmin ? "All countries" : `In ${userCountry}`}
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Admin Users"
            value={stats.adminUsers}
            icon={<Person color="warning" />}
            color="warning.main"
            subtitle={isSuperAdmin ? "All admin users" : "Country admins"}
          />
        </Grid>

        {/* Additional Stats Row */}
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Requests"
            value={stats.requests}
            icon={<TrendingUp color="primary" />}
            color="primary.main"
            subtitle="Total requests"
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Responses"
            value={stats.responses}
            icon={<TrendingUp color="success" />}
            color="success.main"
            subtitle="Total responses"
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Price Listings"
            value={stats.priceListings}
            icon={<ShoppingCart color="info" />}
            color="info.main"
            subtitle="Active listings"
          />
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Users"
            value={stats.users}
            icon={<Person color="warning" />}
            color="warning.main"
            subtitle="Total users"
          />
        </Grid>
      </Grid>

      {/* Recent Activity */}
      {recentActivity.length > 0 && (
        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom sx={{ fontWeight: 'bold' }}>
              Recent Activity
            </Typography>
            <TableContainer>
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>Activity</TableCell>
                    <TableCell>Time</TableCell>
                    <TableCell>Priority</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {recentActivity.map((activity, index) => (
                    <TableRow key={index}>
                      <TableCell>
                        <Box sx={{ display: 'flex', alignItems: 'center' }}>
                          {activity.type === 'business' && <Business sx={{ mr: 1, color: 'success.main' }} />}
                          {activity.type === 'driver' && <DirectionsCar sx={{ mr: 1, color: 'info.main' }} />}
                          {activity.type === 'request' && <TrendingUp sx={{ mr: 1, color: 'primary.main' }} />}
                          {activity.message}
                        </Box>
                      </TableCell>
                      <TableCell>{activity.time}</TableCell>
                      <TableCell>
                        <Chip 
                          label={activity.priority} 
                          size="small"
                          color={activity.priority === 'high' ? 'error' : activity.priority === 'medium' ? 'warning' : 'default'}
                        />
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </CardContent>
        </Card>
      )}
    </Box>
  );
};

export default Dashboard;
