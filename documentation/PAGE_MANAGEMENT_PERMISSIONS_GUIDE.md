// Page Management Permission Flow Explanation

## 🌟 **SUPER ADMIN (Global Access)**
**Email:** superadmin@request.lk
**Country:** Global  
**Role:** super_admin

### **What Super Admin Can Do:**

#### **1. Centralized Pages (Global Pages):**
- ✅ Create pages that apply to ALL countries
- ✅ Edit any centralized page
- ✅ Approve centralized pages from country admins  
- ✅ Publish centralized pages to make them live globally
- ✅ Delete centralized pages (affects all countries)
- ✅ Auto-approval: Super admin pages don't need approval

#### **2. Country-Specific Pages:**
- ✅ View pages from ALL countries
- ✅ Approve country-specific pages from any country admin
- ✅ Edit pages for any country
- ✅ Publish pages for any country
- ✅ Override country admin decisions

---

## 🏴 **COUNTRY ADMIN (Country-Specific Access)**
**Email:** rimaz.m.flyil@gmail.com
**Country:** LK (Sri Lanka)
**Role:** country_admin

### **What Country Admin Can Do:**

#### **1. Centralized Pages (Global Pages):**
- ✅ Create centralized pages (requires super admin approval)
- ✅ Edit centralized pages (requires super admin approval)
- ❌ Cannot directly publish centralized pages
- ❌ Cannot delete centralized pages
- ✅ Submit centralized pages for approval

#### **2. Country-Specific Pages (LK only):**
- ✅ Create pages specific to Sri Lanka (LK)
- ✅ Edit pages for Sri Lanka only
- ✅ Submit LK pages for approval
- ❌ Cannot see pages from other countries
- ❌ Cannot approve their own pages (needs super admin)

#### **3. Template Pages:**
- ✅ Use templates to create country-specific versions
- ✅ Customize templates for Sri Lanka
- ✅ Submit customized templates for approval

---

## 🔄 **Permission Flow Examples:**

### **Example 1: LK Admin Creates "Privacy Policy - Sri Lanka"**
```
1. LK Admin logs in → sees only LK-related content
2. Creates "Privacy Policy - Sri Lanka" 
3. Status: Draft → Pending (submitted for approval)
4. Super Admin sees it in "Pending Approval" 
5. Super Admin approves → Status: Approved
6. Super Admin publishes → Status: Published
7. Now live for Sri Lanka users only
```

### **Example 2: LK Admin Creates "How It Works" (Centralized)**
```
1. LK Admin creates centralized page
2. System warns: "This will affect ALL countries"
3. Status: Draft → Pending (requires super admin approval)
4. Super Admin reviews content
5. Super Admin approves/publishes globally
6. Now live for ALL countries
```

### **Example 3: Super Admin Creates Global Page**
```
1. Super Admin creates centralized page
2. Status: Auto-approved (super admin privilege)
3. Super Admin publishes immediately
4. Live across all countries instantly
```

---

## 🛡️ **Security & Access Control:**

### **Data Filtering:**
- Country admins only see their country's data
- Super admin sees all countries' data
- Permission checks on every action

### **Page Creation Rules:**
- **Centralized pages:** Both can create, super admin approves
- **Country pages:** Country admin for their country only
- **Templates:** Country admin can customize for their country

### **Approval Workflow:**
- Country admin creates → Super admin approves → Published
- Super admin creates → Auto-approved → Can publish immediately

---

## 📋 **Permission Structure in Database:**

```javascript
// Super Admin Permissions
{
  role: "super_admin",
  country: "Global",
  permissions: {
    contentManagement: true,     // Can access page management
    adminUsersManagement: true,  // Can manage other admins
    // ... other permissions
  }
}

// Country Admin Permissions  
{
  role: "country_admin", 
  country: "LK",
  permissions: {
    contentManagement: true,     // Can access page management
    adminUsersManagement: false, // Cannot manage other admins
    // ... other permissions
  }
}
```

This ensures country admins can only manage content for their assigned country while super admins have global oversight!
