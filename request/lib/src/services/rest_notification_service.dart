import 'dart:convert';
// No platform-specific imports needed; base URL comes from ApiClient
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';
import 'api_client.dart';

class RestNotificationService {
  RestNotificationService._();
  static RestNotificationService? _inst;
  static RestNotificationService get instance =>
      _inst ??= RestNotificationService._();

  // Use the centralized ApiClient base to ensure correct HTTPS host in all envs
  static String get _baseUrl => ApiClient.baseUrlPublic;

  Future<List<NotificationModel>> fetchMyNotifications() async {
    final token = await ApiClient.instance.getToken();
    final resp =
        await http.get(Uri.parse('$_baseUrl/api/notifications'), headers: {
      if (token != null) 'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
    if (resp.statusCode != 200) return [];
    try {
      final decoded = jsonDecode(resp.body);
      final list = (decoded is Map && decoded['data'] is List)
          ? (decoded['data'] as List)
          : (decoded is List ? decoded : const []);
      return list
          .whereType<Map>()
          .map((j) => _fromJson(j.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> markAllRead() async {
    final token = await ApiClient.instance.getToken();
    await http
        .post(Uri.parse('$_baseUrl/api/notifications/mark-all-read'), headers: {
      if (token != null) 'Authorization': 'Bearer $token',
    });
  }

  Future<void> markRead(String id) async {
    final token = await ApiClient.instance.getToken();
    await http
        .post(Uri.parse('$_baseUrl/api/notifications/$id/read'), headers: {
      if (token != null) 'Authorization': 'Bearer $token',
    });
  }

  Future<void> delete(String id) async {
    final token = await ApiClient.instance.getToken();
    await http.delete(Uri.parse('$_baseUrl/api/notifications/$id'), headers: {
      if (token != null) 'Authorization': 'Bearer $token',
    });
  }

  NotificationModel _fromJson(Map<String, dynamic> j) {
    final typeStr = (j['type'] as String?) ?? 'systemMessage';
    // Support legacy boolean is_read flag
    final statusStr = j.containsKey('is_read')
        ? ((j['is_read'] == true) ? 'read' : 'unread')
        : ((j['status'] as String?) ?? 'unread');
    return NotificationModel(
      id: j['id'].toString(),
      recipientId: (j['recipient_id'] ?? j['user_id'])?.toString() ?? '',
      senderId: j['sender_id']?.toString() ?? '',
      senderName: null,
      type: NotificationType.values.firstWhere(
        (t) => t.name.toLowerCase() == typeStr.toLowerCase(),
        orElse: () => NotificationType.systemMessage,
      ),
      title: j['title']?.toString() ?? '',
      // message field may be 'message' (new) or 'body' (legacy)
      message: (j['message'] ?? j['body'])?.toString() ?? '',
      data: (j['data'] is Map)
          ? (j['data'] as Map)
              .map((k, v) => MapEntry(k.toString(), v))
              .cast<String, dynamic>()
          : <String, dynamic>{},
      status: NotificationStatus.values.firstWhere(
        (s) => s.name.toLowerCase() == statusStr.toLowerCase(),
        orElse: () => NotificationStatus.unread,
      ),
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
          DateTime.now(),
      readAt: j['read_at'] != null
          ? DateTime.tryParse(j['read_at'].toString())
          : null,
    );
  }

  Future<({int total, int messages})> unreadCounts() async {
    final token = await ApiClient.instance.getToken();
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/notifications/counts'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode != 200) return (total: 0, messages: 0);
    final data = jsonDecode(resp.body)['data'] as Map<String, dynamic>;
    return (
      total: (data['total'] as num?)?.toInt() ?? 0,
      messages: (data['messages'] as num?)?.toInt() ?? 0,
    );
  }
}
