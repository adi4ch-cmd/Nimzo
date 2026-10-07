/// Approved Nimzo membership reference values (2026-10-07).
///
/// These are display-only. The server must authorize membership purchases,
/// verified recharges and weekly rewards. Never credit a wallet using these.
class NimzoVipTiers {
  NimzoVipTiers._();

  static const List<int> normalVipCoins = [
    1000000, 3000000, 8000000, 15000000, 30000000,
    60000000, 100000000, 200000000, 350000000, 600000000,
  ];

  static const List<int> svipRechargeUsd = [
    50, 200, 500, 1000, 3000, 10000, 30000, 75000, 200000, 500000,
  ];

  static const List<int> svipWeeklyCoins = [
    2000000, 5000000, 10000000, 20000000, 40000000,
    80000000, 150000000, 250000000, 450000000, 800000000,
  ];

  static const int coinsPerUsd = 500000;
  static const String rewardTimezone = 'Asia/Riyadh';
  static const int sundayRewardHour = 21;
}
