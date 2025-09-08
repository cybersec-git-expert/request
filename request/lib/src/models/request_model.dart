import '../models/enhanced_user_model.dart';

enum RequestStatus {
  draft,
  active,
  open, // Added to handle legacy or alternate status
  inProgress,
  completed,
  cancelled,
  expired
}

enum Priority { low, medium, high, urgent }

class RequestModel {
  final String id;
  final String requesterId;
  final String title;
  final String description;
  final RequestType type;
  final RequestStatus status;
  final Priority priority;
  final LocationInfo? location;
  final LocationInfo? destinationLocation; // For rides/delivery
  final double? budget;
  final String? currency;
  final DateTime? deadline;
  final List<String> images;
  final Map<String, dynamic> typeSpecificData;
  final List<String> tags;
  final String? contactMethod; // phone, email, app
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? assignedTo; // ID of the person handling the request
  final List<ResponseModel> responses;
  final String? country; // Country code (e.g., "LK")
  final String? countryName; // Country name (e.g., "Sri Lanka")

  RequestModel({
    required this.id,
    required this.requesterId,
    required this.title,
    required this.description,
    required this.type,
    this.status = RequestStatus.draft,
    this.priority = Priority.medium,
    this.location,
    this.destinationLocation,
    this.budget,
    this.currency,
    this.deadline,
    this.images = const [],
    this.typeSpecificData = const {},
    this.tags = const [],
    this.contactMethod,
    this.isPublic = true,
    required this.createdAt,
    required this.updatedAt,
    this.assignedTo,
    this.responses = const [],
    this.country,
    this.countryName,
  });

  // Helper methods for specific request types
  ItemRequestData? get itemData => type == RequestType.item
      ? ItemRequestData.fromMap(typeSpecificData)
      : null;

  ServiceRequestData? get serviceData => type == RequestType.service
      ? ServiceRequestData.fromMap(typeSpecificData)
      : null;

  RideRequestData? get rideData => type == RequestType.ride
      ? RideRequestData.fromMap(typeSpecificData)
      : null;

  DeliveryRequestData? get deliveryData => type == RequestType.delivery
      ? DeliveryRequestData.fromMap(typeSpecificData)
      : null;

  RentalRequestData? get rentalData => type == RequestType.rental
      ? RentalRequestData.fromMap(typeSpecificData)
      : null;

  PriceRequestData? get priceData => type == RequestType.price
      ? PriceRequestData.fromMap(typeSpecificData)
      : null;

