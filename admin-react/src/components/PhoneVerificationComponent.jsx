import React, { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  TextField,
  Button,
  Typography,
  Alert,
  CircularProgress,
  InputAdornment,
  IconButton,
  Stepper,
  Step,
  StepLabel,
  Grid,
  Chip
} from '@mui/material';
import {
  Phone as PhoneIcon,
  Send as SendIcon,
  Verified as VerifiedIcon,
  Add as AddIcon,
  Star as StarIcon,
  Delete as DeleteIcon
} from '@mui/icons-material';
import { apiClient } from '../services/api';

/**
 * 📱 Phone Verification Component
 * Supports multiple phone numbers with different purposes
 */
const PhoneVerificationComponent = ({ 
  purpose = 'general', 
  onVerificationSuccess, 
  allowMultiple = true,
  showExisting = true,
  autoSubmit = false 
}) => {
  const [step, setStep] = useState(0); // 0: phone input, 1: OTP verification
  const [phoneNumber, setPhoneNumber] = useState('');
  const [otp, setOtp] = useState('');
  const [otpId, setOtpId] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [countdown, setCountdown] = useState(0);
  const [existingPhones, setExistingPhones] = useState([]);
  const [showAddForm, setShowAddForm] = useState(false);

  // Purpose labels
  const purposeLabels = {
    'login': 'Login Authentication',
    'driver_verification': 'Driver Profile',
    'business_profile': 'Business Profile', 
    'profile_update': 'Profile Phone',
    'general': 'General Purpose'
  };

  useEffect(() => {
    if (showExisting) {
      loadExistingPhones();
    }
  }, [showExisting]);

  useEffect(() => {
    let timer;
    if (countdown > 0) {
      timer = setTimeout(() => setCountdown(countdown - 1), 1000);
    }
    return () => clearTimeout(timer);
  }, [countdown]);

  const loadExistingPhones = async () => {
    try {
      const response = await apiClient.get('/api/sms/user-phones');
      if (response.data.success) {
        setExistingPhones(response.data.data);
      }
    } catch (error) {
      console.error('Error loading existing phones:', error);
    }
  };

  const handleSendOTP = async () => {
    if (!phoneNumber) {
      setError('Please enter a phone number');
      return;
    }

    // Basic phone validation
    const phoneRegex = /^\+[1-9]\d{1,14}$/;
    if (!phoneRegex.test(phoneNumber)) {
      setError('Please enter a valid phone number with country code (e.g., +94771234567)');
      return;
    }

    try {
      setLoading(true);
      setError('');

      const response = await apiClient.post('/api/sms/send-otp', {
        phoneNumber,
        purpose
      });

      if (response.data.success) {
        setOtpId(response.data.data.otpId);
        setStep(1);
        setCountdown(300); // 5 minutes
        setSuccess('OTP sent successfully! Check your phone.');
      }
    } catch (error) {
      setError(error.response?.data?.message || 'Failed to send OTP');
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOTP = async () => {
    if (!otp) {
      setError('Please enter the OTP code');
      return;
    }

    try {
      setLoading(true);
      setError('');

      const response = await apiClient.post('/api/sms/verify-otp', {
        phoneNumber,
        otp,
        otpId,
        purpose
      });

      if (response.data.success) {
        setSuccess('Phone number verified successfully! ✅');
        
        // If this is for adding multiple phones, add it to the user's account
        if (allowMultiple) {
          await addPhoneToAccount();
        }

        // Call success callback
        if (onVerificationSuccess) {
          onVerificationSuccess({
            phoneNumber,
            purpose,
            verified: true
          });
        }

        // Auto-submit if required
        if (autoSubmit) {
          setTimeout(() => {
            // Handle auto-submit logic
          }, 1000);
        }

        // Reset form
        setTimeout(() => {
          setStep(0);
          setPhoneNumber('');
          setOtp('');
          setOtpId('');
          setShowAddForm(false);
          loadExistingPhones();
        }, 2000);
      }
    } catch (error) {
      setError(error.response?.data?.message || 'OTP verification failed');
    } finally {
      setLoading(false);
    }
  };

  const addPhoneToAccount = async () => {
    try {
      await apiClient.post('/api/sms/add-phone', {
        phoneNumber,
        label: getLabelFromPurpose(purpose),
        purpose,
        isPrimary: existingPhones.length === 0 // Make first phone primary
      });
    } catch (error) {
      console.error('Error adding phone to account:', error);
    }
  };

  const setPrimaryPhone = async (phoneId) => {
    try {
      await apiClient.put(`/api/sms/set-primary/${phoneId}`);
      setSuccess('Primary phone updated successfully!');
      loadExistingPhones();
    } catch (error) {
      setError('Failed to update primary phone');
    }
  };

  const removePhone = async (phoneId) => {
    if (!confirm('Are you sure you want to remove this phone number?')) return;

    try {
      await apiClient.delete(`/api/sms/remove-phone/${phoneId}`);
      setSuccess('Phone number removed successfully!');
      loadExistingPhones();
    } catch (error) {
      setError(error.response?.data?.message || 'Failed to remove phone number');
    }
  };

  const getLabelFromPurpose = (purpose) => {
    const labels = {
      'login': 'personal',
      'driver_verification': 'driver',
      'business_profile': 'business',
      'profile_update': 'personal',
      'general': 'personal'
    };
    return labels[purpose] || 'personal';
  };

  const formatCountdown = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const steps = ['Enter Phone Number', 'Verify OTP'];

  return (
    <Box>
      {/* Existing Phone Numbers */}
      {showExisting && existingPhones.length > 0 && (
        <Card sx={{ mb: 3 }}>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              📱 Your Phone Numbers
            </Typography>
            <Grid container spacing={2}>
              {existingPhones.map((phone) => (
                <Grid item xs={12} sm={6} md={4} key={phone.phoneId}>
                  <Card variant="outlined" sx={{ p: 2 }}>
                    <Box display="flex" justifyContent="between" alignItems="center">
                      <Box>
                        <Typography variant="body1" fontWeight="bold">
                          {phone.phoneNumber}
                        </Typography>
                        <Box display="flex" gap={1} mt={1}>
                          <Chip 
                            label={phone.label} 
                            size="small" 
                            color="primary" 
                            variant="outlined"
                          />
                          {phone.isPrimary && (
                            <Chip 
                              label="Primary" 
                              size="small" 
                              color="success"
                              icon={<StarIcon />}
                            />
                          )}
                          {phone.isVerified && (
                            <Chip 
                              label="Verified" 
                              size="small" 
                              color="success"
                              icon={<VerifiedIcon />}
                            />
                          )}
                        </Box>
                      </Box>
                      <Box>
                        {!phone.isPrimary && phone.isVerified && (
                          <IconButton 
                            size="small" 
                            onClick={() => setPrimaryPhone(phone.phoneId)}
                            title="Set as primary"
                          >
                            <StarIcon />
                          </IconButton>
                        )}
                        <IconButton 
                          size="small" 
                          onClick={() => removePhone(phone.phoneId)}
                          color="error"
                          title="Remove phone"
                        >
                          <DeleteIcon />
                        </IconButton>
                      </Box>
                    </Box>
                  </Card>
                </Grid>
              ))}
            </Grid>
            
            {allowMultiple && (
              <Button
                startIcon={<AddIcon />}
                onClick={() => setShowAddForm(true)}
                sx={{ mt: 2 }}
              >
                Add Another Phone Number
              </Button>
            )}
          </CardContent>
        </Card>
      )}

      {/* Add Phone Form */}
      {(showAddForm || existingPhones.length === 0 || !showExisting) && (
        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              📱 {purposeLabels[purpose]}
            </Typography>

            <Stepper activeStep={step} sx={{ mb: 3 }}>
              {steps.map((label) => (
                <Step key={label}>
                  <StepLabel>{label}</StepLabel>
                </Step>
              ))}
            </Stepper>

            {error && (
              <Alert severity="error" sx={{ mb: 2 }}>
                {error}
              </Alert>
            )}

            {success && (
              <Alert severity="success" sx={{ mb: 2 }}>
                {success}
              </Alert>
            )}

            {/* Step 1: Phone Number Input */}
            {step === 0 && (
              <Box>
                <TextField
                  fullWidth
                  label="Phone Number"
                  value={phoneNumber}
                  onChange={(e) => setPhoneNumber(e.target.value)}
                  placeholder="+94771234567"
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <PhoneIcon />
                      </InputAdornment>
                    ),
                  }}
                  sx={{ mb: 3 }}
                />
                
                <Button
                  fullWidth
                  variant="contained"
                  onClick={handleSendOTP}
                  disabled={loading}
                  startIcon={loading ? <CircularProgress size={20} /> : <SendIcon />}
                  size="large"
                >
                  {loading ? 'Sending...' : 'Send Verification Code'}
                </Button>
              </Box>
            )}

            {/* Step 2: OTP Verification */}
            {step === 1 && (
              <Box>
                <Typography variant="body2" color="text.secondary" mb={2}>
                  Enter the 6-digit code sent to {phoneNumber}
                  {countdown > 0 && (
                    <Typography component="span" color="primary" ml={1}>
                      ({formatCountdown(countdown)})
                    </Typography>
                  )}
                </Typography>

                <TextField
                  fullWidth
                  label="Verification Code"
                  value={otp}
                  onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                  placeholder="123456"
                  inputProps={{ 
                    maxLength: 6,
                    style: { textAlign: 'center', fontSize: '1.5rem', letterSpacing: '0.5rem' }
                  }}
                  sx={{ mb: 3 }}
                />

                <Box display="flex" gap={2}>
                  <Button
                    variant="outlined"
                    onClick={() => setStep(0)}
                    disabled={loading}
                    fullWidth
                  >
                    Change Number
                  </Button>
                  
                  <Button
                    fullWidth
                    variant="contained"
                    onClick={handleVerifyOTP}
                    disabled={loading || otp.length !== 6}
                    startIcon={loading ? <CircularProgress size={20} /> : <VerifiedIcon />}
                  >
                    {loading ? 'Verifying...' : 'Verify Code'}
                  </Button>
                </Box>

                {countdown === 0 && (
                  <Button
                    fullWidth
                    variant="text"
                    onClick={handleSendOTP}
                    disabled={loading}
                    sx={{ mt: 2 }}
                  >
                    Resend Code
                  </Button>
                )}
              </Box>
            )}
          </CardContent>
        </Card>
      )}
    </Box>
  );
};

export default PhoneVerificationComponent;
