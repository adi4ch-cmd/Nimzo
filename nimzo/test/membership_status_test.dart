import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/premium/membership_status.dart';

void main() {
  test('retirement overrides stale profile tiers and purchase capability', () {
    final status = MembershipStatus.fromJson({
      'retired': true,
      'vip_level': 10,
      'svip_level': 10,
      'purchases_enabled': true,
    });
    expect(status.vipLevel, 0);
    expect(status.svipLevel, 0);
    expect(status.canPurchase, isFalse);
  });

  test('purchase requires explicit server capability', () {
    expect(MembershipStatus.fromJson({'vip_level': 1}).canPurchase, isFalse);
    expect(
      MembershipStatus.fromJson({'retired': false, 'purchases_enabled': true})
          .canPurchase,
      isTrue,
    );
  });

  test('server effective levels include real tiers beyond artwork range', () {
    final status = MembershipStatus.fromJson({
      'retired': false,
      'vip_level': 10,
      'svip_level': 9,
      'svip_cycle_cents': 3000000,
      'vip_daily_claimed_today': true,
    });
    expect(status.vipLevel, 10);
    expect(status.svipLevel, 9);
    expect(status.cycleCents, 3000000);
    expect(status.vipDailyClaimed, isTrue);
  });
  test('claims require restored capability and valid effective membership', () {
    final status = MembershipStatus.fromJson({
      'retired': false,
      'claims_enabled': true,
      'vip_level': 1,
      'vip_daily_reward_coins': 3000,
      'svip_weekly_claimable': true,
      'svip_weekly_reward_coins': 2000000
    });
    expect(status.canClaim, isTrue);
    expect(status.vipDailyReward, 3000);
    expect(status.svipWeeklyReward, 2000000);
    expect(
        MembershipStatus.fromJson({'retired': true, 'claims_enabled': true})
            .canClaim,
        isFalse);
  });
}