  factory RequestModel.fromMap(Map<String, dynamic> map) {
    return RequestModel(
      id: map['id'] ?? '',
      requesterId: map['requesterId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: _parseRequestType(map['type']),
      status: _parseRequestStatus(map['status']),
      priority: _parsePriority(map['priority']),
      location: map['location'] != null
          ? LocationInfo.fromMap(map['location'])
          : null,
      destinationLocation: map['destinationLocation'] != null
          ? LocationInfo.fromMap(map['destinationLocation'])
          : null,
      budget: map['budget']?.toDouble(),
      currency: map['currency'],
      deadline:
          map['deadline'] != null ? _parseDateTime(map['deadline']) : null,
      images: List<String>.from(map['images'] ?? []),
      typeSpecificData:
          Map<String, dynamic>.from(map['typeSpecificData'] ?? {}),
      tags: List<String>.from(map['tags'] ?? []),
      contactMethod: map['contactMethod'],
      isPublic: map['isPublic'] ?? true,
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
      assignedTo: map['assignedTo'],
      responses: (map['responses'] as List<dynamic>?)
              ?.map((e) => ResponseModel.fromMap(e))
              .toList() ??
          [],
      country: map['country'],
      countryName: map['countryName'],
    );
  }

  static RequestType _parseRequestType(String? type) {
    // Normalize various backend/legacy representations to enum values
    if (type == null) return RequestType.item;
    var t = type.trim().toLowerCase();
    // Handle formats like "RequestType.item"
    if (t.startsWith('requesttype.')) {
      t = t.substring('requesttype.'.length);
    }
    // Common aliases/synonyms and plural forms
    switch (t) {
      case 'items':
      case 'product':
      case 'products':
        t = 'item';
        break;
      case 'services':
        t = 'service';
        break;
      case 'rental':
      case 'rent':
      case 'rentals':
        t = 'rental';
        break;
      case 'deliver':
      case 'courier':
      case 'parcel':
        t = 'delivery';
        break;
      case 'rides':
      case 'transport':
      case 'trip':
        t = 'ride';
        break;
      case 'price_comparison':
      case 'pricing':
        t = 'price';
        break;
    }
    try {
      return RequestType.values.byName(t);
    } catch (_) {
      return RequestType.item; // Fallback to item type
    }
  }

  static RequestStatus _parseRequestStatus(String? status) {
    if (status == 'open') {
      return RequestStatus.active; // Treat 'open' as 'active'
    }
    try {
      return RequestStatus.values.byName(status ?? 'draft');
    } catch (e) {
      return RequestStatus.draft; // Fallback for any other unknown status
    }
  }

  static Priority _parsePriority(String? priority) {
    try {
      return Priority.values.byName(priority ?? 'medium');
    } catch (e) {
      return Priority.medium; // Fallback to medium priority
    }
  }

  static DateTime? _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return null;
    try {
      if (dateTime is String) {
        return DateTime.parse(dateTime);
      } else if (dateTime is Map && dateTime.containsKey('_seconds')) {
        // Handle Firestore Timestamp
        int seconds = dateTime['_seconds'] ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requesterId': requesterId,
      'title': title,
      'description': description,
      'type': type.name,
      'status': status.name,
      'priority': priority.name,
      'location': location?.toMap(),
      'destinationLocation': destinationLocation?.toMap(),
      'budget': budget,
      'currency': currency,
      'deadline': deadline?.toIso8601String(),
      'images': images,
      'typeSpecificData': typeSpecificData,
      'tags': tags,
      'contactMethod': contactMethod,
      'isPublic': isPublic,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'assignedTo': assignedTo,
      'responses': responses.map((e) => e.toMap()).toList(),
      'country': country,
      'countryName': countryName,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RequestModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'RequestModel(id: $id, title: $title, type: ${type.name}, status: ${status.name})';
  }
}

class LocationInfo {
  final double latitude;
  final double longitude;
  final String address;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;

  LocationInfo({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.city,
    this.state,
    this.country,
    this.postalCode,
  });

  factory LocationInfo.fromMap(Map<String, dynamic> map) {
    return LocationInfo(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      address: map['address'] ?? '',
      city: map['city'],
      state: map['state'],
      country: map['country'],
      postalCode: map['postalCode'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
    };
  }
}

// Type-specific request data models
class ItemRequestData {
  final String category;
  final String? categoryId;
  final String? subcategory;
  final String? subcategoryId;
  final String? itemName;
  final int? quantity;
  final String? brand;
  final String? model;
  final String condition; // new, used, like-new, etc.
  final Map<String, String> specifications;
  final bool acceptAlternatives;

  ItemRequestData({
    required this.category,
    this.categoryId,
    this.subcategory,
    this.subcategoryId,
    this.itemName,
    this.quantity,
    this.brand,
    this.model,
    required this.condition,
    this.specifications = const {},
    this.acceptAlternatives = true,
  });

  factory ItemRequestData.fromMap(Map<String, dynamic> map) {
    return ItemRequestData(
      category: map['category'] ?? '',
      categoryId: map['categoryId'] ?? map['subCategoryId'],
      subcategory: map['subcategory'],
      subcategoryId: map['subcategoryId'] ?? map['subCategoryId'],
      itemName: map['itemName'],
      quantity: map['quantity'],
      brand: map['brand'],
      model: map['model'],
      condition: map['condition'] ?? 'any',
      specifications: Map<String, String>.from(map['specifications'] ?? {}),
      acceptAlternatives: map['acceptAlternatives'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'categoryId': categoryId,
      'subcategory': subcategory,
      'subcategoryId': subcategoryId,
      'itemName': itemName,
      'quantity': quantity,
      'brand': brand,
      'model': model,
      'condition': condition,
      'specifications': specifications,
      'acceptAlternatives': acceptAlternatives,
    };
  }
}

class ServiceRequestData {
  final String serviceType;
  final String? skillLevel; // beginner, intermediate, expert
  final DateTime? preferredTime;
  final int estimatedDuration; // in hours
  final bool isRecurring;
  final String? recurrencePattern; // weekly, monthly, etc.
  final Map<String, String> requirements;

  ServiceRequestData({
    required this.serviceType,
    this.skillLevel,
    this.preferredTime,
    required this.estimatedDuration,
    this.isRecurring = false,
    this.recurrencePattern,
    this.requirements = const {},
  });

  factory ServiceRequestData.fromMap(Map<String, dynamic> map) {
    return ServiceRequestData(
      serviceType: map['serviceType'] ?? '',
      skillLevel: map['skillLevel'],
      preferredTime: map['preferredTime'] != null
          ? DateTime.parse(map['preferredTime'])
          : null,
      estimatedDuration: map['estimatedDuration'] ?? 1,
      isRecurring: map['isRecurring'] ?? false,
      recurrencePattern: map['recurrencePattern'],
      requirements: Map<String, String>.from(map['requirements'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serviceType': serviceType,
      'skillLevel': skillLevel,
      'preferredTime': preferredTime?.toIso8601String(),
      'estimatedDuration': estimatedDuration,
      'isRecurring': isRecurring,
      'recurrencePattern': recurrencePattern,
      'requirements': requirements,
    };
  }
}

class RideRequestData {
  final int passengers;
  final DateTime preferredTime;
  final bool isFlexibleTime;
  final String? vehicleType; // car, bike, van, etc.
  final bool needsWheelchairAccess;
  final bool allowSmoking;
  final bool petsAllowed;
  final String? specialRequests;

  RideRequestData({
    required this.passengers,
    required this.preferredTime,
    this.isFlexibleTime = false,
    this.vehicleType,
    this.needsWheelchairAccess = false,
    this.allowSmoking = false,
    this.petsAllowed = false,
    this.specialRequests,
  });

  factory RideRequestData.fromMap(Map<String, dynamic> map) {
    return RideRequestData(
      passengers: map['passengers'] ?? 1,
      preferredTime: DateTime.parse(map['preferredTime']),
      isFlexibleTime: map['isFlexibleTime'] ?? false,
      vehicleType: map['vehicleType'],
      needsWheelchairAccess: map['needsWheelchairAccess'] ?? false,
      allowSmoking: map['allowSmoking'] ?? false,
      petsAllowed: map['petsAllowed'] ?? false,
      specialRequests: map['specialRequests'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'passengers': passengers,
      'preferredTime': preferredTime.toIso8601String(),
      'isFlexibleTime': isFlexibleTime,
      'vehicleType': vehicleType,
      'needsWheelchairAccess': needsWheelchairAccess,
      'allowSmoking': allowSmoking,
      'petsAllowed': petsAllowed,
      'specialRequests': specialRequests,
    };
  }
}

class DeliveryRequestData {
  final PackageInfo package;
  final DateTime preferredPickupTime;
  final DateTime preferredDeliveryTime;
  final bool isFlexibleTime;
  final bool requireSignature;
  final bool isFragile;
  final bool needsRefrigeration;
  final String? deliveryInstructions;

  DeliveryRequestData({
    required this.package,
    required this.preferredPickupTime,
    required this.preferredDeliveryTime,
    this.isFlexibleTime = false,
    this.requireSignature = false,
    this.isFragile = false,
    this.needsRefrigeration = false,
    this.deliveryInstructions,
  });

  factory DeliveryRequestData.fromMap(Map<String, dynamic> map) {
    return DeliveryRequestData(
      package: PackageInfo.fromMap(map['package'] ?? {}),
      preferredPickupTime:
          _parseDateTime(map['preferredPickupTime']) ?? DateTime.now(),
      preferredDeliveryTime: _parseDateTime(map['preferredDeliveryTime']) ??
          DateTime.now().add(Duration(hours: 2)),
      isFlexibleTime: map['isFlexibleTime'] ?? false,
      requireSignature: map['requireSignature'] ?? false,
      isFragile: map['isFragile'] ?? false,
      needsRefrigeration: map['needsRefrigeration'] ?? false,
      deliveryInstructions: map['deliveryInstructions'],
    );
  }

  // Helper method to safely parse DateTime
  static DateTime? _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return null;
    try {
      if (dateTime is String) {
        return DateTime.parse(dateTime);
      } else if (dateTime is Map && dateTime.containsKey('_seconds')) {
        // Handle Firestore Timestamp
        int seconds = dateTime['_seconds'] ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'package': package.toMap(),
      'preferredPickupTime': preferredPickupTime.toIso8601String(),
      'preferredDeliveryTime': preferredDeliveryTime.toIso8601String(),
      'isFlexibleTime': isFlexibleTime,
      'requireSignature': requireSignature,
      'isFragile': isFragile,
      'needsRefrigeration': needsRefrigeration,
      'deliveryInstructions': deliveryInstructions,
    };
  }
}

class PackageInfo {
  final String description;
  final double weight; // in kg
  final PackageDimensions dimensions;
  final String? category;

  PackageInfo({
    required this.description,
    required this.weight,
    required this.dimensions,
    this.category,
  });

  factory PackageInfo.fromMap(Map<String, dynamic> map) {
    return PackageInfo(
      description: map['description'] ?? '',
      weight: map['weight']?.toDouble() ?? 0.0,
      dimensions: PackageDimensions.fromMap(map['dimensions'] ?? {}),
      category: map['category'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'weight': weight,
      'dimensions': dimensions.toMap(),
      'category': category,
    };
  }
}

class PackageDimensions {
  final double length;
  final double width;
  final double height;

  PackageDimensions({
    required this.length,
    required this.width,
    required this.height,
  });

  factory PackageDimensions.fromMap(Map<String, dynamic> map) {
    return PackageDimensions(
      length: map['length']?.toDouble() ?? 0.0,
      width: map['width']?.toDouble() ?? 0.0,
      height: map['height']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'length': length,
      'width': width,
      'height': height,
    };
  }
}

class RentalRequestData {
  final String itemCategory;
  final DateTime startDate;
  final DateTime endDate;
  final bool isFlexibleDates;
  final String? preferredBrand;
  final Map<String, String> specifications;
  final bool needsDelivery;
  final bool needsSetup;

  RentalRequestData({
    required this.itemCategory,
    required this.startDate,
    required this.endDate,
    this.isFlexibleDates = false,
    this.preferredBrand,
    this.specifications = const {},
    this.needsDelivery = false,
    this.needsSetup = false,
  });

  factory RentalRequestData.fromMap(Map<String, dynamic> map) {
    return RentalRequestData(
      itemCategory: map['itemCategory'] ?? '',
      startDate: _parseDateTime(map['startDate']) ?? DateTime.now(),
      endDate: _parseDateTime(map['endDate']) ??
          DateTime.now().add(Duration(days: 1)),
      isFlexibleDates: map['isFlexibleDates'] ?? false,
      preferredBrand: map['preferredBrand'],
      specifications: _parseStringMap(map['specifications'] ?? {}),
      needsDelivery: map['needsDelivery'] ?? false,
      needsSetup: map['needsSetup'] ?? false,
    );
  }

  // Helper method to safely convert any map to Map<String, String>
  static Map<String, String> _parseStringMap(Map<String, dynamic>? map) {
    if (map == null) return {};
    return map.map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }

  // Helper method to safely parse DateTime
  static DateTime? _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return null;
    try {
      if (dateTime is String) {
        return DateTime.parse(dateTime);
      } else if (dateTime is Map && dateTime.containsKey('_seconds')) {
        // Handle Firestore Timestamp
        int seconds = dateTime['_seconds'] ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'itemCategory': itemCategory,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isFlexibleDates': isFlexibleDates,
      'preferredBrand': preferredBrand,
      'specifications': specifications,
      'needsDelivery': needsDelivery,
      'needsSetup': needsSetup,
    };
  }
}

class PriceRequestData {
  final String itemOrService;
  final String category;
  final String? brand;
  final String? model;
  final Map<String, String> specifications;
  final String condition;
  final int quantity;
  final bool compareNewAndUsed;

  PriceRequestData({
    required this.itemOrService,
    required this.category,
    this.brand,
    this.model,
    this.specifications = const {},
    required this.condition,
    this.quantity = 1,
    this.compareNewAndUsed = true,
  });

  factory PriceRequestData.fromMap(Map<String, dynamic> map) {
    return PriceRequestData(
      itemOrService: map['itemOrService'] ?? '',
      category: map['category'] ?? '',
      brand: map['brand'],
      model: map['model'],
      specifications: _parseStringMap(map['specifications'] ?? {}),
      condition: map['condition'] ?? 'any',
      quantity: map['quantity'] ?? 1,
      compareNewAndUsed: map['compareNewAndUsed'] ?? true,
    );
  }

  // Helper method to safely convert any map to Map<String, String>
  static Map<String, String> _parseStringMap(Map<String, dynamic>? map) {
    if (map == null) return {};
    return map.map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }

  Map<String, dynamic> toMap() {
    return {
      'itemOrService': itemOrService,
      'category': category,
      'brand': brand,
      'model': model,
      'specifications': specifications,
      'condition': condition,
      'quantity': quantity,
      'compareNewAndUsed': compareNewAndUsed,
    };
  }
}

// Response model for handling responses to requests
class ResponseModel {
  final String id;
  final String requestId;
  final String responderId;
  final String message;
  final double? price;
  final String? currency;
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final List<String> images;
  final Map<String, dynamic> additionalInfo;
  final DateTime createdAt;
  final bool isAccepted;
  final String? rejectionReason;
  final String? country; // Country code (e.g., "LK")
  final String? countryName; // Country name (e.g., "Sri Lanka")

  ResponseModel({
    required this.id,
    required this.requestId,
    required this.responderId,
    required this.message,
    this.price,
    this.currency,
    this.availableFrom,
    this.availableUntil,
    this.images = const [],
    this.additionalInfo = const {},
    required this.createdAt,
    this.isAccepted = false,
    this.rejectionReason,
    this.country,
    this.countryName,
  });

  factory ResponseModel.fromMap(Map<String, dynamic> map) {
    return ResponseModel(
      id: map['id'] ?? '',
      requestId: map['requestId'] ?? '',
      responderId: map['responderId'] ?? '',
      message: map['message'] ?? '',
      price: map['price']?.toDouble(),
      currency: map['currency'],
      availableFrom: map['availableFrom'] != null
          ? DateTime.parse(map['availableFrom'])
          : null,
      availableUntil: map['availableUntil'] != null
          ? DateTime.parse(map['availableUntil'])
          : null,
      images: List<String>.from(map['images'] ?? []),
      additionalInfo: Map<String, dynamic>.from(map['additionalInfo'] ?? {}),
      createdAt: DateTime.parse(map['createdAt']),
      isAccepted: map['isAccepted'] ?? false,
      rejectionReason: map['rejectionReason'],
      country: map['country'],
      countryName: map['countryName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requestId': requestId,
      'responderId': responderId,
      'message': message,
      'price': price,
      'currency': currency,
      'availableFrom': availableFrom?.toIso8601String(),
      'availableUntil': availableUntil?.toIso8601String(),
      'images': images,
      'additionalInfo': additionalInfo,
      'createdAt': createdAt.toIso8601String(),
      'isAccepted': isAccepted,
      'rejectionReason': rejectionReason,
      'country': country,
      'countryName': countryName,
    };
  }
}

// Helper function to parse request status
RequestStatus _parseRequestStatus(String? status) {
  if (status == 'open') {
    return RequestStatus.active;
  }
  try {
    return RequestStatus.values.byName(status ?? 'draft');
  } catch (e) {
    return RequestStatus.draft;
  }
}
