import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/profile/profile.dart';

void main() {
  test('profile reads server SVIP level and active VIP tier', () {
    final p = Profile.fromJson({
      'id': 'test-user',
      'nimzo_id': 100005,
      'svip_level': 5,
      'vip_level': 3,
      'vip_expires_at': '2099-12-31T23:59:59Z',
    });
    expect(p.svipLevel, 5);
    expect(p.vipLevel, 3);
  });

  test('profile does not display an expired VIP membership as active', () {
    final p = Profile.fromJson({
      'id': 'test-user',
      'nimzo_id': 100005,
      'svip_level': 8,
      'vip_level': 7,
      'vip_expires_at': '2000-01-01T00:00:00Z',
    });
    expect(p.svipLevel, 8);
    expect(p.vipLevel, 0);
  });

  test('profiles without membership fields remain compatible', () {
    final p = Profile.fromJson({'id': 'test-user', 'nimzo_id': 100005});
    expect(p.svipLevel, 0);
    expect(p.vipLevel, 0);
  });
}
