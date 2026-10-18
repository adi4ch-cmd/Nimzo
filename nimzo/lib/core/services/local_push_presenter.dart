import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'push_notifications.dart';

/// Foreground Android notifications use the same generic content/tag as FCM.
class LocalPushPresenter {
  LocalPushPresenter(this.plugin, this.currentUser);
  final FlutterLocalNotificationsPlugin plugin;
  final String? Function() currentUser;
  final _opened = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get opened => _opened.stream;
  Future<void> initialize() async {
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('nimzo_notification_icon'),
        iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (response) {
        final data = _decode(response.payload);
        if (data != null) _opened.add(data);
      },
    );
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'nimzo_activity',
          'NIMZO activity',
          description: 'Messages, gifts and room activity',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ));
  }

  Future<void> show(Map<String, dynamic> data) async {
    final id = pushNotificationId(data, currentUser());
    if (id == null) return;
    final identity = {'notification_id': id, 'user_id': currentUser()};
    await plugin.show(
        0,
        'NIMZO',
        'Open NIMZO to view your notification.',
        NotificationDetails(
            android: AndroidNotificationDetails(
          'nimzo_activity',
          'NIMZO activity',
          channelDescription: 'Messages, gifts and room activity',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.private,
          tag: id,
          icon: 'nimzo_notification_icon',
        )),
        payload: jsonEncode(identity));
  }

  Future<Map<String, dynamic>?> initialMessage() async {
    final launch = await plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true
        ? _decode(launch?.notificationResponse?.payload)
        : null;
  }

  Map<String, dynamic>? _decode(String? payload) {
    try {
      final data = jsonDecode(payload ?? '');
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() => _opened.close();
}
