import React, { createContext, useContext, useEffect, useState } from 'react';
import authService from '../services/authService';

const AuthContext = createContext();

export { AuthContext }; // Export the context

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = authService.onChange(({ user }) => { setUser(user); setLoading(false); });
    setLoading(false);
    return unsub;
  }, []);

  const logout = async () => { await authService.logout(); };

  const value = {
  user,
  adminData: user, // Alias for user - many components expect adminData
  loading,
  logout,
  isAuthenticated: !!user,
  isSuperAdmin: user?.role === 'super_admin',
  isCountryAdmin: user?.role === 'country_admin',
  userRole: user?.role,
  userCountry: user?.country
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};
