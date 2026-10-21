import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/profile/profile.dart';

void main() {
  test('missing counters do not create invented badges', () {
    final profile = Profile.fromJson({'id': 'u', 'nimzo_id': 100001});
    expect([profile.wealthLevel, profile.charmLevel, profile.activeLevel],
        [0, 0, 0]);
  });

  test('unrelated profile information remains after legacy entitlement removal', () {
    final profile = Profile.fromJson({
      'id': 'u',
      'nimzo_id': 100001,
      'display_name': 'Review',
      'vip_level': 6,
      'svip_level': 8,
      'vip_expires_at': '2099-01-01T00:00:00Z',
      'wealth_level': 12,
      'charm_level': 4,
    });
    expect(profile.displayName, 'Review');
    expect(profile.wealthLevel, 12);
    expect(profile.charmLevel, 4);
    expect(profile.activeLevel, 0);
  });
}
