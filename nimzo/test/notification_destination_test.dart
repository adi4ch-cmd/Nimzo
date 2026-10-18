import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/notifications/notification_repository.dart';

void main() {
  test('social notice opens the actual actor or CP flow', () {
    expect(
        notificationDestination({'event_type': 'follow', 'actor_id': 'user'}),
        '/profile/user');
    expect(
        notificationDestination(
            {'event_type': 'friend_request', 'actor_id': 'user'}),
        '/profile/user');
    expect(
        notificationDestination(
            {'event_type': 'cp_accepted', 'actor_id': 'user'}),
        '/cp');
  });
  test('legacy or unsupported notice does not invent a target', () {
    expect(notificationDestination({'category': 'system'}), isNull);
    expect(notificationDestination({'event_type': 'store', 'actor_id': 'user'}),
        isNull);
  });
}
