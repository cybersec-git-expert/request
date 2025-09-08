# Role-Based Registration System

This document outlines the complete role-based registration and verification system implemented in the Request Marketplace app.

## Overview

The app supports four user roles, each with different capabilities and verification requirements:

1. **General User** - Basic app usage (no verification required)
2. **Driver** - Ride-hailing services (full verification required)
3. **Delivery Partner** - Package/food delivery services (full verification required)  
4. **Business Owner** - Offer products/services (business verification required)

## Registration Flow

### 1. Initial Registration
- User completes phone/email verification
- User completes basic profile (name, optional email)
- **NEW**: User is automatically redirected to role selection

### 2. Role Selection
- User selects their primary role from available options
- Each role displays features and verification requirements
- User can add multiple roles over time

### 3. Role-Specific Verification

#### Driver Verification
- **Personal Information**: License details, experience
- **Vehicle Information**: Make, model, year, license plate
- **Document Upload**: Driver license, vehicle registration, insurance
- **Photo Verification**: Profile photo, vehicle photos

#### Business Verification  
- **Business Information**: Name, type, address, contact details
- **Operating Hours**: Weekly schedule or 24/7 operation
- **Documentation**: Business license (optional), business photos
- **Verification Timeline**: 1-3 business days

#### Delivery Partner Verification
- **Company Information**: Service name, address, contact person
- **Service Capabilities**: Delivery types, vehicle fleet, special services
- **Availability**: Service hours and areas covered
- **Documentation**: Business license, insurance, vehicle photos
- **Verification Timeline**: 2-5 business days

## Implementation Details

### Key Screens
- `role_selection_screen.dart` - Initial role selection interface
- `driver_verification_screen.dart` - Comprehensive driver setup (existing)
- `business_verification_screen.dart` - **NEW** Business registration flow
- `delivery_verification_screen.dart` - **NEW** Delivery partner setup
- `verification_status_screen.dart` - **NEW** View all role statuses

### Backend Integration
- Uses existing `EnhancedUserService` for role management
- Supports multiple roles per user with verification tracking
- File upload integration for document verification
- Admin approval workflow through existing admin dashboard

### Data Models
- `UserModel` - Supports multiple roles with verification status
- `DriverData` - Complete driver information and vehicle details
- `BusinessData` - Business information with hours and licensing
- `DeliveryData` - Delivery service capabilities and availability
- `VerificationStatus` - Pending, Approved, Rejected, Not Required

### Navigation Updates
- Profile completion now routes to role selection instead of main dashboard
- All verification screens properly integrated with navigation system
- Support for adding additional roles after initial setup

## Verification Process

### For Admins
1. Users submit verification requests through mobile app
2. Admin receives verification data through existing web dashboard
3. Admin reviews documents and information
4. Admin approves/rejects with optional notes
5. Users receive notifications of verification status changes

### For Users
1. Complete role-specific verification form
2. Upload required documents and photos
3. Submit for review
4. Receive status updates
5. Access role-specific features once approved

## Features

### Multi-Role Support
- Users can hold multiple roles simultaneously
- Switch between roles in the app
- Each role maintains separate verification status
- Role-specific features and dashboards

### Document Management
- Secure file upload to Firebase Storage
- Image compression and optimization
- Support for multiple document types
- Admin dashboard for document review

### Status Tracking
- Real-time verification status updates
- Detailed verification progress
- Admin notes and feedback
- Resubmission capability for rejected applications

## Error Handling
- Comprehensive form validation
- Upload progress indicators  
- Offline capability consideration
- User-friendly error messages
- Graceful fallbacks for network issues

## Security Considerations
- Document access restricted to authorized admins
- Secure file upload with proper validation
- User data encryption in transit and at rest
- Role-based access control for app features
