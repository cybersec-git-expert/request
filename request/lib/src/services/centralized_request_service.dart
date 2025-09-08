import 'country_service.dart';
import 'rest_request_service.dart';
import '../models/request_model.dart' as ui;
import '../models/enhanced_user_model.dart' as enhanced;

class CentralizedRequestService {
  final RestRequestService _rest = RestRequestService.instance;

  Future<List<dynamic>> getRequests() async {
    final resp = await _rest.getRequests(limit: 50);
    return resp?.requests ?? [];
  }

  Future<dynamic> createRequest(Map<String, dynamic> data) async {
    try {
      final typeSpecific =
          (data['typeSpecificData'] as Map<String, dynamic>?) ?? {};

      // Extract category & subcategory IDs from either root-level keys or nested typeSpecificData
      String? categoryId = _firstNonEmpty([
        data['categoryId'],
        data['category_id'],
        typeSpecific['categoryId'],
        typeSpecific['category_id'],
      ]);
      String? subcategoryId = _firstNonEmpty([
        data['subCategoryId'],
        data['subcategoryId'],
        data['subcategory_id'],
        typeSpecific['subCategoryId'],
        typeSpecific['subcategoryId'],
        typeSpecific['subcategory_id'],
      ]);

      // Treat synthetic fallback IDs (from local picker defaults) as missing so we don't send invalid UUIDs
      final isSynthetic =
          categoryId != null && categoryId.startsWith('fallback_');
      if (categoryId == null || categoryId.isEmpty || isSynthetic) {
        categoryId = '';
      }

      // Budget as single value
      final budgetRaw = data['budget'];
      double? budget = _asDoubleInternal(budgetRaw);

      // Resolve city id (backend requires city_id). Accept multiple key names.
      String? cityId = _firstNonEmpty([
        data['cityId'],
        data['city_id'],
        data['locationCityId'],
        typeSpecific['cityId'],
        typeSpecific['city_id'],
        typeSpecific['locationCityId'],
      ]);

      // Extract raw location details if provided
      String? locationAddress;
      double? locationLat;
      double? locationLon;
      final dynamic locationObj = data['location'];
      if (locationObj != null) {
        try {
          if (locationObj is Map) {
            locationAddress = locationObj['address']?.toString();
            locationLat = _asDoubleInternal(locationObj['latitude']);
            locationLon = _asDoubleInternal(locationObj['longitude']);
          } else if (locationObj is ui.LocationInfo) {
            // Handle LocationInfo objects
            locationAddress = locationObj.address;
            locationLat = _asDoubleInternal(locationObj.latitude);
            locationLon = _asDoubleInternal(locationObj.longitude);
            print('=== CENTRALIZED SERVICE LOCATION DEBUG ===');
            print('LocationInfo detected - address: "$locationAddress"');
            print('LocationInfo detected - latitude: $locationLat');
            print('LocationInfo detected - longitude: $locationLon');
            print('==========================================');
          } else {
            print('=== UNKNOWN LOCATION OBJECT TYPE ===');
            print('locationObj type: ${locationObj.runtimeType}');
            print('locationObj: $locationObj');
            print('====================================');
          }
        } catch (_) {}
      }

      // Fallback: infer from any existing request for same country
      if (cityId == null || cityId.isEmpty) {
        try {
          final existing = await _rest.getRequests(
              limit: 1,
              countryCode: CountryService.instance.countryCode ?? 'LK');
          cityId = existing?.requests.first.locationCityId;
        } catch (_) {}
      }

      // Final hardcoded fallback (temporary) so creation succeeds; replace with real city picker.
      cityId ??=
          '72e9d78c-8f05-483a-ae63-e5c9aacfd9bf'; // Kandy (from sample data)

      final createData = CreateRequestData(
        title: (data['title'] ?? '').toString(),
        description: (data['description'] ?? '').toString(),
        // If categoryId is empty (synthetic or missing) supply a temporary safe placeholder UUID-like value that backend will reject with clear error,
        // OR adjust backend to allow null. For now, if empty we'll short-circuit before calling API.
        categoryId: categoryId,
        subcategoryId: (subcategoryId != null && subcategoryId.isNotEmpty)
            ? subcategoryId
            : null,
        locationCityId: cityId,
        locationAddress: locationAddress,
        locationLatitude: locationLat,
        locationLongitude: locationLon,
        countryCode: CountryService.instance.countryCode ?? 'LK',
        budget: budget,
        currency: data['currency']?.toString(),
        deadline: data['deadline'] is DateTime ? data['deadline'] : null,
        imageUrls: (data['images'] as List<String>?)
            ?.where((e) => e.isNotEmpty)
            .toList(),
        requestType: data['type']?.toString(), // Add request_type from data
        metadata: {
          'type': data['type'],
          'request_type': data['type']
              ?.toString(), // Keep in metadata for backward compatibility
          ...typeSpecific,
        },
      );

      // Debug log final create payload
      // ignore: avoid_print
      print('CentralizedRequestService -> creating with city_id=$cityId');
      // ignore: avoid_print
      print(
          'CentralizedRequestService -> metadata being sent: ${createData.metadata}');
      // ignore: avoid_print
      print('CentralizedRequestService -> typeSpecific data: $typeSpecific');

      // Check if this is a ride request (identified by metadata)
      final isRideRequest = createData.metadata != null &&
          createData.metadata!['request_type'] == 'ride' &&
          createData.metadata!['pickup'] != null &&
          createData.metadata!['destination'] != null;

      // Only require category for non-ride requests
      if (!isRideRequest &&
          (createData.categoryId == null || createData.categoryId!.isEmpty)) {
        throw Exception(
            'Please select a real category before creating the request');
      }

      final created = await _rest.createRequest(createData);
      // ignore: avoid_print
      print('CentralizedRequestService -> created request result: $created');
      // ignore: avoid_print
      print(
          'CentralizedRequestService -> created request metadata: ${created?.metadata}');
      return created?.id; // Return the new request ID
    } catch (e) {
      print('CentralizedRequestService.createRequest error: $e');
      rethrow;
    }
  }

