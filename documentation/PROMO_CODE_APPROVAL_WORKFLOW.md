# 🎫 Promo Code Approval Workflow System

## Overview

This system implements a hierarchical approval workflow for promotional codes where:
- **Country Admins** can create promo codes for their regions
- **Super Admins** must approve all promo codes before they become active
- **Automated notifications** keep everyone informed of the approval process

## 🏗️ System Architecture

### **User Roles & Permissions**

#### **Super Admin**
- **Global access** to all countries and features
- **Approve/Reject** promo codes created by country admins
- **Modify promo codes** during approval (title, description, value, max uses)
- **Full analytics** and system management
- **Manage country admins** and their permissions

#### **Country Admin**
- **Limited to specific countries** (e.g., LK, IN, BD, etc.)
- **Create promo codes** for their assigned countries
- **View status** of their submitted promo codes
- **Receive notifications** about approval/rejection
- **Access country-specific analytics**

### **Promo Code Statuses**

1. **`pendingApproval`** - Created by country admin, waiting for super admin review
2. **`active`** - Approved by super admin and available for use
3. **`rejected`** - Rejected by super admin with reason
4. **`disabled`** - Manually disabled by super admin
5. **`expired`** - Automatically expired based on end date

## 🔄 Workflow Process

### **Step 1: Country Admin Creates Promo Code**
```dart
// Country admin creates promo code
final promoCodeId = await PromoCodeService.createPromoCodeForApproval(
  promoCode,
  adminId,
  countryCode,
);
```

**What happens:**
- Promo code is saved with `pendingApproval` status
- Super admins receive notification
- Country admin sees "Pending Approval" in their dashboard

### **Step 2: Super Admin Reviews**
```dart
// Super admin can approve
await PromoCodeService.approvePromoCode(
  promoCodeId,
  superAdminId,
  modifiedTitle: "Updated title", // Optional modifications
);

// Or reject
await PromoCodeService.rejectPromoCode(
  promoCodeId,
  superAdminId,
  "Reason for rejection",
);
```

**What happens:**
- Status changes to `active` or `rejected`
- Country admin receives notification
- If approved, promo code becomes available for users

### **Step 3: User Application**
```dart
// Users can only use approved promo codes
final result = await PromoCodeService.validateAndApplyPromoCode(
  "SUMMER2025",
  userType,
  countryCode,
);
```

## 📱 UI Components

### **Country Admin Interface**
- **My Promo Codes Tab**: View all created promo codes with status
- **Create New Tab**: Form to create new promo codes
- **Status Indicators**: Pending, Approved, Rejected with appropriate colors
- **Notification System**: Receive approval/rejection notifications

### **Super Admin Interface**
- **Pending Approvals List**: All promo codes waiting for approval
- **Detailed Review Cards**: Full promo code information for decision making
- **Approval/Rejection Actions**: Approve with modifications or reject with reason
- **Analytics Dashboard**: Usage statistics and approval metrics

## 🔧 Implementation Details

### **Database Structure**

#### **Enhanced PromoCode Model**
```javascript
{
  // Basic fields
  code: "SUMMER2025",
  title: "Summer Special",
  description: "50% off for summer",
  type: "percentageDiscount",
  value: 50,
  
  // Approval workflow fields
  status: "pendingApproval",
  createdBy: "country_admin_uid",
  approvedBy: "super_admin_uid",
  approvedAt: timestamp,
  rejectionReason: "Discount too high",
  createdByCountry: "LK",
  
  // Usage and validity
  maxUses: 1000,
  currentUses: 0,
  validFrom: timestamp,
  validTo: timestamp,
  applicableUserTypes: ["rider", "business"],
  applicableCountries: ["LK"],
  
  timestamps...
}
```

#### **Admin Users Collection**
```javascript
{
  uid: "admin_user_id",
  email: "admin@example.com",
  role: "country_admin", // or "super_admin"
  countries: ["LK", "IN"], // Countries this admin manages
  permissions: [
    "create_promo_codes",
    "view_country_analytics"
  ],
  createdAt: timestamp,
  updatedAt: timestamp
}
```

