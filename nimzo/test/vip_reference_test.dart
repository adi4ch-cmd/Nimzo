import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/vip/vip_tier.dart';
void main() {
 test('SVIP preserves all approved thresholds and weekly rewards', () {
  expect(SvipTier.reference.map((t)=>t.usd), [50,200,500,1000,3000,10000,30000,75000,200000,500000]);
  expect(SvipTier.reference.map((t)=>t.weeklyCoins), [2000000,5000000,10000000,20000000,40000000,80000000,150000000,250000000,450000000,800000000]);
 });
 test('next reward respects Sunday 21 Riyadh across UTC week boundary', () {
  expect(nextSvipReward(DateTime.utc(2026,10,11,17,59,59)),DateTime.utc(2026,10,11,18));
  expect(nextSvipReward(DateTime.utc(2026,10,11,18)),DateTime.utc(2026,10,18,18));
  expect(nextSvipReward(DateTime.utc(2026,10,12)),DateTime.utc(2026,10,18,18));
 });
}
