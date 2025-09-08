import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize({
    void Function(String?)? onSelect,
  }) async {
    if (_initialized) return;

    // Android init
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS init (disabled for now; app targets Android primarily)
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (onSelect != null) {
          onSelect(response.payload);
        }
      },
    );

    // Create a default channel on Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'default_channel',
      'General',
      description: 'General notifications',
      importance: Importance.defaultImportance,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<bool> ensurePermission() async {
    if (!Platform.isAndroid) return true;
    if (await Permission.notification.isGranted) return true;

    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'default_channel',
  }) async {
    if (!_initialized) {
      debugPrint('[NotificationService] Not initialized; initializing now');
      await initialize();
    }

    await ensurePermission();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'General',
        channelDescription: 'General notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
        styleInformation: const BigTextStyleInformation(''),
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }
}
