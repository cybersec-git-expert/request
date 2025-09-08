import React, { useState, useEffect } from 'react';
import {
  Container,
  Typography,
  Card,
  CardContent,
  Button,
  Box,
  Chip,
  Grid,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Alert,
  Avatar,
  IconButton,
  CircularProgress,
  Tabs,
  Tab,
  CardHeader,
  CardMedia,
  CardActions,
  LinearProgress,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Snackbar
} from '@mui/material';
import {
  Person as PersonIcon,
  CheckCircle as ApproveIcon,
  Cancel as RejectIcon,
  Visibility as ViewIcon,
  Phone as PhoneIcon,
  Email as EmailIcon,
  LocationOn as LocationIcon,
  DriveEta as CarIcon,
  Image as ImageIcon,
  CheckCircleOutline as CheckIcon,
  RadioButtonUnchecked as PendingIcon,
  Error as ErrorIcon,
  Assignment as AssignmentIcon,
  Description as DescriptionIcon,
  Security as SecurityIcon,
  TwoWheeler,
  DirectionsCar,
  LocalTaxi,
  AirportShuttle,
  People,
  LocalShipping,
  Download as DownloadIcon,
  Launch as LaunchIcon,
  Store as StoreIcon,
  ContactPhone as ContactIcon,
  CalendarToday as CalendarIcon,
  Category as CategoryIcon,
  Assessment as ReportsIcon,
  VerifiedUser as VerifiedIcon,
  AccessTime as TimeIcon,
  Language as WebsiteIcon,
  Map as MapIcon,
  PhotoLibrary as GalleryIcon,
  PictureAsPdf as PdfIcon,
  InsertDriveFile as FileIcon,
  CloudDownload as CloudIcon,
  Fullscreen as FullscreenIcon,
  Close as CloseIcon,
  Warning as WarningIcon,
  Info as InfoIcon,
  Visibility as VisibilityIcon,
  AccessTime as AccessTimeIcon
} from '@mui/icons-material';
import { useAuth } from '../contexts/AuthContext';
import api from '../services/apiClient';

