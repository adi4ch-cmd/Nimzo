import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimzo/features/premium/membership_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/premium/membership_pack_runtime.dart';
import 'package:nimzo/features/premium/membership_status.dart';
import 'package:nimzo/features/premium/membership_room_background.dart';
import 'package:nimzo/features/store/cosmetic_media_view.dart';
import 'package:nimzo/features/store/premium_cosmetics.dart';

MembershipStatus _status({int vip = 0, int svip = 0, bool retired = false}) =>
    MembershipStatus.fromJson({
      'retired': retired,
      'vip_level': vip,
      'svip_level': svip,
      'purchases_enabled': false,
      'claims_enabled': false,
      'pack_kind': svip > 0
          ? 'svip'
          : vip > 0
              ? 'vip'
              : null,
      'pack_tier': svip > 0 ? svip : vip,
      'pack_slots': [
        'Avatar Frame',
        'Rides',
        'Chat Bubble',
        'Mic Wave',
        'Profile Card',
        'Profile Decoration',
        'ID Frame',
        'Royal Badge',
        'Room Header'
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every active VIP and SVIP level receives a distinct tier theme', () {
    final vipColors = <Color>{};
    final svipColors = <Color>{};
    for (var tier = 1; tier <= 10; tier++) {
      final vip = MembershipPackTheme.fromStatus(_status(vip: tier));
      final svip = MembershipPackTheme.fromStatus(_status(svip: tier));
      expect(vip?.label, 'VIP $tier');
      expect(svip?.label, 'SVIP $tier');
      vipColors.add(vip!.dark);
      svipColors.add(svip!.dark);
    }
    expect(vipColors.length, 10);
    expect(svipColors.length, 10);
  });

  test(
      'SVIP takes visual precedence and absent/retired memberships do not render',
      () {
    final both = MembershipPackTheme.fromStatus(_status(vip: 3, svip: 7));
    expect(both?.label, 'SVIP 7');
    expect(MembershipPackTheme.fromStatus(_status()), isNull);
    expect(
        MembershipPackTheme.fromStatus(_status(vip: 5, retired: true)), isNull);
  });

  testWidgets('verified live cosmetics render on profile, voice room and chat',
      (tester) async {
    for (final kind in ['vip', 'svip']) {
      for (final tier in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]) {
        final status = _status(
            vip: kind == 'vip' ? tier : 0, svip: kind == 'svip' ? tier : 0);
        await tester.pumpWidget(ProviderScope(
          key: ValueKey('$kind-$tier'),
          overrides: [
            effectiveMembershipProvider('person')
                .overrideWith((_) async => status),
          ],
          child: MaterialApp(
            home: Scaffold(
                body: Column(children: [
              MembershipPackAvatar(
                userId: 'person',
                size: 48,
                child: const CircleAvatar(child: Text('A')),
              ),
              const MembershipPackNameplate(
                  userId: 'person', child: Text('User')),
              const MembershipPackChatBubble(
                  userId: 'person', child: Text('Hello')),
              const MembershipPackRoomBanner(ownerId: 'person'),
              const Expanded(
                  child: MembershipPackRoomAtmosphere(
                      ownerId: 'person', child: SizedBox.expand())),
            ])),
          ),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        for (final name in [
          'avatar',
          'nameplate',
          'chat',
          'room',
          'atmosphere'
        ]) {
          expect(find.byKey(ValueKey('membership-pack-$name-$kind-$tier')),
              findsOneWidget,
              reason: '$name must render for $kind $tier');
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('no active tier causes cosmetic wrappers to fail closed',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        effectiveMembershipProvider('person')
            .overrideWith((_) async => _status(retired: true, vip: 10)),
      ],
      child: const MaterialApp(
          home: Scaffold(
              body: Column(children: [
        MembershipPackAvatar(
            userId: 'person', size: 48, child: CircleAvatar(child: Text('A'))),
        MembershipPackNameplate(userId: 'person', child: Text('User')),
        MembershipPackChatBubble(userId: 'person', child: Text('Hello')),
        MembershipPackRoomBanner(ownerId: 'person'),
      ]))),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('membership-pack-avatar-vip-10')),
        findsNothing);
    expect(find.byKey(const ValueKey('membership-pack-nameplate-vip-10')),
        findsNothing);
    expect(find.byKey(const ValueKey('membership-pack-chat-vip-10')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('VIP 1 live profile frame and chat use its own original art',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        effectiveMembershipProvider('vip1')
            .overrideWith((_) async => _status(vip: 1)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Column(children: [
            MembershipPackAvatar(
                userId: 'vip1',
                size: 64,
                child: CircleAvatar(child: Text('N'))),
            MembershipPackChatBubble(userId: 'vip1', child: Text('Hello')),
          ]),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final imagePaths = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .map((image) => image.assetName)
        .toList();
    expect(
        imagePaths, contains('assets/willchill_premium/vip/icon_vip1_2.png'));
    expect(
        imagePaths,
        contains(
            'assets/membership/packs/29771b99ce574549535a0f30c4dba08599dbb2dbfa9748ec9488a9d4b09eb3b1.png'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('SVIP 5 speaking mic selects its actual Orii SVIP 5 SVGA',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        effectiveMembershipProvider('svip5')
            .overrideWith((_) async => _status(svip: 5)),
      ],
      child: const MaterialApp(
        home: Scaffold(
            body: MembershipPackAvatar(
          userId: 'svip5',
          size: 62,
          speaking: true,
          child: CircleAvatar(child: Text('N')),
        )),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Decoder readiness and frame playback still require Android device QA.
    expect(find.byType(CosmeticMediaView), findsOneWidget);
    final media =
        tester.widget<CosmeticMediaView>(find.byType(CosmeticMediaView)).media;
    expect(media.asset, contains('c1cc37dc26d4f78b5c3626021f95ee'));
    expect(media.kind, CosmeticMediaKind.svga);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('VIP6 original room wallpaper only appears with permission',
      (tester) async {
    Future<void> buildRoom(bool allowOriginal) async {
      await tester.pumpWidget(ProviderScope(
        key: ValueKey('wallpaper-$allowOriginal'),
        overrides: [
          membershipRoomBackgroundProvider('room').overrideWith(
              (_) async => allowOriginal ? (kind: 'vip', tier: 6) : null),
          effectiveMembershipProvider('vip6')
              .overrideWith((_) async => _status(vip: 6)),
        ],
        child: MaterialApp(
            home: Scaffold(
          body: MembershipPackRoomAtmosphere(
            ownerId: 'vip6',
            roomId: 'room',
            allowOriginalBackground: allowOriginal,
            child: const SizedBox.expand(),
          ),
        )),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    await buildRoom(false);
    var surface = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('membership-pack-atmosphere-vip-6')));
    expect((surface.decoration as BoxDecoration).image, isNull,
        reason: 'Custom or non-default room backgrounds must win');

    await buildRoom(true);
    surface = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('membership-pack-atmosphere-vip-6')));
    final image = (surface.decoration as BoxDecoration).image?.image;
    expect(image, isA<AssetImage>());
    expect((image! as AssetImage).assetName,
        'assets/membership/tana-vip6-room-bg.webp');
    expect(tester.takeException(), isNull);
  });

  testWidgets('native VIP entry animates at every tier without media assets',
      (tester) async {
    for (var tier = 1; tier <= 10; tier++) {
      final theme = MembershipPackTheme.fromStatus(_status(vip: tier))!;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MembershipPackEntranceBanner(theme: theme),
        ),
      ));
      await tester.pump();
      expect(find.byKey(ValueKey('membership-pack-entry-vip-$tier')),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    }
  });
}
