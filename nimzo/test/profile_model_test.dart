import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/profile/profile.dart';

void main() {
  test(
    'missing earned level records do not create fictional profile badges',
    () {
      final p = Profile.fromJson({'id': 'u', 'nimzo_id': 100001});
      expect([p.wealthLevel, p.charmLevel, p.activeLevel], [0, 0, 0]);
    },
  );
  test('expired VIP and SVIP records do not appear as active membership', () {
    final p = Profile.fromJson({
      'id': 'u',
      'nimzo_id': 100001,
      'vip_level': 5,
      'vip_expires_at': '2020-01-01T00:00:00Z',
      'svip_level': 3,
      'svip_cycle_start': '2020-01-01T00:00:00Z',
    });
    expect(p.vipLevel, 0);
    expect(p.svipLevel, 0);
  });
  test('active memberships retain their actual recorded levels', () {
    final p = Profile.fromJson({
      'id': 'u',
      'nimzo_id': 100001,
      'vip_level': 5,
      'vip_expires_at':
          DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      'svip_level': 3,
      'svip_cycle_start': DateTime.now().toIso8601String(),
    });
    expect(p.vipLevel, 5);
    expect(p.svipLevel, 3);
  });
}
