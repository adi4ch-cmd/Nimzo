import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/premium/membership_identity.dart';
import 'package:nimzo/features/premium/membership_status.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:nimzo/features/profile/tingle_me_screen.dart';
import 'package:nimzo/features/store/store_live_catalog.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';
import 'tingle_video_ui_test.dart' show account;

void main() {
  for (final kind in ['vip', 'svip']) {
    testWidgets('Me avatar reflects applied $kind pack and removal',
        (tester) async {
      final status =
          StateProvider<MembershipStatus?>((_) => MembershipStatus.fromJson({
                'vip_level': 5,
                'svip_level': 6,
                'pack_kind': kind,
                'pack_tier': kind == 'vip' ? 5 : 6,
                'pack_slots': ['Avatar Frame', 'Royal Badge'],
              }));
      await tester.pumpWidget(ProviderScope(overrides: [
        currentUserIdProvider.overrideWithValue('review'),
        profileProvider('review').overrideWith((_) async => account),
        profileStatsProvider('review')
            .overrideWith((_) async => {'following': 0, 'followers': 0}),
        walletProvider
            .overrideWith((_) async => throw StateError('No wallet fixture')),
        nimzoStoreProvider.overrideWith((_) async =>
            const NimzoStoreSnapshot(items: [], owned: {}, equipped: {})),
        effectiveMembershipProvider('review')
            .overrideWith((ref) async => ref.watch(status)),
      ], child: const MaterialApp(home: TingleMeScreen())));
      await tester.pumpAndSettle();
      final key =
          ValueKey('membership-pack-avatar-$kind-${kind == 'vip' ? 5 : 6}');
      expect(find.byKey(key), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
      final container = ProviderScope.containerOf(
          tester.element(find.byType(TingleMeScreen)));
      container.read(status.notifier).state = null;
      await tester.pumpAndSettle();
      expect(find.byKey(key), findsNothing);
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
