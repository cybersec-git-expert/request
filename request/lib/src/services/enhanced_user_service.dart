import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/enhanced_user_model.dart';
// Import only the needed auth service (hide its UserModel to avoid symbol clash)
import 'rest_auth_service.dart' show RestAuthService;
import 'api_client.dart';

/// Enhanced User Service for REST API
/// Provides user management functionality using REST endpoints
class EnhancedUserService {
  factory EnhancedUserService() =>
      instance; // allow default constructor usage in screens
  static EnhancedUserService? _instance;
  static EnhancedUserService get instance =>
      _instance ??= EnhancedUserService._();

  EnhancedUserService._();

  final RestAuthService _authService = RestAuthService.instance;

  UserModel? _cachedUser; // simple in-memory cache

  /// Getter used by legacy screens expecting synchronous access (nullable)
  UserModel? get currentUser => _cachedUser;

  /// Get current user model (fetches fresh data from API)
  Future<UserModel?> getCurrentUserModel() async {
    try {
      if (!await _authService.isAuthenticated()) {
        return null;
      }
      final authUser = _authService.currentUser;
      if (authUser == null) return null;

      // Fetch fresh user data from the API
      try {
        final response =
            await ApiClient.instance.get('/api/users/${authUser.id}');

        if (response.isSuccess && response.data != null) {
          final userData = response.data['data'] ?? response.data;

          // Create enhanced user model from fresh API data
          final mapped = UserModel(
            id: userData['id'] ?? authUser.id,
            name: userData['display_name'] ?? authUser.fullName,
            firstName: userData['first_name'],
            lastName: userData['last_name'],
            email: userData['email'] ?? authUser.email,
            phoneNumber: userData['phone'],
            profilePictureUrl: userData['photo_url'],
            dateOfBirth: userData['date_of_birth'] != null
                ? DateTime.tryParse(userData['date_of_birth'].toString())
                : null,
            gender: userData['gender'],
            roles: const [UserRole.general],
            activeRole: UserRole.general,
            roleData: const {},
            isEmailVerified:
                userData['email_verified'] ?? authUser.emailVerified,
            isPhoneVerified:
                userData['phone_verified'] ?? authUser.phoneVerified,
            profileComplete: true,
            countryCode: userData['country_code'] ?? authUser.countryCode,
            countryName: null,
            createdAt: userData['created_at'] != null
                ? (DateTime.tryParse(userData['created_at'].toString()) ??
                    authUser.createdAt)
                : authUser.createdAt,
            updatedAt: userData['updated_at'] != null
                ? (DateTime.tryParse(userData['updated_at'].toString()) ??
                    authUser.updatedAt)
                : authUser.updatedAt,
          );

          _cachedUser = mapped;
          return mapped;
        } else {
          print(
              'API response not successful, falling back to auth service data');
        }
      } catch (apiError) {
        print(
            'Error fetching user data from API: $apiError, falling back to auth service data');
      }

      // Fallback to auth service data if API call fails
      final mapped = UserModel(
        id: authUser.id,
        name: authUser.fullName,
        email: authUser.email,
        phoneNumber: authUser.phoneNumber,
        profilePictureUrl: null, // No profile picture in fallback data
        roles: const [UserRole.general],
        activeRole: UserRole.general,
        roleData: const {},
        isEmailVerified: authUser.emailVerified,
        isPhoneVerified: authUser.phoneVerified,
        profileComplete: true,
        countryCode: authUser.countryCode,
        countryName: null,
        createdAt: authUser.createdAt,
        updatedAt: authUser.updatedAt,
      );
      _cachedUser = mapped;
      return mapped;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current user model: $e');
      }
      return null;
    }
  }

  /// Get current user (alias for getCurrentUserModel)
  Future<UserModel?> getCurrentUser() async {
    return getCurrentUserModel();
  }

  /// Clear cached user data to force fresh fetch
  void clearCache() {
    _cachedUser = null;
  }

  /// Refresh user data (clears cache and fetches fresh data)
  Future<UserModel?> refreshCurrentUser() async {
    clearCache();
    return getCurrentUserModel();
  }

  /// Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      // Try cache first if it matches
      if (_cachedUser?.id == userId) return _cachedUser;

      // Fetch from REST API
      final response = await ApiClient.instance.get('/api/users/$userId');
      if (response.isSuccess && response.data != null) {
        final userData = response.data['data'] ?? response.data;
        return UserModel(
          id: userData['id']?.toString() ?? userId,
          name: userData['display_name'] ??
              [userData['first_name'], userData['last_name']]
                  .where((e) => (e ?? '').toString().isNotEmpty)
                  .join(' '),
          firstName: userData['first_name'],
          lastName: userData['last_name'],
          email: userData['email'],
          phoneNumber: userData['phone'],
          profilePictureUrl: userData['photo_url'],
          dateOfBirth: userData['date_of_birth'] != null
              ? DateTime.tryParse(userData['date_of_birth'].toString())
              : null,
          gender: userData['gender'],
          roles: const [UserRole.general],
          activeRole: UserRole.general,
          roleData: const {},
          isEmailVerified: userData['email_verified'] ?? false,
          isPhoneVerified: userData['phone_verified'] ?? false,
          profileComplete: true,
          countryCode: userData['country_code'],
          countryName: null,
          createdAt: userData['created_at'] != null
              ? (DateTime.tryParse(userData['created_at'].toString()) ??
                  DateTime.now())
              : DateTime.now(),
          updatedAt: userData['updated_at'] != null
              ? (DateTime.tryParse(userData['updated_at'].toString()) ??
                  DateTime.now())
              : DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user by ID: $e');
      }
      return null;
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? email,
    String? displayName,
    String? profilePictureUrl,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    try {
      final user = await getCurrentUser();
      if (user == null) {
        print('Error: No authenticated user found');
        return false;
      }

      // Build update data
      final Map<String, dynamic> updateData = {};
      if (firstName != null) updateData['first_name'] = firstName;
      if (lastName != null) updateData['last_name'] = lastName;
      if (phoneNumber != null) updateData['phone'] = phoneNumber;
      if (email != null) updateData['email'] = email;
      if (displayName != null) updateData['display_name'] = displayName;
      if (profilePictureUrl != null)
        updateData['photo_url'] = profilePictureUrl;
      if (dateOfBirth != null)
        updateData['date_of_birth'] =
            dateOfBirth.toIso8601String().split('T')[0]; // Send as YYYY-MM-DD
      if (gender != null) updateData['gender'] = gender;

      if (updateData.isEmpty) {
        print('No data to update');
        return true;
      }

      // Debug authentication before API call
      final token = await ApiClient.instance.getToken();
      if (kDebugMode) {
        print('🔑 [EnhancedUserService] Before profile update:');
        print('🔑 Token exists: ${token != null}');
        print('🔑 Token length: ${token?.length ?? 0}');
        print('🔑 Update data: $updateData');
        print('🔑 User ID: ${user.id}');
      }

      // Make REST API call to update user profile
      final response = await ApiClient.instance.put(
        '/api/users/${user.id}',
        data: updateData,
      );

      if (response.isSuccess) {
        print('DEBUG: User profile updated successfully: $updateData');
        // Clear cache to ensure fresh data is fetched next time
        clearCache();
        return true;
      } else {
        print('Error updating user profile: ${response.error}');
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating user profile: $e');
      }
      return false;
    }
  }

  // Legacy alias (screens call updateProfile with a map or named params)
  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? email,
    String? displayName,
    String? profilePictureUrl,
    DateTime? dateOfBirth,
    String? gender,
  }) =>
      updateUserProfile(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        email: email,
        displayName: displayName,
        profilePictureUrl: profilePictureUrl,
        dateOfBirth: dateOfBirth,
        gender: gender,
      );

  // ---- Stubs to satisfy legacy verification / role management screens ----

  Future<void> submitDriverVerification(Map<String, dynamic> driverData) async {
    try {
      if (kDebugMode) {
        print('Submitting driver verification with: ${driverData.keys}');
      }

      // First test connectivity with simple endpoint
      if (kDebugMode) {
        print('Testing connectivity to server...');
      }

      try {
        final testResponse =
            await ApiClient.instance.get('/api/driver-verifications/test');
        if (kDebugMode) {
          print('✅ Connectivity test successful: ${testResponse.success}');
          if (testResponse.data != null) {
            print('Test response: ${testResponse.data}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Connectivity test failed: $e');
        }
        throw Exception('Network connectivity test failed: $e');
      }

      // Transform the data to match our API structure
      final apiData = {
        'userId': driverData['userId'],
        'firstName': driverData['firstName'],
        'lastName': driverData['lastName'],
        'fullName': driverData['fullName'],
        'dateOfBirth': driverData['dateOfBirth']
            ?.toIso8601String()
            ?.split('T')[0], // Format as YYYY-MM-DD
        'gender': driverData['gender'],
        'nicNumber': driverData['nicNumber'],
        'phoneNumber': driverData['phoneNumber'],
        'secondaryMobile': driverData['secondaryMobile'],
        'email': driverData['email'],
        'cityId': driverData['city']?['id'],
        'cityName': driverData['city']?['name'],
        'country': driverData['country'] ?? 'LK',
        'licenseNumber': driverData['licenseNumber'],
        'licenseExpiry':
            driverData['licenseExpiry']?.toIso8601String()?.split('T')[0],
        'licenseHasNoExpiry': driverData['licenseHasNoExpiry'] ?? false,
        'vehicleTypeId': driverData['vehicleType']?['id'],
        'vehicleTypeName': driverData['vehicleType']?['name'],
        'vehicleModel': driverData['vehicleModel'],
        'vehicleYear': driverData['vehicleYear'],
        'vehicleNumber': driverData['vehicleNumber'],
        'vehicleColor': driverData['vehicleColor'],
        'isVehicleOwner': driverData['isVehicleOwner'] ?? true,
        'insuranceNumber': driverData['insuranceNumber'],
        'insuranceExpiry':
            driverData['insuranceExpiry']?.toIso8601String()?.split('T')[0],
        'driverImageUrl': driverData['driverImageUrl'],
        'nicFrontUrl': driverData['nicFrontUrl'],
        'nicBackUrl': driverData['nicBackUrl'],
        'licenseFrontUrl': driverData['licenseFrontUrl'],
        'licenseBackUrl': driverData['licenseBackUrl'],
        'licenseDocumentUrl': driverData['licenseDocumentUrl'],
        'vehicleRegistrationUrl': driverData['vehicleRegistrationUrl'],
        'insuranceDocumentUrl': driverData['insuranceDocumentUrl'],
        'billingProofUrl': driverData['billingProofUrl'],
        'vehicleImageUrls': driverData['vehicleImageUrls'],
        'documentVerification': driverData['documentVerification'],
        'vehicleImageVerification': driverData['vehicleImageVerification'],
        'subscriptionPlan': driverData['subscriptionPlan'] ?? 'free',
        'notes': null,
      };

      // Remove null values to avoid issues
      apiData.removeWhere((key, value) => value == null);

      // Convert any remaining DateTime objects to strings recursively
      final cleanedApiData = _cleanDateTimeObjects(apiData);

      if (kDebugMode) {
        print('📦 Final API data size: ${cleanedApiData.length} fields');
        print('📦 API data keys: ${cleanedApiData.keys.toList()}');

        // Check for large data fields and any remaining problematic objects
        cleanedApiData.forEach((key, value) {
          if (value is String && value.length > 100) {
            print(
                '📦 Large field $key: ${value.length} characters (${value.substring(0, 50)}...)');
          } else if (value is DateTime) {
            print('⚠️ Found uncleaned DateTime in $key: $value');
          } else if (value is List) {
            print('📦 List field $key: ${value.length} items');
            for (int i = 0; i < value.length; i++) {
              if (value[i] is DateTime) {
                print('⚠️ Found DateTime in list $key[$i]: ${value[i]}');
              }
            }
          }
        });

        // Try to encode to JSON to catch any remaining issues
        try {
          final jsonString = jsonEncode(cleanedApiData);
          print('📦 JSON payload size: ${jsonString.length} characters');
        } catch (e) {
          print('❌ JSON encoding failed: $e');
          // Print each field to find the problematic one
          cleanedApiData.forEach((key, value) {
            try {
              jsonEncode({key: value});
            } catch (fieldError) {
              print('❌ Field $key caused JSON error: $fieldError');
              print('   Field type: ${value.runtimeType}');
              print('   Field value: $value');
            }
          });
          rethrow;
        }
      }

      final response = await ApiClient.instance.post(
        '/api/driver-verifications',
        data: cleanedApiData,
      );

      if (response.isSuccess) {
        if (kDebugMode) {
          print('Driver verification submitted successfully');
        }
      } else {
        throw Exception(
            'Failed to submit driver verification: ${response.error ?? response.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error submitting driver verification: $e');
      }
      rethrow;
    }
  }

  /// Recursively clean DateTime objects from data structure
  dynamic _cleanDateTimeObjects(dynamic data) {
    if (data is DateTime) {
      return data.toIso8601String().split('T')[0];
    } else if (data is Map<String, dynamic>) {
      final cleaned = <String, dynamic>{};
      for (final entry in data.entries) {
        cleaned[entry.key] = _cleanDateTimeObjects(entry.value);
      }
      return cleaned;
    } else if (data is List) {
      return data.map((item) => _cleanDateTimeObjects(item)).toList();
    } else {
      return data;
    }
  }

  Future<void> submitBusinessVerification(
      Map<String, dynamic> businessData) async {
    if (kDebugMode) {
      print('submitBusinessVerification called with: ${businessData.keys}');
    }

    try {
      // Prepare data for backend API
      final apiData = {
        'business_name': businessData['businessName'],
        'business_email': businessData['businessEmail'],
        'business_phone': businessData['businessPhone'],
        'business_address': businessData['businessAddress'],
        // Prefer new ID-based field; keep legacy string fallback for backward compat
        if (businessData['businessTypeId'] != null)
          'business_type_id': businessData['businessTypeId'],
        if (businessData['businessCategory'] != null)
          'business_type': businessData['businessCategory'],
        if (businessData['categories'] != null)
          'categories': businessData['categories'],
        'registration_number': businessData['licenseNumber'],
        'tax_number': businessData['taxId'],
        'country_code': businessData['country'], // ISO code
        'description': businessData['businessDescription'],
        // Add document URLs if available
        'business_license_url': businessData['businessLicenseUrl'],
        'tax_certificate_url': businessData['taxCertificateUrl'],
        'insurance_document_url': businessData['insuranceDocumentUrl'],
        'business_logo_url': businessData['businessLogoUrl'],
      };

      if (kDebugMode) {
        print('🚀 Submitting business verification to API: $apiData');
      }

      // Call the backend API
      final response = await ApiClient.instance.post(
        '/api/business-verifications',
        data: apiData,
      );

      if (response.isSuccess) {
        if (kDebugMode) {
          print('✅ Business verification submitted successfully');
        }
      } else {
        throw Exception('API Error: ${response.error}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error submitting business verification: $e');
      }
      rethrow;
    }
  }

  Future<void> updateRoleData(
      [String? role, Map<String, dynamic>? data]) async {
    if (kDebugMode) {
      print('updateRoleData stub role=$role keys=${data?.keys}');
    }
  }

  Future<void> submitRoleForVerification([String? role]) async {
    if (kDebugMode) {
      print('submitRoleForVerification stub role=$role');
    }
  }

  // Named wrapper variants used by legacy screens (ignore userId parameter)
  Future<void> updateRoleDataNamed(
      {String? userId, dynamic role, Map<String, dynamic>? data}) async {
    await updateRoleData(role?.toString(), data);
  }

  Future<void> submitRoleForVerificationNamed(
      {String? userId, dynamic role}) async {
    await submitRoleForVerification(role?.toString());
  }

  Future<void> switchActiveRole(String userId, String role) async {
    if (kDebugMode) {
      print('switchActiveRole stub userId=$userId role=$role');
    }
    // Update cached user activeRole if matches
    if (_cachedUser != null) {
      _cachedUser = UserModel(
        id: _cachedUser!.id,
        name: _cachedUser!.name,
        email: _cachedUser!.email,
        phoneNumber: _cachedUser!.phoneNumber,
        roles: _cachedUser!.roles,
        activeRole: _parseRole(role),
        roleData: _cachedUser!.roleData,
        isEmailVerified: _cachedUser!.isEmailVerified,
        isPhoneVerified: _cachedUser!.isPhoneVerified,
        profileComplete: _cachedUser!.profileComplete,
        countryCode: _cachedUser!.countryCode,
        countryName: _cachedUser!.countryName,
        createdAt: _cachedUser!.createdAt,
        updatedAt: DateTime.now(),
      );
    }
  }

  UserRole _parseRole(String role) {
    return UserRole.values.firstWhere(
      (r) => describeEnum(r) == role,
      orElse: () => UserRole.general,
    );
  }
}
