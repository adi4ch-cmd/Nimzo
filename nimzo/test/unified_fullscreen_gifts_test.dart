import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Retired concept cards no longer appear in verified gifts', () {
    final sheet = File('lib/features/gifts/gift_sheet.dart').readAsStringSync();
    expect(sheet, isNot(contains('_stagedGiftCard')));
    expect(sheet, isNot(contains('stagedGiftPreviews')));
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
