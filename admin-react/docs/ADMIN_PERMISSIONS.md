# 🔐 Admin Role Permissions System

## Overview
The admin system now has role-based permissions to control who can create what type of admin users.

## 🎯 Permission Matrix

### Super Admin 👑
- **Full Access**: Can create and manage all types of admin users
- **Global Scope**: Can manage admins for any country
- **Create Permissions**: 
  - ✅ Super Admins
  - ✅ Country Admins  
  - ✅ Any department users
- **Special Actions**: 
  - ✅ Password reset for any admin
  - ✅ Bulk password reset
  - ✅ Delete admin users
  - ✅ Activate/Deactivate admins

### Country Admin 🌍
- **Regional Access**: Can only manage admins for their assigned country
- **Limited Creation**: Cannot create Super Admins
- **Create Permissions**:
  - ❌ Super Admins (restricted)
  - ✅ Country Admins (same country only)
  - ✅ Department users (same country only)
- **Actions Available**:
  - ✅ Edit admin users (same country)
  - ❌ Delete admin users (super admin only)
  - ❌ Password reset (super admin only)
  - ✅ View admin users (same country)

## 🛡️ Security Features

### Role-Based UI
- **Add Button**: Only visible to Super Admin and Country Admin
- **Role Dropdown**: Country Admin can only select "Country Admin"
- **Country Selection**: Country Admin locked to their assigned country
- **Action Buttons**: Delete/Reset buttons only for Super Admin

### Validation Layer
- **Form Validation**: Prevents country admins from creating super admins
- **Server-Side**: Firebase rules should also enforce these permissions
- **Error Messages**: Clear feedback when permissions are exceeded

### Visual Indicators
- **Info Alerts**: Show current user's role and permissions
- **Dialog Hints**: Explain limitations in the create/edit form
- **Button Tooltips**: Clear action descriptions
- **Role Chips**: Visual distinction between Super Admin and Country Admin

## 🚀 Usage Examples

### For Super Admin
```
Login → Admin Users → Add New Admin User
- Can select any role (Super Admin or Country Admin)
- Can select any country
- Can perform all actions (edit, delete, reset passwords)
```

### For Country Admin (LK)
```
Login → Admin Users → Add New Admin User  
- Role dropdown only shows "Country Admin"
- Country is locked to "LK" 
- Cannot see password reset or delete buttons
- Can only edit users in same country
```

## 🔧 Technical Implementation

### Frontend Restrictions
- **AdminUsers.jsx**: Role-based button visibility
- **Form Validation**: Prevents invalid role assignments
- **UI Feedback**: Clear error messages and hints

### Backend Security (TODO)
- **Firebase Rules**: Should mirror frontend restrictions
- **API Validation**: Server-side permission checks
- **Audit Logging**: Track admin user creation/changes

## 📋 Permission Summary

| Action | Super Admin | Country Admin |
|--------|-------------|---------------|
| Create Super Admin | ✅ | ❌ |
| Create Country Admin | ✅ | ✅ (same country) |
| Edit Any Admin | ✅ | ✅ (same country) |
| Delete Admin | ✅ | ❌ |
| Reset Passwords | ✅ | ❌ |
| View All Countries | ✅ | ❌ |
| Bulk Actions | ✅ | ❌ |

## 🔄 Migration Notes

### Existing Users
- Current admin users retain their existing permissions
- No data migration required
- UI will automatically adapt based on user role

### Testing
- Test with both Super Admin and Country Admin accounts
- Verify form restrictions work correctly  
- Confirm API calls respect permission boundaries

---

*This system ensures proper separation of duties while maintaining administrative efficiency.*
