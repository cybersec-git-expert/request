import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Grid,
  Chip,
  Alert,
  LinearProgress
} from '@mui/material';
import { Add, Edit, Public } from '@mui/icons-material';
import api from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter';

const COUNTRIES = [
  'United States', 'Canada', 'United Kingdom', 'Australia', 'Germany', 
  'France', 'Japan', 'South Korea', 'India', 'Brazil', 'Mexico', 'Other'
];

const DOCUMENT_TYPES = [
  { value: 'privacy_policy', label: 'Privacy Policy' },
  { value: 'terms_of_service', label: 'Terms of Service' },
  { value: 'user_agreement', label: 'User Agreement' },
  { value: 'data_protection', label: 'Data Protection Notice' }
];

const PrivacyTerms = () => {
  const { adminData, isSuperAdmin, userCountry } = useCountryFilter();
  
  // Initialize state first
  const [documents, setDocuments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openDialog, setOpenDialog] = useState(false);
  const [editingDoc, setEditingDoc] = useState(null);
  const [formData, setFormData] = useState({
    type: '',
    country: '',
    title: '',
    content: '',
    version: '1.0'
  });
  
  // Check permissions
  const hasLegalPermission = isSuperAdmin || adminData?.permissions?.legalDocumentManagement;

  useEffect(() => {
    if (hasLegalPermission) {
      loadDocuments();
    }
  }, [userCountry, hasLegalPermission]);

  if (!hasLegalPermission) {
    return (
      <Box sx={{ p: 3 }}>
        <Alert severity="error">
          You don't have permission to access Legal Documents Management. Please contact your administrator.
        </Alert>
      </Box>
    );
  }

  const loadDocuments = async () => {
    try {
      setLoading(true);
      const params = {};
      if (!isSuperAdmin && userCountry) params.country = userCountry;
      const { data } = await api.get('/legal-documents', { params });
      const docsData = Array.isArray(data) ? data : data?.items || [];
      setDocuments([...docsData].sort((a, b) => {
        if (a.country !== b.country) return a.country.localeCompare(b.country);
        return a.type.localeCompare(b.type);
      }));
    } catch (error) {
      console.error('Error loading documents:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleOpenDialog = (doc = null) => {
    if (doc) {
      setEditingDoc(doc.id);
      setFormData({
        type: doc.type,
        country: doc.country,
        title: doc.title,
        content: doc.content,
        version: doc.version
      });
    } else {
      setEditingDoc(null);
      setFormData({
        type: '',
        country: isSuperAdmin ? '' : userCountry || '',
        title: '',
        content: '',
        version: '1.0'
      });
    }
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setEditingDoc(null);
    setFormData({
      type: '',
      country: '',
      title: '',
      content: '',
      version: '1.0'
    });
  };

  const handleSave = async () => {
    try {
      const docData = {
        ...formData,
        updatedBy: adminData.email
      };
      if (editingDoc) {
        await api.put(`/legal-documents/${editingDoc}`, docData);
      } else {
        await api.post('/legal-documents', {
          ...docData,
          createdBy: adminData.email
        });
      }
      handleCloseDialog();
      loadDocuments();
    } catch (error) {
      console.error('Error saving document:', error);
    }
  };

  const getDocumentTypeLabel = (type) => {
    return DOCUMENT_TYPES.find(dt => dt.value === type)?.label || type;
  };

  const groupedDocuments = documents.reduce((acc, doc) => {
    if (!acc[doc.country]) {
      acc[doc.country] = [];
    }
    acc[doc.country].push(doc);
    return acc;
  }, {});

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4">Privacy & Terms Management</Typography>
        <Button
          variant="contained"
          startIcon={<Add />}
          onClick={() => handleOpenDialog()}
        >
          Add Document
        </Button>
      </Box>

      {!isSuperAdmin && (
        <Alert severity="info" sx={{ mb: 3 }}>
          You can only manage legal documents for {adminData?.country}. 
          Users in your country will see these documents in the mobile app.
        </Alert>
      )}

      {loading && <LinearProgress sx={{ mb: 2 }} />}

      <Grid container spacing={3}>
        {Object.entries(groupedDocuments).map(([country, countryDocs]) => (
          <Grid item xs={12} key={country}>
            <Card>
              <CardContent>
                <Box display="flex" alignItems="center" gap={2} mb={2}>
                  <Public />
                  <Typography variant="h6">{country}</Typography>
                  <Chip label={`${countryDocs.length} documents`} size="small" />
                </Box>
                
                <Grid container spacing={2}>
                  {countryDocs.map((doc) => (
                    <Grid item xs={12} md={6} key={doc.id}>
                      <Card variant="outlined">
                        <CardContent>
                          <Box display="flex" justifyContent="between" alignItems="start" mb={2}>
                            <Box>
                              <Typography variant="h6" gutterBottom>
                                {doc.title}
                              </Typography>
                              <Chip 
                                label={getDocumentTypeLabel(doc.type)} 
                                size="small" 
                                color="primary" 
                                sx={{ mb: 1 }}
                              />
                              <Typography variant="body2" color="text.secondary" display="block">
                                Version {doc.version}
                              </Typography>
                            </Box>
                            <Button
                              size="small"
                              startIcon={<Edit />}
                              onClick={() => handleOpenDialog(doc)}
                            >
                              Edit
                            </Button>
                          </Box>
                          <Typography variant="body2" color="text.secondary">
                            {doc.content.length > 200 
                              ? `${doc.content.substring(0, 200)}...` 
                              : doc.content
                            }
                          </Typography>
                        </CardContent>
                      </Card>
                    </Grid>
                  ))}
                </Grid>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>

      {documents.length === 0 && !loading && (
        <Box textAlign="center" py={4}>
          <Typography variant="h6" color="text.secondary" gutterBottom>
            No legal documents found
          </Typography>
          <Typography variant="body2" color="text.secondary" mb={2}>
            Create privacy policies and terms of service for your {isSuperAdmin ? 'countries' : 'country'}
          </Typography>
          <Button variant="contained" startIcon={<Add />} onClick={() => handleOpenDialog()}>
            Create First Document
          </Button>
        </Box>
      )}

      <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="md" fullWidth>
        <DialogTitle>
          {editingDoc ? 'Edit Legal Document' : 'Add Legal Document'}
        </DialogTitle>
        <DialogContent>
          <Box display="flex" flexDirection="column" gap={3} pt={2}>
            <FormControl fullWidth>
              <InputLabel>Document Type</InputLabel>
              <Select
                value={formData.type}
                onChange={(e) => setFormData(prev => ({ ...prev, type: e.target.value }))}
              >
                {DOCUMENT_TYPES.map(type => (
                  <MenuItem key={type.value} value={type.value}>
                    {type.label}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>

            <FormControl fullWidth>
              <InputLabel>Country</InputLabel>
              <Select
                value={formData.country}
                onChange={(e) => setFormData(prev => ({ ...prev, country: e.target.value }))}
                disabled={!isSuperAdmin}
              >
                {COUNTRIES.map(country => (
                  <MenuItem key={country} value={country}>
                    {country}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>

            <TextField
              fullWidth
              label="Title"
              value={formData.title}
              onChange={(e) => setFormData(prev => ({ ...prev, title: e.target.value }))}
            />

            <TextField
              fullWidth
              label="Version"
              value={formData.version}
              onChange={(e) => setFormData(prev => ({ ...prev, version: e.target.value }))}
              placeholder="1.0"
            />

            <TextField
              fullWidth
              multiline
              rows={12}
              label="Content"
              value={formData.content}
              onChange={(e) => setFormData(prev => ({ ...prev, content: e.target.value }))}
              placeholder="Enter the full text of the legal document..."
            />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog}>Cancel</Button>
          <Button 
            onClick={handleSave} 
            variant="contained"
            disabled={!formData.type || !formData.country || !formData.title || !formData.content}
          >
            {editingDoc ? 'Update' : 'Create'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default PrivacyTerms;
