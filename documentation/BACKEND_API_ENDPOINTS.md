# Backend API Endpoints Required for Flutter App

Your Flutter app authentication flow now expects these REST API endpoints to be implemented in your Node.js/Express backend:

## 🔐 **Authentication Endpoints**

### 1. **Check User Exists**
```
POST /api/auth/check-user-exists
```
**Request Body:**
```json
{
  "emailOrPhone": "user@example.com" | "+1234567890"
}
```
**Response:**
```json
{
  "exists": true|false,
  "message": "User found" | "User not found"
}
```

### 2. **User Login**
```
POST /api/auth/login
```
**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```
**Response:**
```json
{
  "token": "jwt_token_here",
  "user": {
    "id": "user_id",
    "email": "user@example.com",
    "display_name": "John Doe",
    "phone": "+1234567890",
    "country_code": "US"
  }
}
```

### 3. **Send OTP**
```
POST /api/auth/send-otp
```
**Request Body:**
```json
{
  "emailOrPhone": "user@example.com" | "+1234567890",
  "isEmail": true|false,
  "countryCode": "US"
}
```
**Response:**
```json
{
  "otpToken": "secure_otp_token",
  "message": "OTP sent successfully"
}
```

### 4. **Verify OTP**
```
POST /api/auth/verify-otp
```
**Request Body:**
```json
{
  "emailOrPhone": "user@example.com",
  "otp": "123456",
  "otpToken": "secure_otp_token"
}
```
**Response:**
```json
{
  "verified": true,
  "token": "jwt_token_here",
  "user": {
    "id": "user_id",
    "email": "user@example.com",
    "display_name": "John Doe"
  }
}
```

### 5. **User Registration**
```
POST /api/auth/register
```
**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123",
  "display_name": "John Doe",
  "phone": "+1234567890"
}
```
**Response:**
```json
{
  "token": "jwt_token_here",
  "user": {
    "id": "user_id",
    "email": "user@example.com",
    "display_name": "John Doe",
    "phone": "+1234567890",
    "country_code": "US"
  }
}
```

### 6. **Get User Profile**
```
GET /api/auth/profile
```
**Headers:**
```
Authorization: Bearer jwt_token_here
```
**Response:**
```json
{
  "user": {
    "id": "user_id",
    "email": "user@example.com",
    "display_name": "John Doe",
    "phone": "+1234567890",
    "country_code": "US"
  }
}
```

## 🔧 **Implementation Notes:**

### **Country-Based System:**
- Users should be assigned to countries based on phone number country code or manual selection
- Super admins see all countries, country admins see only their assigned country
- Users see only content from their registered country

### **OTP System:**
- **Email OTP**: Use AWS SES for sending email OTPs
- **SMS OTP**: Use configurable SMS providers per country (admin panel controlled)
- OTP should expire in 10 minutes
- Store OTP tokens securely with expiration

### **Security:**
- Use JWT tokens for authentication
- Hash passwords with bcrypt
- Rate limiting on OTP sending (max 3 per 10 minutes)
- Validate country codes against allowed list

### **Database Schema:**
```sql
-- Users table
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE,
  phone VARCHAR(20),
  password_hash VARCHAR(255),
  display_name VARCHAR(255),
  country_code VARCHAR(3),
  role ENUM('user', 'country_admin', 'super_admin') DEFAULT 'user',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- OTP tokens table
CREATE TABLE otp_tokens (
  id SERIAL PRIMARY KEY,
  email_or_phone VARCHAR(255),
  otp_code VARCHAR(6),
  token_hash VARCHAR(255),
  expires_at TIMESTAMP,
  used BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 🚀 **Priority Order:**
1. **check-user-exists** - Required for login screen routing
2. **send-otp** - Required for new user registration
3. **verify-otp** - Required for OTP screen
4. **login** - Required for password screen
5. **register** - Required for profile completion
6. **profile** - Required for user session management
