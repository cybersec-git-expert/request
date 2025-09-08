enum NotificationType {
  // Request/Response notifications
  newResponse,
  requestEdited,
  responseEdited,
  responseAccepted,
  responseRejected,
  
  // Messaging notifications
  newMessage,
  
  // Ride-specific notifications
  newRideRequest,
  rideResponseAccepted,
  rideDetailsUpdated,
  
  // Price list notifications
  productInquiry,
  
  // General notifications
  systemMessage,
}

enum NotificationStatus {
  unread,
  read,
  dismissed,
}

class NotificationModel {
  final String id;
  final String recipientId;
  final String senderId;
  final String? senderName;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data; // Additional data like requestId, responseId, etc.
  final NotificationStatus status;
  final DateTime createdAt;
  final DateTime? readAt;

  NotificationModel({
    required this.id,
    required this.recipientId,
    required this.senderId,
    this.senderName,
    required this.type,
    required this.title,
    required this.message,
    this.data = const {},
    this.status = NotificationStatus.unread,
    required this.createdAt,
    this.readAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      recipientId: map['recipientId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'],
      type: NotificationType.values.byName(map['type'] ?? 'systemMessage'),
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      status: NotificationStatus.values.byName(map['status'] ?? 'unread'),
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
      readAt: map['readAt'] != null ? DateTime.parse(map['readAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipientId': recipientId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.name,
      'title': title,
      'message': message,
      'data': data,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? recipientId,
    String? senderId,
    String? senderName,
    NotificationType? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    NotificationStatus? status,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      recipientId: recipientId ?? this.recipientId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, type: ${type.name}, title: $title, status: ${status.name})';
  }
}

// Driver subscription model for ride notifications
class DriverSubscription {
  final String id;
  final String driverId;
  final String vehicleType;
  final bool isSubscribed;
  final String subscriptionPlan; // 'free', 'premium', etc.
  final DateTime subscriptionExpiry;
  final List<String> serviceAreas; // Cities or areas they serve
  final String? location; // Primary service location
  final DateTime createdAt;
  final DateTime updatedAt;

  DriverSubscription({
    required this.id,
    required this.driverId,
    required this.vehicleType,
    required this.isSubscribed,
    required this.subscriptionPlan,
    required this.subscriptionExpiry,
    this.serviceAreas = const [],
    this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriverSubscription.fromMap(Map<String, dynamic> map) {
    return DriverSubscription(
      id: map['id'] ?? '',
      driverId: map['driverId'] ?? '',
      vehicleType: map['vehicleType'] ?? '',
      isSubscribed: map['isSubscribed'] ?? false,
      subscriptionPlan: map['subscriptionPlan'] ?? 'free',
      subscriptionExpiry: map['subscriptionExpiry'] != null
          ? DateTime.parse(map['subscriptionExpiry'])
          : DateTime.now(),
      serviceAreas: List<String>.from(map['serviceAreas'] ?? []),
      location: map['location'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'driverId': driverId,
      'vehicleType': vehicleType,
      'isSubscribed': isSubscribed,
      'subscriptionPlan': subscriptionPlan,
      'subscriptionExpiry': subscriptionExpiry.toIso8601String(),
      'serviceAreas': serviceAreas,
      'location': location,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  bool get isActive {
    return isSubscribed && subscriptionExpiry.isAfter(DateTime.now());
  }

  DateTime get expiresAt => subscriptionExpiry;
}
