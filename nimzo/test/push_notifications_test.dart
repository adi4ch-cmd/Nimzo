import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/services/push_notifications.dart';

class FakePush implements PushGateway {
  bool granted = true;
  Future<bool>? permission;
  final tokens = StreamController<String>.broadcast();
  final taps = StreamController<Map<String, dynamic>>.broadcast();
  @override
  Future<bool> requestPermission() async =>
      permission != null ? await permission! : granted;
  @override
  Future<String?> getToken() async => 'phone-token';
  @override
  Stream<String> get tokenRefresh => tokens.stream;
  @override
  Stream<Map<String, dynamic>> get opened => taps.stream;
  @override
  Future<Map<String, dynamic>?> initialMessage() async => null;
}

void main() {
  test('only signed-in permitted users register and token rotation is saved',
      () async {
    final gateway = FakePush();
    final saved = <String>[];
    final controller = PushNotifications(
        gateway: gateway,
        register: (token) async => saved.add(token),
        open: (_) async {});
    await controller.setUser(null);
    expect(saved, isEmpty);
    await controller.setUser('alice');
    gateway.tokens.add('rotated-token');
    await Future<void>.delayed(Duration.zero);
    expect(saved, ['phone-token', 'rotated-token']);
    await controller.dispose();
    await gateway.tokens.close();
    await gateway.taps.close();
  });
  test('denied permission never registers a device', () async {
    final gateway = FakePush()..granted = false;
    final saved = <String>[];
    final controller = PushNotifications(
        gateway: gateway,
        register: (token) async => saved.add(token),
        open: (_) async {});
    await controller.setUser('alice');
    expect(saved, isEmpty);
    await controller.dispose();
    await gateway.tokens.close();
    await gateway.taps.close();
  });
  test('a pending old-account token cannot register after logout', () async {
    final gateway = FakePush();
    final saved = <String>[];
    final permission = Completer<bool>();
    gateway.permission = permission.future;
    final controller = PushNotifications(
        gateway: gateway,
        register: (token) async => saved.add(token),
        open: (_) async {});
    final pending = controller.setUser('alice');
    await controller.setUser(null);
    permission.complete(true);
    await pending;
    expect(saved, isEmpty);
    await controller.dispose();
    await gateway.tokens.close();
    await gateway.taps.close();
  });
  test('token stream errors do not break the signed-in app', () async {
    final gateway = FakePush();
    final controller = PushNotifications(
        gateway: gateway, register: (_) async {}, open: (_) async {});
    await controller.setUser('alice');
    gateway.tokens.addError(StateError('FCM temporarily unavailable'));
    await Future<void>.delayed(Duration.zero);
    await controller.dispose();
    await gateway.tokens.close();
    await gateway.taps.close();
  });
  test('notification taps only accept matching recipient and UUID identity',
      () {
    const id = '00000000-0000-4000-8000-000000000101';
    expect(
        pushNotificationId(
            {'notification_id': id, 'user_id': 'alice'}, 'alice'),
        id);
    expect(
        pushNotificationId({'notification_id': id, 'user_id': 'bob'}, 'alice'),
        isNull);
    expect(
        pushNotificationId(
            {'notification_id': 'https://evil', 'user_id': 'alice'}, 'alice'),
        isNull);
  });
}
