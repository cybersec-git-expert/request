// // REMOVED_FB_IMPORT: import 'package:cloud_firestore/cloud_firestore.dart'; import 'src/utils/firebase_shim.dart'; // Added by migration script
// Removed Firebase dependency

class ConversationModel {
  final String id;
  final String requestId;
  final String requestTitle;
  final List<String> participantIds;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String requesterId;
  final String responderId;
  final DateTime createdAt;
  final Map<String, bool> readStatus;

  ConversationModel({
    required this.id,
    required this.requestId,
    required this.requestTitle,
    required this.participantIds,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.requesterId,
    required this.responderId,
    required this.createdAt,
    required this.readStatus,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> map, String id) {
    return ConversationModel(
      id: id,
      requestId: map['requestId'] ?? '',
      requestTitle: map['requestTitle'] ?? '',
      participantIds: List<String>.from(map['participantIds'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.parse(map['lastMessageTime'].toString())
          : DateTime.now(),
      requesterId: map['requesterId'] ?? '',
      responderId: map['responderId'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'].toString())
          : DateTime.now(),
      readStatus: Map<String, bool>.from(map['readStatus'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'requestTitle': requestTitle,
      'participantIds': participantIds,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'requesterId': requesterId,
      'responderId': responderId,
      'createdAt': createdAt.toIso8601String(),
      'readStatus': readStatus,
    };
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final Map<String, dynamic>? metadata;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.type = MessageType.text,
    this.metadata,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      conversationId: map['conversationId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'].toString())
          : DateTime.now(),
      type: MessageType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'metadata': metadata,
    };
  }
}

enum MessageType {
  text,
  system,
  request_created,
  response_submitted,
}
