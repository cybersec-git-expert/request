import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'notification_service.dart';
import 'rest_notification_service.dart';
import '../models/notification_model.dart';

/// Foreground notification polling + badge updater.
///
/// Notes:
/// - Runs only when the app is alive (not a background/alarm service).
/// - First run is "primed" (no toasts) to avoid spamming old backlog.
class NotificationCenter {
  NotificationCenter._();
  static final NotificationCenter instance = NotificationCenter._();

  final ValueNotifier<int> unreadMessages = ValueNotifier<int>(0);

  Timer? _timer;
  bool _running = false;
  bool _primed = false;
  final Set<String> _seenIds = LinkedHashSet();

  static const _prefsSeenKey = 'seen_notification_ids';
  static const _maxSeen = 200; // cap stored IDs
  // Polling interval: faster in debug to help validation
  static Duration get _interval =>
      kReleaseMode ? const Duration(seconds: 45) : const Duration(seconds: 15);

  Future<void> start() async {
    if (_running) return;
    _running = true;

    await _loadSeen();
    debugPrint('[NotificationCenter] start(): polling every '
        '${_interval.inSeconds}s (primed=$_primed)');
    // Kick once immediately, then schedule.
    unawaited(_poll());
    _timer = Timer.periodic(_interval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  Future<void> _loadSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsSeenKey) ?? const [];
      _seenIds
        ..clear()
        ..addAll(list);
    } catch (_) {}
  }

  Future<void> _saveSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep only the most recent N to bound storage size
      final trimmed = _seenIds.toList().take(_maxSeen).toList();
      await prefs.setStringList(_prefsSeenKey, trimmed);
    } catch (_) {}
  }

  Future<void> _poll() async {
    // Skip if no auth token
    final token = await ApiClient.instance.getToken();
    if (token == null || token.isEmpty) {
      if (kDebugMode) {
        debugPrint(
            '[NotificationCenter] _poll(): no auth token; clearing badges');
      }
      if (unreadMessages.value != 0) unreadMessages.value = 0;
      return;
    }

    try {
      // 1) Update unread counts for badges
      final counts = await RestNotificationService.instance.unreadCounts();
      if (kDebugMode) {
        debugPrint(
            '[NotificationCenter] unread counts -> messages=${counts.messages}');
      }
      if (unreadMessages.value != counts.messages) {
        unreadMessages.value = counts.messages;
      }

      // 2) Detect new notifications and toast them locally
      final list =
          await RestNotificationService.instance.fetchMyNotifications();
      if (kDebugMode) {
        debugPrint('[NotificationCenter] fetched ${list.length} notifications');
      }
      if (list.isEmpty) return;

      // Sort by createdAt ascending to show in order
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // On first prime, just record existing without showing
      if (!_primed) {
        if (kDebugMode) {
          debugPrint(
              '[NotificationCenter] priming with ${list.length} existing items (no toasts)');
        }
        for (final n in list) {
          _seenIds.add(n.id);
        }
        _primed = true;
        await _saveSeen();
        return;
      }

      // Find truly new items (not previously seen)
      final newOnes = list.where((n) => !_seenIds.contains(n.id)).toList();
      if (kDebugMode) {
        debugPrint(
            '[NotificationCenter] detected ${newOnes.length} new notifications');
      }
      if (newOnes.isEmpty) return;

      // Limit bursts
      final toShow = newOnes.take(3);
      for (final n in toShow) {
        await _showLocal(n);
        _seenIds.add(n.id);
      }
      await _saveSeen();
    } catch (_) {
      // Network errors ignored silently
    }
  }

  Future<void> _showLocal(NotificationModel n) async {
    final title = (n.title.isNotEmpty) ? n.title : _titleForType(n.type);
    final body = (n.message.isNotEmpty) ? n.message : 'Open to view details';
    if (kDebugMode) {
      debugPrint(
          '[NotificationCenter] showing local notification: title="$title"');
    }
    await NotificationService.instance.showLocalNotification(
      title: title,
      body: body,
      payload: '/notifications',
    );
  }

  String _titleForType(NotificationType type) {
    switch (type) {
      case NotificationType.newMessage:
        return 'New message';
      case NotificationType.newResponse:
        return 'New response';
      case NotificationType.responseAccepted:
        return 'Response accepted';
      case NotificationType.responseRejected:
        return 'Response rejected';
      case NotificationType.newRideRequest:
        return 'New ride request';
      case NotificationType.rideResponseAccepted:
        return 'Ride accepted';
      case NotificationType.rideDetailsUpdated:
        return 'Ride updated';
      case NotificationType.productInquiry:
        return 'Product inquiry';
      case NotificationType.requestEdited:
      case NotificationType.responseEdited:
        return 'Update';
      case NotificationType.systemMessage:
        return 'Notification';
    }
  }
}
