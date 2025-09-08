import api, { setAuthSession, clearAuthSession } from './apiClient';

function mapUser(u) {
  if (!u) return null;
  let role = u.role;
  if (role === 'admin') role = 'super_admin'; // normalize legacy role
  return {
    id: u.id,
    email: u.email,
    phone: u.phone,
    role,
    country: u.country_code || u.country || null,
    emailVerified: u.email_verified,
    phoneVerified: u.phone_verified,
    displayName: u.display_name,
  isActive: u.is_active,
  permissions: u.permissions || {}
  };
}

class AuthService {
  constructor() { this.user = null; this.loading = false; this.listeners = new Set(); }
  _notify() { this.listeners.forEach(cb => cb({ user: this.user, loading: this.loading })); }
  onChange(cb) { this.listeners.add(cb); return () => this.listeners.delete(cb); }

  async login({ email, phone, password }) {
    this.loading = true; this._notify();
    try {
      const res = await api.post('/auth/login', { email, phone, password });
      const { user, token, refreshToken } = res.data.data;
      setAuthSession({ token, refresh: refreshToken, id: user.id });
      this.user = mapUser(user);
      this.loading = false; this._notify();
      return this.user;
    } catch (e) {
      this.loading = false; this._notify();
      throw new Error(e.response?.data?.error || e.message);
    }
  }

  async fetchProfile() {
    if (!this.user) return null;
    try {
      const res = await api.get('/auth/profile');
      this.user = mapUser(res.data.data);
      this._notify();
      return this.user;
    } catch {
      return null;
    }
  }

  async logout() { clearAuthSession(); this.user = null; this._notify(); }

  async sendEmailOTP(email) { const res = await api.post('/auth/send-email-otp', { email }); return res.data; }
  async verifyEmailOTP(email, otp) { const res = await api.post('/auth/verify-email-otp', { email, otp }); const { user, token, refreshToken } = res.data.data; setAuthSession({ token, refresh: refreshToken, id: user.id }); this.user = mapUser(user); this._notify(); return res.data; }
  async sendPhoneOTP(phone, countryCode) { const res = await api.post('/auth/send-phone-otp', { phone, countryCode }); return res.data; }
  async verifyPhoneOTP(phone, otp) { const res = await api.post('/auth/verify-phone-otp', { phone, otp }); const { user, token, refreshToken } = res.data.data; setAuthSession({ token, refresh: refreshToken, id: user.id }); this.user = mapUser(user); this._notify(); return res.data; }

  isAuthenticated() { return !!this.user; }
  isSuperAdmin() { return this.user?.role === 'super_admin'; }
  isCountryAdmin() { return this.user?.role === 'country_admin'; }
}

const authService = new AuthService();
export default authService;
