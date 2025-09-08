// Temporary placeholder service to prevent compilation errors
// TODO: Implement with REST API

import '../models/notification_model.dart';
import '../models/vehicle_type_model.dart';
import '../models/request_model.dart';

class ComprehensiveNotificationService {
  // Simple REST-backed implementation
  Future<List<NotificationModel>> getNotifications() async =>
      <NotificationModel>[];
  Future<void> markAsRead(String id) async {}
  Future<void> deleteNotification(String id) async {}
  Stream<List<NotificationModel>> getUserNotifications(String? userId) async* {
    // For now, emit polling-less empty list; NotificationScreen will call fetch on build.
    yield <NotificationModel>[];
  }

  Future<void> markAllAsRead(String? userId) async {}

  // Additional stubs referenced by pricing & subscription screens
  Future<void> notifyProductInquiry({
    String? businessId,
    String? businessName,
    String? productName,
    String? inquirerId,
    String? inquirerName,
    String? listingId,
  }) async {}

  Future<List<DriverSubscription>> getDriverSubscriptions(
          String? userId) async =>
      <DriverSubscription>[];
  Future<void> subscribeToRideNotifications({
    String? userId,
    String? city,
    String? vehicleType,
    String? driverId,
    List<String>? serviceAreas,
    String? location,
    int? subscriptionDays,
  }) async {}
  Future<void> updateSubscriptionStatus(
      String subscriptionId, bool active) async {}
  Future<void> deleteSubscription(String subscriptionId) async {}
  Future<void> extendSubscription(String subscriptionId, int days) async {}
}

class EnhancedUserService {
  EnhancedUserService();
  dynamic _cached;
  Future<dynamic> getCurrentUser() async => _cached;
  dynamic get currentUser => _cached; // legacy getter usage
  Future<void> updateProfile(Map<String, dynamic> data) async {}
  Future<void> submitBusinessVerification(Map<String, dynamic> data) async {}
  Future<void> submitDriverVerification(Map<String, dynamic> data) async {}

  // Allow calling with no args in some screens by making parameters optional & nullable
  Future<void> updateRoleData(
      {String? userId, dynamic role, Map<String, dynamic>? data}) async {}
  Future<void> submitRoleForVerification(
      {String? userId, dynamic role}) async {}

  Future<void> switchActiveRole(String? userId, String role) async {}

  // Wrapper variants matching real service helper names
  Future<void> updateRoleDataNamed(
      {String? userId, dynamic role, Map<String, dynamic>? data}) async {}
  Future<void> submitRoleForVerificationNamed(
      {String? userId, dynamic role}) async {}
}

class CentralizedRequestService {
  Future<List<dynamic>> getRequests() async => [];
  Future<dynamic> createRequest([Map<String, dynamic>? data]) async => null;
  Future<void> updateRequest([String? id, Map<String, dynamic>? data]) async {}
  Future<void> deleteRequest([String? id]) async {}
  // Provide flexible signatures used by UI (sometimes called with no args)
  Future<void> createResponse(
      [String? requestId, Map<String, dynamic>? data]) async {}
  Future<void> updateResponse(
      [String? responseId, Map<String, dynamic>? data]) async {}
}

class EnhancedRequestService {
  Future<List<dynamic>> getRequests() async => [];
  Future<dynamic> getRequestById([String? id]) async => null;
  Future<void> updateRequest([String? id, Map<String, dynamic>? data]) async {}
  Future<List<ResponseModel>> getResponsesForRequest(
          [String? requestId]) async =>
      <ResponseModel>[];
  Future<void> updateResponse({
    String? responseId,
    String? message,
    double? price,
    String? currency,
    DateTime? availableFrom,
    DateTime? availableUntil,
    List<String>? images,
    Map<String, dynamic>? additionalInfo,
  }) async {}
}

class MessagingService {
  // Placeholder methods
  Future<dynamic> getOrCreateConversation(
      String userId1, String userId2) async {
    return null;
  }

  Future<List<dynamic>> getConversations() async {
    return [];
  }

  Future<void> sendMessage(String conversationId, String message) async {
    // TODO: Implement
  }
}

class VehicleService {
  Future<List<VehicleTypeModel>> getVehicleTypes() async =>
      <VehicleTypeModel>[];
  Future<VehicleTypeModel?> getVehicleById(String? id) async => null;
  Future<List<VehicleTypeModel>> refreshVehicles() async =>
      <VehicleTypeModel>[];
}

class CategoryService {
  // Placeholder methods
  Future<List<dynamic>> getCategories() async {
    return [];
  }

  Future<List<dynamic>> getSubcategories(String categoryId) async {
    return [];
  }
}

class CountryService {
  static final CountryService instance = CountryService._internal();
  CountryService._internal();

  // Placeholder methods
  Future<List<dynamic>> getCountries() async {
    return [];
  }

  String getCurrentCountryCode() {
    return 'LK'; // Default to Sri Lanka
  }
}
