import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import { CssBaseline } from '@mui/material';
import { AuthProvider } from './contexts/AuthContext';
import { CountryFilterProvider } from './hooks/useCountryFilter.jsx';
import ProtectedRoute from './components/ProtectedRoute';
import Layout from './components/Layout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Products from './pages/Products';
import Categories from './pages/Categories';
import Brands from './pages/Brands';
import Variables from './pages/Variables';
import Countries from './pages/Countries';
import Cities from './pages/Cities';
import PaymentMethods from './pages/PaymentMethods';
import AdminUsers from './pages/AdminUsers';
import ModuleManagement from './pages/ModuleManagement';
import BusinessVerificationEnhanced from './pages/BusinessVerificationEnhanced';
import BusinessTypesManagement from './pages/BusinessTypesManagement';
import GlobalBusinessTypesManagement from './pages/GlobalBusinessTypesManagement';
import DriverVerificationEnhanced from './pages/DriverVerificationEnhanced';
import Vehicles from './pages/Vehicles';
import RequestsModule from './pages/RequestsModule';
import ResponsesModule from './pages/ResponsesModule';
import PriceListingsModule from './pages/PriceListingsModule';
import CategoriesModule from './pages/CategoriesModule';
import DriverVerificationModule from './pages/DriverVerificationModule';
import VehiclesModule from './pages/VehiclesModule';
import VariablesModule from './pages/VariablesModule';
import SubcategoriesModule from './pages/SubcategoriesModule';
import PagesModule from './pages/PagesModule';
import CentralizedPagesModule from './pages/CentralizedPagesModule';
// Removed: Subscriptions module
import PromoCodes from './pages/PromoCodes';
import CountryProductManagement from './pages/CountryProductManagement';
import CountryCategoryManagement from './pages/CountryCategoryManagement';
import CountrySubcategoryManagement from './pages/CountrySubcategoryManagement';
import CountryBrandManagement from './pages/CountryBrandManagement';
import CountryVariableTypeManagement from './pages/CountryVariableTypeManagement';
import SMSConfigurationModule from './pages/SMSConfigurationModule';
import SuperAdminSMSManagement from './pages/SuperAdminSMSManagement';
import DebugAuth from './components/DebugAuth';
import SubscriptionAdmin from './components/subscriptions/SubscriptionAdmin.jsx';
// Removed: SubscriptionPlansNew
import BusinessPriceManagement from './pages/BusinessPriceManagement';
import PriceComparisonPage from './pages/PriceComparisonPage';
import BannersModule from './pages/BannersModule.jsx';
// Removed: SubscriptionManagement, BusinessTypeBenefits, EnhancedBusinessBenefitsManagement

const theme = createTheme({
  palette: {
    primary: {
      main: '#1976d2',
    },
    secondary: {
      main: '#dc004e',
    },
  },
});

function App() {
  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <AuthProvider>
        <CountryFilterProvider>
          <Router>
            <Routes>
              <Route path="/login" element={<Login />} />
              <Route
                path="/*"
                element={
                  <ProtectedRoute>
                    <Layout />
                  </ProtectedRoute>
                }
            >
              <Route index element={<Dashboard />} />
              <Route path="debug" element={<DebugAuth />} />
              <Route path="modules" element={<ModuleManagement />} />
              <Route path="products" element={<Products />} />
              <Route path="categories" element={<CategoriesModule />} />
              <Route path="brands" element={<Brands />} />
              <Route path="variables" element={<Variables />} />
              <Route path="variable-types" element={<VariablesModule />} />
              <Route path="subcategories" element={<SubcategoriesModule />} />
              <Route path="countries" element={<Countries />} />
              <Route path="country-data" element={<Countries />} />
              <Route path="cities" element={<Cities />} />
              <Route path="payment-methods" element={<PaymentMethods />} />
              <Route path="admin-users" element={<AdminUsers />} />
              <Route path="admin-management" element={<AdminUsers />} />
              <Route path="users" element={<AdminUsers />} />
              <Route path="businesses" element={<BusinessVerificationEnhanced />} />
              <Route path="business-management" element={<BusinessVerificationEnhanced />} />
              <Route path="business-types" element={<GlobalBusinessTypesManagement />} />
              <Route path="country-business-types" element={<BusinessTypesManagement />} />
              <Route path="drivers" element={<DriverVerificationEnhanced />} />
              <Route path="vehicles" element={<Vehicles />} />
              <Route path="country-vehicle-types" element={<Vehicles />} />
              <Route path="vehicles-module" element={<VehiclesModule />} />
              <Route path="cars" element={<VehiclesModule />} />
              <Route path="bikes" element={<VehiclesModule />} />
              <Route path="driver-verification" element={<DriverVerificationEnhanced />} />
              <Route path="requests" element={<RequestsModule />} />
              <Route path="responses" element={<ResponsesModule />} />
              <Route path="price-listings" element={<PriceListingsModule />} />
              {/* Removed: Subscriptions admin */}
              <Route path="promo-codes" element={<PromoCodes />} />
              <Route path="pages" element={<PagesModule />} />
              <Route path="centralized-pages" element={<CentralizedPagesModule />} />
              <Route path="banners" element={<BannersModule />} />
              <Route path="global-banners" element={<BannersModule />} />
              
              {/* Country Management Routes */}
              <Route path="country-products" element={<CountryProductManagement />} />
              <Route path="country-categories" element={<CountryCategoryManagement />} />
              <Route path="country-subcategories" element={<CountrySubcategoryManagement />} />
              <Route path="country-brands" element={<CountryBrandManagement />} />
              <Route path="country-variable-types" element={<CountryVariableTypeManagement />} />
              <Route path="sms-config" element={<SMSConfigurationModule />} />
              <Route path="sms-management" element={<SuperAdminSMSManagement />} />
              
              {/* Add more protected routes here */}
              {/* Subscriptions admin */}
              <Route path="subscription-management" element={<SubscriptionAdmin />} />
              
              {/* Price Management Routes */}
              <Route path="business-price-management" element={<BusinessPriceManagement />} />
              <Route path="price-comparison" element={<PriceComparisonPage />} />
              {/* Removed: business-type-benefits and enhanced-business-benefits routes */}
            </Route>
          </Routes>
        </Router>
        </CountryFilterProvider>
      </AuthProvider>
    </ThemeProvider>
  );
}

export default App;