#### **Admin Notifications Collection**
```javascript
{
  recipientId: "admin_uid",
  type: "promo_code_approval_request",
  title: "Promo Code Approval Required",
  message: "Country admin from LK created promo code...",
  promoCodeId: "promo_code_id",
  isRead: false,
  createdAt: timestamp
}
```

### **Security Rules**

```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Promo codes - tiered access
    match /promoCodes/{promoId} {
      allow read: if request.auth != null;
      allow create: if isCountryAdmin() || isSuperAdmin();
      allow update: if isSuperAdmin() || 
        (isCountryAdmin() && resource.data.createdBy == request.auth.uid);
    }
    
    // Admin users - restricted access
    match /admin_users/{adminId} {
      allow read, write: if isSuperAdmin() || 
        request.auth.uid == adminId;
    }
    
    // Admin notifications
    match /admin_notifications/{notificationId} {
      allow read, write: if request.auth.uid == resource.data.recipientId ||
        isSuperAdmin();
    }
    
    // Helper functions
    function isCountryAdmin() {
      return exists(/databases/$(database)/documents/admin_users/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/admin_users/$(request.auth.uid)).data.role == 'country_admin';
    }
    
    function isSuperAdmin() {
      return exists(/databases/$(database)/documents/admin_users/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/admin_users/$(request.auth.uid)).data.role == 'super_admin';
    }
  }
}
```

## 🚀 Setup Instructions

### **1. Initialize Admin Roles**
```bash
# Run the initialization script
node initialize_subscription_system.js
```

This creates:
- Sample admin users (replace UIDs with real ones)
- Permission structure
- Demo promo codes (pre-approved)

### **2. Configure Admin Access**

**Create Super Admin:**
```javascript
// In Firebase Console or Admin SDK
await db.collection('admin_users').doc('SUPER_ADMIN_UID').set({
  email: 'superadmin@yourdomain.com',
  role: 'super_admin',
  countries: [], // All countries
  permissions: [
    'approve_promo_codes',
    'manage_subscriptions',
    'view_all_analytics',
    'manage_country_admins'
  ],
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

**Create Country Admin:**
```javascript
await db.collection('admin_users').doc('COUNTRY_ADMIN_UID').set({
  email: 'admin.lk@yourdomain.com',
  role: 'country_admin',
  countries: ['LK'], // Sri Lanka only
  permissions: [
    'create_promo_codes',
    'view_country_analytics',
    'manage_country_subscriptions'
  ],
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

### **3. Integrate UI Components**

**For Country Admins:**
```dart
// Add to country admin dashboard
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => CountryAdminPromoCodeScreen(
      adminCountryCode: 'LK', // Admin's country
    ),
  ),
);
```

**For Super Admins:**
```dart
// Add to super admin dashboard
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => SuperAdminPromoApprovalScreen(),
  ),
);
```

## 📊 Benefits of This System

### **Quality Control**
- All promo codes reviewed before going live
- Prevents excessive discounts or inappropriate offers
- Maintains brand consistency across regions

### **Regional Management**
- Country admins understand local market conditions
- Targeted promotions for specific regions
- Localized pricing and campaigns

### **Audit Trail**
- Complete history of who created and approved what
- Rejection reasons for learning and improvement
- Usage analytics for measuring effectiveness

### **Scalability**
- Easy to add new countries and admins
- Automated notification system
- Self-service promo code creation with oversight

## 🔍 Monitoring & Analytics

### **Super Admin Dashboard Metrics**
- Total promo codes pending approval
- Approval/rejection ratios by country
- Most effective promo code types
- Usage statistics across all regions

### **Country Admin Dashboard Metrics**
- Promo codes created vs approved
- Usage statistics for approved codes
- Performance metrics by promo type
- Suggestions for future campaigns

## 🎯 Best Practices

1. **Clear Guidelines**: Provide country admins with promo code creation guidelines
2. **Quick Turnaround**: Super admins should review within 24-48 hours
3. **Constructive Feedback**: Always provide detailed rejection reasons
4. **Regular Reviews**: Monitor promo code performance and adjust limits
5. **Seasonal Planning**: Plan promotional campaigns in advance

This approval workflow ensures quality control while empowering regional admins to create targeted campaigns for their markets!
