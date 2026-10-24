import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/premium/membership_identity.dart';
import 'package:nimzo/features/premium/membership_pack_runtime.dart';
import 'package:nimzo/features/premium/membership_status.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/premium/membership_pack_controls.dart';

void main() {
  testWidgets(
      'all 20 Apply and Remove controls wait for persistent server confirmation',
      (tester) async {
    const slots = [
      'Avatar Frame',
      'Rides',
      'Chat Bubble',
      'Mic Wave',
      'Profile Card',
      'Profile Decoration',
      'ID Frame',
      'Royal Badge',
      'Room Header'
    ];
    for (final kind in ['vip', 'svip']) {
      for (var tier = 1; tier <= 10; tier++) {
        Map<String, dynamic> state = {'vip_level': tier, 'svip_level': tier};
        final calls = <String>[];
        final client = (await tester.runAsync(() async => SupabaseClient(
                'https://example.supabase.co', 'test',
                authOptions: const AuthClientOptions(autoRefreshToken: false),
                httpClient: MockClient((request) async {
              calls.add(request.url.path);
              if (request.url.path.endsWith('apply_full_set')) {
                expect(
                    jsonDecode(request.body), {'p_kind': kind, 'p_tier': tier});
                state = {
                  ...state,
                  'pack_kind': kind,
                  'pack_tier': tier,
                  'primary_kind': kind,
                  'primary_tier': tier,
                  'pack_slots': slots
                };
              } else if (request.url.path.endsWith('remove_full_set')) {
                state = {
                  ...state,
                  'pack_kind': null,
                  'pack_tier': 0,
                  'primary_kind': 'svip',
                  'primary_tier': tier,
                  'pack_slots': []
                };
              } else {
                throw StateError('Unexpected request');
              }
              return http.Response(jsonEncode(state), 200,
                  headers: {'content-type': 'application/json'});
            }))))!;
        await tester.pumpWidget(ProviderScope(
            key: ValueKey('$kind$tier'),
            overrides: [
              sessionSupabaseProvider
                  .overrideWithValue((client: client, userId: 'member')),
              currentUserIdProvider.overrideWithValue('member'),
              effectiveMembershipProvider('member')
                  .overrideWith((_) async => MembershipStatus.fromJson(state)),
            ],
            child: MaterialApp(
                home: Scaffold(
                    body: Column(children: [
              MembershipPackControls(kind: kind, tier: tier),
              const MembershipPackAvatar(
                  userId: 'member',
                  size: 64,
                  child: CircleAvatar(child: Text('Actual avatar'))),
              const MembershipPackChatBubble(
                  userId: 'member', child: Text('Real message')),
            ])))));
        await tester.pumpAndSettle();
        expect(
            find.text(kind == 'vip' && tier == 6
                ? 'Apply Full VIP Set'
                : 'Apply available ${kind.toUpperCase()} items'),
            findsOneWidget);
        await tester.tap(find.byKey(ValueKey('apply-full-$kind-$tier')));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(FilledButton, 'Applied'), findsOneWidget);
        expect(find.byKey(ValueKey('membership-pack-avatar-$kind-$tier')),
            findsOneWidget);
        expect(find.byKey(ValueKey('membership-pack-chat-$kind-$tier')),
            findsOneWidget);
        await tester
            .tap(find.byKey(const ValueKey('remove-full-membership-set')));
        await tester.pumpAndSettle();
        expect(find.text('Ready to apply'), findsOneWidget);
        expect(find.byKey(ValueKey('membership-pack-avatar-$kind-$tier')),
            findsNothing);
        expect(find.byKey(ValueKey('membership-pack-chat-$kind-$tier')),
            findsNothing);
        expect(calls, [
          '/rest/v1/rpc/nimzo_membership_apply_full_set',
          '/rest/v1/rpc/nimzo_membership_remove_full_set'
        ]);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(client.dispose);
      }
    }
  });
  testWidgets('owning a tier without Apply does not equip its full set',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          effectiveMembershipProvider('member')
              .overrideWith((_) async => MembershipStatus.fromJson({
                    'vip_level': 5,
                    'svip_level': 6,
                  })),
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: MembershipPackAvatar(
          userId: 'member',
          size: 64,
          child: CircleAvatar(child: Text('Real avatar')),
        )))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('membership-pack-avatar-svip-6')),
        findsNothing);
    expect(find.text('Real avatar'), findsOneWidget);
  });

  test('server-selected VIP wins over simultaneous SVIP entitlement', () {
    final status = MembershipStatus.fromJson({
      'vip_level': 5,
      'svip_level': 6,
      'primary_kind': 'vip',
      'primary_tier': 5,
      'pack_kind': 'vip',
      'pack_tier': 5,
      'pack_slots': ['Avatar Frame', 'Chat Bubble'],
    });
    expect(MembershipPackTheme.fromStatus(status)?.label, 'VIP 5');
  });

  testWidgets('manual frame override does not disable the matching chat bubble',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          effectiveMembershipProvider('member')
              .overrideWith((_) async => MembershipStatus.fromJson({
                    'vip_level': 5,
                    'pack_kind': 'vip',
                    'pack_tier': 5,
                    'pack_slots': ['Chat Bubble'],
                  })),
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: Column(children: [
          MembershipPackAvatar(
              userId: 'member', size: 64, child: CircleAvatar()),
          MembershipPackChatBubble(
              userId: 'member', child: Text('Real message')),
        ])))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('membership-pack-avatar-vip-5')),
        findsNothing);
    expect(find.byKey(const ValueKey('membership-pack-chat-vip-5')),
        findsOneWidget);
    expect(find.text('Real message'), findsOneWidget);
  });
}
