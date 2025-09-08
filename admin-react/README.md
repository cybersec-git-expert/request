# Request Marketplace Admin Panel (React + Vite)

A modern, scalable admin panel built with React and Vite for the Request Marketplace platform. This admin system provides role-based access control with country-specific data management.

## Features

### 🔐 Authentication & Authorization
- Firebase Authentication integration
- Role-based access control (Super Admin vs Country Admin)
- Secure admin user management

### 🌍 Country-Specific Data Management
- **Super Admin**: Global access to all countries and system settings
- **Country Admin**: Limited to specific country's businesses, drivers, and legal documents
- **Centralized Products**: All admins can manage the global product database

### 📱 Mobile App Integration
- Privacy policies and terms of service per country
- Users see content specific to their registered country
- Centralized product database for global consistency

### 🛠 Admin Features
- Dashboard with country-specific statistics
- Master Products management (centralized)
- Business management (country-filtered)
- Driver management (country-filtered)
- Legal documents management (privacy policies, terms of service)
- Admin user management (Super Admin only)

## Tech Stack

- **Frontend**: React 18 + Vite
- **UI Framework**: Material-UI (MUI)
- **Authentication**: Firebase Auth
- **Database**: Firebase Firestore
- **Routing**: React Router v6
- **State Management**: React Context
- **Forms**: React Hook Form

## Setup Instructions

### 1. Install Dependencies
```bash
cd admin-react
npm install
```

### 2. Firebase Setup
The Firebase configuration is already included in `src/firebase/config.js` with your project credentials.

### 3. Create Super Admin User
Run the setup script to create your first super admin:
```bash
npm run setup-admin
```

### 4. Start Development Server
```bash
npm run dev
```

The admin panel will be available at `http://localhost:5173`

## Project Structure

```
admin-react/
├── src/
│   ├── components/          # Reusable components
│   │   ├── Layout.jsx       # Main layout with sidebar
│   │   └── ProtectedRoute.jsx
│   ├── contexts/           # React contexts
│   │   └── AuthContext.jsx # Authentication context
│   ├── firebase/           # Firebase configuration
│   │   ├── config.js       # Firebase setup
│   │   └── auth.js         # Authentication utilities
│   ├── pages/              # Page components
│   │   ├── Dashboard.jsx   # Main dashboard
│   │   ├── Login.jsx       # Login page
│   │   └── PrivacyTerms.jsx # Legal documents
│   └── App.jsx            # Main app component
```

## Admin Roles

### Super Admin
- Access to all countries' data
- Can create and manage other admin users
- System-wide configuration access
- Global statistics and analytics

### Country Admin
- Limited to specific country's data
- Can manage businesses and drivers in their country
- Can create country-specific legal documents
- Cannot access other countries' data

## Data Structure

### Firestore Collections

#### admin_users
```javascript
{
  name: "John Doe",
  email: "admin@example.com",
  role: "super_admin", // or "country_admin"
  country: "United States", // null for super_admin
  isActive: true,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

#### legal_documents
```javascript
{
  type: "privacy_policy", // privacy_policy, terms_of_service, etc.
  country: "United States",
  title: "Privacy Policy",
  content: "Full document content...",
  version: "1.0",
  createdAt: timestamp,
  updatedAt: timestamp,
  createdBy: "admin@example.com"
}
```

## Security Features

- Firebase Authentication for secure login
- Role-based route protection
- Country-filtered data queries for non-super admins
- Secure admin user creation process
- Session management and auto-logout

## Integration with Flutter App

The Flutter mobile app will:
1. Query legal documents based on user's registered country
2. Display country-specific privacy policies and terms
3. Show requests and prices filtered by user's country
4. Access centralized product database globally

## Development Guidelines

### Adding New Pages
1. Create component in `src/pages/`
2. Add route in `App.jsx`
3. Add navigation item in `Layout.jsx`
4. Implement proper access control

### Country-Filtered Queries
Use the `getCountryFilteredQuery` utility:
```javascript
import { getCountryFilteredQuery } from '../firebase/auth';

let businessesQuery = collection(db, 'businesses');
if (!isSuperAdmin) {
  businessesQuery = getCountryFilteredQuery(businessesQuery, adminData);
}
```

## Deployment

### Build for Production
```bash
npm run build
```

### Firebase Hosting (Optional)
```bash
firebase deploy --only hosting
```

## Support

For setup issues or questions, refer to the Firebase console and ensure all Firestore security rules are properly configured for admin access.

## Next Steps

1. Complete the remaining pages (Products, Businesses, Drivers, etc.)
2. Add data export/import functionality
3. Implement audit logging
4. Add real-time notifications
5. Create comprehensive analytics dashboard

## New Subscription Plans (Normalized Table)
A new table `subscription_plans_new` was introduced (migration 021) to normalize plan storage.

Schema highlights:
- code (unique), name
- type (rider|business)
- plan_type (monthly|yearly|pay_per_click)
- price / currency / duration_days
- features (JSON array), limitations (JSON object)
- countries (string array) for scoping, null = global
- pricing_by_country JSON (future use)
- flags: is_active, is_default_plan, requires_country_pricing

Admin UI route: `/subscriptions-new` (Component `SubscriptionPlansNew.jsx`).
Provides CRUD with JSON editors for features & limitations.

## Backend capability toggles (optional)
If you want to toggle per-country respond/manage capabilities in Admin, run the backend migration once:

- From repo root:
  - Node: backend/run_add_country_business_capabilities.js

This adds columns to `country_business_types` and backfills sensible defaults for Product Seller and Delivery.
