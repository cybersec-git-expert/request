import React, { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Grid,
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
  Chip,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  IconButton,
  Tooltip,
  Alert,
  Switch,
  FormControlLabel,
  Tab,
  Tabs,
  Divider,
  Avatar,
  Badge,
  Accordion,
  AccordionSummary,
  AccordionDetails
} from '@mui/material';
import {
  Add,
  Edit,
  Delete,
  Visibility,
  Check,
  Close,
  Public,
  Language,
  Gavel,
  Article,
  Pending,
  CheckCircle,
  Cancel,
  Preview,
  Publish,
  ExpandMore,
  Info,
  Business,
  Apartment
} from '@mui/icons-material';
import useCountryFilter from '../hooks/useCountryFilter.jsx';
import api from '../services/apiClient';

const CentralizedPagesModule = () => {
  const {
    getFilteredData,
    adminData,
    isSuperAdmin,
    getCountryDisplayName,
    userCountry
  } = useCountryFilter();

  const [pages, setPages] = useState([]);
  const [loading, setLoading] = useState(true);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [viewDialogOpen, setViewDialogOpen] = useState(false);
  const [selectedPage, setSelectedPage] = useState(null);
  const [currentTab, setCurrentTab] = useState(0);
  const [formData, setFormData] = useState({
    title: '',
    slug: '',
    type: 'centralized',
    category: 'info',
    content: '',
    metaDescription: '',
    keywords: [],
  status: 'draft',
  metadata: {}
  });
  const [previewLogoUrl, setPreviewLogoUrl] = useState('');

  // Page categories for centralized pages
  const centralizedCategories = {
    company: {
      label: 'Company Information',
      icon: <Apartment />,
      description: 'Pages about your company that are the same globally',
      pages: ['About Us', 'Our Story', 'Mission & Vision', 'Leadership Team', 'Company Culture']
    },
    info: {
      label: 'Information & Guides',
      icon: <Info />,
      description: 'Universal guides and information pages',
      pages: ['How It Works', 'User Guide', 'Getting Started', 'Platform Overview', 'Features']
    },
    safety: {
      label: 'Safety & Guidelines',
      icon: <CheckCircle />,
      description: 'Safety information that applies globally',
      pages: ['Safety Guidelines', 'Community Guidelines', 'Best Practices', 'Emergency Procedures']
    },
    business: {
      label: 'Business Information',
      icon: <Business />,
      description: 'Business processes that are universal',
      pages: ['Partnership Program', 'Business Solutions', 'API Documentation', 'Developer Guide']
    },
    legal: {
      label: 'Global Legal',
      icon: <Gavel />,
      description: 'Legal documents with universal clauses',
      pages: ['Global Terms', 'Platform Rules', 'Intellectual Property', 'Copyright Policy']
    }
  };

  const statusColors = {
    draft: 'default',
    pending: 'warning',
    approved: 'success',
    rejected: 'error',
    published: 'info'
  };

  const loadCentralizedPages = async () => { try { setLoading(true); const res = await api.get('/content-pages', { params: { type: 'centralized' }}); const list = Array.isArray(res.data)? res.data : res.data?.data || []; setPages(list);} catch(e){ console.error('Error loading centralized pages', e); setPages([]);} finally { setLoading(false);} };

  useEffect(() => {
    loadCentralizedPages();
  }, []);

  const handleCreatePage = () => {
    setFormData({
      title: '',
      slug: '',
      type: 'centralized',
      category: 'info',
      content: '',
      metaDescription: '',
  keywords: [],
  status: 'draft',
  metadata: {}
    });
    setSelectedPage(null);
    setDialogOpen(true);
  };

  const handleEditPage = (page) => {
    setFormData({
      title: page.title || '',
      slug: page.slug || '',
      type: 'centralized',
      category: page.category || 'info',
      content: page.content || '',
      metaDescription: page.metaDescription || '',
      keywords: page.keywords || [],
  status: page.status || 'draft',
  metadata: page.metadata || {}
    });
    setSelectedPage(page);
    setDialogOpen(true);
  };

  // When a logo URL is present, try to get a signed URL for preview
  useEffect(() => {
    const url = formData?.metadata?.logoUrl;
    if (!url) {
      setPreviewLogoUrl('');
      return;
    }
    let cancelled = false;
    (async () => {
      try {
        const res = await api.post('/s3/signed-url', { url });
        if (!cancelled) {
          setPreviewLogoUrl(res.data?.signedUrl || url);
        }
      } catch (e) {
        if (!cancelled) setPreviewLogoUrl(url);
      }
    })();
    return () => { cancelled = true; };
  }, [formData?.metadata?.logoUrl]);

  const handleSavePage = async () => {
    try {
  const payload = { ...formData, slug: formData.slug || formData.title.toLowerCase().replace(/\s+/g,'-').replace(/[^a-z0-9-]/g,''), countries:['global'], isTemplate:false, requiresApproval: !isSuperAdmin, metadata: formData.metadata || {} };
  if (selectedPage){ await api.put(`/content-pages/${selectedPage.id}`, payload);} else { await api.post('/content-pages', { ...payload, status: isSuperAdmin ? 'approved' : 'draft' }); }

      setDialogOpen(false);
      loadCentralizedPages();
    } catch (error) {
      console.error('Error saving page:', error);
    }
  };

  const handleStatusChange = async (page, newStatus) => {
    try {
  await api.put(`/content-pages/${page.id}/status`, { status: newStatus });
      loadCentralizedPages();
    } catch (error) {
      console.error('Error updating page status:', error);
    }
  };

  const handleDeletePage = async (page) => {
    if (window.confirm(`Are you sure you want to delete "${page.title}"? This will affect all countries.`)) {
      try {
  await api.delete(`/content-pages/${page.id}`);
        loadCentralizedPages();
      } catch (error) {
        console.error('Error deleting page:', error);
      }
    }
  };

  const handleViewPage = (page) => {
    setSelectedPage(page);
    setViewDialogOpen(true);
  };

  const generateSlug = (title) => {
    return title.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '');
  };

  const getFilteredPages = () => {
    switch (currentTab) {
      case 1: return pages.filter(p => p.status === 'pending');
      case 2: return pages.filter(p => p.status === 'approved');
      case 3: return pages.filter(p => p.status === 'published');
      default: return pages;
    }
  };

  const getPageStats = () => {
    return {
      total: pages.length,
      draft: pages.filter(p => p.status === 'draft').length,
      pending: pages.filter(p => p.status === 'pending').length,
      approved: pages.filter(p => p.status === 'approved').length,
      published: pages.filter(p => p.status === 'published').length
    };
  };

  const stats = getPageStats();

  const formatDate = (value) => {
    if(!value) return 'Never';
    try {
      const d = value?.toDate ? value.toDate() : new Date(value);
      if(isNaN(d.getTime())) return 'Never';
      return d.toLocaleDateString();
    } catch { return 'Never'; }
  };
  const filteredPages = getFilteredPages();

  return (
    <Box>
      {/* Header */}
      <Box mb={3}>
        <Typography variant="h4" gutterBottom>
          🌐 Centralized Pages Management
        </Typography>
        <Alert severity="info" sx={{ mb: 2 }}>
          <Typography variant="body2">
            <strong>Centralized pages</strong> have the same content globally across all countries. 
            Perfect for company information, universal guides, and global policies.
          </Typography>
        </Alert>
      </Box>

      {/* Category Guide */}
      <Box mb={3}>
        <Typography variant="h6" gutterBottom>Page Categories Guide</Typography>
        <Grid container spacing={2}>
          {Object.entries(centralizedCategories).map(([key, category]) => (
            <Grid item xs={12} md={6} xl={4} key={key}>
              <Accordion>
                <AccordionSummary expandIcon={<ExpandMore />}>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    {category.icon}
                    <Typography variant="subtitle2">{category.label}</Typography>
                  </Box>
                </AccordionSummary>
                <AccordionDetails>
                  <Typography variant="body2" color="text.secondary" paragraph>
                    {category.description}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    <strong>Examples:</strong> {category.pages.join(', ')}
                  </Typography>
                </AccordionDetails>
              </Accordion>
            </Grid>
          ))}
        </Grid>
      </Box>

      {/* Stats Cards */}
      <Grid container spacing={3} mb={3}>
        <Grid item xs={12} sm={6} md={2.4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography color="text.secondary" gutterBottom variant="overline">
                    Total Global Pages
                  </Typography>
                  <Typography variant="h4" color="primary.main">
                    {stats.total}
                  </Typography>
                </Box>
                <Public color="primary" sx={{ fontSize: 40, opacity: 0.3 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={2.4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography color="text.secondary" gutterBottom variant="overline">
                    Published
                  </Typography>
                  <Typography variant="h4" color="info.main">
                    {stats.published}
                  </Typography>
                </Box>
                <Publish color="info" sx={{ fontSize: 40, opacity: 0.3 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={2.4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography color="text.secondary" gutterBottom variant="overline">
                    Approved
                  </Typography>
                  <Typography variant="h4" color="success.main">
                    {stats.approved}
                  </Typography>
                </Box>
                <CheckCircle color="success" sx={{ fontSize: 40, opacity: 0.3 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={2.4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography color="text.secondary" gutterBottom variant="overline">
                    Pending
                  </Typography>
                  <Typography variant="h4" color="warning.main">
                    {stats.pending}
                  </Typography>
                </Box>
                <Badge badgeContent={stats.pending} color="warning">
                  <Pending color="warning" sx={{ fontSize: 40, opacity: 0.3 }} />
                </Badge>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={2.4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography color="text.secondary" gutterBottom variant="overline">
                    Draft
                  </Typography>
                  <Typography variant="h4" color="grey.main">
                    {stats.draft}
                  </Typography>
                </Box>
                <Edit color="action" sx={{ fontSize: 40, opacity: 0.3 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Controls */}
      <Paper sx={{ p: 2, mb: 3 }}>
        <Box display="flex" justifyContent="space-between" alignItems="center">
          <Tabs value={currentTab} onChange={(e, newValue) => setCurrentTab(newValue)}>
            <Tab label="All Global Pages" />
            <Tab 
              label={
                <Badge badgeContent={stats.pending} color="warning">
                  Pending Approval
                </Badge>
              }
            />
            <Tab label="Approved" />
            <Tab label="Live (Published)" />
          </Tabs>
          <Button
            variant="contained"
            startIcon={<Add />}
            onClick={handleCreatePage}
            sx={{ bgcolor: 'primary.main' }}
          >
            Create Global Page
          </Button>
        </Box>
      </Paper>

      {/* Pages Table */}
      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Page Details</TableCell>
              <TableCell>Category</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Global Impact</TableCell>
              <TableCell>Last Updated</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredPages.map((page) => (
              <TableRow key={page.id} hover>
                <TableCell>
                  <Box>
                    <Typography variant="subtitle2" fontWeight="medium">
                      🌐 {page.title}
                    </Typography>
                    <Typography variant="caption" color="text.secondary">
                      /{page.slug}
                    </Typography>
                  </Box>
                </TableCell>
                <TableCell>
                  <Chip
                    icon={centralizedCategories[page.category]?.icon}
                    label={centralizedCategories[page.category]?.label || page.category}
                    size="small"
                    variant="outlined"
                  />
                </TableCell>
                <TableCell>
                  <Chip
                    label={page.status}
                    size="small"
                    color={statusColors[page.status]}
                    variant={page.status === 'published' ? 'filled' : 'outlined'}
                  />
                </TableCell>
                <TableCell>
                  <Chip 
                    label="ALL COUNTRIES" 
                    size="small" 
                    color="primary"
                    icon={<Public />}
                  />
                </TableCell>
                <TableCell>
                  <Typography variant="caption" color="text.secondary">
                    {formatDate(page.updatedAt)}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Box sx={{ display: 'flex', gap: 0.5 }}>
                    <Tooltip title="View">
                      <IconButton size="small" onClick={() => handleViewPage(page)}>
                        <Visibility />
                      </IconButton>
                    </Tooltip>
                    <Tooltip title="Edit">
                      <IconButton size="small" onClick={() => handleEditPage(page)}>
                        <Edit />
                      </IconButton>
                    </Tooltip>
                    {isSuperAdmin && (
                      <>
                        {page.status === 'pending' && (
                          <>
                            <Tooltip title="Approve">
                              <IconButton 
                                size="small" 
                                onClick={() => handleStatusChange(page, 'approved')}
                                color="success"
                              >
                                <Check />
                              </IconButton>
                            </Tooltip>
                            <Tooltip title="Reject">
                              <IconButton 
                                size="small" 
                                onClick={() => handleStatusChange(page, 'rejected')}
                                color="error"
                              >
                                <Close />
                              </IconButton>
                            </Tooltip>
                          </>
                        )}
                        {page.status === 'approved' && (
                          <Tooltip title="Publish Globally">
                            <IconButton 
                              size="small" 
                              onClick={() => handleStatusChange(page, 'published')}
                              color="info"
                            >
                              <Publish />
                            </IconButton>
                          </Tooltip>
                        )}
                        <Tooltip title="Delete (Affects All Countries)">
                          <IconButton 
                            size="small" 
                            onClick={() => handleDeletePage(page)}
                            color="error"
                          >
                            <Delete />
                          </IconButton>
                        </Tooltip>
                      </>
                    )}
                    {!isSuperAdmin && page.status === 'draft' && (
                      <Tooltip title="Submit for Global Approval">
                        <IconButton 
                          size="small" 
                          onClick={() => handleStatusChange(page, 'pending')}
                          color="warning"
                        >
                          <Pending />
                        </IconButton>
                      </Tooltip>
                    )}
                  </Box>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      {/* Create/Edit Dialog */}
      <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle>
          {selectedPage ? 'Edit Global Page' : 'Create New Global Page'}
          <Typography variant="caption" color="text.secondary" display="block">
            This page will be the same across all countries
          </Typography>
        </DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid item xs={12} sm={8}>
              <TextField
                fullWidth
                label="Page Title"
                value={formData.title}
                onChange={(e) => {
                  setFormData({
                    ...formData,
                    title: e.target.value,
                    slug: generateSlug(e.target.value)
                  });
                }}
                required
              />
            </Grid>
            <Grid item xs={12} sm={4}>
              <TextField
                fullWidth
                label="URL Slug"
                value={formData.slug}
                onChange={(e) => setFormData({...formData, slug: e.target.value})}
                helperText="Auto-generated"
              />
            </Grid>
            
            <Grid item xs={12}>
              <FormControl fullWidth>
                <InputLabel>Page Category</InputLabel>
                <Select
                  value={formData.category}
                  onChange={(e) => setFormData({...formData, category: e.target.value})}
                  label="Page Category"
                >
                  {Object.entries(centralizedCategories).map(([key, cat]) => (
                    <MenuItem key={key} value={key}>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        {cat.icon}
                        {cat.label}
                      </Box>
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>

            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Meta Description"
                value={formData.metaDescription}
                onChange={(e) => setFormData({...formData, metaDescription: e.target.value})}
                multiline
                rows={2}
                helperText="SEO description for search engines"
              />
            </Grid>

            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Page Content"
                value={formData.content}
                onChange={(e) => setFormData({...formData, content: e.target.value})}
                multiline
                rows={12}
                placeholder="Enter page content (supports HTML/Markdown)"
                required
              />
            </Grid>

            {/* About Us helper fields (optional). These map to metadata used by the mobile app. */}
            <Grid item xs={12}>
              <Accordion>
                <AccordionSummary expandIcon={<ExpandMore />}>
                  <Typography>About Us details (optional)</Typography>
                </AccordionSummary>
                <AccordionDetails>
                  <Grid container spacing={2}>
                    <Grid item xs={12}>
                      <TextField
                        fullWidth
                        label="About Text"
                        multiline
                        rows={5}
                        value={formData.metadata?.aboutText || ''}
                        onChange={(e)=> setFormData(fd=>({...fd, metadata:{...fd.metadata, aboutText: e.target.value}}))}
                      />
                    </Grid>
                    <Grid item xs={12} sm={6}>
                      <TextField
                        fullWidth
                        label="Logo URL"
                        value={formData.metadata?.logoUrl || ''}
                        onChange={(e)=> setFormData(fd=>({...fd, metadata:{...fd.metadata, logoUrl: e.target.value}}))}
                        helperText="You can paste a URL or upload below"
                      />
                      <Box sx={{ display:'flex', alignItems:'center', gap:2, mt:1, flexWrap:'wrap' }}>
                        {formData.metadata?.logoUrl && (
                          <Avatar src={previewLogoUrl || formData.metadata.logoUrl} variant="rounded" sx={{ width:56, height:56 }} />
                        )}
                        <Button
                          variant="outlined"
                          component="label"
                        >
                          Upload Logo
                          <input type="file" accept="image/*" hidden onChange={async (e)=>{
                            const file = e.target.files?.[0];
                            if(!file) return;
                            const form = new FormData();
                            form.append('file', file);
                            try {
                              // Try S3 first
                              const s3Form = new FormData();
                              s3Form.append('file', file);
                              s3Form.append('uploadType', 'about-us');
                              let url = '';
                              try {
                                const s3 = await api.post('/s3/upload', s3Form, { headers: { 'Content-Type': 'multipart/form-data' } });
                                url = s3.data?.url || s3.data?.location || '';
                              } catch(err){
                                const res = await api.post('/upload/payment-methods', form, { headers: { 'Content-Type': 'multipart/form-data' } });
                                url = res.data?.url || '';
                              }
                              if(url){ setFormData(fd=>({...fd, metadata:{...fd.metadata, logoUrl: url}})); }
                            } catch(err){ console.error('Logo upload failed', err); }
                          }} />
                        </Button>
                        {formData.metadata?.logoUrl && (
                          <Button color="error" onClick={()=> setFormData(fd=>({...fd, metadata:{...fd.metadata, logoUrl:''}}))}>Remove</Button>
                        )}
                      </Box>
                    </Grid>
                    <Grid item xs={12} sm={6}>
                      <TextField
                        fullWidth
                        label="Website URL"
                        value={formData.metadata?.websiteUrl || ''}
                        onChange={(e)=> setFormData(fd=>({...fd, metadata:{...fd.metadata, websiteUrl: e.target.value}}))}
                      />
                    </Grid>
                    <Grid item xs={12} sm={6}>
                      <TextField
                        fullWidth
                        label="HQ Title"
                        value={formData.metadata?.hqTitle || ''}
                        onChange={(e)=> setFormData(fd=>({...fd, metadata:{...fd.metadata, hqTitle: e.target.value}}))}
                      />
                    </Grid>
                    <Grid item xs={12} sm={6}>
                      <TextField
                        fullWidth
                        label="HQ Address"
                        multiline
                        rows={2}
                        value={formData.metadata?.hqAddress || ''}
                        onChange={(e)=> setFormData(fd=>({...fd, metadata:{...fd.metadata, hqAddress: e.target.value}}))}
                      />
                    </Grid>
                    <Grid item xs={12} sm={4}>
                      <TextField
                        fullWidth
                        label="Support - Passenger"
                        value={formData.metadata?.supportPassenger || ''}
                        onChange={(e)=> setFormData(fd=>({...fd, metadata:{...fd.metadata, supportPassenger: e.target.value}}))}
                      />
                    </Grid>
                    <Grid item xs={12} sm={4}>
                      <TextField
                        fullWidth
                        label="Hotline"
                        value={formData.metadata?.hotline || ''}
                        onChange={(e)=> setFormData(fd=>({...fd, metadata:{...fd.metadata, hotline: e.target.value}}))}
                      />
                    </Grid>
                    <Grid item xs={12} sm={4}>
                      <TextField
                        fullWidth
                        label="Support Email"
                        value={formData.metadata?.supportEmail || ''}
                        onChange={(e)=> setFormData(fd=>({...fd, metadata:{...fd.metadata, supportEmail: e.target.value}}))}
                      />
                    </Grid>
                    <Grid item xs={12}>
                      <TextField
                        fullWidth
                        label="Feedback Text"
                        multiline
                        rows={3}
                        value={formData.metadata?.feedbackText || ''}
                        onChange={(e)=> setFormData(fd=>({...fd, metadata:{...fd.metadata, feedbackText: e.target.value}}))}
                      />
                    </Grid>
                    <Grid item xs={12} sm={6}>
                      <TextField
                        fullWidth
                        label="Facebook URL"
                        value={formData.metadata?.facebookUrl || ''}
                        onChange={(e)=> setFormData(fd=>({...fd, metadata:{...fd.metadata, facebookUrl: e.target.value}}))}
                      />
                    </Grid>
                    <Grid item xs={12} sm={6}>
                      <TextField
                        fullWidth
                        label="X (Twitter) URL"
                        value={formData.metadata?.xUrl || ''}
                        onChange={(e)=> setFormData(fd=>({...fd, metadata:{...fd.metadata, xUrl: e.target.value}}))}
                      />
                    </Grid>
                  </Grid>
                </AccordionDetails>
              </Accordion>
            </Grid>

            <Grid item xs={12}>
              <Alert severity="info">
                <Typography variant="body2">
                  <strong>Global Impact:</strong> This page will be identical across all countries. 
                  Changes will affect all users worldwide.
                </Typography>
              </Alert>
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDialogOpen(false)}>Cancel</Button>
          <Button onClick={handleSavePage} variant="contained">
            {selectedPage ? 'Update Global Page' : 'Create Global Page'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* View Page Dialog */}
      <Dialog 
        open={viewDialogOpen} 
        onClose={() => setViewDialogOpen(false)} 
        maxWidth="lg" 
        fullWidth
      >
        {selectedPage && (
          <>
            <DialogTitle>
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <Box>
                  <Typography variant="h6">🌐 {selectedPage.title}</Typography>
                  <Typography variant="caption" color="text.secondary">
                    Global page: /{selectedPage.slug}
                  </Typography>
                </Box>
                <Box sx={{ display: 'flex', gap: 1 }}>
                  <Chip 
                    label={selectedPage.status} 
                    color={statusColors[selectedPage.status]}
                  />
                  <Chip 
                    label="ALL COUNTRIES" 
                    color="primary"
                    icon={<Public />}
                  />
                </Box>
              </Box>
            </DialogTitle>
            <DialogContent>
              <Grid container spacing={2}>
                <Grid item xs={6}>
                  <Typography variant="subtitle2" color="text.secondary">Category</Typography>
                  <Typography>{centralizedCategories[selectedPage.category]?.label}</Typography>
                </Grid>
                <Grid item xs={6}>
                  <Typography variant="subtitle2" color="text.secondary">Global Scope</Typography>
                  <Typography>Available in all countries</Typography>
                </Grid>
              </Grid>
              <Divider sx={{ my: 2 }} />
              <Typography variant="h6" gutterBottom>Content Preview</Typography>
              <Box 
                sx={{ 
                  p: 2, 
                  bgcolor: 'grey.50', 
                  borderRadius: 1,
                  maxHeight: 400,
                  overflow: 'auto'
                }}
              >
                <Typography variant="body2" style={{ whiteSpace: 'pre-wrap' }}>
                  {selectedPage.content}
                </Typography>
              </Box>
            </DialogContent>
            <DialogActions>
              <Button onClick={() => setViewDialogOpen(false)}>Close</Button>
            </DialogActions>
          </>
        )}
      </Dialog>
    </Box>
  );
};

export default CentralizedPagesModule;
