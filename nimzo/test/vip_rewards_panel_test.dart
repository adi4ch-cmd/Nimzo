import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nimzo/features/vip/vip_repository.dart';
import 'package:nimzo/features/vip/vip_reward_actions.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';

class FakeVipRepository extends VipRepository {
  FakeVipRepository(super.db);
  int dailyCalls = 0;
  int weeklyCalls = 0;

  @override
  Future<void> claimDaily() async { dailyCalls++; }

  @override
  Future<void> claimSvipFriday() async { weeklyCalls++; }
}

void main() {
  final todayStatus = <String, dynamic>{
    'vip_level': 3,
    'svip_level': 6,
    'vip_daily_claimed_today': false,
    'svip_weekly_claimed': false,
    'vip_expires_at': '2026-11-08T00:00:00Z',
  };

  testWidgets('daily VIP claim requires active membership and backend catalog',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        vipDailyRewardsProvider.overrideWith((_) async => [
          {'level': 3, 'coins': 75000}
        ]),
      ],
      child: MaterialApp(home: Scaffold(body:
        VipRewardActions(
          svip: false, status: {...todayStatus, 'vip_level': 0},
          accent: Colors.green,
        ),
      )),
    ));
    await tester.pumpAndSettle();
    final b = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('claim-vip-daily')));
    expect(b.onPressed, isNull);
    expect(find.textContaining('Activate membership'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('daily VIP reward calls the secure server only once per tap',
      (tester) async {
    final db = (await tester.runAsync(
      () async => SupabaseClient('https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final fake = FakeVipRepository(db);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        vipRepositoryProvider.overrideWithValue(fake),
        vipDailyRewardsProvider.overrideWith((_) async => [
          {'level': 3, 'coins': 75000}
        ]),
        vipStatusProvider.overrideWith((_) async => todayStatus),
        walletProvider.overrideWith((_) async => (coins: 0, diamonds: 0)),
      ],
      child: MaterialApp(home: Scaffold(body:
        VipRewardActions(svip: false, status: todayStatus,
          accent: Colors.green),
      )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('claim-vip-daily')));
    await tester.pump();
    expect(fake.dailyCalls, 1);
    expect(fake.weeklyCalls, 0);
    expect(find.textContaining('verified and credited'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sunday SVIP reward uses the existing secure RPC and locks repeats',
      (tester) async {
    final db = (await tester.runAsync(
      () async => SupabaseClient('https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    final fake = FakeVipRepository(db);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        vipRepositoryProvider.overrideWithValue(fake),
        svipFridayRewardsProvider.overrideWith((_) async => [
          {'level': 6, 'coins': 80000000}
        ]),
        vipStatusProvider.overrideWith((_) async => todayStatus),
        walletProvider.overrideWith((_) async => (coins: 0, diamonds: 0)),
      ],
      child: MaterialApp(home: Scaffold(body:
        VipRewardActions(svip: true, status: todayStatus,
          accent: Colors.orange),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sunday, 9:00 PM Saudi'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('claim-svip-weekly')));
    await tester.pump();
    expect(fake.dailyCalls, 0);
    expect(fake.weeklyCalls, 1);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(ProviderScope(
      key: const ValueKey('claimed'),
      overrides: [
        svipFridayRewardsProvider.overrideWith((_) async => [
          {'level': 6, 'coins': 80000000}
        ]),
      ],
      child: MaterialApp(home: Scaffold(body:
        VipRewardActions(svip: true,
          status: {...todayStatus, 'svip_weekly_claimed': true},
          accent: Colors.orange),
      )),
    ));
    await tester.pumpAndSettle();
    final b = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('claim-svip-weekly')));
    expect(b.onPressed, isNull);
    expect(find.text('Already claimed this cycle'), findsOneWidget);
  });
}
