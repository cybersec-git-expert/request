import React, { useEffect, useState } from 'react';
import { Box, Typography, Paper, TextField, Button, Select, MenuItem, FormControl, InputLabel, Switch, FormControlLabel, Divider, Chip } from '@mui/material';
import apiClient from '../../services/apiClient';
import { useAuth } from '../../contexts/AuthContext';

export default function SubscriptionAdmin() {
  const { isSuperAdmin, isCountryAdmin, userCountry } = useAuth();
  const [plans, setPlans] = useState([]);
  const [plansLoading, setPlansLoading] = useState(false);
  const [plansError, setPlansError] = useState('');
  const [form, setForm] = useState({ code: '', name: '', plan_type: 'basic', description: '', default_responses_per_month: 3 });
  const [editingCode, setEditingCode] = useState('');

  const [countryCode, setCountryCode] = useState('LK');
  const [countrySettings, setCountrySettings] = useState([]);
  // Use the correct global plan codes used by the backend
  const PLAN_CODES = ['pro_responder', 'pro_driver', 'pro_seller_monthly', 'pro_seller_ppc'];
  const [settingsForm, setSettingsForm] = useState({ plan_code: 'pro_responder', currency: 'LKR', price: '', responses_per_month: 3, ppc_price: '', is_active: false });

  const [businessTypes, setBusinessTypes] = useState([]);
  const [mappings, setMappings] = useState([]);
  const [mappingForm, setMappingForm] = useState({ business_type_id: '', plan_code: 'pro_responder', is_active: true });
  const [editingMappingId, setEditingMappingId] = useState(null);
  const [mappingError, setMappingError] = useState('');

  useEffect(() => {
    if (isSuperAdmin) {
      loadPlans();
    }
  }, [isSuperAdmin]);

  // Default country code from logged-in country admin
  useEffect(() => {
    if (isCountryAdmin && userCountry) {
      setCountryCode((userCountry || '').toUpperCase());
    }
  }, [isCountryAdmin, userCountry]);

  // Load country-scoped data only for country admins
  useEffect(() => {
    if (isCountryAdmin && countryCode) {
      loadCountrySettings(countryCode);
      loadBusinessTypes(countryCode);
      loadMappings(countryCode);
    }
  }, [isCountryAdmin, countryCode]);

  async function loadPlans() {
    try {
      setPlansLoading(true);
      setPlansError('');
  const { data } = await apiClient.get('/subscriptions/plans');
      setPlans(Array.isArray(data) ? data : (data?.data || []));
    } catch (e) {
      console.error('Load plans failed', e);
      setPlansError(e?.response?.data?.error || e.message || 'Failed to load plans');
    }
    finally { setPlansLoading(false); }
  }

  async function createOrUpdatePlan() {
    try {
  await apiClient.post('/subscriptions/plans', form);
      await loadPlans();
      setEditingCode('');
      // reset form after save
      setForm({ code: '', name: '', plan_type: 'basic', description: '', default_responses_per_month: 3 });
    } catch (e) {
      console.error('Create plan failed', e);
    }
  }

  async function approvePlan(code) {
    try {
  await apiClient.post(`/subscriptions/plans/${code}/approve`);
      await loadPlans();
    } catch (e) {
      console.error('Approve plan failed', e);
    }
  }

  async function loadCountrySettings(cc) {
    try {
  const { data } = await apiClient.get('/subscriptions/country-settings', { params: { country_code: cc } });
      setCountrySettings(data || []);
    } catch (e) {
      console.error('Load country settings failed', e);
    }
  }

  async function upsertCountrySettings() {
    try {
  await apiClient.post('/subscriptions/country-settings', { country_code: countryCode, ...settingsForm });
      await loadCountrySettings(countryCode);
    } catch (e) {
      console.error('Upsert country settings failed', e);
    }
  }

  async function loadBusinessTypes(cc) {
    try {
  const { data } = await apiClient.get('/subscriptions/business-types', { params: { country_code: cc, source: 'country' } });
  // If backend expects global IDs for mappings, include only those with global link; otherwise use all
  setBusinessTypes(Array.isArray(data) ? data : []);
    } catch (e) {
      console.error('Load business types failed', e);
    }
  }

  async function loadMappings(cc) {
    try {
  const { data } = await apiClient.get('/subscriptions/mappings', { params: { country_code: cc } });
      setMappings(data || []);
    } catch (e) {
      console.error('Load mappings failed', e);
    }
  }

  async function upsertMapping() {
    try {
  setMappingError('');
      const payload = { country_code: countryCode, ...mappingForm };
      if (editingMappingId) {
        payload.mapping_id = editingMappingId;
      }
      await apiClient.post('/subscriptions/mappings', payload);
      setMappingForm({ business_type_id: '', plan_code: 'pro_responder', is_active: true });
      setEditingMappingId(null);
      await loadMappings(countryCode);
    } catch (e) {
  console.error('Upsert mapping failed', e);
  const msg = e?.response?.data?.details || e?.response?.data?.error || e?.message || 'Failed to save mapping';
  setMappingError(msg);
    }
  }

  function editMapping(mapping) {
    console.log('Editing mapping:', mapping);
    console.log('Available business types:', businessTypes);
    
    // Find the matching business type by name since IDs might be different types
    const matchingBusinessType = businessTypes.find(bt => 
      (bt.name || bt.global_name) === mapping.business_type_name
    );
    
    console.log('Matching business type found:', matchingBusinessType);
    
    setEditingMappingId(mapping.id);
    setMappingForm({
  // Prefer global id if available so submit uses the correct type expected by backend
  business_type_id: matchingBusinessType ? (matchingBusinessType.global_business_type_id ?? matchingBusinessType.id) : mapping.business_type_id,
      plan_code: mapping.plan_code,
      is_active: mapping.is_active
    });
  }

  function cancelMappingEdit() {
    setEditingMappingId(null);
    setMappingForm({ business_type_id: '', plan_code: 'pro_responder', is_active: true });
  }

  return (
    <Box p={2}>
      <Typography variant="h4" gutterBottom>🎯 Subscription Management</Typography>
      
      {/* Quick Stats */}
      <Paper variant="outlined" sx={{ p: 2, mb: 3, backgroundColor: '#f5f5f5' }}>
        <Typography variant="h6" gutterBottom>📊 Quick Overview</Typography>
        <Box display="flex" gap={4} flexWrap="wrap">
          <Box>
            <Typography variant="body2" color="text.secondary">Total Plans</Typography>
            <Typography variant="h6">{plans.length}</Typography>
          </Box>
          <Box>
            <Typography variant="body2" color="text.secondary">Country Settings</Typography>
            <Typography variant="h6">{countrySettings.length}</Typography>
          </Box>
          <Box>
            <Typography variant="body2" color="text.secondary">Business Mappings</Typography>
            <Typography variant="h6">{mappings.length}</Typography>
          </Box>
          <Box>
            <Typography variant="body2" color="text.secondary">Country</Typography>
            <Typography variant="h6">{countryCode}</Typography>
          </Box>
        </Box>
      </Paper>

      {isSuperAdmin && (
        <Paper variant="outlined" sx={{ p:2, mb:3 }}>
          <Typography variant="h6">Create/Update Global Plan (Super Admin)</Typography>
          <Box display="flex" gap={2} mt={2} flexWrap="wrap">
            <TextField label="Code" size="small" value={form.code} disabled={!!editingCode} onChange={e=>setForm({ ...form, code:e.target.value })} />
            <TextField label="Name" size="small" value={form.name} onChange={e=>setForm({ ...form, name:e.target.value })} />
            <FormControl size="small">
              <InputLabel>Type</InputLabel>
              <Select label="Type" value={form.plan_type} onChange={e=>setForm({ ...form, plan_type:e.target.value })}>
                <MenuItem value="basic">Basic</MenuItem>
                <MenuItem value="unlimited">Unlimited</MenuItem>
                <MenuItem value="ppc">Pay Per Click</MenuItem>
              </Select>
            </FormControl>
            <TextField label="Default Responses/Month" size="small" type="number" value={form.default_responses_per_month||''} onChange={e=>setForm({ ...form, default_responses_per_month:Number(e.target.value) })} />
            <TextField label="Description" size="small" fullWidth value={form.description} onChange={e=>setForm({ ...form, description:e.target.value })} />
            <Button variant="contained" onClick={createOrUpdatePlan}>{editingCode ? 'Update Plan' : 'Save Plan'}</Button>
            {editingCode && (
              <Button variant="text" color="inherit" onClick={()=>{ setEditingCode(''); setForm({ code: '', name: '', plan_type: 'basic', description: '', default_responses_per_month: 3 }); }}>Cancel</Button>
            )}
            <Button variant="outlined" onClick={loadPlans} disabled={plansLoading}>Refresh</Button>
          </Box>
          <Box mt={2}>
            <Typography variant="h6" gutterBottom>📋 Current Subscription Plans:</Typography>
          {plansError && <Typography color="error" variant="body2">{plansError}</Typography>}
          {!plansError && plans.length === 0 && (
              <Typography variant="body2" color="text.secondary">No plans found.</Typography>
          )}
          {plans.map(p => (
            <Paper key={p.id || p.code} sx={{ p: 2, mb: 1, border: '1px solid #e0e0e0' }}>
              <Box display="flex" alignItems="center" justifyContent="space-between">
                <Box>
                  <Typography variant="h6" color="primary">{p.name}</Typography>
                  <Typography variant="body2" color="text.secondary">
                    Code: {p.code} | Type: {p.plan_type} | Status: 
                    <span style={{ color: p.status === 'active' ? 'green' : 'orange', fontWeight: 'bold' }}>
                      {p.status}
                    </span>
                  </Typography>
                  {p.description && <Typography variant="body2" sx={{ mt: 1 }}>{p.description}</Typography>}
                  {p.default_responses_per_month && (
                    <Typography variant="body2" sx={{ mt: 1, fontWeight: 'bold' }}>
                      📊 Default Responses: {p.default_responses_per_month}/month
                    </Typography>
                  )}
                </Box>
                <Box display="flex" gap={1}>
                  {p.status !== 'active' && (
                    <Button size="small" variant="contained" color="success" onClick={()=>approvePlan(p.code)}>
                      ✅ Approve
                    </Button>
                  )}
                  <Button size="small" variant="outlined" onClick={()=>{ setEditingCode(p.code); setForm({
                    code: p.code,
                    name: p.name,
                    plan_type: p.plan_type,
                    description: p.description || '',
                    default_responses_per_month: p.default_responses_per_month || ''
                  }); }}>
                    ✏️ Edit
                  </Button>
                </Box>
              </Box>
            </Paper>
          ))}
          </Box>
        </Paper>
      )}

  {isCountryAdmin && (
  <Paper variant="outlined" sx={{ p:2, mb:3 }}>
        <Typography variant="h6">Country Pricing/Responses (Country Admin)</Typography>
        <Box display="flex" gap={2} mt={2} flexWrap="wrap">
          <TextField 
            label="Country Code" 
            size="small" 
            value={countryCode}
            disabled={isCountryAdmin}
            onChange={e=>{ if(!isCountryAdmin) setCountryCode(e.target.value.toUpperCase()); }} 
          />
          <FormControl size="small">
            <InputLabel>Plan Code</InputLabel>
            <Select label="Plan Code" value={settingsForm.plan_code} onChange={e=>setSettingsForm({ ...settingsForm, plan_code:e.target.value })}>
              {plans.map(plan => (
                <MenuItem key={plan.code} value={plan.code}>
                  {plan.name} ({plan.code})
                </MenuItem>
              ))}
              {plans.length === 0 && PLAN_CODES.map(c=> 
                <MenuItem key={c} value={c}>{c}</MenuItem>
              )}
            </Select>
          </FormControl>
          <TextField 
            label="Currency" 
            size="small" 
            value={settingsForm.currency} 
            disabled={isCountryAdmin}
            onChange={e=>setSettingsForm({ ...settingsForm, currency:e.target.value })} 
          />
          <TextField label="Price" size="small" type="number" value={settingsForm.price} onChange={e=>setSettingsForm({ ...settingsForm, price:e.target.value })} />
          <TextField label="Responses/Month (Basic)" size="small" type="number" value={settingsForm.responses_per_month} onChange={e=>setSettingsForm({ ...settingsForm, responses_per_month:Number(e.target.value) })} />
          <TextField label="PPC Price (PPC)" size="small" type="number" value={settingsForm.ppc_price} onChange={e=>setSettingsForm({ ...settingsForm, ppc_price:e.target.value })} />
          <FormControlLabel control={<Switch checked={settingsForm.is_active} onChange={e=>setSettingsForm({ ...settingsForm, is_active:e.target.checked })} />} label="Active" />
          <Button variant="contained" onClick={upsertCountrySettings}>Save Country Settings</Button>
        </Box>
        <Divider sx={{ my:2 }} />
        <Typography>Existing Settings for {countryCode}:</Typography>
        {countrySettings.map(s => (
          <Box key={s.id} mt={1}>
            <Typography>{s.plan_code} - {s.currency} {s.price ?? s.ppc_price ?? ''} | responses: {s.responses_per_month ?? '-'} | active: {String(s.is_active)}</Typography>
          </Box>
        ))}
      </Paper>
  )}

  {isCountryAdmin && (
  <Paper variant="outlined" sx={{ p:2 }}>
        <Typography variant="h6">Plan-to-Business-Type Mapping (Country Admin)</Typography>
        <Box display="flex" gap={2} mt={2} flexWrap="wrap">
          <FormControl size="small" sx={{ minWidth: 220 }}>
            <InputLabel>Business Type</InputLabel>
            <Select 
              label="Business Type" 
              value={mappingForm.business_type_id} 
              onChange={e=>setMappingForm({ ...mappingForm, business_type_id: e.target.value })}
              displayEmpty
            >
              {businessTypes.length === 0 && (
                <MenuItem disabled>
                  <Typography variant="body2" color="text.secondary">Loading business types...</Typography>
                </MenuItem>
              )}
              {businessTypes.map(bt => {
                const value = bt.global_business_type_id ?? bt.id; // prefer global id if present
                const label = bt.name || bt.global_name;
                return (
                  <MenuItem key={`${bt.id}`} value={value}>{label}</MenuItem>
                );
              })}
            </Select>
          </FormControl>
          <FormControl size="small">
            <InputLabel>Plan</InputLabel>
            <Select label="Plan" value={mappingForm.plan_code} onChange={e=>setMappingForm({ ...mappingForm, plan_code:e.target.value })}>
              {plans.map(plan => (
                <MenuItem key={plan.code} value={plan.code}>
                  {plan.name} ({plan.code})
                </MenuItem>
              ))}
              {plans.length === 0 && PLAN_CODES.map(c=> 
                <MenuItem key={c} value={c}>{c}</MenuItem>
              )}
            </Select>
          </FormControl>
          <FormControlLabel control={<Switch checked={mappingForm.is_active} onChange={e=>setMappingForm({ ...mappingForm, is_active:e.target.checked })} />} label="Active" />
          <Button 
            variant="contained" 
            onClick={upsertMapping}
            sx={{ mr: 1 }}
          >
            {editingMappingId ? 'Update Mapping' : 'Save Mapping'}
          </Button>
          {editingMappingId && (
            <Button 
              variant="outlined" 
              color="secondary"
              onClick={cancelMappingEdit}
            >
              Cancel Edit
            </Button>
          )}
        </Box>
        {mappingError && (
          <Typography color="error" variant="body2" sx={{ mt: 1 }}>{mappingError}</Typography>
        )}
        <Divider sx={{ my:2 }} />
        <Typography>Existing Mappings for {countryCode}:</Typography>
        {mappings.map(m => (
          <Box key={m.id} mt={1} display="flex" alignItems="center" justifyContent="space-between">
            <Typography>
              {`${m.business_type_name} -> ${m.plan_code} | active: ${String(m.is_active)}`}
            </Typography>
            <Button 
              size="small" 
              variant="outlined"
              color="primary"
              onClick={() => editMapping(m)}
              disabled={editingMappingId === m.id}
            >
              {editingMappingId === m.id ? 'Editing...' : 'Edit'}
            </Button>
          </Box>
        ))}
      </Paper>
  )}
    </Box>
  );
}
