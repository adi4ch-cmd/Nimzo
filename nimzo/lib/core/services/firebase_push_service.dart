import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/router.dart';
import '../../features/notifications/notification_repository.dart';
import '../providers/supabase_provider.dart';
import 'push_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  // Android displays notification payloads. No account data is fetched here.
  await Firebase.initializeApp();
}

class FirebasePushGateway implements PushGateway {
  FirebasePushGateway(this.messaging);
  final FirebaseMessaging messaging;
  @override
  Future<bool> requestPermission() async {
    final settings = await messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => messaging.getToken();
  @override
  Stream<String> get tokenRefresh => messaging.onTokenRefresh;
  @override
  Stream<Map<String, dynamic>> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map((message) => message.data);
  @override
  Future<Map<String, dynamic>?> initialMessage() async =>
      (await messaging.getInitialMessage())?.data;
}

/// No configuration means push stays unavailable; authentication still works.
Future<PushGateway?> initializeFirebasePush() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    return FirebasePushGateway(FirebaseMessaging.instance);
  } catch (_) {
    return null;
  }
}

final pushGatewayProvider = Provider<PushGateway?>((ref) => null);

class _PushLifecycle with WidgetsBindingObserver {
  _PushLifecycle(this.resume) {
    WidgetsBinding.instance.addObserver(this);
  }
  final void Function() resume;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) resume();
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);
}

final pushLifecycleProvider = Provider.autoDispose<PushNotifications?>((ref) {
  final gateway = ref.watch(pushGatewayProvider);
  if (gateway == null) return null;
  final db = ref.watch(supabaseProvider);
  final controller = PushNotifications(
    gateway: gateway,
    register: (token) async {
      if (db.auth.currentUser != null) {
        await db.rpc('register_device', params: {'p_token': token});
      }
    },
    open: (id) async {
      final user = db.auth.currentUser?.id;
      if (user == null) return;
      final row = await db
          .from('notifications')
          .select()
          .eq('id', id)
          .eq('user_id', user)
          .maybeSingle();
      if (row == null || db.auth.currentUser?.id != user) return;
      await ref.read(notificationRepositoryProvider).markRead(id);
      if (db.auth.currentUser?.id != user) return;
      ref.invalidate(notificationsProvider);
      ref
          .read(routerProvider)
          .go(notificationDestination(row) ?? '/notifications');
    },
  );
  ref.listen(currentUserIdProvider, (_, user) {
    unawaited(controller.setUser(user));
  });
  unawaited(controller.setUser(ref.read(currentUserIdProvider)));
  final lifecycle = _PushLifecycle(() {
    unawaited(controller.setUser(ref.read(currentUserIdProvider)));
  });
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(controller.dispose());
  });
  return controller;
});
