import 'rest_request_service.dart' as rest;
import '../models/request_model.dart' as ui;
import '../models/enhanced_user_model.dart' show RequestType; // enum definition

/// Bridge between legacy UI layer models and new REST models.
class EnhancedRequestService {
  final rest.RestRequestService _rest = rest.RestRequestService.instance;

  // ---- Requests (minimal pass-through for now) ----
  Future<List<ui.RequestModel>> getRequests() async {
    final r = await _rest.getRequests(limit: 50);
    if (r == null) return [];
    return r.requests.map(_convertRequest).toList();
  }

  Future<ui.RequestModel?> getRequestById(String id) async {
    final r = await _rest.getRequestById(id);
    if (r == null) return null;
    return _convertRequest(r);
  }

  Future<void> updateRequest(String id, Map<String, dynamic> data) async {
    await _rest.updateRequest(id, data);
  }

  Future<void> updateRequestFlexible({
    String? requestId,
    String? title,
    String? description,
    double? budget,
    dynamic location,
    dynamic destinationLocation,
    List<String>? images,
    Map<String, dynamic>? typeSpecificData,
  }) async {
    if (requestId == null) return;
    final map = <String, dynamic>{};
    if (title != null) map['title'] = title;
    if (description != null) map['description'] = description;
    if (budget != null) map['budget'] = budget;
    if (images != null) map['image_urls'] = images;
    if (typeSpecificData != null) map['metadata'] = typeSpecificData;
    await _rest.updateRequest(requestId, map);
  }

  Future<void> updateRequestNamed(
      {String? requestId, Map<String, dynamic>? data}) async {
    if (requestId == null || data == null) return;
    await _rest.updateRequest(requestId, data);
  }

  Future<void> createRequestNamed({Map<String, dynamic>? data}) async {
    // Creation handled elsewhere via CentralizedRequestService; keep placeholder
  }

  // ---- Responses ----
  Future<List<ui.ResponseModel>> getResponsesForRequest(
      String requestId) async {
    // Fetch responses
    final page = await _rest.getResponses(requestId, limit: 50);

    // Also fetch the request to know which response (if any) was accepted
    final req = await _rest.getRequestById(requestId);
    final acceptedId = req?.acceptedResponseId;

    // Convert to UI models and flag the accepted one so the UI can reflect it
    final list = page.responses.map(_convertResponse).toList();
    if (acceptedId != null && acceptedId.isNotEmpty) {
      for (var i = 0; i < list.length; i++) {
        final r = list[i];
        if (r.id == acceptedId) {
          list[i] = ui.ResponseModel(
            id: r.id,
            requestId: r.requestId,
            responderId: r.responderId,
            message: r.message,
            price: r.price,
            currency: r.currency,
            availableFrom: r.availableFrom,
            availableUntil: r.availableUntil,
            images: r.images,
            additionalInfo: r.additionalInfo,
            createdAt: r.createdAt,
            isAccepted: true,
            rejectionReason: r.rejectionReason,
            country: r.country,
            countryName: r.countryName,
          );
        }
      }
    }

    return list;
  }

  Future<void> updateResponse(
      String responseId, Map<String, dynamic> data) async {
    // Need requestId to call REST endpoint; expect caller to include it.
    final requestId = data.remove('requestId');
    if (requestId == null) return;
    await _rest.updateResponse(requestId, responseId, data);
  }

  Future<void> updateResponseNamed({
    String? responseId,
    String? requestId,
    String? message,
    double? price,
    String? currency,
    DateTime? availableFrom,
    DateTime? availableUntil,
    List<String>? images,
    Map<String, dynamic>? additionalInfo,
    String? locationAddress,
    double? locationLatitude,
    double? locationLongitude,
    String? countryCode,
  }) async {
    if (responseId == null || requestId == null) return;
    final map = <String, dynamic>{};
    if (message != null) map['message'] = message;
    if (price != null) map['price'] = price;
    if (currency != null) map['currency'] = currency;
    if (images != null) map['image_urls'] = images;
    // Allow clearing by sending empty object explicitly
    if (additionalInfo != null) {
      map['metadata'] = additionalInfo.isEmpty ? {} : additionalInfo;
    }
    // Location fields (backend PUT not yet supporting; include for future)
    if (locationAddress != null) map['location_address'] = locationAddress;
    if (locationLatitude != null) map['location_latitude'] = locationLatitude;
    if (locationLongitude != null)
      map['location_longitude'] = locationLongitude;
    if (countryCode != null) map['country_code'] = countryCode;
    await _rest.updateResponse(requestId, responseId, map);
  }

