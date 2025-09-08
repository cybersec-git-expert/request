# Flutter Migration Cleanup Plan

## Firebase Dependencies Removed - Files Need Updating

### Phase 1: Remove Firebase-only Services (Safe to delete)
These services are pure Firebase and have REST API equivalents:

- `lib/src/services/auth_service.dart` ❌ (replaced by `rest_auth_service.dart`)
- `lib/src/services/enhanced_auth_service.dart` ❌ (replaced by `rest_auth_service.dart`)
- `lib/src/services/contact_verification_service.dart` ❌ (OTP handled by backend)
- `lib/src/services/sms_auth_service.dart` ❌ (SMS handled by backend)
- `lib/src/services/file_upload_service.dart` ❌ (Firebase Storage)
- `lib/src/services/image_upload_service.dart` ❌ (Firebase Storage)

### Phase 2: Remove Subscription/Payment Firebase Services
These are complex Firebase services that need backend implementation:

- `lib/src/services/subscription_service.dart` ❌ (needs backend REST API)
- `lib/src/services/usage_limiter_service.dart` ❌ (depends on subscription service)
- `lib/src/services/payment_methods_service.dart` ❌ (needs backend implementation)
- `lib/src/services/promo_code_service.dart` ❌ (needs backend implementation)

### Phase 3: Remove Other Firebase Services
- `lib/src/services/comprehensive_notification_service.dart` ❌
- `lib/src/services/notification_service.dart` ❌
- `lib/src/services/messaging_service.dart` ❌
- `lib/src/services/legal_documents_service.dart` ❌
- `lib/src/services/pricing_service.dart` ❌

### Phase 4: Convert Core Services to REST
- `lib/src/services/category_service.dart` ✅ (convert to use `rest_category_service.dart`)
- `lib/src/services/country_service.dart` ✅ (convert to use REST API)
- `lib/src/services/content_service.dart` ✅ (convert to use REST API)
- `lib/src/services/vehicle_service.dart` ✅ (convert to use REST API)
- `lib/src/services/enhanced_user_service.dart` ✅ (convert to use REST API)
- `lib/src/services/enhanced_request_service.dart` ✅ (convert to use `rest_request_service.dart`)

### Phase 5: Remove Firebase-dependent Screens
Many screens import Firebase services and will need updates or removal:

- All admin screens (they use Firestore directly)
- Subscription-related screens
- Business verification screens
- Driver verification screens

### Phase 6: Update Model Classes
Remove Firebase imports and Timestamp usage:
- `lib/src/models/*.dart` files need Timestamp replaced with DateTime

## Current Status
- ✅ REST API services created
- ✅ Main app updated to use ServiceManager
- ❌ Need to remove/convert Firebase services
- ❌ Need to update screens to use REST services
- ❌ Need to fix model classes
