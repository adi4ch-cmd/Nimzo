import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/nimzo_gift_control_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('licensed gift controls are packaged intact under NIMZO paths', () async {
    const originals = <String, int>{
      'video_send_gift.webp': 1712,
      'icon_gift_modal.webp': 398,
      'bg_gift_selected_box.webp': 710,
    };
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final entry in originals.entries) {
      final path = 'assets/nimzo/gift_controls/${entry.key}';
      expect(manifest.listAssets(), contains(path));
      final bytes = await rootBundle.load(path);
      expect(bytes.lengthInBytes, entry.value);
    }
  });

  testWidgets('NIMZO gift controls display without imported app branding',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: NimzoGiftControlArt(
            'video_send_gift.webp',
            width: 48,
            height: 48,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(NimzoGiftControlArt), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('Hilo'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
