import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/services/local_push_presenter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getNotificationAppLaunchDetails')
        return {'notificationLaunchedApp': false};
      return true;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));
  test('Android activity channel enables sound and vibration', () async {
    final presenter =
        LocalPushPresenter(FlutterLocalNotificationsPlugin(), () => 'alice');
    await presenter.initialize();
    final args = calls
        .firstWhere((c) => c.method == 'createNotificationChannel')
        .arguments as Map;
    final config = args;
    expect(config['id'], 'nimzo_activity');
    expect(config['playSound'], true);
    expect(config['enableVibration'], true);
    await presenter.dispose();
  });
  test('foreground notification is private, identity-only and account scoped',
      () async {
    final presenter =
        LocalPushPresenter(FlutterLocalNotificationsPlugin(), () => 'alice');
    await presenter.initialize();
    await presenter.show({
      'notification_id': '00000000-0000-4000-8000-000000000101',
      'user_id': 'bob'
    });
    expect(calls.where((c) => c.method == 'show'), isEmpty);
    await presenter.show({
      'notification_id': '00000000-0000-4000-8000-000000000101',
      'user_id': 'alice',
      'body': 'Private message must not leak'
    });
    final args = calls.firstWhere((c) => c.method == 'show').arguments as Map;
    expect(args['title'], 'NIMZO');
    expect(args['body'], 'Open NIMZO to view your notification.');
    expect(args.toString(), isNot(contains('Private message must not leak')));
    await presenter.dispose();
  });
}