  // Stream country-filtered requests (simplified: single fetch -> yield)
  Stream<List<ui.RequestModel>> getCountryRequestsStream({
    String? category,
    String? type,
    int limit = 50,
  }) async* {
    final resp = await _rest.getRequests(
      limit: limit,
      countryCode: CountryService.instance.countryCode ?? 'LK',
    );
    if (resp == null) {
      yield <ui.RequestModel>[];
      return;
    }
    final list = resp.requests
        .where((r) => _filterByType(r, type))
        .map(_convert)
        .toList();
    yield list.cast<ui.RequestModel>();
  }

  enhanced.RequestType _parseUiType(String? t) {
    if (t == null) return enhanced.RequestType.item;
    try {
      return enhanced.RequestType.values.byName(t);
    } catch (_) {
      return enhanced.RequestType.item;
    }
  }

  bool _filterByType(RequestModel r, String? type) {
    if (type == null || type.isEmpty) return true;
    final metaType = r.metadata?['type']?.toString();
    return metaType == type;
  }

  ui.RequestModel _convert(RequestModel r) {
    final metaType = r.metadata?['type']?.toString();
    final uiType = _parseUiType(metaType);
    return ui.RequestModel(
      id: r.id,
      requesterId: r.userId,
      title: r.title,
      description: r.description,
      type: uiType,
      status: ui.RequestStatus.active,
      priority: ui.Priority.medium,
      location: null,
      destinationLocation: null,
      budget: r.budget,
      currency: r.currency,
      deadline: r.deadline,
      images: r.imageUrls ?? const [],
      typeSpecificData: r.metadata ?? const {},
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

  String? _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      if (v == null) continue;
      final s = v.toString();
      if (s.trim().isEmpty) continue;
      return s;
    }
    return null;
  }

