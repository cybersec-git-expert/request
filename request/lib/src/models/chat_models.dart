class Conversation {
  final String id;
  final String requestId;
  final String? participantA;
  final String? participantB;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final String? requestTitle;
  final int? unreadCount;

  Conversation({
    required this.id,
    required this.requestId,
    this.participantA,
    this.participantB,
    this.lastMessageText,
    this.lastMessageAt,
    this.requestTitle,
    this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as String,
        requestId: j['request_id'] as String,
        participantA: j['participant_a'] as String?,
        participantB: j['participant_b'] as String?,
        lastMessageText: j['last_message_text'] as String?,
        lastMessageAt: j['last_message_at'] != null
            ? DateTime.parse(j['last_message_at'] as String)
            : null,
        requestTitle: (j['requestTitle'] ?? j['request_title']) as String?,
        unreadCount: (j['unread_count'] ?? j['unreadCount']) as int?,
      );
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        conversationId: j['conversation_id'] as String,
        senderId: j['sender_id'] as String,
        content: j['content'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
