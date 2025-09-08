import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';
import 'api_client.dart';

class ChatService {
  ChatService._();
  static final instance = ChatService._();

  // Use centralized ApiClient base (https://api.alphabet.lk)
  static String get _baseUrl => ApiClient.baseUrlPublic;

  Future<Map<String, String>> _authHeaders() async {
    final token = await ApiClient.instance.getToken();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<List<Conversation>> listConversations({required String userId}) async {
    final uri = Uri.parse('$_baseUrl/api/chat/conversations?userId=$userId');
    final resp = await http.get(uri, headers: await _authHeaders());
    if (resp.statusCode != 200) {
      throw Exception(
          'Failed to list conversations: ${resp.statusCode} - ${resp.body}');
    }
    final data = jsonDecode(resp.body);
    final list = (data['conversations'] as List? ?? [])
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<(Conversation, List<ChatMessage>)> openConversation({
    required String requestId,
    required String currentUserId,
    required String otherUserId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/chat/open');
    final resp = await http.post(uri,
        headers: await _authHeaders(),
        body: jsonEncode({
          'requestId': requestId,
          'currentUserId': currentUserId,
          'otherUserId': otherUserId,
        }));

    print('🔥 [ChatService] openConversation response: ${resp.statusCode}');
    print('🔥 [ChatService] response body: ${resp.body}');

    if (resp.statusCode != 200) {
      throw Exception(
          'Failed to open conversation: ${resp.statusCode} - ${resp.body}');
    }

    try {
      final data = jsonDecode(resp.body);
      print('🔥 [ChatService] parsed data: $data');

      final convo = Conversation.fromJson(data['conversation']);
      final messages = (data['messages'] as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
      return (convo, messages);
    } catch (e, stack) {
      print('🔥 [ChatService] JSON parsing error: $e');
      print('🔥 [ChatService] Stack trace: $stack');
      rethrow;
    }
  }

  Future<List<ChatMessage>> getMessages(
      {required String conversationId}) async {
    final uri = Uri.parse('$_baseUrl/api/chat/messages/$conversationId');
    final resp = await http.get(uri, headers: await _authHeaders());
    if (resp.statusCode != 200) {
      throw Exception(
          'Failed to get messages: ${resp.statusCode} - ${resp.body}');
    }
    final data = jsonDecode(resp.body);
    final msgs = (data['messages'] as List)
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
    return msgs;
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/chat/messages');

    print('🔥 [ChatService] sendMessage to: $uri');
    print(
        '🔥 [ChatService] payload: conversationId=$conversationId, senderId=$senderId, content="$content"');

    final resp = await http.post(uri,
        headers: await _authHeaders(),
        body: jsonEncode({
          'conversationId': conversationId,
          'senderId': senderId,
          'content': content,
        }));

    print('🔥 [ChatService] sendMessage response: ${resp.statusCode}');
    print('🔥 [ChatService] response body: ${resp.body}');

    if (resp.statusCode != 200) {
      throw Exception(
          'Failed to send message: ${resp.statusCode} - ${resp.body}');
    }

    try {
      final data = jsonDecode(resp.body);
      return ChatMessage.fromJson(data['message']);
    } catch (e, stack) {
      print('🔥 [ChatService] sendMessage JSON parsing error: $e');
      print('🔥 [ChatService] Stack trace: $stack');
      rethrow;
    }
  }
}
