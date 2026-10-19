import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/staged_gift_previews.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('All five missing gifts appear in same gallery as active gifts', () {
    expect(stagedGiftPreviews.map((g) => g.name).toSet(), {
      'Libra', 'Aries', 'Romantic Blossom',
      'Ice Queen Magic', 'Tiger Warrior',
    });
    expect(stagedGiftPreviews.where((g) => g.proposedCoins == 100000).length, 2);
    expect(stagedGiftPreviews.where((g) => g.proposedCoins == 500000).length, 3);
    final sheet = File('lib/features/gifts/gift_sheet.dart').readAsStringSync();
    expect(sheet, contains('_stagedGiftCard('));
    expect(sheet, contains('stagedGiftPreviews.length'));
    expect(sheet, contains('PREVIEW'));
    expect(sheet, contains('No coins charged.'));
    expect(sheet, isNot(contains('NewGiftPreviewCollection(')));
  });

  test('Preview cards use real bundled icons, never a fake paid gift UUID', () async {
    for (final preview in stagedGiftPreviews) {
      final bytes = await rootBundle.load(preview.iconAsset);
      expect(bytes.lengthInBytes, greaterThan(200));
      expect(String.fromCharCodes(bytes.buffer.asUint8List()), contains('<svg'));
    }
    final sheet = File('lib/features/gifts/gift_sheet.dart').readAsStringSync();
    final previewUi = sheet.split('Widget _stagedGiftCard(')[1].split('Widget _giftCard(')[0];
    expect(previewUi, isNot(contains('await r.send(')));
    expect(previewUi, isNot(contains('sendProfile(')));
  });

  test('Full-room VAP playback is never constrained to half viewport', () {
    final source=File('lib/features/gifts/hall_of_fame_vap_overlay.dart').readAsStringSync();
    expect(source, contains('VapScaleType.centerCrop'));
    expect(source, contains('fit: StackFit.expand'));
    expect(source, contains('SizedBox.expand(child: VapPlayer(_controller!))'));
    expect(source, isNot(contains('size.width * .92')));
    expect(source, isNot(contains('size.height * .75')));
  });
}
