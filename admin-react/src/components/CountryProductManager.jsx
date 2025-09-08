import React, { useState, useEffect } from 'react';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  Typography,
  Box,
  Grid,
  Card,
  CardContent,
  Switch,
  FormControlLabel,
  TextField,
  Alert,
  Chip,
  Accordion,
  AccordionSummary,
  AccordionDetails,
  ImageList,
  ImageListItem,
  IconButton
} from '@mui/material';
import {
  ExpandMore,
  PhotoCamera,
  Close,
  Sync,
  Warning
} from '@mui/icons-material';
import api from '../services/apiClient';

const CountryProductManager = ({ open, onClose, masterProduct }) => {
  const [countryVariations, setCountryVariations] = useState([]);
  const [loading, setLoading] = useState(false);
  const [syncing, setSyncing] = useState(false);

  useEffect(() => {
    if (open && masterProduct) {
      loadCountryVariations();
    }
  }, [open, masterProduct]);

  const loadCountryVariations = async () => {
    try {
      setLoading(true);
      const response = await api.get(`/product-sync/country-variations/${masterProduct.id}`);
      setCountryVariations(response.data.data || []);
    } catch (error) {
      console.error('Error loading country variations:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSyncChanges = async (syncFields = ['name', 'category', 'images']) => {
    try {
      setSyncing(true);
      await api.post(`/product-sync/sync-master-product/${masterProduct.id}`, {
        syncFields
      });
      
      // Show success message
      alert('✅ Successfully synced changes to all countries!');
      loadCountryVariations(); // Reload to see updated data
      
    } catch (error) {
      console.error('Error syncing changes:', error);
      alert('❌ Error syncing changes: ' + error.message);
    } finally {
      setSyncing(false);
    }
  };

  const handleCountryOverride = async (countryCode, overrideData) => {
    try {
      await api.post('/product-sync/country-override', {
        masterProductId: masterProduct.id,
        countryCode,
        ...overrideData
      });
      
      alert(`✅ Country override saved for ${countryCode}`);
      loadCountryVariations();
      
    } catch (error) {
      console.error('Error saving country override:', error);
      alert('❌ Error saving override: ' + error.message);
    }
  };

  if (!masterProduct) return null;

  return (
    <Dialog open={open} onClose={onClose} maxWidth="lg" fullWidth>
      <DialogTitle>
        <Box display="flex" justifyContent="space-between" alignItems="center">
          <Typography variant="h6">
            Country Product Management: {masterProduct.name}
          </Typography>
          <Button
            variant="outlined"
            startIcon={<Sync />}
            onClick={() => handleSyncChanges()}
            disabled={syncing}
          >
            {syncing ? 'Syncing...' : 'Sync All Changes'}
          </Button>
        </Box>
      </DialogTitle>
      
      <DialogContent>
        <Box mb={3}>
          <Alert severity="info" sx={{ mb: 2 }}>
            <Typography variant="subtitle2" gutterBottom>
              🌍 Master Product Changes Impact
            </Typography>
            <Typography variant="body2">
              When you update the master product (images, category, etc.), these changes can be automatically 
              synced to all countries, or you can set country-specific overrides.
            </Typography>
          </Alert>

          {/* Sync Options */}
          <Card sx={{ mb: 3 }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                🔄 Sync Options
              </Typography>
              <Grid container spacing={2}>
                <Grid item xs={12} md={4}>
                  <Button
                    fullWidth
                    variant="outlined"
                    onClick={() => handleSyncChanges(['name'])}
                    disabled={syncing}
                  >
                    Sync Name Only
                  </Button>
                </Grid>
                <Grid item xs={12} md={4}>
                  <Button
                    fullWidth
                    variant="outlined"
                    onClick={() => handleSyncChanges(['category'])}
                    disabled={syncing}
                  >
                    Sync Category Only
                  </Button>
                </Grid>
                <Grid item xs={12} md={4}>
                  <Button
                    fullWidth
                    variant="outlined"
                    onClick={() => handleSyncChanges(['images'])}
                    disabled={syncing}
                  >
                    Sync Images Only
                  </Button>
                </Grid>
              </Grid>
            </CardContent>
          </Card>

          {/* Master Product Info */}
          <Card sx={{ mb: 3 }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                📋 Current Master Product Data
              </Typography>
              <Grid container spacing={2}>
                <Grid item xs={12} md={6}>
                  <Typography variant="body2" color="text.secondary">Name:</Typography>
                  <Typography variant="body1">{masterProduct.name}</Typography>
                </Grid>
                <Grid item xs={12} md={6}>
                  <Typography variant="body2" color="text.secondary">Category:</Typography>
                  <Typography variant="body1">{masterProduct.categoryId || 'Not set'}</Typography>
                </Grid>
                <Grid item xs={12}>
                  <Typography variant="body2" color="text.secondary">Images:</Typography>
                  <Box>
                    {masterProduct.images && masterProduct.images.length > 0 ? (
                      <ImageList sx={{ height: 100 }} cols={4} rowHeight={80}>
                        {masterProduct.images.map((image, index) => (
                          <ImageListItem key={index}>
                            <img src={image} alt={`Master ${index + 1}`} style={{ objectFit: 'cover' }} />
                          </ImageListItem>
                        ))}
                      </ImageList>
                    ) : (
                      <Typography variant="body2" color="text.secondary">No images</Typography>
                    )}
                  </Box>
                </Grid>
              </Grid>
            </CardContent>
          </Card>

          {/* Country Variations */}
          <Typography variant="h6" gutterBottom>
            🌏 Country Variations ({countryVariations.length})
          </Typography>

          {loading ? (
            <Typography>Loading country variations...</Typography>
          ) : (
            countryVariations.map((variation) => (
              <Accordion key={variation.id} sx={{ mb: 1 }}>
                <AccordionSummary expandIcon={<ExpandMore />}>
                  <Box display="flex" alignItems="center" width="100%">
                    <Typography variant="subtitle1" sx={{ flexGrow: 1 }}>
                      {variation.country_code} - {variation.country_name}
                    </Typography>
                    <Box display="flex" gap={1}>
                      <Chip 
                        label={variation.is_active ? 'Active' : 'Inactive'} 
                        color={variation.is_active ? 'success' : 'default'}
                        size="small"
                      />
                      {variation.override_master && (
                        <Chip 
                          label="Custom Override" 
                          color="warning"
                          size="small"
                          icon={<Warning />}
                        />
                      )}
                    </Box>
                  </Box>
                </AccordionSummary>
                <AccordionDetails>
                  <CountryVariationDetails 
                    variation={variation}
                    masterProduct={masterProduct}
                    onSave={(overrideData) => handleCountryOverride(variation.country_code, overrideData)}
                  />
                </AccordionDetails>
              </Accordion>
            ))
          )}
        </Box>
      </DialogContent>
      
      <DialogActions>
        <Button onClick={onClose}>Close</Button>
      </DialogActions>
    </Dialog>
  );
};

// Component for managing individual country variations
const CountryVariationDetails = ({ variation, masterProduct, onSave }) => {
  const [customImages, setCustomImages] = useState(variation.custom_images || []);
  const [useCustomImages, setUseCustomImages] = useState(!!variation.custom_images?.length);
  const [isActive, setIsActive] = useState(variation.is_active);

  const handleImageUpload = async (event) => {
    const files = Array.from(event.target.files || []);
    if (files.length === 0) return;

    try {
      const urls = [];
      for (let i = 0; i < files.length; i++) {
        const f = files[i];
        const formData = new FormData();
        formData.append('file', f);
        formData.append('uploadType', 'country-products');
        formData.append('country', variation.country_code);
        formData.append('imageIndex', String(i));
        
        const { data } = await api.post('/s3/upload', formData, {
          headers: { 'Content-Type': 'multipart/form-data' }
        });
        
        if (data?.success && data?.url) {
          urls.push(data.url);
        }
      }
      setCustomImages(prev => [...prev, ...urls]);
    } catch (error) {
      console.error('Error uploading country-specific images:', error);
      alert('Error uploading images: ' + error.message);
    }
  };

  const removeCustomImage = (index) => {
    setCustomImages(prev => prev.filter((_, i) => i !== index));
  };

  const handleSave = () => {
    onSave({
      customImages: useCustomImages ? customImages : null,
      isActive
    });
  };

  return (
    <Box>
      <Grid container spacing={3}>
        <Grid item xs={12}>
          <FormControlLabel
            control={
              <Switch
                checked={isActive}
                onChange={(e) => setIsActive(e.target.checked)}
              />
            }
            label={`Product ${isActive ? 'Active' : 'Inactive'} in ${variation.country_code}`}
          />
        </Grid>

        <Grid item xs={12}>
          <FormControlLabel
            control={
              <Switch
                checked={useCustomImages}
                onChange={(e) => setUseCustomImages(e.target.checked)}
              />
            }
            label="Use custom images for this country"
          />
        </Grid>

        {useCustomImages && (
          <Grid item xs={12}>
            <Typography variant="subtitle2" gutterBottom>
              Country-Specific Images
            </Typography>
            <input
              accept="image/*"
              style={{ display: 'none' }}
              id={`country-image-upload-${variation.country_code}`}
              multiple
              type="file"
              onChange={handleImageUpload}
            />
            <label htmlFor={`country-image-upload-${variation.country_code}`}>
              <Button
                variant="outlined"
                component="span"
                startIcon={<PhotoCamera />}
                sx={{ mb: 2 }}
              >
                Upload Country Images
              </Button>
            </label>

            {customImages.length > 0 && (
              <ImageList sx={{ height: 160 }} cols={4} rowHeight={120}>
                {customImages.map((image, index) => (
                  <ImageListItem key={index}>
                    <img src={image} alt={`Country ${index + 1}`} style={{ objectFit: 'cover' }} />
                    <IconButton
                      sx={{
                        position: 'absolute',
                        top: 5,
                        right: 5,
                        bgcolor: 'rgba(255,255,255,0.8)'
                      }}
                      size="small"
                      onClick={() => removeCustomImage(index)}
                    >
                      <Close fontSize="small" />
                    </IconButton>
                  </ImageListItem>
                ))}
              </ImageList>
            )}
          </Grid>
        )}

        <Grid item xs={12}>
          <Alert severity="info">
            <Typography variant="body2">
              <strong>Current Settings:</strong><br />
              • Using {useCustomImages ? 'custom' : 'master'} images<br />
              • Product {isActive ? 'enabled' : 'disabled'} in {variation.country_code}
            </Typography>
          </Alert>
        </Grid>

        <Grid item xs={12}>
          <Button variant="contained" onClick={handleSave}>
            Save Country Settings
          </Button>
        </Grid>
      </Grid>
    </Box>
  );
};

export default CountryProductManager;
