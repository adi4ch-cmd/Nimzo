import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Store screen is backed by live catalog, not mock designs', () {
    final source = File('lib/features/store/store_screen.dart').readAsStringSync();
    expect(source, contains('NimzoLiveStore(initialBag: initialBag)'));
    expect(source, isNot(contains('StoreCategoryPreview')));
    expect(source, isNot(contains('StoreDesignGallery')));
  });
}
