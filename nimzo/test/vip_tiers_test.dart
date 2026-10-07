import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/vip/vip_tiers.dart';

void main() {
  test('normal VIP coin prices match locked ten-tier contract', () {
    expect(NimzoVipTiers.normalVipCoins, [
      1000000, 3000000, 8000000, 15000000, 30000000,
      60000000, 100000000, 200000000, 350000000, 600000000,
    ]);
  });

  test('SVIP USD qualification and weekly rewards match locked contract', () {
    expect(NimzoVipTiers.svipRechargeUsd, [
      50, 200, 500, 1000, 3000, 10000, 30000, 75000, 200000, 500000,
    ]);
    expect(NimzoVipTiers.svipWeeklyCoins, [
      2000000, 5000000, 10000000, 20000000, 40000000,
      80000000, 150000000, 250000000, 450000000, 800000000,
    ]);
    expect(NimzoVipTiers.coinsPerUsd, 500000);
    expect(NimzoVipTiers.rewardTimezone, 'Asia/Riyadh');
    expect(NimzoVipTiers.sundayRewardHour, 21);
  });

  test('each tier increases in price and reward', () {
    expect(NimzoVipTiers.normalVipCoins.length, 10);
    expect(NimzoVipTiers.svipRechargeUsd.length, 10);
    expect(NimzoVipTiers.svipWeeklyCoins.length, 10);
    for (var i = 1; i < 10; i++) {
      expect(NimzoVipTiers.normalVipCoins[i],
          greaterThan(NimzoVipTiers.normalVipCoins[i - 1]));
      expect(NimzoVipTiers.svipRechargeUsd[i],
          greaterThan(NimzoVipTiers.svipRechargeUsd[i - 1]));
      expect(NimzoVipTiers.svipWeeklyCoins[i],
          greaterThan(NimzoVipTiers.svipWeeklyCoins[i - 1]));
    }
  });
}