  Future<void> createResponseNamed({
    String? requestId,
    String? message,
    double? price,
    String? currency,
    Map<String, dynamic>? additionalInfo,
    List<String>? images,
    String? locationAddress,
    double? locationLatitude,
    double? locationLongitude,
    String? countryCode,
  }) async {
    if (requestId == null || message == null) return;
    final payload = rest.CreateResponseData(
      message: message,
      price: price,
      currency: currency,
      metadata: additionalInfo,
      imageUrls: images,
      locationAddress: locationAddress,
      locationLatitude: locationLatitude,
      locationLongitude: locationLongitude,
      countryCode: countryCode,
    );
    await _rest.createResponse(requestId, payload);
  }

  // Adapter for legacy named usage
  Future<void> createResponse({
    String? requestId,
    String? message,
    double? price,
    String? currency,
    Map<String, dynamic>? additionalData,
    List<String>? images,
  }) async {
    await createResponseNamed(
      requestId: requestId,
      message: message,
      price: price,
      currency: currency,
      images: images,
      additionalInfo: additionalData,
    );
  }

  // Methods for response management (accept / reject not yet backed by REST endpoints here)
  Future<bool> acceptResponse(String requestId, String responseId) async {
    final res = await _rest.acceptResponse(requestId, responseId);
    return res != null; // returns updated RequestModel on success
  }

  Future<void> rejectResponse(String responseId, String reason) async {
    // No-op placeholder
  }

  // ---- Converters ----
  ui.RequestModel _convertRequest(rest.RequestModel r) {
    // Normalize metadata and ensure ride fields exist when applicable
    final Map<String, dynamic> meta =
        Map<String, dynamic>.from(r.metadata ?? const {});

    // Derive request type with preference to top-level requestType, then metadata
    final reqType = _deriveTypeWithFallback(r.requestType, meta);

    // Extract pickup/destination from metadata (preferred) or fall back to top-level columns
    ui.LocationInfo? pickup;
    final pickupMap = meta['pickup'] as Map<String, dynamic>?;
    if (pickupMap != null) {
      final lat =
          (pickupMap['lat'] as num?)?.toDouble() ?? r.locationLatitude ?? 0.0;
      final lng =
          (pickupMap['lng'] as num?)?.toDouble() ?? r.locationLongitude ?? 0.0;
      final address =
          (pickupMap['address'] as String?) ?? r.locationAddress ?? '';
      pickup = ui.LocationInfo(
        latitude: lat,
        longitude: lng,
        address: address,
        city: null,
        state: null,
        country: r.countryCode,
        postalCode: null,
      );
    } else if (r.locationAddress != null ||
        (r.locationLatitude != null && r.locationLongitude != null)) {
      pickup = ui.LocationInfo(
        latitude: r.locationLatitude ?? 0.0,
        longitude: r.locationLongitude ?? 0.0,
        address: r.locationAddress ?? '',
        city: r.cityName,
        state: null,
        country: r.countryCode,
        postalCode: null,
      );
    }

    ui.LocationInfo? destination;
    final destMap = meta['destination'] as Map<String, dynamic>?;
    if (destMap != null) {
      destination = ui.LocationInfo(
        latitude: (destMap['lat'] as num?)?.toDouble() ?? 0.0,
        longitude: (destMap['lng'] as num?)?.toDouble() ?? 0.0,
        address: (destMap['address'] as String?) ?? '',
        city: null,
        state: null,
        country: r.countryCode,
        postalCode: null,
      );
    }

    // If this is a ride, ensure expected fields exist to avoid parsing errors downstream
    if (reqType == RequestType.ride) {
      // Passengers default to 1
      meta['passengers'] = (meta['passengers'] as num?)?.toInt() ?? 1;
      // Preferred time required by RideRequestData.fromMap; default to createdAt
      meta['preferredTime'] =
          (meta['preferredTime'] as String?) ?? r.createdAt.toIso8601String();
      // Flexible timing default
      meta['isFlexibleTime'] = meta['isFlexibleTime'] ?? true;
      // Vehicle type: prefer human-readable if present; else fallback to id
      if (meta['vehicleType'] == null) {
        meta['vehicleType'] = meta['vehicle_type_name'] ??
            meta['vehicle_type'] ??
            meta['vehicle_type_id'];
      }
    }

    // Provide requester info in metadata for UI fallbacks when direct user fetch is not allowed
    // These keys are checked by the Ride View screen
    meta['requester_id'] = meta['requester_id'] ?? r.userId;
    if ((meta['requester_name'] == null ||
            meta['requester_name'].toString().trim().isEmpty) &&
        (r.userName != null && r.userName!.toString().trim().isNotEmpty)) {
      meta['requester_name'] = r.userName;
      meta['user_name'] = meta['user_name'] ?? r.userName; // compatibility
      meta['requester_display_name'] =
          meta['requester_display_name'] ?? r.userName;
      meta['user_display_name'] = meta['user_display_name'] ?? r.userName;
      meta['display_name'] = meta['display_name'] ?? r.userName;
    }
    if ((meta['requester_phone'] == null ||
            meta['requester_phone'].toString().trim().isEmpty) &&
        (r.userPhone != null && r.userPhone!.toString().trim().isNotEmpty)) {
      meta['requester_phone'] = r.userPhone;
      meta['user_phone'] = meta['user_phone'] ?? r.userPhone; // compatibility
      meta['phone'] = meta['phone'] ?? r.userPhone;
      meta['requester_mobile'] = meta['requester_mobile'] ?? r.userPhone;
      meta['mobile'] = meta['mobile'] ?? r.userPhone;
    }
    if ((meta['requester_email'] == null ||
            meta['requester_email'].toString().trim().isEmpty) &&
        (r.userEmail != null && r.userEmail!.toString().trim().isNotEmpty)) {
      meta['requester_email'] = r.userEmail;
      meta['user_email'] = meta['user_email'] ?? r.userEmail;
      meta['email'] = meta['email'] ?? r.userEmail;
    }

    return ui.RequestModel(
      id: r.id,
      requesterId: r.userId,
      title: r.title,
      description: r.description,
      type: reqType,
      status: ui.RequestStatus.active,
      priority: ui.Priority.medium,
      location: pickup,
      destinationLocation: destination,
      budget: r.budget,
      currency: r.currency,
      deadline: r.deadline,
      images: r.imageUrls ?? const [],
      typeSpecificData: meta,
      tags: const [],
      contactMethod: null,
      isPublic: true,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      assignedTo: null,
      responses: const [],
      country: r.countryCode,
      countryName: null,
    );
  }

