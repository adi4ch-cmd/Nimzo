import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/vip/phoenix_entitlement.dart';

void main() {
  Map<String, dynamic> status(int level) => {
    'vip_level': level,
    'server_now': '2026-10-10T02:00:00Z',
    'vip_expires_at': '2026-10-10T03:00:00Z',
  };

  test('Lion King room entry requires server-verified VIP 10 exactly', () {
    for (final tier in [0, 1, 5, 6, 9]) {
      expect(PhoenixEntitlement.fromJson(status(tier)).isRoyalLion,
        isFalse, reason: 'VIP $tier is not Lion King eligible');
    }
    expect(PhoenixEntitlement.fromJson(status(10)).isRoyalLion, isTrue);
    expect(PhoenixEntitlement.fromJson({
      ...status(10),
      'vip_expires_at': '2026-10-10T01:59:00Z',
    }).isRoyalLion, isFalse);
  });

  test('clock-skew-safe Lion eligibility declines with server latency', () {
    expect(PhoenixEntitlement.fromJson(status(10),
      requestTime: const Duration(hours: 2)).isRoyalLion, isFalse);
    expect(PhoenixEntitlement.fromJson({'vip_level':10}).isRoyalLion, isFalse);
  });
}
