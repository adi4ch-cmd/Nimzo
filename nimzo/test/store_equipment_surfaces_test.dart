import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/store/premium_cosmetics.dart';
import 'package:nimzo/features/store/store_live_catalog.dart';
import 'package:nimzo/features/store/store_visual_equipment.dart';
import 'package:nimzo/features/store/room_cosmetic_entrance.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';

void main() {
  test('equipment RPC rejects unknown IDs and mismatched categories', () async {
    final db = SupabaseClient('https://example.supabase.co', 'test',
        httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/nimzo_cosmetic_media')) {
        return http.Response('[]', 200,
            request: request,
            headers: {'content-type': 'application/json'});
      }
      expect(request.url.path, endsWith('/rpc/nimzo_store_visual_equipment'));
      expect(jsonDecode(request.body), {
        'p_user_ids': ['member']
      });
      return http.Response(
          jsonEncode([
            {
              'item_id': 'nimzo-media-frame-gold-circle',
              'category': 'Avatar Frame'
            },
            {'item_id': 'nimzo-media-theme-gold', 'category': 'Avatar Frame'},
            {
              'item_id': 'https://untrusted.example/frame',
              'category': 'Avatar Frame'
            },
          ]),
          200,
          request: request,
          headers: {'content-type': 'application/json'});
    }), authOptions: const AuthClientOptions(autoRefreshToken: false));
    final container = ProviderContainer(overrides: [
      sessionSupabaseProvider.overrideWithValue((client: db, userId: 'viewer')),
    ]);
    addTearDown(db.dispose);
    addTearDown(container.dispose);
    final result =
        await container.read(storeVisualEquipmentProvider('member').future);
    expect(result.keys, ['Avatar Frame']);
    expect(result['Avatar Frame']?.id, 'nimzo-media-frame-gold-circle');
  });

  testWidgets(
      'equipped media reaches avatar, speaking wave and room background',
      (tester) async {
    final frame = premiumCosmetics['nimzo-media-frame-gold-circle']!;
    final wave =
        premiumCosmetics['nimzo-media-mic-voiceroom_mic_wave_default']!;
    final theme = premiumCosmetics['nimzo-media-theme-gold']!;
    var speaking = false;
    late StateSetter update;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          storeVisualEquipmentProvider('member').overrideWith((_) async => {
                'Avatar Frame': frame,
                'Mic Wave': wave,
                'Party Theme': theme,
              }),
        ],
        child: MaterialApp(
            home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
          update = setState;
          return EquippedCosmetic(
              userId: 'member',
              category: 'Party Theme',
              child: Center(
                  child: EquippedAvatar(
                      userId: 'member',
                      size: 48,
                      speaking: speaking,
                      child: const Text('Member'))));
        })))));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(ValueKey(frame.id)), findsOneWidget);
    expect(find.byKey(ValueKey(wave.id)), findsNothing);
    expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == theme.asset),
        findsOneWidget);
    update(() => speaking = true);
    await tester.pump();
    expect(find.byKey(ValueKey(wave.id)), findsOneWidget);
    update(() => speaking = false);
    await tester.pump();
    expect(find.byKey(ValueKey(wave.id)), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Backpack removal uses the server category and refreshes equipment',
      (tester) async {
    final calls = <String>[];
    final db = (await tester.runAsync(() async =>
        SupabaseClient('https://example.supabase.co', 'test',
            httpClient: MockClient((request) async {
          calls.add(request.url.path);
          expect(jsonDecode(request.body), {'p_category': 'Avatar Frame'});
          return http.Response('null', 200,
              request: request, headers: {'content-type': 'application/json'});
        }), authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    var removed = false;
    const id = 'nimzo-media-frame-gold-circle';
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionSupabaseProvider.overrideWithValue((client: db, userId: 'viewer')),
      nimzoStoreProvider.overrideWith((_) async {
        final equipped = removed ? <String, String>{} : {'Avatar Frame': id};
        removed = true;
        return NimzoStoreSnapshot(items: [
          const NimzoCosmeticItem(
              id: id,
              category: 'Avatar Frame',
              name: 'Gold Circle',
              variant: 0,
              coinPrice: 0)
        ], owned: {
          id
        }, equipped: equipped);
      }),
    ], child: const MaterialApp(home: NimzoLiveStore())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(calls, ['/rest/v1/rpc/nimzo_store_unequip']);
    expect(find.text('Equip'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.dispose);
  });

  testWidgets(
      'room rides skip historical members and play only newly joined members',
      (tester) async {
    final members = StateProvider<List<String>>((_) => ['old']);
    final lookedUp = <String>[];
    await tester.pumpWidget(ProviderScope(overrides: [
      // The initial list has no viewer, so no own entrance is requested.
      currentUserIdProvider.overrideWithValue('viewer'),
      roomMemberIdsProvider('room')
          .overrideWith((ref) => Stream.value(ref.watch(members))),
      storeVisualEquipmentProvider.overrideWith((_, id) async {
        lookedUp.add(id);
        return {};
      }),
    ], child: const MaterialApp(home: RoomCosmeticEntrance(roomId: 'room'))));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(RoomCosmeticEntrance)));
    await tester.pump();
    expect(lookedUp, isEmpty);
    container.read(members.notifier).state = ['old', 'new'];
    await tester.pump();
    await tester.pump();
    expect(lookedUp, ['new']);
    container.read(members.notifier).state = ['old', 'new'];
    await tester.pump();
    expect(lookedUp, ['new']);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
