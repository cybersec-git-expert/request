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
  Badge
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
  Publish
} from '@mui/icons-material';
import useCountryFilter from '../hooks/useCountryFilter.jsx';
import api from '../services/apiClient';
import RichTextEditor from '../components/RichTextEditor.jsx';
import DOMPurify from 'dompurify';

const PagesModule = () => {
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
    category: 'legal',
    content: '',
    countries: [],
    isTemplate: false,
    requiresApproval: true,
    status: 'draft',
    metaDescription: '',
  keywords: [],
  // UI fields mapped to payload.metadata
  headerLogoUrl: '',
  effectiveDate: ''
  });

  // Page types and categories
  const pageTypes = [
    { value: 'centralized', label: 'Centralized (Global)', icon: <Public /> },
    { value: 'country-specific', label: 'Country Specific', icon: <Language /> },
    { value: 'template', label: 'Template (Country Customizable)', icon: <Article /> }
  ];

  const pageCategories = {
    legal: {
      label: 'Legal & Compliance',
      icon: <Gavel />,
      pages: ['Privacy Policy', 'Terms & Conditions', 'Cookie Policy', 'Data Protection', 'Refund Policy', 'Cancellation Policy']
    },
    info: {
      label: 'Information',
      icon: <Article />,
      pages: ['About Us', 'How It Works', 'FAQ', 'Contact Us', 'Help Center', 'Safety Guidelines']
    },
    business: {
      label: 'Business',
      icon: <Public />,
      pages: ['Pricing', 'Service Areas', 'Driver Requirements', 'Business Solutions', 'Partner Program']
    },
    company: {
      label: 'Company',
      icon: <Article />,
      pages: ['Careers', 'Press', 'Community Guidelines', 'Support']
    }
  };

  const statusColors = {
    draft: 'default',
    pending: 'warning',
    approved: 'success',
    rejected: 'error',
    published: 'info'
  };

  const loadPages = async () => {
    try { setLoading(true); const params = {}; if (!isSuperAdmin) params.country = userCountry; const res = await api.get('/content-pages', { params }); const all = Array.isArray(res.data)? res.data : res.data?.data || []; const pagesData = isSuperAdmin ? all : all.filter(page => page.countries?.includes(userCountry) || page.countries?.includes('global') || page.type==='centralized' || (page.type==='template' && page.isTemplate)); setPages(pagesData);} catch(e){ console.error('Error loading pages', e); setPages([]);} finally { setLoading(false);} };

  useEffect(() => {
    loadPages();
  }, [adminData]);

  const handleCreatePage = () => {
    setFormData({
      title: '',
      slug: '',
      type: isSuperAdmin ? 'centralized' : 'country-specific', // Default based on role
      category: 'legal',
      content: '',
      countries: isSuperAdmin ? ['global'] : [userCountry], // Auto-assign based on role
      isTemplate: false,
      requiresApproval: !isSuperAdmin, // Super admin pages don't need approval
      status: 'draft',
      metaDescription: '',
  keywords: [],
  headerLogoUrl: '',
  effectiveDate: ''
    });
    setSelectedPage(null);
    setDialogOpen(true);
  };

  const handleEditPage = (page) => {
    setFormData({
      title: page.title || '',
      slug: page.slug || '',
      type: page.type || 'centralized',
      category: page.category || 'legal',
      content: page.content || '',
      countries: page.countries || [],
      isTemplate: page.isTemplate || false,
      requiresApproval: page.requiresApproval !== false,
      status: page.status || 'draft',
      metaDescription: page.metaDescription || '',
  keywords: page.keywords || [],
  headerLogoUrl: (page.metadata?.headerLogoUrl || page.metadata?.logoUrl || page.metadata?.brandLogoUrl || page.metadata?.logo || ''),
  effectiveDate: (page.metadata?.effectiveDate || page.metadata?.effective_date || page.metadata?.effectiveDateDisplay || page.metadata?.effective_date_display || '')
    });
    setSelectedPage(page);
    setDialogOpen(true);
  };

  const handleSavePage = async () => {
    try {
      // Exclude UI-only fields from top-level payload
      const { headerLogoUrl, effectiveDate, ...rest } = formData;
      const payload = {
        ...rest,
        slug: rest.slug || rest.title.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, ''),
        country: rest.type === 'country-specific' ? userCountry : null,
        // Only send metadata fields the mobile app consumes
        metadata: {
          headerLogoUrl: headerLogoUrl || undefined,
          effectiveDate: effectiveDate || undefined
        }
      };
      if (selectedPage) { await api.put(`/content-pages/${selectedPage.id}`, payload); } else { await api.post('/content-pages', payload); }

      setDialogOpen(false);
      loadPages();
    } catch (error) {
      console.error('Error saving page:', error);
    }
  };

  const handleStatusChange = async (page, newStatus) => {
    try {
  await api.put(`/content-pages/${page.id}/status`, { status: newStatus });
      loadPages();
    } catch (error) {
      console.error('Error updating page status:', error);
    }
  };

  const handleDeletePage = async (page) => {
    if (window.confirm(`Are you sure you want to delete "${page.title}"?`)) {
      try {
  await api.delete(`/content-pages/${page.id}`);
        loadPages();
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
  const filteredPages = getFilteredPages();

  return (
    <Box>
      {/* Header */}
      <Box mb={3}>
        <Typography variant="h4" gutterBottom>
          Page Management
        </Typography>
        <Typography variant="body2" color="text.secondary">
          {isSuperAdmin ? 
            'Manage global and country-specific pages with approval workflow' : 
            `Manage country-specific pages for ${getCountryDisplayName(userCountry)}`
          }
        </Typography>
        
        {!isSuperAdmin && (
          <Alert severity="info" sx={{ mt: 2 }}>
            <Typography variant="body2">
              <strong>Country Admin Access:</strong> You can create country-specific pages for {getCountryDisplayName(userCountry)}. 
              All pages require super admin approval before publishing.
            </Typography>
          </Alert>
        )}
      </Box>

      {/* Stats Cards */}
      <Grid container spacing={3} mb={3}>
        <Grid item xs={12} sm={6} md={2.4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography color="text.secondary" gutterBottom variant="overline">
                    Total Pages
                  </Typography>
                  <Typography variant="h4" color="primary.main">
                    {stats.total}
                  </Typography>
                </Box>
                <Article color="primary" sx={{ fontSize: 40, opacity: 0.3 }} />
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
      </Grid>

      {/* Controls */}
      <Paper sx={{ p: 2, mb: 3 }}>
        <Box display="flex" justifyContent="space-between" alignItems="center">
          <Tabs value={currentTab} onChange={(e, newValue) => setCurrentTab(newValue)}>
            <Tab label="All Pages" />
            <Tab 
              label={
                <Badge badgeContent={stats.pending} color="warning">
                  Pending Approval
                </Badge>
              }
            />
            <Tab label="Approved" />
            <Tab label="Published" />
          </Tabs>
          <Button
            variant="contained"
            startIcon={<Add />}
            onClick={handleCreatePage}
          >
            Create Page
          </Button>
        </Box>
      </Paper>

      {/* Pages Table */}
      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Page Details</TableCell>
              <TableCell>Type</TableCell>
              <TableCell>Category</TableCell>
              <TableCell>Countries</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Created By</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredPages.map((page) => (
              <TableRow key={page.id} hover>
                <TableCell>
                  <Box>
                    <Typography variant="subtitle2" fontWeight="medium">
                      {page.title}
                    </Typography>
                    <Typography variant="caption" color="text.secondary">
                      /{page.slug}
                    </Typography>
                  </Box>
                </TableCell>
                <TableCell>
                  <Chip
                    icon={pageTypes.find(t => t.value === page.type)?.icon}
                    label={pageTypes.find(t => t.value === page.type)?.label || page.type}
                    size="small"
                    variant="outlined"
                    color={page.type === 'centralized' ? 'primary' : 'default'}
                  />
                </TableCell>
                <TableCell>
                  <Chip
                    icon={pageCategories[page.category]?.icon}
                    label={pageCategories[page.category]?.label || page.category}
                    size="small"
                    variant="outlined"
                  />
                </TableCell>
                <TableCell>
                  {page.type === 'centralized' ? (
                    <Chip 
                      label="🌐 ALL COUNTRIES" 
                      size="small" 
                      color="primary"
                      variant="filled"
                    />
                  ) : (
                    <Box sx={{ display: 'flex', gap: 0.5, flexWrap: 'wrap' }}>
                      {(page.countries || []).map(country => (
                        <Chip 
                          key={country} 
                          label={country === 'global' ? '🌐 Global' : getCountryDisplayName(country)} 
                          size="small"
                          color={country === userCountry ? 'success' : 'default'}
                          variant={country === userCountry ? 'filled' : 'outlined'}
                        />
                      ))}
                    </Box>
                  )}
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
                  <Box>
                    <Typography variant="caption" color="text.secondary">
                      {page.createdBy && adminData?.uid && page.createdBy === adminData.uid ? 'You' : 'Other Admin'}
                    </Typography>
                    <Typography variant="caption" display="block" color="text.secondary">
                      {getCountryDisplayName(page.country) || 'Global'}
                    </Typography>
                  </Box>
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
                          <Tooltip title="Publish">
                            <IconButton 
                              size="small" 
                              onClick={() => handleStatusChange(page, 'published')}
                              color="info"
                            >
                              <Publish />
                            </IconButton>
                          </Tooltip>
                        )}
                        <Tooltip title="Delete">
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
                      <Tooltip title="Submit for Approval">
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
          {selectedPage ? 'Edit Page' : 'Create New Page'}
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
                helperText="Auto-generated from title"
              />
            </Grid>
            
            <Grid item xs={12} sm={6}>
              <FormControl fullWidth>
                <InputLabel>Page Type</InputLabel>
                <Select
                  value={formData.type}
                  onChange={(e) => {
                    const newType = e.target.value;
                    setFormData({
                      ...formData, 
                      type: newType,
                      countries: newType === 'centralized' ? ['global'] : [userCountry],
                      requiresApproval: !isSuperAdmin || newType === 'centralized'
                    });
                  }}
                  label="Page Type"
                >
                  {pageTypes.filter(type => {
                    // Country admins can only create country-specific pages
                    // Super admin can create any type except templates (for now)
                    if (!isSuperAdmin) {
                      return type.value === 'country-specific'; // Country admins can only create country-specific pages
                    }
                    return type.value !== 'template'; // Super admin can create centralized and country-specific (hide templates for now)
                  }).map(type => (
                    <MenuItem key={type.value} value={type.value}>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        {type.icon}
                        {type.label}
                      </Box>
                    </MenuItem>
                  ))}
                </Select>
                <Typography variant="caption" color="text.secondary" sx={{ mt: 1 }}>
                  {formData.type === 'centralized' ? 
                    '🌐 This page will be the same across all countries' :
                    `📍 This page is specific to ${getCountryDisplayName(userCountry)}`
                  }
                </Typography>
              </FormControl>
            </Grid>
            
            <Grid item xs={12} sm={6}>
              <FormControl fullWidth>
                <InputLabel>Category</InputLabel>
                <Select
                  value={formData.category}
                  onChange={(e) => setFormData({...formData, category: e.target.value})}
                  label="Category"
                >
                  {Object.entries(pageCategories).map(([key, cat]) => (
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

            {/* Metadata: Header Logo URL & Effective Date */}
            <Grid item xs={12} sm={8}>
              <TextField
                fullWidth
                label="Header Logo URL"
                value={formData.headerLogoUrl}
                onChange={(e) => setFormData({ ...formData, headerLogoUrl: e.target.value })}
                placeholder="https://cdn.example.com/brand/logo.png or /public/logo.png"
                helperText="Shown at top of Legal/Privacy pages in the mobile app"
              />
            </Grid>
            <Grid item xs={12} sm={4}>
              <TextField
                fullWidth
                label="Effective Date"
                type="date"
                value={formData.effectiveDate}
                onChange={(e) => setFormData({ ...formData, effectiveDate: e.target.value })}
                InputLabelProps={{ shrink: true }}
                helperText="Displayed under the title (YYYY-MM-DD)"
              />
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
              <Typography variant="subtitle2" sx={{ mb: 0.5 }}>Content</Typography>
              <RichTextEditor
                value={formData.content}
                onChange={(html) => setFormData({ ...formData, content: html })}
                placeholder="Write and format your page content"
              />
            </Grid>

            <Grid item xs={12}>
              <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
                <FormControlLabel
                  control={
                    <Switch
                      checked={formData.isTemplate}
                      onChange={(e) => setFormData({...formData, isTemplate: e.target.checked})}
                      disabled={!isSuperAdmin} // Only super admin can create templates
                    />
                  }
                  label="Is Template"
                />
                <FormControlLabel
                  control={
                    <Switch
                      checked={formData.requiresApproval}
                      onChange={(e) => setFormData({...formData, requiresApproval: e.target.checked})}
                      disabled={!isSuperAdmin} // Country admins always need approval
                    />
                  }
                  label="Requires Approval"
                />
              </Box>
            </Grid>

            {/* Warning for country admins creating centralized pages */}
            {!isSuperAdmin && formData.type === 'centralized' && (
              <Grid item xs={12}>
                <Alert severity="warning">
                  <Typography variant="body2">
                    <strong>Global Page Alert:</strong> You are creating a page that will affect ALL countries. 
                    This page will require super admin approval before it can be published globally.
                  </Typography>
                </Alert>
              </Grid>
            )}

            {/* Info for country-specific pages */}
            {formData.type === 'country-specific' && (
              <Grid item xs={12}>
                <Alert severity="info">
                  <Typography variant="body2">
                    <strong>Country Page:</strong> This page will only be visible in {getCountryDisplayName(userCountry)}. 
                    {!isSuperAdmin && ' It will require super admin approval before publishing.'}
                  </Typography>
                </Alert>
              </Grid>
            )}
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDialogOpen(false)}>Cancel</Button>
          <Button onClick={handleSavePage} variant="contained">
            {selectedPage ? 'Update' : 'Create'} Page
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
                  <Typography variant="h6">{selectedPage.title}</Typography>
                  <Typography variant="caption" color="text.secondary">
                    /{selectedPage.slug}
                  </Typography>
                </Box>
                <Chip 
                  label={selectedPage.status} 
                  color={statusColors[selectedPage.status]}
                />
              </Box>
            </DialogTitle>
            <DialogContent>
              <Box sx={{ mb: 2 }}>
                <Grid container spacing={2}>
                  <Grid item xs={6}>
                    <Typography variant="subtitle2" color="text.secondary">Type</Typography>
                    <Typography>{pageTypes.find(t => t.value === selectedPage.type)?.label}</Typography>
                  </Grid>
                  <Grid item xs={6}>
                    <Typography variant="subtitle2" color="text.secondary">Category</Typography>
                    <Typography>{pageCategories[selectedPage.category]?.label}</Typography>
                  </Grid>
                </Grid>
              </Box>
              <Divider sx={{ mb: 2 }} />
              <Typography variant="h6" gutterBottom>Content Preview</Typography>
              <Box
                sx={{
                  p: 2,
                  bgcolor: 'grey.50',
                  borderRadius: 1,
                  maxHeight: 400,
                  overflow: 'auto',
                  '& h1': { fontSize: '1.6rem', marginTop: 0 },
                  '& h2': { fontSize: '1.3rem' },
                  '& p, & li': { lineHeight: 1.7 },
                  '& blockquote': { borderLeft: '4px solid', borderColor: 'divider', paddingLeft: 8, color: 'text.secondary' },
                  '& pre': { backgroundColor: 'grey.100', padding: 8, borderRadius: 4, fontFamily: 'monospace', overflowX: 'auto' }
                }}
                dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(selectedPage.content || '') }}
              />
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

export default PagesModule;