  // Prefer top-level requestType (from DB column) then metadata['request_type'] then metadata['type']
  RequestType _deriveTypeWithFallback(
      String? requestType, Map<String, dynamic> meta) {
    final candidates = <String?>[
      requestType,
      meta['request_type']?.toString(),
      meta['type']?.toString(),
    ];
    for (final t in candidates) {
      if (t == null) continue;
      try {
        return RequestType.values.firstWhere((e) => e.name == t);
      } catch (_) {
        // continue
      }
    }
    return RequestType.item;
  }

  // (removed legacy _deriveType to satisfy lints)

  ui.ResponseModel _convertResponse(rest.ResponseModel r) {
    // Debug: Print the REST response model to see what location data it has
    print('🔍 DEBUG: REST Response Model conversion:');
    print('  REST locationAddress: ${r.locationAddress}');
    print('  REST locationLatitude: ${r.locationLatitude}');
    print('  REST locationLongitude: ${r.locationLongitude}');
    print('  REST countryCode: ${r.countryCode}');
    print('  REST metadata: ${r.metadata}');

    return ui.ResponseModel(
      id: r.id,
      requestId: r.requestId,
      responderId: r.userId,
      message: r.message,
      price: r.price,
      currency: r.currency,
      availableFrom: null,
      availableUntil: null,
      images: r.imageUrls ?? const [],
      additionalInfo: {
        ...?r.metadata,
        if (r.locationAddress != null) 'location_address': r.locationAddress,
        if (r.locationLatitude != null) 'location_latitude': r.locationLatitude,
        if (r.locationLongitude != null)
          'location_longitude': r.locationLongitude,
        if (r.countryCode != null) 'country_code': r.countryCode,
        if (r.userName != null) 'responder_name': r.userName,
        if (r.userEmail != null) 'responder_email': r.userEmail,
        if (r.userPhone != null) 'responder_phone': r.userPhone,
      },
      createdAt: r.createdAt,
      isAccepted: false, // derive when backend supplies accepted id
      rejectionReason: null,
      country: r.countryCode,
      countryName: null,
    );
  }
}
