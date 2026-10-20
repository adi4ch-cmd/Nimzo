import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vap_player/flutter_vap_player.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nimzo/features/store/cosmetic_media_view.dart';
import 'package:nimzo/features/store/premium_cosmetics.dart';
import 'package:nimzo/features/store/store_visual_equipment.dart';

const _memberId = '00000000-0000-0000-0000-000000000002';

/// Uses real elapsed time without waiting for continuously repeating SVGAs.
Future<void> _renderFor(WidgetTester tester, Duration duration) async {
  final clock = Stopwatch()..start();
  while (clock.elapsed < duration) {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

Widget _stage(String title, Widget child) => MaterialApp(
  home: Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _AlphaBackdrop()),
        const Positioned(
          left: 12,
          bottom: 12,
          child: Text(
            'NIMZO native media QA • background must remain visible',
            style: TextStyle(fontSize: 12, color: Color(0xff30213d)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: child),
        ),
      ],
    ),
  ),
);

class _AlphaBackdrop extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tile = 32.0;
    final paint = Paint();
    for (var y = 0; y < (size.height / tile).ceil(); y++) {
      for (var x = 0; x < (size.width / tile).ceil(); x++) {
        paint.color = (x + y).isEven
            ? const Color(0xfff8f4ff)
            : const Color(0xffd6cbe8);
        canvas.drawRect(Rect.fromLTWH(x * tile, y * tile, tile, tile), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AlphaBackdrop oldDelegate) => false;
}

void _expectHealthy(WidgetTester tester, String label) {
  expect(tester.takeException(), isNull, reason: label);
  expect(find.byIcon(Icons.broken_image_outlined), findsNothing, reason: label);
  expect(
    find.byIcon(Icons.hourglass_empty),
    findsNothing,
    reason: '$label did not decode',
  );
  expect(
    find.byIcon(Icons.play_circle_outline),
    findsNothing,
    reason: '$label VAP did not initialize',
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'all bundled Store media decodes and equipment renders on Android',
    (tester) async {
      await tester.pumpWidget(
        _stage('Native Store media', const Text('Starting')),
      );
      // Android needs conversion before screenshots can capture Flutter textures.
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      final photographedCategories = <String>{};
      final verified = <Map<String, Object>>[];
      for (final media in premiumCosmetics.values) {
        await tester.pumpWidget(
          _stage(
            '${media.category}: ${media.name}',
            SizedBox(
              width: 330,
              height: 420,
              child: CosmeticMediaView(key: ValueKey(media.id), media: media),
            ),
          ),
        );
        final native = media.kind == CosmeticMediaKind.vap;
        if (native) {
          final readyDeadline = Stopwatch()..start();
          while (readyDeadline.elapsed < const Duration(seconds: 10)) {
            final players = find.byType(VapPlayer).evaluate();
            if (players.isNotEmpty &&
                (players.single.widget as VapPlayer).controller.value.isPlaying)
              break;
            if (find.byIcon(Icons.broken_image_outlined).evaluate().isNotEmpty)
              break;
            await _renderFor(tester, const Duration(milliseconds: 100));
          }
          expect(
            find.byType(VapPlayer),
            findsOneWidget,
            reason: '${media.id} did not initialize in 10 seconds',
          );
          // These entrances are precisely 48 frames at 16fps (3 seconds).
          // Photograph during playback, before the completed texture clears.
          await _renderFor(tester, const Duration(milliseconds: 800));
          final nativeValue = tester
              .widget<VapPlayer>(find.byType(VapPlayer))
              .controller
              .value;
          expect(nativeValue.isInitialized, isTrue, reason: media.id);
          expect(
            nativeValue.hasError,
            isFalse,
            reason: '${media.id}: ${nativeValue.errorDescription}',
          );
          expect(
            nativeValue.isPlaying,
            isTrue,
            reason: '${media.id}: native decoder did not start',
          );
          expect(
            nativeValue.size,
            const Size(750, 600),
            reason: 'VAP must expose its composited view, not packed RGB/alpha dimensions',
          );
          expect(nativeValue.frameCount, 48, reason: media.id);
          expect(nativeValue.fps, 16, reason: media.id);
        } else {
          await _renderFor(tester, const Duration(seconds: 3));
        }
        _expectHealthy(tester, media.id);
        switch (media.kind) {
          case CosmeticMediaKind.image:
            expect(
              find.image(AssetImage(media.asset)),
              findsOneWidget,
              reason: media.id,
            );
            break;
          case CosmeticMediaKind.svga:
            expect(find.byType(SVGAImage), findsOneWidget, reason: media.id);
            break;
          case CosmeticMediaKind.vap:
            expect(find.byType(VapPlayer), findsOneWidget, reason: media.id);
            break;
        }
        // Each category has visual evidence; every distinct native VAP decoder
        // input is photographed individually against the alpha checkerboard.
        if (photographedCategories.add(media.category) || native) {
          final bytes = await binding.takeScreenshot('store-${media.id}');
          expect(
            bytes.length,
            greaterThan(1000),
            reason: 'Empty screenshot for ${media.id}',
          );
        }
        if (native) {
          await _renderFor(tester, const Duration(milliseconds: 2200));
          _expectHealthy(tester, '${media.id} complete playback');
        }
        verified.add({
          'id': media.id,
          'kind': media.kind.name,
          'category': media.category,
          'asset': media.asset,
        });
      }

      final frame = premiumCosmetics['nimzo-media-frame-family']!;
      final wave =
          premiumCosmetics['nimzo-media-mic-voiceroom_mic_wave_default']!;
      final badge = premiumCosmetics['nimzo-media-badge-imperial-crown']!;
      final nameplate = premiumCosmetics['nimzo-media-id-gold']!;
      final card = premiumCosmetics['nimzo-media-profile-blue']!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storeVisualEquipmentProvider(_memberId).overrideWith(
              (ref) async => {
                'Avatar Frame': frame,
                'Mic Wave': wave,
                'Royal Badge': badge,
                'ID Frame': nameplate,
                'Profile Card': card,
              },
            ),
          ],
          child: _stage(
            'Equipped member • appearance only',
            SizedBox(
              width: 320,
              child: EquippedCosmetic(
                userId: _memberId,
                category: 'Profile Card',
                fit: BoxFit.fill,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 42, 24, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const EquippedAvatar(
                        userId: _memberId,
                        size: 76,
                        speaking: true,
                        child: CircleAvatar(radius: 38, child: Text('A')),
                      ),
                      const SizedBox(height: 24),
                      const EquippedIdentity(
                        userId: _memberId,
                        child: Text(
                          'Room member',
                          style: TextStyle(
                            color: Color(0xff30213d),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const EquippedAvatar(
                        userId: _memberId,
                        size: 64,
                        speaking: false,
                        child: CircleAvatar(radius: 32, child: Text('Quiet')),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () {},
                        child: const Text('Open profile'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _renderFor(tester, const Duration(seconds: 3));
      _expectHealthy(tester, 'Equipped appearance');
      final rendered = tester
          .widgetList<CosmeticMediaView>(find.byType(CosmeticMediaView))
          .toList();
      expect(
        rendered.where((widget) => widget.media.id == wave.id),
        hasLength(1),
        reason: 'Quiet seat must not animate a mic wave',
      );
      expect(
        rendered.where((widget) => widget.media.id == frame.id),
        hasLength(2),
      );
      expect(rendered.any((widget) => widget.media.id == badge.id), isTrue);
      expect(rendered.any((widget) => widget.media.id == nameplate.id), isTrue);
      expect(find.image(AssetImage(card.asset)), findsOneWidget);
      expect(find.text('Room member'), findsOneWidget);
      expect(find.text('Quiet'), findsOneWidget);
      await tester.tap(find.text('Open profile'));
      await tester.pump();
      await binding.takeScreenshot('store-equipped-member-card');

      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['store_native_media'] = verified;
      binding.reportData!['store_native_media_count'] = verified.length;
      // Console evidence survives a failure in a later host-driver step too.
      debugPrint('NIMZO_STORE_NATIVE_MEDIA_VERIFIED=${jsonEncode(verified)}');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
