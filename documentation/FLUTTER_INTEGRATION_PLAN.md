# Flutter Integration Plan - REST API Migration

## Migration Overview

We're migrating the Flutter app from Firebase to our new REST API backend. This involves:

1. **Replace Firebase Services** with HTTP API calls
2. **Update Authentication Flow** to use JWT tokens
3. **Modify Data Fetching** from Firestore queries to REST endpoints
4. **Implement State Management** for API responses
5. **Add Error Handling** for HTTP responses

## Phase 1: Add HTTP Dependencies

First, we need to add HTTP client dependencies to `pubspec.yaml`:

```yaml
dependencies:
  # Existing dependencies...
  http: ^1.1.0
  dio: ^5.3.2  # Alternative HTTP client with interceptors
  flutter_secure_storage: ^9.0.0  # For storing JWT tokens securely
  provider: ^6.0.5  # For state management
```

## Phase 2: Create API Service Layer

### 1. Base API Client
Create `lib/src/services/api_client.dart` - HTTP client with authentication

### 2. Authentication Service
Update `lib/src/services/auth_service.dart` - Replace Firebase Auth with REST API

### 3. Data Services
Create REST API services for:
- Categories Service
- Cities Service  
- Vehicle Types Service
- Requests Service

## Phase 3: Update Authentication Flow

### 1. Login Screen Updates
- Replace Firebase Auth calls with REST API
- Store JWT tokens securely
- Handle API error responses

### 2. Registration Flow
- Update registration to use REST API
- Remove Firebase-specific code
- Update validation logic

## Phase 4: Update Data Fetching

### 1. Home Screen
- Replace Firestore queries with REST API calls
- Update request listing logic
- Add pagination support

### 2. Categories/Cities
- Update dropdown data fetching
- Cache API responses locally

## Phase 5: Testing & Validation

- Test all authentication flows
- Verify data consistency
- Performance testing
- Error handling validation

---

## Implementation Start

Let's begin with Phase 1 - adding dependencies and creating the base API service layer.