const DriverVerificationEnhanced = () => {
  const { adminData, isCountryAdmin, isSuperAdmin } = useAuth();
  const [drivers, setDrivers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedDriver, setSelectedDriver] = useState(null);
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [filterStatus, setFilterStatus] = useState('all');
  const [tabValue, setTabValue] = useState(0);
  
  // Document verification states
  const [rejectionDialog, setRejectionDialog] = useState({ open: false, target: null, type: '' });
  const [rejectionReason, setRejectionReason] = useState('');
  const [actionLoading, setActionLoading] = useState(false);
  const [fullscreenImage, setFullscreenImage] = useState({ open: false, url: '', title: '' });
  const [auditLogs, setAuditLogs] = useState([]);
  const [auditLoading, setAuditLoading] = useState(false);
  const [auditError, setAuditError] = useState(null);
  
  // Phone verification states
  const [phoneVerificationDialog, setPhoneVerificationDialog] = useState({ open: false, driver: null, step: 'send' });
  const [otpCode, setOtpCode] = useState('');
  const [verificationLoading, setVerificationLoading] = useState(false);
  
  // City and Vehicle Type mapping
  const [cityNames, setCityNames] = useState({});
  const [vehicleTypeNames, setVehicleTypeNames] = useState({});
  
  // Notification state
  const [notification, setNotification] = useState({ open: false, message: '', severity: 'success' });

  useEffect(() => {
    loadDrivers();
    loadCityNames();
    loadVehicleTypeNames();
  }, [filterStatus, isCountryAdmin, adminData?.country]);

  const loadDrivers = async () => {
    try {
      setLoading(true);
      const params = {};
      if (isCountryAdmin && adminData?.country) params.country = adminData.country;
      if (filterStatus !== 'all') params.status = filterStatus;
      const res = await api.get('/driver-verifications', { params });
      const list = Array.isArray(res.data) ? res.data : res.data?.data || [];
      // Normalize each driver (parse document_verification JSON and build helper camelCase fields if missing)
      const normalized = list.map(d => {
        let docVer = d.documentVerification || d.document_verification;
        if (typeof docVer === 'string') {
          try { docVer = JSON.parse(docVer); } catch { docVer = {}; }
        }
        // Parse vehicle image verification
        let vehImgVer = d.vehicleImageVerification || d.vehicle_image_verification;
        if (typeof vehImgVer === 'string') {
          try { vehImgVer = JSON.parse(vehImgVer); } catch { vehImgVer = {}; }
        }
        // Parse vehicle image urls if JSON string
        let vehImgUrls = d.vehicleImageUrls || d.vehicle_image_urls;
        if (typeof vehImgUrls === 'string' && vehImgUrls.trim().startsWith('[')) {
          try { vehImgUrls = JSON.parse(vehImgUrls); } catch { /* ignore */ }
        }
        // Inject camelCase status fallbacks from snake_case
        const withStatuses = { ...d };
        const statusPairs = [
          ['driver_image_status','driverImageStatus'],
          ['nic_front_status','nicFrontStatus'],
          ['nic_back_status','nicBackStatus'],
          ['license_front_status','licenseFrontStatus'],
            ['license_back_status','licenseBackStatus'],
          ['vehicle_registration_status','vehicleRegistrationStatus'],
          ['vehicle_insurance_status','vehicleInsuranceStatus'],
          ['billing_proof_status','billingProofStatus']
        ];
        statusPairs.forEach(([snake, camel]) => {
          if (withStatuses[snake]) withStatuses[camel] = withStatuses[snake];
        });
  withStatuses.documentVerification = docVer || {};
  withStatuses.vehicleImageVerification = vehImgVer || {};
  withStatuses.vehicleImageUrls = vehImgUrls;
        return withStatuses;
      });
      const sorted = [...normalized].sort((a,b)=> new Date(b.submittedAt || b.createdAt || 0) - new Date(a.submittedAt || a.createdAt || 0));
      setDrivers(sorted);
      // Auto-refresh selected driver object with latest data
      if (selectedDriver) {
        const updated = sorted.find(d => d.id === selectedDriver.id);
        if (updated) {
          setSelectedDriver(updated);
        } else {
          // Driver not found in current filter (e.g., approved driver when filter is 'pending') - close modal
          console.log(`🔄 Selected driver ${selectedDriver.id} not found in current filter, closing modal`);
          setSelectedDriver(null);
          setDetailsOpen(false);
        }
      }
    } catch (e) {
      console.error('❌ Error loading drivers:', e);
    } finally { setLoading(false); }
  };

  const loadAuditLogs = async (driverId) => {
    if (!driverId) return;
    try {
      setAuditLoading(true);
      setAuditError(null);
      const resp = await api.get(`/driver-verifications/${driverId}/audit-logs`, { params: { limit: 200 } });
      const list = resp.data?.data || [];
      setAuditLogs(list);
    } catch (e) {
      console.error('Error loading audit logs', e);
      setAuditError(e.message || 'Failed to load');
    } finally { setAuditLoading(false); }
  };

  const loadCityNames = async () => {
    try { 
      const res = await api.get('/cities'); 
      const map = {}; 
      // Handle nested data structure: res.data.data or res.data
      const cities = res.data?.data || res.data || [];
      cities.forEach(c => { 
        map[c.id] = c.name || c.cityName || c.displayName || c.id; 
      }); 
      setCityNames(map);
    } catch(e) { 
      console.error('Error loading city names', e);
    } 
  };

  const loadVehicleTypeNames = async () => { 
    try { 
      const res = await api.get('/vehicle-types'); 
      const map = {}; 
      // Handle nested data structure: res.data.data or res.data
      const vehicleTypes = res.data?.data || res.data || [];
      vehicleTypes.forEach(v => { 
        map[v.id] = v.name || v.typeName || v.displayName || v.id; 
      }); 
      setVehicleTypeNames(map);
    } catch(e) { 
      console.error('Error loading vehicle types', e);
    } 
  };

  // Phone verification helper function
  const getPhoneVerificationStatus = (driverData) => {
    // Use backend-provided verification status if available
    if (typeof driverData.phoneVerified === 'boolean') {
      return {
        isVerified: driverData.phoneVerified,
        source: driverData.phoneVerificationSource || 'unknown',
        needsManualVerification: driverData.requiresPhoneVerification || false,
        hasPhoneNumber: !!driverData.phoneNumber
      };
    }

    // Fallback logic for older data
    if (driverData.userId && driverData.phoneNumber) {
      return {
        isVerified: true,
        source: 'firebase_auth_registration',
        needsManualVerification: false,
        hasPhoneNumber: true
      };
    }

    // Default to not verified, needs manual verification
    return {
      isVerified: false,
      source: 'not_verified',
      needsManualVerification: true,
      hasPhoneNumber: !!driverData.phoneNumber
    };
  };

  // Email verification helper function
  const getEmailVerificationStatus = (driverData) => {
    // Use backend-provided verification status if available
    if (typeof driverData.emailVerified === 'boolean') {
      return {
        isVerified: driverData.emailVerified,
        source: driverData.emailVerificationSource || 'unknown',
        needsManualVerification: driverData.requiresEmailVerification || false,
        hasEmail: !!driverData.email
      };
    }

    // Fallback logic for older data
    if (driverData.userId && driverData.email) {
      return {
        isVerified: true,
        source: 'firebase_auth_registration',
        needsManualVerification: false,
        hasEmail: true
      };
    }

    // Default to not verified
    return {
      isVerified: false,
      source: 'not_verified',
      needsManualVerification: true,
      hasEmail: !!driverData.email
    };
  };

  const getStatusColor = (status) => {
    switch (status?.toLowerCase()) {
      case 'approved': return 'success';
      case 'rejected': return 'error';
      case 'pending': return 'warning';
      default: return 'default';
    }
  };

  const getStatusIcon = (status) => {
    switch (status?.toLowerCase()) {
      case 'approved': return <CheckIcon />;
      case 'rejected': return <ErrorIcon />;
      case 'pending': return <PendingIcon />;
      default: return <PendingIcon />;
    }
  };

  const getDocumentStatus = (driver, docType) => {
    // Always use flat status fields for reliability - they are the source of truth
    // The JSON documentVerification field can get out of sync
    switch (docType) {
      case 'licenseImage': return driver.licenseImageStatus || 'pending';
      case 'idImage': return driver.idImageStatus || 'pending';
      case 'vehicleRegistration': return driver.vehicleRegistrationStatus || 'pending';
      case 'profileImage': return driver.profileImageStatus || 'pending';
      // Support for new document types from mobile app
      case 'driverImage': {
        const status = driver.driverImageStatus || driver.driver_image_status || 'pending';
        return status;
      }
      case 'licenseFront': return driver.licenseFrontStatus || driver.license_front_status || 'pending';
      case 'licenseBack': return driver.licenseBackStatus || driver.license_back_status || 'pending';
      case 'licenseDocument': return driver.licenseDocumentStatus || 'pending';
      case 'nicFront': return driver.nicFrontStatus || driver.nic_front_status || 'pending';
      case 'nicBack': return driver.nicBackStatus || driver.nic_back_status || 'pending';
      case 'billingProof': return driver.billingProofStatus || driver.billing_proof_status || 'pending';
      case 'vehicleInsurance': return driver.vehicleInsuranceStatus || driver.vehicle_insurance_status || 'pending';
      default: return 'pending';
    }
  };

  const getVehicleImageStatus = (driver, imageIndex) => {
    const vehicleImageVerification = driver.vehicleImageVerification?.[imageIndex];
    if (vehicleImageVerification?.status) {
      return vehicleImageVerification.status;
    }
    return 'pending';
  };

  const getVehicleIcon = (vehicleType) => {
    switch (vehicleType?.toLowerCase()) {
      case 'bicycle':
      case 'bike':
        return <TwoWheeler sx={{ fontSize: 40 }} />;
      case 'car':
      case 'sedan':
      case 'hatchback':
        return <DirectionsCar sx={{ fontSize: 40 }} />;
      case 'taxi':
        return <LocalTaxi sx={{ fontSize: 40 }} />;
      case 'van':
      case 'minivan':
        return <AirportShuttle sx={{ fontSize: 40 }} />;
      case 'bus':
        return <People sx={{ fontSize: 40 }} />;
      case 'truck':
        return <LocalShipping sx={{ fontSize: 40 }} />;
      default:
        return <CarIcon sx={{ fontSize: 40 }} />;
    }
  };

  const getDocumentUrl = (driver, docType) => {
    switch (docType) {
      case 'licenseImage': return driver.licenseImageUrl;
      case 'idImage': return driver.idImageUrl;
      case 'vehicleRegistration': return driver.vehicleRegistrationUrl;
      case 'profileImage': return driver.profileImageUrl;
      // Support for new document types from mobile app
      case 'driverImage': return driver.driverImageUrl;
      case 'licenseFront': return driver.licenseFrontUrl;
      case 'licenseBack': return driver.licenseBackUrl;
      case 'licenseDocument': return driver.licenseDocumentUrl;
      case 'nicFront': return driver.nicFrontUrl;
      case 'nicBack': return driver.nicBackUrl;
      case 'billingProof': return driver.billingProofUrl;
      case 'vehicleInsurance': return driver.vehicleInsuranceUrl || driver.insuranceDocumentUrl;
      default: return null;
    }
  };

  const getCityName = (cityId) => {
    return cityNames[cityId] || cityId || 'Unknown City';
  };

  const getVehicleTypeName = (vehicleTypeId) => {
    return vehicleTypeNames[vehicleTypeId] || vehicleTypeId || 'Unknown Vehicle Type';
  };

  // Map frontend camelCase document types to backend snake_case format
  const mapDocumentTypeToBackend = (frontendDocType) => {
    const mapping = {
      'driverImage': 'driver_image',
      'licenseFront': 'license_front', 
      'licenseBack': 'license_back',
      'nicFront': 'nic_front',
      'nicBack': 'nic_back',
      'vehicleRegistration': 'vehicle_registration',
      'vehicleInsurance': 'vehicle_insurance',
      'billingProof': 'billing_proof',
      // Legacy mappings
      'licenseImage': 'license_front', // Map legacy to new format
      'idImage': 'nic_front',         // Map legacy to new format  
      'profileImage': 'driver_image'   // Map legacy to new format
    };
    return mapping[frontendDocType] || frontendDocType;
  };

  const handleDocumentApprovalWithClose = async (driver, docType, action) => {
    setActionLoading(true);
    try {
      const backendDocType = mapDocumentTypeToBackend(docType);
      await api.put(`/driver-verifications/${driver.id}/document-status`, { documentType: backendDocType, status: action });
      // Optimistic local update before full reload
      setSelectedDriver(prev => prev && prev.id === driver.id ? {
        ...prev,
        documentVerification: {
          ...(prev.documentVerification||{}),
          [docType]: { ...(prev.documentVerification?.[docType]||{}), status: action }
        },
        [`${backendDocType.replace(/_.(.)/g,(m,g)=>g.toUpperCase())}Status`]: action
      } : prev);
      await loadDrivers();
      const res = await api.get(`/driver-verifications/${driver.id}`);
      const raw = res.data?.data || res.data;
      if (raw) {
        let docVer = raw.documentVerification || raw.document_verification;
        if (typeof docVer === 'string') { try { docVer = JSON.parse(docVer); } catch { docVer = {}; } }
        const enriched = { ...raw, documentVerification: docVer };
        setSelectedDriver(enriched);
      }
    } catch (error) {
      console.error('Error updating document status:', error);
    } finally { setActionLoading(false); }
  };

  const handleDocumentAction = async (driver, docType, action) => {
    if (action === 'reject') {
      setRejectionDialog({ open: true, target: driver, type: 'document', docType });
      return;
    }
    setActionLoading(true);
    try {
      const backendDocType = mapDocumentTypeToBackend(docType);
      await api.put(`/driver-verifications/${driver.id}/document-status`, { documentType: backendDocType, status: action });
      
      // Optimistic local update before full reload
      setSelectedDriver(prev => prev && prev.id === driver.id ? {
        ...prev,
        documentVerification: {
          ...(prev.documentVerification||{}),
          [docType]: { ...(prev.documentVerification?.[docType]||{}), status: action }
        },
        [`${backendDocType.replace(/_.(.)/g,(m,g)=>g.toUpperCase())}Status`]: action
      } : prev);
      
      // Reload drivers list and refresh selected driver data
      await loadDrivers();
      const res = await api.get(`/driver-verifications/${driver.id}`);
      const raw = res.data?.data || res.data;
      if (raw) {
        let docVer = raw.documentVerification || raw.document_verification;
        if (typeof docVer === 'string') { try { docVer = JSON.parse(docVer); } catch { docVer = {}; } }
        let vehImgVer = raw.vehicleImageVerification || raw.vehicle_image_verification;
        if (typeof vehImgVer === 'string') { try { vehImgVer = JSON.parse(vehImgVer); } catch { vehImgVer = {}; } }
        
        // Apply the same normalization as loadDrivers
        const withStatuses = { ...raw };
        const statusPairs = [
          ['driver_image_status','driverImageStatus'],
          ['nic_front_status','nicFrontStatus'],
          ['nic_back_status','nicBackStatus'],
          ['license_front_status','licenseFrontStatus'],
          ['license_back_status','licenseBackStatus'],
          ['vehicle_registration_status','vehicleRegistrationStatus'],
          ['vehicle_insurance_status','vehicleInsuranceStatus'],
          ['billing_proof_status','billingProofStatus']
        ];
        statusPairs.forEach(([snake, camel]) => {
          if (withStatuses[snake]) withStatuses[camel] = withStatuses[snake];
        });
        
        const enriched = { 
          ...withStatuses, 
          documentVerification: docVer, 
          vehicleImageVerification: vehImgVer 
        };
        setSelectedDriver(enriched);
      }
    } catch(err){ 
      console.error('Error updating document status', err);
    } finally { 
      setActionLoading(false);
    } 
  };

  const handleDriverAction = async (driver, action) => {
    if (action === 'reject') {
      setRejectionDialog({ 
        open: true, 
        target: driver,
        type: 'driver'
      });
      return;
    }

    if (action === 'approve') {
      // Define all possible document types (both new and legacy)
      const allDocTypes = [
        // New mobile app documents (mandatory)
        'driverImage', 'licenseFront', 'licenseBack', 'vehicleInsurance', 'vehicleRegistration',
        // Legacy documents (for backward compatibility)  
        'profileImage', 'licenseImage', 'idImage'
      ];
      
      // Find which documents this driver actually has
      const availableDocuments = allDocTypes.filter(docType => getDocumentUrl(driver, docType));
      
      // Check if all available documents are approved
      const allDocsApproved = availableDocuments.every(docType => {
        const status = getDocumentStatus(driver, docType);
        return status === 'approved';
      });

      if (!allDocsApproved) {
        alert('All submitted documents must be approved before approving the driver.');
        return;
      }

      // Check contact verification requirements
      const phoneStatus = getPhoneVerificationStatus(driver);
      const emailStatus = getEmailVerificationStatus(driver);
      
      const verificationIssues = [];
      
      if (!phoneStatus.hasPhoneNumber) {
        verificationIssues.push('Phone number is required');
      } else if (!phoneStatus.isVerified) {
        verificationIssues.push('Phone number must be verified');
      }
      
      if (!emailStatus.hasEmail) {
        verificationIssues.push('Email address is required');
      } else if (!emailStatus.isVerified) {
        verificationIssues.push('Email address must be verified');
      }
      
      if (verificationIssues.length > 0) {
        alert(`Cannot approve driver. The following issues must be resolved:\n\n• ${verificationIssues.join('\n• ')}`);
        return;
      }
    }

  setActionLoading(true);
  try { 
    await api.put(`/driver-verifications/${driver.id}/status`, { status: action === 'approve' ? 'approved' : action }); 
    
    // Always show success notification and keep modal open
    setNotification({
      open: true,
      message: `✅ Driver ${driver.fullName || driver.full_name} has been ${action === 'approve' ? 'approved' : action} successfully!`,
      severity: 'success'
    });

    // Reload drivers to get updated data
    await loadDrivers(); 
    
    // Update the selected driver with new status to reflect changes in the modal
    if (selectedDriver && selectedDriver.id === driver.id) {
      setSelectedDriver(prev => ({
        ...prev,
        status: action === 'approve' ? 'approved' : action
      }));
    }
    
    console.log(`✅ Driver ${action}: ${driver.fullName}`);
  } catch (error){ 
    console.error(`Error ${action} driver`, error);
    setNotification({
      open: true,
      message: `❌ Error ${action === 'approve' ? 'approving' : action} driver: ${error.message}`,
      severity: 'error'
    });
  } finally { 
    setActionLoading(false);
  } 
  };

  const handleVehicleImageAction = async (driver, imageIndex, action) => {
    if (action === 'reject') {
      setRejectionDialog({ 
        open: true, 
        target: driver,
        type: 'vehicleImage',
        imageIndex: imageIndex
      });
      return;
    }

  setActionLoading(true);
  try { 
    await api.put(`/driver-verifications/${driver.id}/vehicle-images/${imageIndex}`, { status: action });
    
    // Optimistic update of selected driver modal
    setSelectedDriver(prev => prev && prev.id === driver.id ? {
      ...prev,
      vehicleImageVerification: {
        ...(prev.vehicleImageVerification || {}),
        [imageIndex]: {
          ...((prev.vehicleImageVerification||{})[imageIndex]||{}),
          status: action,
          reviewedAt: new Date().toISOString()
        }
      }
    } : prev);
    
    // Reload drivers list and refresh selected driver data
    await loadDrivers(); 
    const res = await api.get(`/driver-verifications/${driver.id}`);
    const raw = res.data?.data || res.data;
    if (raw) {
      let docVer = raw.documentVerification || raw.document_verification;
      if (typeof docVer === 'string') { try { docVer = JSON.parse(docVer); } catch { docVer = {}; } }
      let vehImgVer = raw.vehicleImageVerification || raw.vehicle_image_verification;
      if (typeof vehImgVer === 'string') { try { vehImgVer = JSON.parse(vehImgVer); } catch { vehImgVer = {}; } }
      
      // Apply the same normalization as loadDrivers
      const withStatuses = { ...raw };
      const statusPairs = [
        ['driver_image_status','driverImageStatus'],
        ['nic_front_status','nicFrontStatus'],
        ['nic_back_status','nicBackStatus'],
        ['license_front_status','licenseFrontStatus'],
        ['license_back_status','licenseBackStatus'],
        ['vehicle_registration_status','vehicleRegistrationStatus'],
        ['vehicle_insurance_status','vehicleInsuranceStatus'],
        ['billing_proof_status','billingProofStatus']
      ];
      statusPairs.forEach(([snake, camel]) => {
        if (withStatuses[snake]) withStatuses[camel] = withStatuses[snake];
      });
      
      const enriched = { 
        ...withStatuses, 
        documentVerification: docVer, 
        vehicleImageVerification: vehImgVer 
      };
      setSelectedDriver(enriched);
    }
    
    console.log(`✅ Vehicle image ${imageIndex} ${action}: ${driver.fullName}`);
  } catch (error){ console.error(`Error ${action} vehicle image`, error);} finally { setActionLoading(false);} 
  };

  const handleRejection = async () => {
    if (!rejectionReason.trim()) {
      alert('Please provide a reason for rejection');
      return;
    }
    const { target, type, docType, imageIndex } = rejectionDialog;
    setActionLoading(true);
    try {
      if (type === 'document') {
        const backendDocType = mapDocumentTypeToBackend(docType);
        const resp = await api.put(`/driver-verifications/${target.id}/document-status`, { documentType: backendDocType, status: 'rejected', rejectionReason });
        // optimistic update
        setSelectedDriver(prev => prev && prev.id === target.id ? {
          ...prev,
          documentVerification: {
            ...(prev.documentVerification||{}),
            [docType]: { ...(prev.documentVerification?.[docType]||{}), status: 'rejected', rejectionReason }
          }
        } : prev);
      } else if (type === 'vehicleImage') {
        await api.put(`/driver-verifications/${target.id}/vehicle-images/${imageIndex}`, { status: 'rejected', rejectionReason });
        // optimistic update for vehicle image status
        setSelectedDriver(prev => prev && prev.id === target.id ? {
          ...prev,
          vehicleImageVerification: {
            ...(prev.vehicleImageVerification || {}),
            [imageIndex]: {
              ...((prev.vehicleImageVerification||{})[imageIndex]||{}),
              status: 'rejected',
              rejectionReason,
              reviewedAt: new Date().toISOString()
            }
          }
        } : prev);
      } else {
        await api.put(`/driver-verifications/${target.id}/status`, { status: 'rejected', rejectionReason });
      }
      await loadDrivers();
      setRejectionDialog({ open: false, target: null, type: '' });
      setRejectionReason('');
    } catch (error) {
      console.error('Reject failed', error.response?.data || error.message);
      alert('Reject failed: ' + (error.response?.data?.message || error.message));
    } finally { setActionLoading(false); }
  };

  // Phone verification functions
  const handleTriggerPhoneVerification = async (driver) => {
    setPhoneVerificationDialog({ open: true, driver, step: 'send' });
  };

  const sendPhoneVerificationOTP = async () => {
    setVerificationLoading(true);
    try {
      const response = await api.post(`/driver-verifications/${phoneVerificationDialog.driver.id}/verify-phone`);
      if (response.isSuccess) {
        setPhoneVerificationDialog(prev => ({ ...prev, step: 'verify' }));
      } else {
        alert('Failed to send OTP: ' + (response.error || 'Unknown error'));
      }
    } catch (error) {
      console.error('Error sending OTP:', error);
      alert('Failed to send OTP: ' + error.message);
    } finally {
      setVerificationLoading(false);
    }
  };

  const verifyPhoneOTP = async () => {
    if (!otpCode.trim()) {
      alert('Please enter the OTP code');
      return;
    }
    
    setVerificationLoading(true);
    try {
      const response = await api.post(`/driver-verifications/${phoneVerificationDialog.driver.id}/verify-otp`, {
        otp: otpCode
      });
      
      if (response.isSuccess) {
        // Close dialog
        setPhoneVerificationDialog({ open: false, driver: null, step: 'send' });
        setOtpCode('');
        
        // Refresh driver data
        await loadDrivers();
        if (selectedDriver && selectedDriver.id === phoneVerificationDialog.driver.id) {
          const res = await api.get(`/driver-verifications/${selectedDriver.id}`);
          if (res.isSuccess) {
            const raw = res.data?.data || res.data;
            setSelectedDriver(raw);
          }
        }
        
        alert('Phone number verified successfully!');
      } else {
        alert('OTP verification failed: ' + (response.error || 'Invalid OTP'));
      }
    } catch (error) {
      console.error('Error verifying OTP:', error);
      alert('OTP verification failed: ' + error.message);
    } finally {
      setVerificationLoading(false);
    }
  };

  const viewDocument = (url, title = 'Document') => {
    if (url) {
      setFullscreenImage({ open: true, url, title });
    }
  };

  const renderDriverCard = (driver) => {
    const overallStatus = driver.status || 'pending';
    const documentsCount = ['licenseImage', 'idImage', 'vehicleRegistration', 'profileImage']
      .filter(docType => getDocumentUrl(driver, docType)).length;
    const approvedDocsCount = ['licenseImage', 'idImage', 'vehicleRegistration', 'profileImage']
      .filter(docType => {
        const url = getDocumentUrl(driver, docType);
        const status = getDocumentStatus(driver, docType);
        return url && status === 'approved';
      }).length;

    return (
      <Card key={driver.id} sx={{ mb: 2 }}>
        <CardContent>
          <Box display="flex" justifyContent="space-between" alignItems="flex-start">
            <Box flex={1}>
              <Box display="flex" alignItems="center" gap={1} mb={1}>
                <PersonIcon color="primary" />
                <Typography variant="h6">{driver.fullName || 'Unknown Driver'}</Typography>
                <Chip 
                  label={overallStatus}
                  color={getStatusColor(overallStatus)}
                  size="small"
                  icon={getStatusIcon(overallStatus)}
                />
              </Box>
              
              <Grid container spacing={1} sx={{ mb: 2 }}>
                <Grid item xs={12} sm={6}>
                  <Box display="flex" alignItems="center" gap={1}>
                    <LocationIcon fontSize="small" color="action" />
                    <Typography variant="body2">{getCityName(driver.cityId) || driver.cityName} • {driver.address || driver.fullAddress || 'No address'}</Typography>
                  </Box>
                </Grid>
                <Grid item xs={12} sm={6}>
                  <Box display="flex" alignItems="center" gap={1}>
                    <EmailIcon fontSize="small" color="action" />
                    <Typography variant="body2">{driver.email || 'No email'}</Typography>
                  </Box>
                </Grid>
                <Grid item xs={12} sm={6}>
                  <Box display="flex" alignItems="center" gap={1}>
                    <PhoneIcon fontSize="small" color="action" />
                    <Typography variant="body2">{driver.phoneNumber || 'No phone'}</Typography>
                  </Box>
                </Grid>
                <Grid item xs={12} sm={6}>
                  <Box display="flex" alignItems="center" gap={1}>
                    <CarIcon fontSize="small" color="action" />
                    <Typography variant="body2">{driver.vehicleTypeName || 'Unknown Vehicle Type'}</Typography>
                  </Box>
                </Grid>
                <Grid item xs={12}>
                  <Typography variant="body2">
                    Applied: {
                      (driver.submissionDate && new Date(driver.submissionDate).toLocaleDateString()) ||
                      (driver.createdAt && new Date(driver.createdAt).toLocaleDateString()) ||
                      (driver.submittedAt && new Date(driver.submittedAt).toLocaleDateString()) ||
                      'Unknown'
                    }
                  </Typography>
                </Grid>
              </Grid>

              <Box display="flex" alignItems="center" gap={2}>
                <Typography variant="body2" color="text.secondary">
                  Documents: {approvedDocsCount}/{documentsCount} approved
                </Typography>
              </Box>
            </Box>

            <Box display="flex" flexDirection="column" gap={1}>
              <Button
                startIcon={<ViewIcon />}
                onClick={() => { setSelectedDriver(driver); setDetailsOpen(true); }}
                size="small"
              >
                View Details
              </Button>
              
              {driver.status === 'pending' && (
                <>
                  <Button
                    startIcon={<ApproveIcon />}
                    color="success"
                    onClick={() => handleDriverAction(driver, 'approve')}
                    disabled={actionLoading}
                    size="small"
                  >
                    Approve
                  </Button>
                  <Button
                    startIcon={<RejectIcon />}
                    color="error"
                    onClick={() => handleDriverAction(driver, 'reject')}
                    disabled={actionLoading}
                    size="small"
                  >
                    Reject
                  </Button>
                </>
              )}
            </Box>
          </Box>
        </CardContent>
      </Card>
    );
  };

  // Helper function to get document icons
  const getDocumentIcon = (docType) => {
    switch (docType) {
      case 'driverImage': return <PersonIcon />;
      case 'licenseFront': return <AssignmentIcon />;
      case 'licenseBack': return <AssignmentIcon />;
      case 'licenseDocument': return <DescriptionIcon />;
      case 'vehicleInsurance': return <SecurityIcon />;
      case 'vehicleRegistration': return <AssignmentIcon />;
      default: return <DescriptionIcon />;
    }
  };

  const renderDocumentCard = (driver, docType, title, description = 'Document verification', required = true) => {
    const url = getDocumentUrl(driver, docType);
    const status = getDocumentStatus(driver, docType);
    const rejectionReason = driver.documentVerification?.[docType]?.rejectionReason || 
                           driver[`${docType}RejectionReason`];
    
    // Determine if driver is already approved - if so, all docs should show as approved
    const isDriverApproved = driver.status === 'approved';
    const displayStatus = isDriverApproved ? 'approved' : status;

    return (
      <Grid item xs={12} md={6} key={docType}>
        <Card 
          variant="outlined" 
          sx={{ 
            height: '100%',
            opacity: !url ? 0.7 : 1,
            border: displayStatus === 'approved' ? 2 : 1,
            borderColor: displayStatus === 'approved' ? 'success.main' : 
                        displayStatus === 'rejected' ? 'error.main' : 'divider'
          }}
        >
          <CardHeader
            avatar={
              <Avatar sx={{ 
                bgcolor: displayStatus === 'approved' ? 'success.main' : 
                        displayStatus === 'rejected' ? 'error.main' : 'grey.400' 
              }}>
                {getDocumentIcon(docType)}
              </Avatar>
            }
            title={
              <Box display="flex" alignItems="center" gap={1}>
                <Typography variant="subtitle1">{title}</Typography>
                {required && displayStatus !== 'approved' && !isDriverApproved && (
                  <Chip label="Required" size="small" color="warning" />
                )}
                {displayStatus === 'approved' && (
                  <Chip label="Verified" size="small" color="success" />
                )}
              </Box>
            }
            subheader={description}
            action={
              <Chip 
                label={displayStatus ? displayStatus.charAt(0).toUpperCase() + displayStatus.slice(1) : 'Not Submitted'} 
                color={getStatusColor(displayStatus)} 
                icon={getStatusIcon(displayStatus)}
                variant="filled"
                size="small"
              />
            }
          />
          
          {url && (
            <CardMedia
              component="img"
              height="120"
              image={url}
              alt={title}
              sx={{ 
                objectFit: 'cover',
                cursor: 'pointer',
                '&:hover': { opacity: 0.8 }
              }}
              onClick={() => viewDocument(url)}
            />
          )}
          
          <CardContent>
            {!url ? (
              <Alert severity="warning" size="small">
                Document not submitted
              </Alert>
            ) : (
              <Box>
                {displayStatus === 'approved' && isDriverApproved && (
                  <Alert severity="success" size="small" sx={{ mb: 1 }}>
                    <Typography variant="caption" component="span">
                      <strong>Document Verified:</strong> This document has been approved as part of the driver verification.
                    </Typography>
                  </Alert>
                )}
                
                {rejectionReason && displayStatus === 'rejected' && (
                  <Alert severity="error" size="small" sx={{ mb: 1 }}>
                    <Typography variant="caption" component="span">
                      <strong>Rejection Reason:</strong> {rejectionReason}
                    </Typography>
                  </Alert>
                )}
                
                <Box display="flex" justifyContent="space-between" alignItems="center" mt={1}>
                  <Button
                    size="small"
                    startIcon={<ViewIcon />}
                    onClick={() => viewDocument(url)}
                  >
                    View Full Size
                  </Button>
                </Box>
              </Box>
            )}
          </CardContent>
          
          {url && displayStatus === 'pending' && !isDriverApproved && (
            <CardActions>
              <Button 
                size="small"
                color="success"
                startIcon={<CheckIcon />}
                onClick={() => handleDocumentAction(driver, docType, 'approved')}
                disabled={actionLoading}
              >
                Approve
              </Button>
              <Button 
                size="small"
                color="error"
                startIcon={<ErrorIcon />}
                onClick={() => handleDocumentAction(driver, docType, 'reject')}
                disabled={actionLoading}
              >
                Reject
              </Button>
            </CardActions>
          )}
          
          {displayStatus === 'approved' && (
            <CardActions>
              <Box display="flex" alignItems="center" gap={1} px={1}>
                <CheckIcon color="success" fontSize="small" />
                <Typography variant="caption" component="span" color="success.main">
                  Document verified and approved
                </Typography>
              </Box>
            </CardActions>
          )}
        </Card>
      </Grid>
    );
  };

  const renderEnhancedDocumentCard = (docType, title, description, required) => {
    const url = getDocumentUrl(selectedDriver, docType);
    const status = getDocumentStatus(selectedDriver, docType);
    const rejectionReason = selectedDriver.documentVerification?.[docType]?.rejectionReason || 
                           selectedDriver[`${docType}RejectionReason`];
    
    // Determine if driver is already approved - if so, all docs should show as approved
    const isDriverApproved = selectedDriver.status === 'approved';
    const displayStatus = isDriverApproved ? 'approved' : status;

    return (
      <Grid item xs={12} md={6} key={docType}>
        <Card 
          variant="outlined" 
          sx={{ 
            height: '100%',
            opacity: !url && !required ? 0.7 : 1,
            border: displayStatus === 'approved' ? 2 : 1,
            borderColor: displayStatus === 'approved' ? 'success.main' : 
                        displayStatus === 'rejected' ? 'error.main' : 'divider'
          }}
        >
          <CardHeader
            avatar={
              <Avatar sx={{ 
                bgcolor: displayStatus === 'approved' ? 'success.main' : 
                        displayStatus === 'rejected' ? 'error.main' : 
                        !url ? 'grey.300' : 'primary.main' 
              }}>
                {getDocumentIcon(docType)}
              </Avatar>
            }
            title={
              <Box display="flex" alignItems="center" gap={1}>
                <Typography variant="subtitle1" fontWeight="medium">
                  {title}
                </Typography>
                {required && (
                  <Chip 
                    label="Required" 
                    size="small" 
                    color="warning" 
                    variant="outlined"
                  />
                )}
                {displayStatus === 'approved' && (
                  <Chip 
                    label="Verified" 
                    size="small" 
                    color="success" 
                    icon={<CheckIcon />}
                  />
                )}
              </Box>
            }
            subheader={description}
            action={
              <Chip 
                label={displayStatus ? displayStatus.charAt(0).toUpperCase() + displayStatus.slice(1) : 'Not Submitted'} 
                color={getStatusColor(displayStatus)} 
                icon={getStatusIcon(displayStatus)}
                variant="filled"
                size="small"
              />
            }
          />
          
          {url ? (
            <CardMedia
              component="img"
              height="140"
              image={url}
              alt={title}
              sx={{ 
                objectFit: 'cover',
                cursor: 'pointer',
                '&:hover': { 
                  opacity: 0.9,
                  transform: 'scale(1.02)',
                  transition: 'all 0.2s ease-in-out'
                }
              }}
              onClick={() => viewDocument(url, title)}
            />
          ) : (
            <Box 
              sx={{ 
                height: 140, 
                display: 'flex', 
                alignItems: 'center', 
                justifyContent: 'center',
                bgcolor: 'grey.50',
                color: 'text.secondary'
              }}
            >
              <Box textAlign="center">
                <ImageIcon sx={{ fontSize: 48, opacity: 0.3 }} />
                <Typography variant="body2" mt={1}>
                  No document uploaded
                </Typography>
              </Box>
            </Box>
          )}
          
          <CardContent>
            {!url && required && (
              <Alert severity="warning" size="small" sx={{ mb: 2 }}>
                <Typography variant="caption" component="span">
                  <strong>Required Document:</strong> This document must be submitted for verification.
                </Typography>
              </Alert>
            )}
            
            {!url && !required && (
              <Alert severity="info" size="small" sx={{ mb: 2 }}>
                <Typography variant="caption" component="span">
                  <strong>Optional Document:</strong> Not submitted.
                </Typography>
              </Alert>
            )}
            
            {displayStatus === 'approved' && isDriverApproved && (
              <Alert severity="success" size="small" sx={{ mb: 2 }}>
                <Typography variant="caption" component="span">
                  <strong>Document Verified:</strong> This document has been approved as part of the driver verification.
                </Typography>
              </Alert>
            )}
            
            {rejectionReason && displayStatus === 'rejected' && (
              <Alert severity="error" size="small" sx={{ mb: 2 }}>
                <Typography variant="caption" component="span">
                  <strong>Rejection Reason:</strong> {rejectionReason}
                </Typography>
              </Alert>
            )}
            
            {url && (
              <Box display="flex" justifyContent="space-between" alignItems="center">
                <Button
                  size="small"
                  startIcon={<ViewIcon />}
                  onClick={() => viewDocument(url, title)}
                  variant="outlined"
                >
                  View Full Size
                </Button>
                <Button
                  size="small"
                  startIcon={<DownloadIcon />}
                  onClick={() => window.open(url, '_blank')}
                  variant="text"
                >
                  Download
                </Button>
              </Box>
            )}
          </CardContent>
          
          {url && displayStatus === 'pending' && !isDriverApproved && (
            <CardActions sx={{ justifyContent: 'space-between', px: 2, py: 1.5 }}>
              <Button 
                size="small"
                color="success"
                startIcon={<CheckIcon />}
                onClick={(e) => { e.preventDefault(); e.stopPropagation(); handleDocumentAction(selectedDriver, docType, 'approved'); }}
                disabled={actionLoading}
                variant="contained"
                sx={{ minWidth: 100 }}
                type="button"
              >
                Approve
              </Button>
              <Button 
                size="small"
                color="error"
                startIcon={<ErrorIcon />}
                onClick={(e) => { e.preventDefault(); e.stopPropagation(); handleDocumentAction(selectedDriver, docType, 'reject'); }}
                disabled={actionLoading}
                variant="outlined"
                sx={{ minWidth: 100 }}
                type="button"
              >
                Reject
              </Button>
            </CardActions>
          )}
          
          {displayStatus === 'approved' && (
            <CardActions sx={{ px: 2, py: 1.5 }}>
              <Box display="flex" alignItems="center" gap={1} width="100%">
                <CheckIcon color="success" fontSize="small" />
                <Typography variant="caption" component="span" color="success.main" fontWeight="medium">
                  Document verified and approved
                </Typography>
              </Box>
            </CardActions>
          )}
        </Card>
      </Grid>
    );
  };

  const renderDocumentListItem = (docType, title, description, required) => {
    const url = getDocumentUrl(selectedDriver, docType);
    const status = getDocumentStatus(selectedDriver, docType);
    const rejectionReason = selectedDriver.documentVerification?.[docType]?.rejectionReason || 
                           selectedDriver[`${docType}RejectionReason`];
    
    // Determine if driver is already approved - if so, all docs should show as approved
    const isDriverApproved = selectedDriver.status === 'approved';
    const displayStatus = isDriverApproved ? 'approved' : status;
    
    const isApproved = displayStatus === 'approved';
    const isPending = displayStatus === 'pending' || !displayStatus;
    const isRejected = displayStatus === 'rejected';

    return (
      <TableRow 
        key={docType}
        sx={{ 
          backgroundColor: isApproved ? 'success.50' : isPending ? 'warning.50' : 'error.50',
          '&:hover': { 
            backgroundColor: isApproved ? 'success.100' : isPending ? 'warning.100' : 'error.100' 
          }
        }}
      >
        <TableCell>
          <Box display="flex" alignItems="center" gap={2}>
            <Avatar sx={{ 
              bgcolor: isApproved ? 'success.main' : isPending ? 'warning.main' : 'error.main',
              width: 32, 
              height: 32
            }}>
              {getDocumentIcon(docType)}
            </Avatar>
            <Box>
              <Typography variant="body2" fontWeight="bold">
                {title}
              </Typography>
              <Typography variant="caption" component="span" color="text.secondary">
                {description}
              </Typography>
              {rejectionReason && isRejected && (
                <Typography variant="caption" component="span" color="error.main" display="block" sx={{ mt: 0.5 }}>
                  <strong>Reason:</strong> {rejectionReason}
                </Typography>
              )}
            </Box>
          </Box>
        </TableCell>
        <TableCell>
          <Chip 
            label={isApproved ? 'Approved' : isPending ? 'Pending' : 'Rejected'} 
            color={isApproved ? 'success' : isPending ? 'warning' : 'error'}
            size="small"
            icon={isApproved ? <CheckIcon /> : isPending ? <AccessTimeIcon /> : <ErrorIcon />}
          />
        </TableCell>
        <TableCell>
          <Chip 
            label={required ? 'Required' : 'Optional'} 
            variant="outlined"
            size="small" 
            color={required ? (isApproved ? 'success' : 'error') : 'default'}
          />
        </TableCell>
        <TableCell align="center">
          <Box display="flex" gap={1} justifyContent="center" alignItems="center">
            <Button
              variant="outlined"
              size="small"
              startIcon={<VisibilityIcon />}
              onClick={() => viewDocument(url, title)}
            >
              View Document
            </Button>
            <Button
              variant="text"
              size="small"
              startIcon={<DownloadIcon />}
              onClick={() => window.open(url, '_blank')}
            >
              Download
            </Button>
            {isPending && !isDriverApproved && (
              <>
                <Button
                  variant="contained"
                  color="success"
                  size="small"
                  startIcon={<CheckIcon />}
                  onClick={() => handleDocumentApprovalWithClose(selectedDriver, docType, 'approved')}
                  disabled={actionLoading}
                >
                  Approve
                </Button>
                <Button
                  variant="outlined"
                  color="error"
                  size="small"
                  startIcon={<ErrorIcon />}
                  onClick={() => handleDocumentAction(selectedDriver, docType, 'reject')}
                  disabled={actionLoading}
                >
                  Reject
                </Button>
              </>
            )}
          </Box>
        </TableCell>
      </TableRow>
    );
  };

  const calculateVerificationCompletion = (driver) => {
    // Define all possible document types (both new and legacy)
    const allDocTypes = [
      // New mobile app documents (mandatory)
      'driverImage', 'licenseFront', 'licenseBack', 'vehicleInsurance', 'vehicleRegistration',
      // Legacy documents (for backward compatibility)  
      'profileImage', 'licenseImage', 'idImage'
    ];
    
    // Find which documents this driver actually has
    const availableDocuments = allDocTypes.filter(docType => getDocumentUrl(driver, docType));
    
    // If no documents found, return 0
    if (availableDocuments.length === 0) return 0;
    
    // Calculate how many of the available documents are approved
    const approvedDocuments = availableDocuments.filter(docType => {
      const status = getDocumentStatus(driver, docType);
      return status === 'approved';
    });
    
    // Calculate percentage based on approved vs available documents
    const completionPercentage = (approvedDocuments.length / availableDocuments.length) * 100;
    
    return Math.round(completionPercentage);
  };

  const renderDriverDetails = () => {
    if (!selectedDriver) return null;

    const completionPercentage = calculateVerificationCompletion(selectedDriver);
    const isApproved = selectedDriver.status === 'approved';

    return (
      <Dialog open={detailsOpen} onClose={() => setDetailsOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle sx={{ pb: 0 }}>
          <Box display="flex" alignItems="center" gap={2} mb={2}>
            <Avatar sx={{ 
              bgcolor: isApproved ? 'success.main' : 
                      selectedDriver.status === 'rejected' ? 'error.main' : 'primary.main',
              width: 48, 
              height: 48 
            }}>
              <PersonIcon />
            </Avatar>
            <Box flex={1}>
              <Typography variant="h5" fontWeight="bold">
                {selectedDriver.fullName || selectedDriver.name || 'Unknown Driver'}
              </Typography>
              <Box display="flex" alignItems="center" gap={2} mt={1}>
                <Chip 
                  label={isApproved ? 'approved' : selectedDriver.status || 'pending'} 
                  color={getStatusColor(selectedDriver.status)} 
                  icon={getStatusIcon(selectedDriver.status)}
                  size="medium"
                />
                <Chip 
                  label={`${completionPercentage}% Complete`}
                  variant="outlined"
                  size="small"
                />
                <Typography variant="body2" color="text.secondary">
                  Submitted: {selectedDriver.createdAt ? 
                    new Date(selectedDriver.createdAt).toLocaleDateString() : 
                    selectedDriver.submissionDate ? 
                    new Date(selectedDriver.submissionDate).toLocaleDateString() :
                    'Unknown'
                  }
                </Typography>
              </Box>
            </Box>
            <IconButton onClick={() => setDetailsOpen(false)} size="large">
              <CloseIcon />
            </IconButton>
          </Box>
          
          {/* Progress Bar */}
          <Box sx={{ width: '100%', mb: 2 }}>
            <Box display="flex" alignItems="center" gap={1} mb={1}>
              <Typography variant="body2" color="text.secondary">
                Verification Progress
              </Typography>
              <Typography variant="body2" color="primary" fontWeight="medium">
                {completionPercentage}%
              </Typography>
            </Box>
            <Box sx={{ 
              height: 6, 
              bgcolor: 'grey.200', 
              borderRadius: 3,
              overflow: 'hidden'
            }}>
              <Box sx={{ 
                height: '100%',
                width: `${completionPercentage}%`,
                bgcolor: isApproved ? 'success.main' : 
                        selectedDriver.status === 'rejected' ? 'error.main' : 'primary.main',
                transition: 'width 0.3s ease',
                borderRadius: 3
              }} />
            </Box>
          </Box>
        </DialogTitle>
        
        <DialogContent>
          <Tabs value={tabValue} onChange={(e, v) => { setTabValue(v); if (v === 5) loadAuditLogs(selectedDriver.id); }}>
            <Tab label="Driver Info" />
            <Tab label="Documents" />
            <Tab label="Contact Info" />
            <Tab label="Vehicle Info" />
            <Tab label="Verification History" />
            <Tab label="Audit Logs" />
          </Tabs>

          {tabValue === 0 && (
            <Box sx={{ mt: 2 }}>
              <Grid container spacing={3}>
                {/* Personal Information Card */}
                <Grid item xs={12} md={6}>
                  <Card variant="outlined" sx={{ height: 'fit-content' }}>
                    <CardHeader 
                      avatar={<PersonIcon color="primary" />}
                      title="Personal Information"
                      subheader="Basic personal details"
                    />
                    <CardContent>
                      <Grid container spacing={2}>
                        <Grid item xs={12}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              Full Name
                            </Typography>
                            <Typography variant="body1" fontWeight="medium">
                              {selectedDriver.fullName || selectedDriver.name || 
                               (selectedDriver.firstName && selectedDriver.lastName ? 
                                `${selectedDriver.firstName} ${selectedDriver.lastName}` : 'Not provided')}
                            </Typography>
                          </Box>
                        </Grid>
                        
                        <Grid item xs={6}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              Gender
                            </Typography>
                            <Typography variant="body1">
                              {selectedDriver.gender || 'Not provided'}
                            </Typography>
                          </Box>
                        </Grid>
                        
                        <Grid item xs={6}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              Date of Birth
                            </Typography>
                            <Typography variant="body1">
                              {selectedDriver.dateOfBirth ? 
                                new Date(selectedDriver.dateOfBirth).toLocaleDateString() : 
                                'Not provided'}
                            </Typography>
                          </Box>
                        </Grid>
                        
                        <Grid item xs={12}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              NIC Number
                            </Typography>
                            <Typography variant="body1" fontFamily="monospace">
                              {selectedDriver.nicNumber || 'Not provided'}
                            </Typography>
                          </Box>
                        </Grid>
                        
                        <Grid item xs={12}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              City
                            </Typography>
                            <Typography variant="body1">
                              {getCityName(selectedDriver.cityId) || selectedDriver.cityName || 'Not provided'}
                            </Typography>
                          </Box>
                        </Grid>
                      </Grid>
                    </CardContent>
                  </Card>
                </Grid>

                {/* Contact Information Card */}
                <Grid item xs={12} md={6}>
                  <Card variant="outlined" sx={{ height: 'fit-content' }}>
                    <CardHeader 
                      avatar={<PhoneIcon color="primary" />}
                      title="Contact Information"
                      subheader="Phone and email details"
                    />
                    <CardContent>
                      <Grid container spacing={2}>
                        <Grid item xs={12}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              Email Address
                            </Typography>
                            <Typography variant="body1">
                              {selectedDriver.email || 'Not provided'}
                            </Typography>
                          </Box>
                        </Grid>
                        
                        <Grid item xs={12}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              Primary Phone
                            </Typography>
                            <Typography variant="body1" fontFamily="monospace">
                              {selectedDriver.phoneNumber || 'Not provided'}
                            </Typography>
                          </Box>
                        </Grid>
                        
                        <Grid item xs={12}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              Secondary Mobile
                            </Typography>
                            <Typography variant="body1" fontFamily="monospace">
                              {selectedDriver.secondaryMobile || 'Not provided'}
                            </Typography>
                          </Box>
                        </Grid>
                      </Grid>
                    </CardContent>
                  </Card>
                </Grid>

                {/* License Information Card */}
                <Grid item xs={12} md={6}>
                  <Card variant="outlined" sx={{ height: 'fit-content' }}>
                    <CardHeader 
                      avatar={<AssignmentIcon color="primary" />}
                      title="License Information"
                      subheader="Driving license details"
                    />
                    <CardContent>
                      <Grid container spacing={2}>
                        <Grid item xs={12}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              License Number
                            </Typography>
                            <Typography variant="body1" fontFamily="monospace">
                              {selectedDriver.licenseNumber || 'Not provided'}
                            </Typography>
                          </Box>
                        </Grid>
                        
                        <Grid item xs={12}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              License Expiry Date
                            </Typography>
                            <Typography variant="body1">
                              {selectedDriver.licenseHasNoExpiry ? (
                                <Chip label="No Expiry Date" color="success" size="small" />
                              ) : selectedDriver.licenseExpiry ? 
                                new Date(selectedDriver.licenseExpiry).toLocaleDateString() : 
                                'Not provided'}
                            </Typography>
                          </Box>
                        </Grid>
                      </Grid>
                    </CardContent>
                  </Card>
                </Grid>

                {/* Vehicle Ownership & Registration Card */}
                <Grid item xs={12} md={6}>
                  <Card variant="outlined" sx={{ height: 'fit-content' }}>
                    <CardHeader 
                      avatar={<CarIcon color="primary" />}
                      title="Vehicle Ownership & Registration"
                      subheader="Vehicle ownership status and registration date"
                    />
                    <CardContent>
                      <Grid container spacing={2}>
                        <Grid item xs={12}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              Ownership Status
                            </Typography>
                            <Typography variant="body1">
                              {selectedDriver.isVehicleOwner !== undefined ? (
                                <Chip 
                                  label={selectedDriver.isVehicleOwner ? 'Vehicle Owner' : 'Not Vehicle Owner'} 
                                  color={selectedDriver.isVehicleOwner ? 'success' : 'default'} 
                                  size="small" 
                                />
                              ) : 'Not specified'}
                            </Typography>
                          </Box>
                        </Grid>
                        
                        <Grid item xs={12}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              Country
                            </Typography>
                            <Typography variant="body1">
                              {selectedDriver.country || 'Not provided'}
                            </Typography>
                          </Box>
                        </Grid>
                        
                        <Grid item xs={12}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              Registration Date
                            </Typography>
                            <Typography variant="body1">
                              {selectedDriver.createdAt ? 
                                new Date(selectedDriver.createdAt).toLocaleString() : 
                                selectedDriver.submissionDate ? 
                                new Date(selectedDriver.submissionDate).toLocaleString() :
                                'Not available'}
                            </Typography>
                          </Box>
                        </Grid>
                      </Grid>
                    </CardContent>
                  </Card>
                </Grid>
              </Grid>
            </Box>
          )}

          {tabValue === 1 && (
            <Box>
              <Alert severity="info" sx={{ mb: 3 }}>
                <Typography variant="subtitle2" gutterBottom>
                  Document Verification Requirements
                </Typography>
                <Typography variant="body2">
                  All documents must be clear, readable, and match the driver information provided. 
                  Click "View Document" to review each submitted document.
                </Typography>
              </Alert>
              
              <TableContainer component={Paper}>
                <Table>
                  <TableHead>
                    <TableRow>
                      <TableCell><strong>Document Type</strong></TableCell>
                      <TableCell><strong>Status</strong></TableCell>
                      <TableCell><strong>Required</strong></TableCell>
                      <TableCell align="center"><strong>Actions</strong></TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {/* Mandatory Documents */}
                    {getDocumentUrl(selectedDriver, 'driverImage') && renderDocumentListItem('driverImage', 'Driver Photo', 'Driver identification photo (Profile Photo)', true)}
                    {getDocumentUrl(selectedDriver, 'licenseFront') && renderDocumentListItem('licenseFront', 'License (Front)', 'Front side of driving license', true)}
                    {getDocumentUrl(selectedDriver, 'licenseBack') && renderDocumentListItem('licenseBack', 'License (Back)', 'Back side of driving license', true)}
                    {getDocumentUrl(selectedDriver, 'vehicleInsurance') && renderDocumentListItem('vehicleInsurance', 'Vehicle Insurance', 'Vehicle insurance certificate', true)}
                    {getDocumentUrl(selectedDriver, 'vehicleRegistration') && renderDocumentListItem('vehicleRegistration', 'Vehicle Registration', 'Official vehicle registration document', true)}
                    
                    {/* Optional Documents */}
                    {getDocumentUrl(selectedDriver, 'nicFront') && renderDocumentListItem('nicFront', 'NIC (Front)', 'Front side of National Identity Card', false)}
                    {getDocumentUrl(selectedDriver, 'nicBack') && renderDocumentListItem('nicBack', 'NIC (Back)', 'Back side of National Identity Card', false)}
                    {getDocumentUrl(selectedDriver, 'billingProof') && renderDocumentListItem('billingProof', 'Billing Proof', 'Utility bill or bank statement for address verification', false)}
                    {getDocumentUrl(selectedDriver, 'licenseDocument') && renderDocumentListItem('licenseDocument', 'License Document', 'Additional license document if available', false)}
                    
                    {/* Legacy Documents */}
                    {getDocumentUrl(selectedDriver, 'profileImage') && renderDocumentListItem('profileImage', 'Profile Photo (Legacy)', 'Driver profile image', true)}
                    {getDocumentUrl(selectedDriver, 'licenseImage') && renderDocumentListItem('licenseImage', 'Driver License (Legacy)', 'Driver license document', true)}
                    {getDocumentUrl(selectedDriver, 'idImage') && renderDocumentListItem('idImage', 'National ID (Legacy)', 'National identification document', true)}
                  </TableBody>
                </Table>
              </TableContainer>

              {/* Vehicle Photos Section - show if they exist or if there are vehicle image verifications */}
              {(() => {
                const hasVehicleImageUrls = Array.isArray(selectedDriver.vehicleImageUrls) && selectedDriver.vehicleImageUrls.length > 0;
                const hasVehicleImageUrlsObject = selectedDriver.vehicleImageUrls && 
                  typeof selectedDriver.vehicleImageUrls === 'object' && 
                  Object.values(selectedDriver.vehicleImageUrls).some(url => url);
                const hasVehicleImages = Array.isArray(selectedDriver.vehicleImages) && selectedDriver.vehicleImages.length > 0;
                const hasVehicleImageVerification = selectedDriver.vehicleImageVerification && 
                  Object.keys(selectedDriver.vehicleImageVerification).length > 0;
                
                return (hasVehicleImageUrls || hasVehicleImageUrlsObject || hasVehicleImages || hasVehicleImageVerification);
              })() && (
                <Box sx={{ mt: 4 }}>
                  <Typography variant="h6" gutterBottom sx={{ mb: 3, fontWeight: 'bold', color: 'primary.main' }}>
                    Vehicle Photos
                  </Typography>
                  <Alert severity="info" sx={{ mb: 3 }}>
                    <Typography variant="body2">
                      {(() => {
                        let vehicleImageUrlsCount = 0;
                        
                        if (Array.isArray(selectedDriver.vehicleImageUrls)) {
                          vehicleImageUrlsCount = selectedDriver.vehicleImageUrls.length;
                        } else if (selectedDriver.vehicleImageUrls && typeof selectedDriver.vehicleImageUrls === 'object') {
                          // Count non-null values in the object
                          vehicleImageUrlsCount = Object.values(selectedDriver.vehicleImageUrls).filter(url => url).length;
                        }
                        
                        const vehicleImagesCount = Array.isArray(selectedDriver.vehicleImages) ? selectedDriver.vehicleImages.length : 0;
                        const totalCount = Math.max(vehicleImageUrlsCount, vehicleImagesCount);
                        return `${totalCount} of 6 photos uploaded. Minimum 4 required for approval.`;
                      })()}
                    </Typography>
                  </Alert>
                  
                  <TableContainer component={Paper} variant="outlined">
                    <Table size="medium">
                      <TableHead>
                        <TableRow>
                          <TableCell><strong>Vehicle Photo Type</strong></TableCell>
                          <TableCell><strong>Status</strong></TableCell>
                          <TableCell><strong>Required</strong></TableCell>
                          <TableCell align="center"><strong>Actions</strong></TableCell>
                        </TableRow>
                      </TableHead>
                      <TableBody>
                        {(() => {
                          // Handle vehicleImageUrls which can be either array or object
                          let vehiclePhotos = [];
                          
                          if (Array.isArray(selectedDriver.vehicleImageUrls)) {
                            vehiclePhotos = selectedDriver.vehicleImageUrls;
                          } else if (selectedDriver.vehicleImageUrls && typeof selectedDriver.vehicleImageUrls === 'object') {
                            // Convert object with numeric keys to array
                            const urlsObj = selectedDriver.vehicleImageUrls;
                            const maxIndex = Math.max(...Object.keys(urlsObj).map(Number).filter(n => !isNaN(n)));
                            vehiclePhotos = [];
                            for (let i = 0; i <= maxIndex; i++) {
                              if (urlsObj[i]) {
                                vehiclePhotos[i] = urlsObj[i];
                              }
                            }
                          } else if (Array.isArray(selectedDriver.vehicleImages)) {
                            vehiclePhotos = selectedDriver.vehicleImages;
                          }
                          
                          if (vehiclePhotos.length === 0) {
                            return (
                              <TableRow>
                                <TableCell colSpan={4} align="center" sx={{ py: 4 }}>
                                  <Typography variant="body2" color="text.secondary">
                                    No vehicle photos uploaded yet
                                  </Typography>
                                </TableCell>
                              </TableRow>
                            );
                          }
                          
                          return vehiclePhotos.map((imageUrl, index) => {
                          const vehicleStatus = selectedDriver.vehicleImageVerification?.[index]?.status || 'pending';
                          const isDriverApproved = selectedDriver.status === 'approved';
                          const displayStatus = isDriverApproved ? 'approved' : vehicleStatus;
                          
                          const getVehiclePhotoTitle = (index) => {
                            switch (index) {
                              case 0: return 'Front View with Number Plate';
                              case 1: return 'Rear View with Number Plate'; 
                              default: return `Vehicle Photo ${index + 1}`;
                            }
                          };

                          const getVehiclePhotoDescription = (index) => {
                            switch (index) {
                              case 0: return 'Clear front view showing number plate';
                              case 1: return 'Clear rear view showing number plate';
                              default: return 'Additional vehicle photo';
                            }
                          };

                          const isRequired = index < 2; // First two photos are required
                          
                          return (
                            <TableRow key={index} hover>
                              <TableCell>
                                <Box display="flex" alignItems="center" gap={2}>
                                  <Avatar sx={{ 
                                    bgcolor: displayStatus === 'approved' ? 'success.main' : 
                                            displayStatus === 'rejected' ? 'error.main' : 'grey.400',
                                    width: 40, height: 40
                                  }}>
                                    <ImageIcon />
                                  </Avatar>
                                  <Box>
                                    <Typography variant="subtitle1" fontWeight="medium">
                                      {getVehiclePhotoTitle(index)}
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                      {getVehiclePhotoDescription(index)}
                                    </Typography>
                                  </Box>
                                </Box>
                              </TableCell>
                              <TableCell>
                                <Chip 
                                  label={displayStatus ? displayStatus.charAt(0).toUpperCase() + displayStatus.slice(1) : 'Pending'} 
                                  color={getStatusColor(displayStatus)} 
                                  icon={getStatusIcon(displayStatus)}
                                  size="small"
                                />
                              </TableCell>
                              <TableCell>
                                <Chip 
                                  label={isRequired ? "Required" : "Optional"} 
                                  color={isRequired ? "warning" : "default"} 
                                  size="small"
                                  variant="outlined"
                                />
                              </TableCell>
                              <TableCell align="center">
                                <Box display="flex" gap={1} justifyContent="center" alignItems="center">
                                  <Button
                                    size="small"
                                    startIcon={<ViewIcon />}
                                    onClick={() => viewDocument(imageUrl, getVehiclePhotoTitle(index))}
                                    variant="outlined"
                                    color="primary"
                                  >
                                    View
                                  </Button>
                                  <Button
                                    size="small"
                                    startIcon={<DownloadIcon />}
                                    onClick={() => window.open(imageUrl, '_blank')}
                                    variant="text"
                                    color="primary"
                                  >
                                    Download
                                  </Button>
                                  {displayStatus === 'pending' && !isDriverApproved && (
                                    <>
                                      <Button 
                                        size="small"
                                        color="success"
                                        startIcon={<CheckIcon />}
                                        onClick={() => handleVehicleImageAction(selectedDriver, index, 'approved')}
                                        disabled={actionLoading}
                                        variant="contained"
                                        sx={{ ml: 1 }}
                                      >
                                        APPROVE
                                      </Button>
                                      <Button 
                                        size="small"
                                        color="error"
                                        startIcon={<CloseIcon />}
                                        onClick={() => handleVehicleImageAction(selectedDriver, index, 'reject')}
                                        disabled={actionLoading}
                                        variant="outlined"
                                        sx={{ ml: 1 }}
                                      >
                                        REJECT
                                      </Button>
                                    </>
                                  )}
                                </Box>
                              </TableCell>
                            </TableRow>
                          );
                          });
                        })()}
                      </TableBody>
                    </Table>
                  </TableContainer>
                </Box>
              )}
            </Box>
          )}

          {tabValue === 2 && (
            <Box sx={{ mt: 2 }}>
              <Alert severity="info" sx={{ mb: 3 }}>
                <Typography variant="subtitle2" gutterBottom>
                  Contact Verification Status
                </Typography>
                <Typography variant="body2">
                  Phone number verification is mandatory and handled automatically in the mobile app. Phone must be verified before driver approval.
                </Typography>
              </Alert>
              
              <Grid container spacing={3}>
                <Grid item xs={12} md={6}>
                  <Card variant="outlined">
                    <CardHeader
                      avatar={
                        <Avatar sx={{ bgcolor: (() => {
                          const phoneStatus = getPhoneVerificationStatus(selectedDriver);
                          return phoneStatus.isVerified ? 'success.main' : 'grey.400';
                        })() }}>
                          <PhoneIcon />
                        </Avatar>
                      }
                      title="Phone Verification"
                      subheader="Primary contact number"
                    />
                    <CardContent>
                      <Box mb={2}>
                        <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                          Phone Number
                        </Typography>
                        <Typography variant="body1" fontWeight="medium">
                          {selectedDriver.phoneNumber || 'Not provided'}
                        </Typography>
                      </Box>
                      <Box mb={2}>
                        <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                          Verification Status
                        </Typography>
                        {(() => {
                          const phoneStatus = getPhoneVerificationStatus(selectedDriver);
                          return (
                            <Chip 
                              label={phoneStatus.isVerified ? 'Verified' : 'Not Verified'}
                              color={phoneStatus.isVerified ? 'success' : 'default'}
                              icon={phoneStatus.isVerified ? <CheckIcon /> : <ErrorIcon />}
                            />
                          );
                        })()}
                      </Box>
                      {(() => {
                        const phoneStatus = getPhoneVerificationStatus(selectedDriver);
                        if (!phoneStatus.hasPhoneNumber) {
                          return (
                            <Box mb={1}>
                              <Alert severity="error" sx={{ mb: 2 }}>
                                <Typography variant="body2">
                                  <strong>Phone number is required for driver verification.</strong> Driver must provide a phone number to proceed.
                                </Typography>
                              </Alert>
                            </Box>
                          );
                        } else if (phoneStatus.isVerified) {
                          return (
                            <Box mb={1}>
                              <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                Verified Via
                              </Typography>
                              <Typography variant="body2">
                                {phoneStatus.source === 'registration' ? 'Verified during registration' :
                                 phoneStatus.source === 'otp' ? 'Verified via OTP' :
                                 phoneStatus.source === 'firebase_auth_registration' ? 'Firebase Auth (Registration)' :
                                 'Manual Verification'}
                              </Typography>
                            </Box>
                          );
                        } else if (phoneStatus.needsManualVerification) {
                          return (
                            <Box mb={1}>
                              <Alert severity="warning" sx={{ mb: 2 }}>
                                <Typography variant="body2">
                                  Phone number needs verification. Use the button below to send an OTP to the driver's phone.
                                </Typography>
                              </Alert>
                              <Button
                                variant="contained"
                                color="primary"
                                startIcon={<PhoneIcon />}
                                size="small"
                                onClick={() => handleTriggerPhoneVerification(selectedDriver)}
                                disabled={verificationLoading}
                              >
                                Send Verification OTP
                              </Button>
                            </Box>
                          );
                        }
                        return null;
                      })()}
                    </CardContent>
                  </Card>
                </Grid>
                
                <Grid item xs={12} md={6}>
                  <Card variant="outlined">
                    <CardHeader
                      avatar={
                        <Avatar sx={{ bgcolor: (() => {
                          const emailStatus = getEmailVerificationStatus(selectedDriver);
                          return emailStatus.isVerified ? 'success.main' : 'grey.400';
                        })() }}>
                          <EmailIcon />
                        </Avatar>
                      }
                      title="Email Verification"
                      subheader="Primary contact email"
                    />
                    <CardContent>
                      <Box mb={2}>
                        <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                          Email Address
                        </Typography>
                        <Typography variant="body1" fontWeight="medium">
                          {selectedDriver.email || 'Not provided'}
                        </Typography>
                      </Box>
                      <Box mb={2}>
                        <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                          Verification Status
                        </Typography>
                        {(() => {
                          const emailStatus = getEmailVerificationStatus(selectedDriver);
                          return (
                            <Chip 
                              label={emailStatus.isVerified ? 'Verified' : 'Not Verified'}
                              color={emailStatus.isVerified ? 'success' : 'default'}
                              icon={emailStatus.isVerified ? <CheckIcon /> : <ErrorIcon />}
                            />
                          );
                        })()}
                      </Box>
                      {(() => {
                        const emailStatus = getEmailVerificationStatus(selectedDriver);
                        if (!emailStatus.hasEmail) {
                          return (
                            <Alert severity="error" sx={{ mb: 1 }}>
                              <Typography variant="body2">
                                <strong>Email address is required for driver verification.</strong> Driver must provide an email address.
                              </Typography>
                            </Alert>
                          );
                        } else if (emailStatus.isVerified) {
                          return (
                            <Box mb={1}>
                              <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                Verified Via
                              </Typography>
                              <Typography variant="body2">
                                {emailStatus.source === 'registration' ? 'Verified during registration' :
                                 emailStatus.source === 'firebase_auth_registration' ? 'Firebase Auth (Registration)' :
                                 'Manual Verification'}
                              </Typography>
                            </Box>
                          );
                        } else {
                          return (
                            <Alert severity="warning" sx={{ mb: 1 }}>
                              <Typography variant="body2">
                                Email address needs verification. Driver should verify this email in their account settings.
                              </Typography>
                            </Alert>
                          );
                        }
                      })()}
                    </CardContent>
                  </Card>
                </Grid>
              </Grid>
            </Box>
          )}

          {tabValue === 3 && (
            <Box sx={{ mt: 2 }}>
              <Grid container spacing={3}>
                {/* Vehicle Details Card */}
                <Grid item xs={12} md={6}>
                  <Card variant="outlined" sx={{ height: 'fit-content' }}>
                    <CardHeader
                      avatar={
                        <Avatar sx={{ bgcolor: 'primary.main', width: 48, height: 48 }}>
                          {getVehicleIcon(selectedDriver.vehicleTypeName)}
                        </Avatar>
                      }
                      title="Vehicle Details"
                      subheader="Primary vehicle information"
                    />
                    <CardContent>
                      <Grid container spacing={2}>
                        <Grid item xs={12}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              Vehicle Type
                            </Typography>
                            <Typography variant="body1" fontWeight="medium">
                              {selectedDriver.vehicleType ? (
                                <Box display="flex" alignItems="center" gap={1}>
                                  <Chip 
                                    label={selectedDriver.vehicleTypeName || 'Unknown'} 
                                    color="primary" 
                                    size="small" 
                                    variant="outlined"
                                  />
                                </Box>
                              ) : (
                                <Typography color="text.secondary" variant="body2">Not specified</Typography>
                              )}
                            </Typography>
                          </Box>
                        </Grid>
                        
                        <Grid item xs={6}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              Make
                            </Typography>
                            <Typography variant="body1" fontWeight="medium">
                              {selectedDriver.vehicleMake || 'Not provided'}
                            </Typography>
                          </Box>
                        </Grid>
                        
                        <Grid item xs={6}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              Model
                            </Typography>
                            <Typography variant="body1">
                              {selectedDriver.vehicleModel || 'Not provided'}
                            </Typography>
                          </Box>
                        </Grid>
                        
                        <Grid item xs={6}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              Year
                            </Typography>
                            <Typography variant="body1">
                              {selectedDriver.vehicleYear || 'Not provided'}
                            </Typography>
                          </Box>
                        </Grid>
                        
                        <Grid item xs={6}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              Color
                            </Typography>
                            <Typography variant="body1">
                              {selectedDriver.vehicleColor || 'Not provided'}
                            </Typography>
                          </Box>
                        </Grid>
                      </Grid>
                    </CardContent>
                  </Card>
                </Grid>

                {/* License Plate & Registration Card */}
                <Grid item xs={12} md={6}>
                  <Card variant="outlined" sx={{ height: 'fit-content' }}>
                    <CardHeader
                      avatar={<AssignmentIcon color="primary" />}
                      title="Registration Details"
                      subheader="License plate and registration info"
                    />
                    <CardContent>
                      <Grid container spacing={2}>
                        <Grid item xs={12}>
                          <Box mb={2}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                              License Plate Number
                            </Typography>
                            <Typography variant="h6" fontFamily="monospace" color="primary">
                              {selectedDriver.vehicleNumber || 'Not provided'}
                            </Typography>
                          </Box>
                        </Grid>
                        
                        {selectedDriver.vehicleRegistration && (
                          <Grid item xs={12}>
                            <Box mb={2}>
                              <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                Registration Status
                              </Typography>
                              <Chip 
                                label="Registration Document Submitted" 
                                color="success" 
                                size="small" 
                                icon={<CheckIcon />}
                              />
                            </Box>
                          </Grid>
                        )}
                      </Grid>
                    </CardContent>
                  </Card>
                </Grid>

                {/* Vehicle Images Section */}
                <Grid item xs={12}>
                  <Card variant="outlined">
                    <CardHeader
                      avatar={<ImageIcon color="primary" />}
                      title="Vehicle Photos"
                      subheader="Submitted vehicle images for verification"
                    />
                    <CardContent>
                      {Array.isArray(selectedDriver.vehicleImages) && selectedDriver.vehicleImages.length > 0 ? (
                        <Grid container spacing={2}>
                          {selectedDriver.vehicleImages.map((imageUrl, index) => {
                            if (!imageUrl) return null;
                            
                            const status = getVehicleImageStatus(selectedDriver, index);
                            const isDriverApproved = selectedDriver.status === 'approved';
                            const displayStatus = isDriverApproved ? 'approved' : status;
                            
                            return (
                              <Grid item xs={12} sm={6} md={4} key={index}>
                                <Card 
                                  variant="outlined" 
                                  sx={{ 
                                    height: '100%',
                                    border: displayStatus === 'approved' ? 2 : 1,
                                    borderColor: displayStatus === 'approved' ? 'success.main' : 
                                                displayStatus === 'rejected' ? 'error.main' : 'divider'
                                  }}
                                >
                                  <Box sx={{ position: 'relative' }}>
                                    <CardMedia
                                      component="img"
                                      height="120"
                                      image={imageUrl}
                                      alt={`Vehicle Image ${index + 1}`}
                                      sx={{ 
                                        objectFit: 'cover',
                                        cursor: 'pointer',
                                        '&:hover': { 
                                          opacity: 0.9
                                        }
                                      }}
                                      onClick={() => viewDocument(imageUrl, `Vehicle Photo ${index + 1}`)}
                                    />
                                    <Box 
                                      sx={{ 
                                        position: 'absolute',
                                        top: 8,
                                        right: 8,
                                        bgcolor: 'rgba(0,0,0,0.7)',
                                        borderRadius: 1,
                                        p: 0.5
                                      }}
                                    >
                                      <Chip 
                                        label={displayStatus ? displayStatus.charAt(0).toUpperCase() + displayStatus.slice(1) : 'Pending'} 
                                        color={getStatusColor(displayStatus)} 
                                        size="small"
                                        sx={{ fontSize: '0.7rem', height: 20 }}
                                      />
                                    </Box>
                                  </Box>
                                  
                                  <CardContent sx={{ p: 1.5, '&:last-child': { pb: 1.5 } }}>
                                    <Typography variant="caption" color="text.secondary" display="block" gutterBottom>
                                      Vehicle Photo {index + 1}
                                    </Typography>
                                    <Box display="flex" gap={1} flexWrap="wrap">
                                      <Button
                                        size="small"
                                        startIcon={<ViewIcon />}
                                        onClick={() => viewDocument(imageUrl, `Vehicle Photo ${index + 1}`)}
                                        variant="outlined"
                                        sx={{ fontSize: '0.7rem', py: 0.5 }}
                                      >
                                        View
                                      </Button>
                                      <Button
                                        size="small"
                                        startIcon={<DownloadIcon />}
                                        onClick={() => window.open(imageUrl, '_blank')}
                                        variant="text"
                                        sx={{ fontSize: '0.7rem', py: 0.5 }}
                                      >
                                        Download
                                      </Button>
                                      {displayStatus !== 'approved' && (
                                        <Button
                                          size="small"
                                          color="success"
                                          startIcon={<ApproveIcon />}
                                          onClick={() => handleVehicleImageAction(selectedDriver, index, 'approved')}
                                          variant="contained"
                                          sx={{ fontSize: '0.7rem', py: 0.5 }}
                                          disabled={actionLoading}
                                        >
                                          Approve
                                        </Button>
                                      )}
                                      {displayStatus !== 'rejected' && (
                                        <Button
                                          size="small"
                                          color="error"
                                          startIcon={<RejectIcon />}
                                          onClick={() => handleVehicleImageAction(selectedDriver, index, 'reject')}
                                          variant="outlined"
                                          sx={{ fontSize: '0.7rem', py: 0.5 }}
                                          disabled={actionLoading}
                                        >
                                          Reject
                                        </Button>
                                      )}
                                    </Box>
                                  </CardContent>
                                </Card>
                              </Grid>
                            );
                          })}
                        </Grid>
                      ) : (
                        <Box 
                          sx={{ 
                            display: 'flex', 
                            alignItems: 'center', 
                            justifyContent: 'center',
                            py: 4,
                            bgcolor: 'grey.50',
                            borderRadius: 1
                          }}
                        >
                          <Box textAlign="center">
                            <ImageIcon sx={{ fontSize: 48, opacity: 0.3, color: 'text.secondary' }} />
                            <Typography variant="body2" color="text.secondary" mt={1}>
                              No vehicle photos submitted

                            </Typography>
                          </Box>
                        </Box>
                      )}
                    </CardContent>
                  </Card>
                </Grid>
              </Grid>
            </Box>
          )}

          {tabValue === 4 && (
            <Box sx={{ mt: 2 }}>
              <Card variant="outlined">
                <CardHeader
                  avatar={<TimeIcon color="primary" />}
                  title="Verification Timeline"
                  subheader="Driver verification process history"
                />
                <CardContent>
                  <Box>
                    <Box display="flex" alignItems="center" gap={2} mb={2} p={2} 
                         sx={{ bgcolor: 'primary.50', borderRadius: 1 }}>
                      <Avatar sx={{ bgcolor: 'primary.main', width: 32, height: 32 }}>
                        <CheckIcon fontSize="small" />
                      </Avatar>
                      <Box flex={1}>
                        <Typography variant="subtitle2" fontWeight="medium">
                          Application Submitted
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                          {selectedDriver.createdAt ? 
                            new Date(selectedDriver.createdAt).toLocaleString() : 
                            selectedDriver.submissionDate ? 
                            new Date(selectedDriver.submissionDate).toLocaleString() :
                            'Unknown'
                          }
                        </Typography>
                      </Box>
                      <Chip label="Completed" color="primary" size="small" />
                    </Box>

                    {selectedDriver.status === 'approved' && (
                      <Box display="flex" alignItems="center" gap={2} mb={2} p={2} 
                           sx={{ bgcolor: 'success.50', borderRadius: 1 }}>
                        <Avatar sx={{ bgcolor: 'success.main', width: 32, height: 32 }}>
                          <VerifiedIcon fontSize="small" />
                        </Avatar>
                        <Box flex={1}>
                          <Typography variant="subtitle2" fontWeight="medium">
                            Driver Approved
                          </Typography>
                          <Typography variant="body2" color="text.secondary">
                            Driver verification completed successfully
                          </Typography>
                        </Box>
                        <Chip label="Approved" color="success" size="small" />
                      </Box>
                    )}

                    {selectedDriver.status === 'rejected' && (
                      <Box display="flex" alignItems="center" gap={2} mb={2} p={2} 
                           sx={{ bgcolor: 'error.50', borderRadius: 1 }}>
                        <Avatar sx={{ bgcolor: 'error.main', width: 32, height: 32 }}>
                          <ErrorIcon fontSize="small" />
                        </Avatar>
                        <Box flex={1}>
                          <Typography variant="subtitle2" fontWeight="medium">
                            Driver Rejected
                          </Typography>
                          <Typography variant="body2" color="text.secondary">
                            {selectedDriver.rejectionReason || 'Verification requirements not met'}
                          </Typography>
                        </Box>
                        <Chip label="Rejected" color="error" size="small" />
                      </Box>
                    )}

                    {selectedDriver.status === 'pending' && (
                      <Box display="flex" alignItems="center" gap={2} mb={2} p={2} 
                           sx={{ bgcolor: 'warning.50', borderRadius: 1 }}>
                        <Avatar sx={{ bgcolor: 'warning.main', width: 32, height: 32 }}>
                          <PendingIcon fontSize="small" />
                        </Avatar>
                        <Box flex={1}>
                          <Typography variant="subtitle2" fontWeight="medium">
                            Pending Review
                          </Typography>
                          <Typography variant="body2" color="text.secondary">
                            Awaiting admin verification and approval
                          </Typography>
                        </Box>
                        <Chip label="Pending" color="warning" size="small" />
                      </Box>
                    )}
                  </Box>
                </CardContent>
              </Card>
            </Box>
          )}
          {tabValue === 5 && (
            <Box sx={{ mt:2 }}>
              <Card variant="outlined">
                <CardHeader title="Audit Logs" subheader="Document & image replacement history" />
                <CardContent>
                  {auditLoading && <Typography variant="body2">Loading logs...</Typography>}
                  {auditError && <Alert severity="error">{auditError}</Alert>}
                  {!auditLoading && !auditError && auditLogs.length === 0 && (
                    <Alert severity="info">No audit events recorded.</Alert>
                  )}
                  {!auditLoading && auditLogs.length > 0 && (
                    <Box sx={{ maxHeight: 300, overflowY: 'auto' }}>
                      <table style={{ width:'100%', borderCollapse:'collapse', fontSize:12 }}>
                        <thead>
                          <tr style={{ textAlign:'left', background:'#f5f5f5' }}>
                            <th style={{ padding:4 }}>Time</th>
                            <th style={{ padding:4 }}>Type</th>
                            <th style={{ padding:4 }}>Action</th>
                            <th style={{ padding:4 }}>Old URL</th>
                            <th style={{ padding:4 }}>New URL</th>
                          </tr>
                        </thead>
                        <tbody>
                          {auditLogs.map(log => (
                            <tr key={log.id} style={{ borderBottom:'1px solid #eee' }}>
                              <td style={{ padding:4 }}>{new Date(log.created_at).toLocaleString()}</td>
                              <td style={{ padding:4 }}>{log.document_type}</td>
                              <td style={{ padding:4 }}>{log.action}</td>
                              <td style={{ padding:4, maxWidth:140, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }} title={log.old_url}>{log.old_url || '-'}</td>
                              <td style={{ padding:4, maxWidth:140, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }} title={log.new_url}>{log.new_url || '-'}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </Box>
                  )}
                  <Box mt={2}>
                    <Button size="small" onClick={()=>loadAuditLogs(selectedDriver.id)}>Refresh Logs</Button>
                  </Box>
                </CardContent>
              </Card>
            </Box>
          )}
        </DialogContent>

        <DialogActions>
          <Button onClick={() => setDetailsOpen(false)}>Close</Button>
          {selectedDriver.status === 'pending' && (() => {
            const requiredDocs = ['driverImage','licenseFront','licenseBack','nicFront','nicBack','vehicleRegistration','vehicleInsurance'];
            const allDocsApproved = requiredDocs.every(d => getDocumentStatus(selectedDriver, d) === 'approved');
            // vehicle photos requirement: at least 4 approved or pending if none required
            let approvedVehiclePhotos = 0;
            if (selectedDriver.vehicleImageVerification && typeof selectedDriver.vehicleImageVerification === 'object') {
              approvedVehiclePhotos = Object.values(selectedDriver.vehicleImageVerification).filter(v => v && v.status === 'approved').length;
            }
            const vehiclePhotoOk = approvedVehiclePhotos >= 4 || !selectedDriver.vehicleImageVerification;
            
            return (
              <>
                <Button 
                  color="error"
                  onClick={() => handleDriverAction(selectedDriver, 'reject')}
                  disabled={actionLoading}
                >
                  Reject Driver
                </Button>
                <Button 
                  color="success" 
                  variant={allDocsApproved && vehiclePhotoOk ? "contained" : "outlined"}
                  onClick={() => handleDriverAction(selectedDriver, 'approve')}
                  disabled={actionLoading}
                >
                  {allDocsApproved && vehiclePhotoOk ? "All Docs Approved - Approve Now" : "Approve Driver"}
                </Button>
              </>
            );
          })()}
        </DialogActions>
      </Dialog>
    );
  };

  if (loading) {
    return (
      <Container maxWidth="lg" sx={{ mt: 4 }}>
        <Box display="flex" justifyContent="center" alignItems="center" minHeight="200px">
          <CircularProgress />
        </Box>
      </Container>
    );
  }

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Typography variant="h4" gutterBottom>
        Driver Verification
      </Typography>
      
      <Typography variant="subtitle1" color="text.secondary" gutterBottom>
        Manage driver verifications for {adminData?.country || 'all countries'}
      </Typography>

      <Box display="flex" gap={2} mb={3}>
        <FormControl size="small" sx={{ minWidth: 120 }}>
          <InputLabel>Status Filter</InputLabel>
          <Select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            label="Status Filter"
          >
            <MenuItem value="all">All Status</MenuItem>
            <MenuItem value="pending">Pending</MenuItem>
            <MenuItem value="approved">Approved</MenuItem>
            <MenuItem value="rejected">Rejected</MenuItem>
          </Select>
        </FormControl>
        
        <Button variant="outlined" onClick={loadDrivers}>
          Refresh
        </Button>
      </Box>

      {drivers.length === 0 ? (
        <Alert severity="info">
          No driver verifications found for the selected filters.
        </Alert>
      ) : (
        drivers.map(renderDriverCard)
      )}

      {renderDriverDetails()}

      {/* Rejection Dialog */}
      <Dialog open={rejectionDialog.open} onClose={() => setRejectionDialog({ open: false, target: null, type: '' })}>
        <DialogTitle>
          Reject {rejectionDialog.type === 'document' ? 'Document' : rejectionDialog.type === 'vehicleImage' ? 'Vehicle Image' : 'Driver'}
        </DialogTitle>
        <DialogContent>
          <Typography variant="body2" sx={{ mb: 2 }}>
            Please provide a reason for rejection:
          </Typography>
          <TextField
            fullWidth
            multiline
            rows={3}
            value={rejectionReason}
            onChange={(e) => setRejectionReason(e.target.value)}
            placeholder="Enter rejection reason..."
            variant="outlined"
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setRejectionDialog({ open: false, target: null, type: '' })}>
            Cancel
          </Button>
          <Button 
            color="error" 
            variant="contained"
            onClick={handleRejection}
            disabled={actionLoading || !rejectionReason.trim()}
          >
            Confirm Rejection
          </Button>
        </DialogActions>
      </Dialog>

      {/* Fullscreen Image Dialog */}
      <Dialog 
        open={fullscreenImage.open} 
        onClose={() => setFullscreenImage({ open: false, url: '', title: '' })}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>
          <Box display="flex" justifyContent="space-between" alignItems="center">
            <Typography variant="h6">{fullscreenImage.title}</Typography>
            <IconButton 
              onClick={() => setFullscreenImage({ open: false, url: '', title: '' })}
              size="large"
            >
              <CloseIcon />
            </IconButton>
          </Box>
        </DialogTitle>
        <DialogContent sx={{ p: 0 }}>
          <Box sx={{ textAlign: 'center' }}>
            <img 
              src={fullscreenImage.url} 
              alt={fullscreenImage.title}
              style={{ 
                width: '100%', 
                height: 'auto', 
                maxHeight: '70vh',
                objectFit: 'contain'
              }}
            />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button 
            startIcon={<DownloadIcon />}
            onClick={() => window.open(fullscreenImage.url, '_blank')}
          >
            Download
          </Button>
          <Button 
            onClick={() => setFullscreenImage({ open: false, url: '', title: '' })}
          >
            Close
          </Button>
        </DialogActions>
      </Dialog>

      {/* Phone Verification Dialog */}
      <Dialog 
        open={phoneVerificationDialog.open} 
        onClose={() => {
          setPhoneVerificationDialog({ open: false, driver: null, step: 'send' });
          setOtpCode('');
        }}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>
          <Box display="flex" alignItems="center" gap={1}>
            <PhoneIcon color="primary" />
            <Typography variant="h6">Phone Verification</Typography>
          </Box>
        </DialogTitle>
        <DialogContent>
          {phoneVerificationDialog.step === 'send' ? (
            <Box>
              <Typography variant="body1" gutterBottom>
                Send an OTP verification code to the driver's phone number:
              </Typography>
              <Typography variant="h6" color="primary" sx={{ mb: 2 }}>
                {phoneVerificationDialog.driver?.phoneNumber}
              </Typography>
              <Alert severity="info" sx={{ mb: 2 }}>
                The driver will receive a 6-digit OTP code that expires in 10 minutes.
              </Alert>
            </Box>
          ) : (
            <Box>
              <Typography variant="body1" gutterBottom>
                OTP has been sent to: <strong>{phoneVerificationDialog.driver?.phoneNumber}</strong>
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                Please ask the driver for the 6-digit code they received.
              </Typography>
              <TextField
                label="Enter OTP Code"
                value={otpCode}
                onChange={(e) => setOtpCode(e.target.value)}
                fullWidth
                inputProps={{ maxLength: 6 }}
                placeholder="123456"
              />
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button 
            onClick={() => {
              setPhoneVerificationDialog({ open: false, driver: null, step: 'send' });
              setOtpCode('');
            }}
          >
            Cancel
          </Button>
          {phoneVerificationDialog.step === 'send' ? (
            <Button 
              variant="contained"
              onClick={sendPhoneVerificationOTP}
              disabled={verificationLoading}
              startIcon={verificationLoading ? <CircularProgress size={20} /> : <PhoneIcon />}
            >
              Send OTP
            </Button>
          ) : (
            <Button 
              variant="contained"
              onClick={verifyPhoneOTP}
              disabled={verificationLoading || !otpCode.trim()}
              startIcon={verificationLoading ? <CircularProgress size={20} /> : <CheckIcon />}
            >
              Verify OTP
            </Button>
          )}
        </DialogActions>
      </Dialog>

      {/* Notification Snackbar */}
      <Snackbar
        open={notification.open}
        autoHideDuration={6000}
        onClose={() => setNotification({ ...notification, open: false })}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert 
          onClose={() => setNotification({ ...notification, open: false })} 
          severity={notification.severity}
          sx={{ width: '100%' }}
        >
          {notification.message}
        </Alert>
      </Snackbar>
    </Container>
  );
};

export default DriverVerificationEnhanced;
