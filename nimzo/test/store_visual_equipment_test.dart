import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/store/cosmetic_media_view.dart';
import 'package:nimzo/features/store/premium_cosmetics.dart';
import 'package:nimzo/features/store/store_visual_equipment.dart';

const ownId = '00000000-0000-0000-0000-000000000001';
const otherId = '00000000-0000-0000-0000-000000000002';

Widget surface(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets(
    'own and other accounts display their own actual equipped frame',
    (tester) async {
      final own = premiumCosmetics['nimzo-media-frame-gold-circle']!;
      final other = premiumCosmetics['nimzo-media-frame-gold-cp']!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storeVisualEquipmentProvider(ownId)
                .overrideWith((ref) async => {'Avatar Frame': own}),
            storeVisualEquipmentProvider(otherId)
                .overrideWith((ref) async => {'Avatar Frame': other}),
          ],
          child: surface(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EquippedAvatar(
                  key: ValueKey('own-avatar'),
                  userId: ownId,
                  size: 60,
                  child: CircleAvatar(child: Text('Me')),
                ),
                const EquippedAvatar(
                  key: ValueKey('other-avatar'),
                  userId: otherId,
                  size: 60,
                  child: CircleAvatar(child: Text('Other')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ownAvatar = find.byKey(const ValueKey('own-avatar'));
      final otherAvatar = find.byKey(const ValueKey('other-avatar'));
      expect(
        find.descendant(
          of: ownAvatar,
          matching: find.image(AssetImage(own.asset)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: otherAvatar,
          matching: find.image(AssetImage(other.asset)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: ownAvatar,
          matching: find.image(AssetImage(other.asset)),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: otherAvatar,
          matching: find.image(AssetImage(own.asset)),
        ),
        findsNothing,
      );
      expect(find.text('Me'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unequipping immediately removes the frame and retains avatar', (
    tester,
  ) async {
    final frame = premiumCosmetics['nimzo-media-frame-gold-circle']!;
    final equipment = StateProvider<Map<String, CosmeticMedia>>(
      (ref) => {'Avatar Frame': frame},
    );
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeVisualEquipmentProvider(ownId)
              .overrideWith((ref) async => ref.watch(equipment)),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return surface(
              const EquippedAvatar(
                userId: ownId,
                size: 60,
                child: CircleAvatar(child: Text('Me')),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.image(AssetImage(frame.asset)), findsOneWidget);
    container.read(equipment.notifier).state = {};
    await tester.pumpAndSettle();
    expect(find.image(AssetImage(frame.asset)), findsNothing);
    expect(find.text('Me'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'badge and nameplate use the selected media around readable identity',
    (tester) async {
      final badge = premiumCosmetics['nimzo-media-badge-imperial-crown']!;
      final nameplate = premiumCosmetics['nimzo-media-id-gold']!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storeVisualEquipmentProvider(otherId).overrideWith(
              (ref) async => {'Royal Badge': badge, 'ID Frame': nameplate},
            ),
          ],
          child: surface(
            const SizedBox(
              width: 320,
              child: EquippedIdentity(
                userId: otherId,
                child: Text('Room member'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final media = tester
          .widgetList<CosmeticMediaView>(find.byType(CosmeticMediaView))
          .map((widget) => widget.media.asset)
          .toSet();
      expect(media, containsAll([badge.asset, nameplate.asset]));
      expect(find.text('Room member'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile card skin uses selected original image and keeps profile controls',
    (tester) async {
      final card = premiumCosmetics['nimzo-media-profile-blue']!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storeVisualEquipmentProvider(otherId)
                .overrideWith((ref) async => {'Profile Card': card}),
          ],
          child: surface(
            EquippedCosmetic(
              userId: otherId,
              category: 'Profile Card',
              child: SizedBox(
                width: 280,
                height: 180,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Open profile'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.image(AssetImage(card.asset)), findsOneWidget);
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNotNull,
      );
      expect(find.text('Open profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('no equipped appearance leaves identity and avatar visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeVisualEquipmentProvider(otherId).overrideWith((ref) async => {}),
        ],
        child: surface(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EquippedAvatar(
                userId: otherId,
                size: 60,
                child: CircleAvatar(child: Text('N')),
              ),
              EquippedIdentity(userId: otherId, child: Text('Member')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('N'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    expect(find.byType(CosmeticMediaView), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('mic wave is visible only on the speaking seat', (tester) async {
    final wave =
        premiumCosmetics['nimzo-media-mic-voiceroom_mic_wave_default']!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeVisualEquipmentProvider(otherId)
              .overrideWith((ref) async => {'Mic Wave': wave}),
        ],
        child: surface(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EquippedAvatar(
                userId: otherId,
                size: 60,
                speaking: true,
                child: CircleAvatar(child: Text('Speaking')),
              ),
              EquippedAvatar(
                userId: otherId,
                size: 60,
                speaking: false,
                child: CircleAvatar(child: Text('Quiet')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CosmeticMediaView && widget.media.id == wave.id,
      ),
      findsOneWidget,
    );
    expect(find.text('Speaking'), findsOneWidget);
    expect(find.text('Quiet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
