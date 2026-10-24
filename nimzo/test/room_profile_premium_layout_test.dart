import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/premium/membership_identity.dart';
import 'package:nimzo/features/premium/membership_status.dart';
import 'package:nimzo/features/profile/profile_equipped_props.dart';
import 'package:nimzo/features/rooms/presentation/room_seat_identity.dart';
import 'package:nimzo/features/store/store_visual_equipment.dart';
import 'package:nimzo/features/store/premium_cosmetics.dart';

MembershipStatus active(String kind, int tier) => MembershipStatus.fromJson({
      'vip_level': kind == 'vip' ? tier : 0,
      'svip_level': kind == 'svip' ? tier : 0,
      'pack_kind': kind,
      'pack_tier': tier,
      'pack_slots': [
        'ID Frame',
        'Avatar Frame',
        'Royal Badge',
        'Profile Card',
        'Chat Bubble',
      ],
    });

void main() {
  testWidgets('five narrow mic seats keep long names and VIP art bounded',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        for (var i = 0; i < 5; i++) ...[
          effectiveMembershipProvider('user-$i')
              .overrideWith((_) async => active(i.isEven ? 'vip' : 'svip', i + 1)),
          storeVisualEquipmentProvider('user-$i')
              .overrideWith((_) async => <String, CosmeticMedia>{}),
        ],
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Container(
                    height: 104,
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey)),
                    child: Column(
                      children: [
                        const SizedBox(height: 55),
                        RoomSeatIdentity(
                          userId: 'user-$i',
                          displayName: 'Very Long Membership Username $i',
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('room-seat-identity-user-$i')),
          findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('only actually equipped premium props appear and open previews',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        effectiveMembershipProvider('user')
            .overrideWith((_) async => active('vip', 2)),
        storeVisualEquipmentProvider('user')
            .overrideWith((_) async => <String, CosmeticMedia>{}),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileEquippedProps(userId: 'user'),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('profile-equipped-props')),
        findsOneWidget);
    expect(find.text('Equipped VIP 2 props'), findsOneWidget);
    await tester.tap(find.text('ID Frame').first);
    await tester.pump();
    expect(find.text('Close'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
