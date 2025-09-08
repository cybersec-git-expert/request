import axios from 'axios';

// Prefer setting VITE_API_BASE_URL in .env files.
// You can override at runtime via localStorage.setItem('ADMIN_API_BASE_URL', 'https://api.alphabet.lk')
const envBase = (import.meta.env.VITE_API_BASE_URL || 'https://api.alphabet.lk');
let base = envBase;
if (typeof window !== 'undefined') {
  const override = localStorage.getItem('ADMIN_API_BASE_URL');
  if (override && typeof override === 'string') {
    base = override;
  }
}
export const API_BASE_URL = base.replace(/\/$/, '');

let accessToken = null;
let refreshToken = null;
let userId = null;

export function setAuthSession({ token, refresh, id }) {
  if (token) { accessToken = token; localStorage.setItem('accessToken', token); }
  if (refresh) { refreshToken = refresh; localStorage.setItem('refreshToken', refresh); }
  if (id) { userId = id; localStorage.setItem('userId', id); }
}

export function clearAuthSession() {
  accessToken = null; refreshToken = null; userId = null;
  localStorage.removeItem('accessToken');
  localStorage.removeItem('refreshToken');
  localStorage.removeItem('userId');
}

(() => {
  const a = localStorage.getItem('accessToken');
  const r = localStorage.getItem('refreshToken');
  const u = localStorage.getItem('userId');
  if (a) accessToken = a; if (r) refreshToken = r; if (u) userId = u;
})();

const api = axios.create({ baseURL: API_BASE_URL + '/api', timeout: 15000 });
if (typeof window !== 'undefined') {
  // Minimal visibility into which API host the admin is using
  console.info('[Admin API] Base URL:', API_BASE_URL + '/api');
}

api.interceptors.request.use(cfg => { if (accessToken) cfg.headers.Authorization = `Bearer ${accessToken}`; return cfg; });

let refreshing = null;
async function attemptRefresh() {
  if (refreshing) return refreshing;
  if (!refreshToken || !userId) return null;
  refreshing = api.post('/auth/refresh', { userId, refreshToken })
    .then(res => { const { token, refreshToken: newRefresh } = res.data.data || {}; if (token) setAuthSession({ token, refresh: newRefresh, id: userId }); return token; })
    .catch(() => null)
    .finally(() => { refreshing = null; });
  return refreshing;
}

api.interceptors.response.use(r => r, async (error) => {
  const original = error.config;
  if (error.response && error.response.status === 401 && !original._retry) {
    original._retry = true;
    const newToken = await attemptRefresh();
    if (newToken) { original.headers.Authorization = `Bearer ${newToken}`; return api(original); } else { clearAuthSession(); }
  }
  return Promise.reject(error);
});

export default api;
