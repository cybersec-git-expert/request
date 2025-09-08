import React, { useEffect, useRef, useState } from 'react';
import { Box, Typography, Button, Grid, Card, CardMedia, CardContent, TextField, Dialog, DialogTitle, DialogContent, DialogActions, FormControlLabel, Switch, Alert, CircularProgress, Stack } from '@mui/material';
import api, { API_BASE_URL } from '../services/apiClient';
import useCountryFilter from '../hooks/useCountryFilter';

export default function BannersModule() {
  const { adminData, isSuperAdmin, userCountry } = useCountryFilter();
  const [loading, setLoading] = useState(false);
  const [banners, setBanners] = useState([]);
  const [error, setError] = useState('');
  const [dialogOpen, setDialogOpen] = useState(false);
  const [form, setForm] = useState({ id: null, title: '', subtitle: '', imageUrl: '', linkUrl: '', active: true, priority: 0 });
  const [uploading, setUploading] = useState(false);
  const [signedImageUrl, setSignedImageUrl] = useState(''); // For signed URL preview
  const fileInputRef = useRef(null);

  const country = isSuperAdmin ? null : (adminData?.country || userCountry || 'LK');

  const load = async () => {
    try {
      setLoading(true);
      setError('');
      const params = {};
      if (country) params.country = country;
  const res = await api.get('/banners', { params });
  const list = Array.isArray(res.data) ? res.data : (res.data?.data || []);
  setBanners(list);
    } catch (e) {
      console.error('Failed to load banners', e);
      setError('Failed to load banners');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load();   }, [country]);

  const openCreate = () => { setForm({ id: null, title: '', subtitle: '', imageUrl: '', linkUrl: '', active: true, priority: 0 }); setDialogOpen(true); };
  const openEdit = (b) => { setForm({ id: b.id, title: b.title || '', subtitle: b.subtitle || '', imageUrl: b.imageUrl || b.image || '', linkUrl: b.linkUrl || b.link || '', active: b.active !== false, priority: b.priority || 0 }); setDialogOpen(true); };
  const closeDialog = () => setDialogOpen(false);

  // Generate signed URL for S3 images
  const getSignedImageUrl = async (url) => {
    if (!url) return '';
    try {
      // Check if it's an S3 URL
      if (/^https?:\/\/.*\.s3\..*amazonaws\.com/i.test(url)) {
        const response = await api.post('/s3/signed-url', { url, expiresIn: 3600 });
        if (response.data?.success && response.data?.signedUrl) {
          return response.data.signedUrl;
        }
      }
      return url; // Return original URL if not S3 or if signing fails
    } catch (error) {
      console.error('Failed to generate signed URL:', error);
      return url; // Fallback to original URL
    }
  };

  // Update signed URL when form imageUrl changes
  useEffect(() => {
    if (form.imageUrl) {
      getSignedImageUrl(form.imageUrl).then(setSignedImageUrl);
    } else {
      setSignedImageUrl('');
    }
  }, [form.imageUrl]);

  const resolveImage = (url) => {
    if (!url) return url;
    try {
      // If it's already a full S3 URL, we'll use signed URL for display
      if (/^https?:\/\/.*\.s3\..*amazonaws\.com/i.test(url)) {
        return signedImageUrl || url; // Use signed URL if available
      }
      // If it's a full HTTP URL, check if it needs localhost replacement
      if (/^https?:\/\//i.test(url)) {
        // Replace localhost with API base
        return url.replace(/^https?:\/\/localhost(?::\d+)?/i, API_BASE_URL);
      }
      if (url.startsWith('/')) return API_BASE_URL + url;
      // bare filename => uploads/images
      return `${API_BASE_URL}/uploads/images/${url}`;
    } catch {
      return url;
    }
  };

  const save = async () => {
    try {
      setLoading(true);
      setError('');
      const payload = { title: form.title, subtitle: form.subtitle, imageUrl: form.imageUrl, linkUrl: form.linkUrl, active: form.active, priority: Number(form.priority) || 0 };
      if (!isSuperAdmin) payload.country = country;
      if (form.id) {
        await api.put(`/banners/${form.id}`, payload);
      } else {
        await api.post('/banners', payload);
      }
      setDialogOpen(false);
      await load();
    } catch (e) {
      console.error('Failed to save banner', e);
      setError(e.response?.data?.message || 'Failed to save banner');
    } finally {
      setLoading(false);
    }
  };

  const remove = async (b) => {
    if (!window.confirm('Delete this banner?')) return;
    try {
      setLoading(true);
      await api.delete(`/banners/${b.id || b._id}`);
      await load();
    } catch (e) {
      console.error('Failed to delete banner', e);
      setError('Failed to delete banner');
    } finally {
      setLoading(false);
    }
  };

  const onClickUpload = () => fileInputRef.current?.click();

  const onFileSelected = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      setUploading(true);
      setError('');
      const fd = new FormData();
      fd.append('file', file); // S3 upload expects 'file' field
      fd.append('uploadType', 'banners'); // Specify upload type for S3 organization
      
      // Try S3 upload first (preferred method)
      try {
        const res = await api.post('/s3/upload', fd, {
          headers: { 'Content-Type': 'multipart/form-data' },
        });
        if (res.data?.success && res.data?.url) {
          setForm((f) => ({ ...f, imageUrl: res.data.url }));
          return;
        }
      } catch (s3Error) {
        console.warn('S3 upload failed, trying local upload as fallback:', s3Error);
      }
      
      // Fallback to local upload if S3 fails
      fd.delete('uploadType'); // Remove S3-specific field
      fd.append('image', file); // Local upload expects 'image' field
      const res = await api.post('/upload', fd, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      const url = res.data?.url;
      if (url) {
        setForm((f) => ({ ...f, imageUrl: url }));
      } else {
        setError('Upload succeeded but no URL was returned');
      }
    } catch (err) {
      console.error('Upload failed', err);
      setError(err.response?.data?.error || 'Failed to upload image');
    } finally {
      setUploading(false);
      // reset input to allow re-selecting same file
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
        <Typography variant="h5">{isSuperAdmin ? 'Global Banners' : `Banners (${country})`}</Typography>
        <Button variant="contained" onClick={openCreate}>Add Banner</Button>
      </Box>
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
      {loading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}><CircularProgress /></Box>
      ) : (
        <>
          {banners.length === 0 ? (
            <Alert severity="info">No banners yet. Click "Add Banner" to create one.</Alert>
          ) : (
            <Box
              sx={{
                display: 'grid',
                gap: 2,
                gridTemplateColumns: {
                  xs: '1fr',
                  sm: 'repeat(2, 1fr)',
                  md: 'repeat(3, 1fr)',
                  lg: 'repeat(4, 1fr)'
                }
              }}
            >
              {banners.map((b) => (
                <Box key={b.id || b._id}>
                  <Card>
                    {(b.imageUrl || b.image) && (
                      <CardMedia component="img" height="140" image={resolveImage(b.imageUrl || b.image)} alt={b.title || 'Banner'} />
                    )}
                    <CardContent>
                      <Typography variant="subtitle1" fontWeight={700}>{b.title || 'Untitled'}</Typography>
                      {b.subtitle && <Typography variant="body2" color="text.secondary">{b.subtitle}</Typography>}
                      {b.linkUrl && <Typography variant="caption" color="primary">{b.linkUrl}</Typography>}
                      <Box sx={{ display: 'flex', gap: 1, mt: 1 }}>
                        <Button size="small" onClick={() => openEdit(b)}>Edit</Button>
                        <Button size="small" color="error" onClick={() => remove(b)}>Delete</Button>
                      </Box>
                    </CardContent>
                  </Card>
                </Box>
              ))}
            </Box>
          )}
        </>
      )}

      <Dialog open={dialogOpen} onClose={closeDialog} maxWidth="sm" fullWidth>
        <DialogTitle>{form.id ? 'Edit Banner' : 'Add Banner'}</DialogTitle>
        <DialogContent>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
            <TextField label="Title" value={form.title} onChange={(e)=>setForm({...form, title: e.target.value})} fullWidth />
            <TextField label="Subtitle" value={form.subtitle} onChange={(e)=>setForm({...form, subtitle: e.target.value})} fullWidth />
            <Stack direction="row" spacing={1} alignItems="center">
              <TextField
                label="Image URL"
                value={form.imageUrl}
                onChange={(e)=>setForm({...form, imageUrl: e.target.value})}
                fullWidth
                placeholder="https://..."
                helperText="Recommended: 3:1 ratio (e.g., 1200x400 or 1500x500), JPG/PNG/WEBP under 5MB"
              />
              <input
                type="file"
                accept="image/*"
                ref={fileInputRef}
                style={{ display: 'none' }}
                onChange={onFileSelected}
              />
              <Button onClick={onClickUpload} disabled={uploading} variant="outlined">
                {uploading ? <CircularProgress size={20} /> : 'Upload'}
              </Button>
            </Stack>
            {form.imageUrl && (
              <Card variant="outlined" sx={{ mt: 1 }}>
                <CardMedia
                  component="img"
                  height="120"
                  image={resolveImage(form.imageUrl)}
                  alt="Banner preview"
                />
              </Card>
            )}
            <TextField label="Link URL (optional)" value={form.linkUrl} onChange={(e)=>setForm({...form, linkUrl: e.target.value})} fullWidth placeholder="/price-listings or https://..." />
            <TextField type="number" label="Priority" value={form.priority} onChange={(e)=>setForm({...form, priority: e.target.value})} fullWidth />
            <FormControlLabel control={<Switch checked={form.active} onChange={(e)=>setForm({...form, active: e.target.checked})} />} label="Active" />
            <Typography variant="caption" color="text.secondary">
              Tip: The mobile app displays banners at ~140dp height with BoxFit.cover. Use a wide image with safe margins; avoid important text near edges.
            </Typography>
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={closeDialog}>Cancel</Button>
          <Button variant="contained" onClick={save} disabled={loading}>{loading ? <CircularProgress size={20} /> : 'Save'}</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
