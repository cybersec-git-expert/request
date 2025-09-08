/// Flutter App Migration Guide: Firebase → AWS RDS PostgreSQL
/// 
/// This guide outlines the step-by-step process to migrate the Flutter mobile app
/// from Firebase to the new AWS RDS PostgreSQL backend with REST APIs.

## 🚀 **Migration Strategy**

### **Phase 1: Preparation** ✅
- ✅ Backend APIs are ready and tested
- ✅ New REST API services created
- ✅ API client configuration ready

### **Phase 2: Service Layer Migration** 🔄 (Current Phase)
Replace Firebase services with REST API services one by one:

1. **Authentication Service** - Replace Firebase Auth with JWT-based REST API
2. **Category Service** - Replace Firestore categories with REST API
3. **City Service** - Replace Firestore cities with REST API  
4. **Vehicle Service** - Replace Firestore vehicle types with REST API
5. **Request Service** - Replace Firestore requests with REST API

### **Phase 3: Screen Updates** 📱 (Next Phase)
Update Flutter screens to use new services:

1. Authentication screens (login, register, OTP)
2. Category selection screens
3. Request creation/editing screens
4. Request listing/browsing screens
5. Profile and settings screens

### **Phase 4: Testing & Deployment** 🧪 (Final Phase)
1. Integration testing
2. User acceptance testing
3. Production deployment

## 📋 **Current Status**

### **✅ Completed:**
- [x] Backend PostgreSQL database setup
- [x] REST API endpoints implemented
- [x] API client (`ApiClient`) with Dio
- [x] Basic REST auth service
- [x] New REST API services created:
  - `RestCategoryService`
  - `RestCityService` 
  - `RestVehicleTypeService`
  - `RestRequestService`

### **🔄 In Progress:**
- [ ] Update authentication flows
- [ ] Update category selection components
- [ ] Update request creation/editing
- [ ] Update request browsing

### **⏳ Pending:**
- [ ] Remove Firebase dependencies
- [ ] Update pubspec.yaml
- [ ] Integration testing
- [ ] Production deployment

## 🔧 **Implementation Steps**

### **Step 1: Update Main App Initialization**

Replace Firebase initialization with REST API initialization in `main.dart`:

```dart
// Remove:
// await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// Add:
ApiClient.instance.initialize();
await RestAuthService.instance.loadStoredAuth();
```

### **Step 2: Update Authentication Screens**

Replace `AuthService` calls with `RestAuthService`:

```dart
// Old Firebase way:
final result = await AuthService.instance.signInWithEmailPassword(email, password);

// New REST API way:
final result = await RestAuthService.instance.login(email: email, password: password);
```

### **Step 3: Update Category Components**

Replace category fetching with REST API:

```dart
// Old Firebase way:
final categories = await CategoryService.instance.getCategories();

// New REST API way:
final categories = await RestCategoryService.instance.getCategories();
```

### **Step 4: Update Request Management**

Replace request operations with REST API:

```dart
// Old Firebase way:
final requests = await EnhancedRequestService.instance.getRequests();

// New REST API way:
final response = await RestRequestService.instance.getRequests();
final requests = response?.requests ?? [];
```

## 🔗 **API Endpoints Available**

### **Authentication:**
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `POST /api/auth/send-email-otp` - Send email OTP
- `POST /api/auth/verify-email-otp` - Verify email OTP
- `POST /api/auth/send-phone-otp` - Send phone OTP
- `POST /api/auth/verify-phone-otp` - Verify phone OTP

### **Categories:**
- `GET /api/categories` - Get categories by country
- `GET /api/categories/:id` - Get category by ID
- `GET /api/categories/:id/subcategories` - Get subcategories

### **Cities:**
- `GET /api/cities` - Get cities by country
- `GET /api/cities/:id` - Get city by ID

### **Vehicle Types:**
- `GET /api/vehicle-types` - Get vehicle types by country
- `GET /api/vehicle-types/:id` - Get vehicle type by ID

### **Requests:**
- `GET /api/requests` - Get requests with filtering/pagination
- `POST /api/requests` - Create new request
- `GET /api/requests/:id` - Get request by ID
- `PUT /api/requests/:id` - Update request
- `DELETE /api/requests/:id` - Delete request

## 📱 **Key Services Created**

1. **`ApiClient`** - Handles HTTP requests with Dio
2. **`RestAuthService`** - JWT-based authentication
3. **`RestCategoryService`** - Category management
4. **`RestCityService`** - City data management
5. **`RestVehicleTypeService`** - Vehicle type management
6. **`RestRequestService`** - Request CRUD operations

## 🚧 **Next Steps**

1. **Update Authentication Flows:**
   - Update login screen to use `RestAuthService`
   - Update registration screen with new REST API
   - Update OTP verification screens

2. **Update Data Loading:**
   - Replace Firebase category loading with REST API
   - Update city/location selection
   - Update vehicle type selection

3. **Update Request Management:**
   - Replace request creation with REST API
   - Update request listing/browsing
   - Update request editing

4. **Remove Firebase Dependencies:**
   - Remove Firebase packages from `pubspec.yaml`
   - Remove Firebase initialization code
   - Clean up unused Firebase service files

## 💡 **Migration Tips**

1. **Gradual Migration:** Replace services one by one to minimize issues
2. **Caching:** New REST services include caching for better performance
3. **Error Handling:** All new services have comprehensive error handling
4. **Testing:** Test each service replacement thoroughly
5. **Rollback Plan:** Keep Firebase services until full migration is complete

## 🔍 **Debugging**

Use these endpoints to test API connectivity:
- Health check: `GET /health`
- Categories test: `GET /api/categories?country=LK`
- Auth test: `POST /api/auth/login` with test credentials