  double? _asDoubleInternal(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  // Compatibility helper matching legacy named-parameter usage
  Future<dynamic> createRequestCompat({
    required String title,
    required String description,
    required dynamic type,
    dynamic location,
    double? budget,
    String? currency,
    List<String>? images,
    Map<String, dynamic>? typeSpecificData,
    List<String>? tags,
  }) async {
    final map = <String, dynamic>{
      'title': title,
      'description': description,
      'type': type.toString(),
      if (location != null) 'location': location,
      if (budget != null) 'budget': budget,
      if (currency != null) 'currency': currency,
      if (images != null) 'images': images,
      if (typeSpecificData != null) 'typeSpecificData': typeSpecificData,
      if (tags != null) 'tags': tags,
    };
    return createRequest(map);
  }

  Future<void> updateRequest(String id, Map<String, dynamic> data) async {}
  Future<void> updateRequestFlexible({
    String? requestId,
    String? title,
    String? description,
    double? budget,
    dynamic location,
    dynamic destinationLocation,
    List<String>? images,
    Map<String, dynamic>? typeSpecificData,
  }) async {}
  Future<void> deleteRequest(String id) async {}
  Future<void> createResponse(
      String requestId, Map<String, dynamic> data) async {
    try {
      // Accept various client-side field names and normalize.
      final message = (data['message'] ?? data['text'] ?? '').toString().trim();
      if (message.isEmpty) {
        throw Exception('Response message is required');
      }

      // Price can arrive as num / String / null.
      double? price;
      final rawPrice = data['price'];
      if (rawPrice != null && rawPrice.toString().trim().isNotEmpty) {
        if (rawPrice is num) {
          price = rawPrice.toDouble();
        } else {
          price = double.tryParse(rawPrice.toString().trim());
        }
      }

      final currency = data['currency']?.toString();

      // Images: allow keys images, imageUrls, image_urls
      List<String>? images;
      for (final key in ['images', 'imageUrls', 'image_urls']) {
        final v = data[key];
        if (v is List) {
          images =
              v.whereType<String>().where((s) => s.trim().isNotEmpty).toList();
          if (images.isEmpty) images = null;
          if (images != null) break;
        }
      }

      // Additional metadata: merge additionalData / additional_info / metadata / availableDate
      final Map<String, dynamic> meta = {};
      void mergeMap(dynamic m) {
        if (m is Map) {
          m.forEach((k, v) {
            if (v != null) meta[k.toString()] = v;
          });
        }
      }

      mergeMap(data['additionalData']);
      mergeMap(data['additional_info']);
      mergeMap(data['metadata']);
      if (data['availableDate'] != null) {
        meta['availableDate'] = data['availableDate'];
      }
      if (data['additionalData'] == null && meta.isEmpty) {
        // Nothing to send -> keep null to avoid empty object clutter in DB
      }

      // Location fields (optional). Accept multiple key variants.
      final locationAddress =
          data['location_address'] ?? data['locationAddress'];
      final locationLatitudeRaw =
          data['location_latitude'] ?? data['locationLatitude'];
      final locationLongitudeRaw =
          data['location_longitude'] ?? data['locationLongitude'];
      final countryCode = data['country_code'] ?? data['countryCode'];
      double? locationLatitude = _asDoubleInternal(locationLatitudeRaw);
      double? locationLongitude = _asDoubleInternal(locationLongitudeRaw);

      final payload = CreateResponseData(
        message: message,
        price: price,
        currency: currency,
        metadata: meta.isEmpty ? null : meta,
        imageUrls: images,
        locationAddress:
            (locationAddress?.toString().trim().isNotEmpty ?? false)
                ? locationAddress.toString().trim()
                : null,
        locationLatitude: locationLatitude,
        locationLongitude: locationLongitude,
        countryCode: countryCode?.toString(),
      );

      // Debug log (non-sensitive)
      // ignore: avoid_print
      print(
          '[CentralizedRequestService][createResponse] requestId=$requestId msgLen=${message.length} price=$price currency=$currency images=${images?.length ?? 0} metaKeys=${payload.metadata?.keys.toList()}');

      final created = await _rest.createResponse(requestId, payload);
      if (created == null) {
        throw Exception('Failed to create response (null result)');
      }
      // ignore: avoid_print
      print(
          '[CentralizedRequestService][createResponse] created id=${created.id}');
    } catch (e) {
      print('[CentralizedRequestService][createResponse][error] $e');
      rethrow;
    }
  }

  Future<void> createResponseNamed({
    String? requestId,
    String? message,
    double? price,
    String? currency,
    Map<String, dynamic>? additionalData,
    List<String>? images,
    String? locationAddress,
    double? locationLatitude,
    double? locationLongitude,
    String? countryCode,
  }) async {
    if (requestId == null) throw Exception('requestId required');
    final map = <String, dynamic>{
      'message': message,
      if (price != null) 'price': price,
      if (currency != null) 'currency': currency,
      if (images != null) 'images': images,
      if (additionalData != null) 'additionalData': additionalData,
      // Location fields
      if (locationAddress != null) 'location_address': locationAddress,
      if (locationLatitude != null) 'location_latitude': locationLatitude,
      if (locationLongitude != null) 'location_longitude': locationLongitude,
      // Country code
      if (countryCode != null) 'country_code': countryCode,
    };
    await createResponse(requestId, map);
  }

  Future<void> updateResponse(
      String responseId, Map<String, dynamic> data) async {}
}
