import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('obsolete preview-only gift cards cannot appear in live send UI', () {
    final sheet = File('lib/features/gifts/gift_sheet.dart').readAsStringSync();
    expect(sheet, isNot(contains('PendingGiftGallery')));
    expect(sheet, isNot(contains('StagedGiftPreview')));
  });
  test('verified gifts remain server-controlled', () {
    final repo = File('lib/features/gifts/gift_repository.dart').readAsStringSync();
    expect(repo, contains(".eq('active', true)"));
    expect(repo, contains("'send_gift'"));
  });
}
