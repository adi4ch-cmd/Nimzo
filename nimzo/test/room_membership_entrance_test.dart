import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/premium/membership_identity.dart';
import 'package:nimzo/features/premium/membership_catalog.dart';
import 'package:nimzo/features/premium/membership_status.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';
import 'package:nimzo/features/store/store_visual_equipment.dart';
import 'package:nimzo/features/store/room_cosmetic_entrance.dart';
import 'package:nimzo/features/store/cosmetic_media_view.dart';
import 'dart:async';

void main() {
  testWidgets('revoked pack cannot start after a delayed catalog response',
      (tester) async {
    final catalog = Completer<List<MembershipPresentation>>();
    final applied = StateProvider<bool>((_) => true);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('member'),
          roomMemberIdsProvider('room')
              .overrideWith((_) => Stream.value(['member'])),
          membershipPresentationsProvider.overrideWith((_) => catalog.future),
          storeVisualEquipmentProvider.overrideWith((_, __) async => {}),
          effectiveMembershipProvider.overrideWith((ref, _) async {
            final selected = ref.watch(applied);
            return MembershipStatus.fromJson({
              'vip_level': 5,
              'pack_kind': selected ? 'vip' : null,
              'pack_tier': selected ? 5 : 0,
              'pack_slots': selected ? ['Rides'] : []
            });
          }),
        ],
        child: const MaterialApp(
            home: Scaffold(body: RoomCosmeticEntrance(roomId: 'room')))));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(RoomCosmeticEntrance)));
    final visibleMember =
        container.listen(effectiveMembershipProvider('member'), (_, __) {});
    await tester.pump();
    await tester.pump();
    container.read(applied.notifier).state = false;
    await tester.pump();
    await tester.pump();
    catalog.complete([]);
    await tester.pump();
    await tester.pump();
    expect(find.byType(CosmeticMediaView), findsNothing);
    visibleMember.close();
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'observer original entrance plays once for a real new occupant and stops when pack removed',
      (tester) async {
    final members = StateProvider<List<String>>((_) => ['historical']);
    final applied = StateProvider<bool>((_) => true);
    final lookups = <String>[];
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('observer'),
          roomMemberIdsProvider('room')
              .overrideWith((ref) => Stream.value(ref.watch(members))),
          membershipPresentationsProvider.overrideWith((_) async => []),
          storeVisualEquipmentProvider.overrideWith((_, __) async => {}),
          effectiveMembershipProvider.overrideWith((ref, id) async {
            lookups.add(id);
            final selected = ref.watch(applied);
            return MembershipStatus.fromJson({
              'vip_level': 5,
              'pack_kind': selected ? 'vip' : null,
              'pack_tier': selected ? 5 : 0,
              'pack_slots': selected ? ['Rides'] : []
            });
          }),
        ],
        child: const MaterialApp(
            home: Scaffold(body: RoomCosmeticEntrance(roomId: 'room')))));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(RoomCosmeticEntrance)));
    await tester.pump();
    expect(lookups, isEmpty);
    container.read(members.notifier).state = ['historical', 'vip5'];
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(CosmeticMediaView), findsOneWidget);
    final key =
        tester.widget<CosmeticMediaView>(find.byType(CosmeticMediaView)).key;
    expect(
        tester
            .widget<CosmeticMediaView>(find.byType(CosmeticMediaView))
            .media
            .asset,
        'assets/membership/hafla/vip5-room-entry.svga');
    container.read(members.notifier).state = ['historical', 'vip5'];
    await tester.pump();
    expect(tester.widget<CosmeticMediaView>(find.byType(CosmeticMediaView)).key,
        key);
    container.read(applied.notifier).state = false;
    await tester.pump();
    await tester.pump();
    expect(find.byType(CosmeticMediaView), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
