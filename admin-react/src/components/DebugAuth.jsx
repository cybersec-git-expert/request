import { useAuth } from '../contexts/AuthContext';
import { Button, Card, CardContent, Typography, Box, Alert } from '@mui/material';
import { useState } from 'react';
import authService from '../services/authService';

const DebugAuth = () => {
  const { user, userRole, userCountry } = useAuth();
  const [fixing, setFixing] = useState(false);
  const [message, setMessage] = useState('');

  const fixSuperAdminUID = async () => {
    setFixing(true);
    try {
      // Placeholder: In Postgres backend, this would call an admin endpoint to correct role mapping.
      if (user && user.email === 'superadmin@request.lk') {
        // Example: await api.post('/admin/fix-super-admin', { userId: user.id });
        setMessage('✅ (Simulated) Super Admin role fix executed. Refresh to re-check.');
      } else {
        setMessage('No action taken. Not superadmin@request.lk');
      }
    } catch (error) {
      setMessage('❌ Error: ' + error.message);
    }
    setFixing(false);
  };

  return (
    <Box sx={{ p: 3 }}>
      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            🔍 Authentication Debug Info
          </Typography>
          
          <Typography variant="body2" paragraph>
            <strong>User ID:</strong> {user?.id || 'Not logged in'}
          </Typography>

          <Typography variant="body2" paragraph>
            <strong>User Email:</strong> {user?.email || 'Not logged in'}
          </Typography>
          
          <Typography variant="body2" paragraph>
            <strong>Detected Role:</strong> {userRole || 'Not detected'}
          </Typography>
          
          <Typography variant="body2" paragraph>
            <strong>Admin Country:</strong> {userCountry || 'Not detected'}
          </Typography>
          
          <Typography variant="body2" paragraph>
            <strong>User Data:</strong> {JSON.stringify(user, null, 2)}
          </Typography>
          
      {user?.email === 'superadmin@request.lk' && userRole !== 'super_admin' && (
            <Box sx={{ mt: 2 }}>
              <Alert severity="warning" sx={{ mb: 2 }}>
        Issue detected: superadmin@request.lk not recognized as super_admin. Role mapping may need correction.
              </Alert>
              
              <Button 
                variant="contained" 
                color="primary"
                onClick={fixSuperAdminUID}
                disabled={fixing}
              >
        {fixing ? 'Fixing...' : '🔧 Simulate Role Fix'}
              </Button>
            </Box>
          )}
          
          {message && (
            <Alert severity={message.includes('✅') ? 'success' : 'error'} sx={{ mt: 2 }}>
              {message}
            </Alert>
          )}
        </CardContent>
      </Card>
    </Box>
  );
};

export default DebugAuth;
