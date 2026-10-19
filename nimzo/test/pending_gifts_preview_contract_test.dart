import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Pending gift concepts are previews only; not sendable catalog items', () {
    final giftSheet = File('lib/features/gifts/gift_sheet.dart').readAsStringSync();
    final gallery = File('lib/features/gifts/pending_gift_gallery.dart').readAsStringSync();
    final preview = File('lib/features/gifts/staged_gift_previews.dart').readAsStringSync();
    expect(giftSheet, contains('PendingGiftGallery()'));
    expect(gallery, contains('ARTWORK PREVIEW ONLY'));
    expect(gallery, contains('cannot'));
    expect(gallery, isNot(contains("rpc('send_gift'")));
    expect(gallery, isNot(contains('Collect free')));
    expect(preview, contains('Romantic Blossom'));
    expect(preview, contains('Ice Queen Magic'));
    expect(preview, contains('Tiger Warrior'));
    expect(preview, contains('Libra'));
    expect(preview, contains('Aries'));
  });
  test('Live catalog still checks active and server controls settlement', () {
    final source = File('lib/features/gifts/gift_repository.dart').readAsStringSync();
    expect(source, contains(".eq('active', true)"));
    expect(source, contains("'send_gift'"));
  });
}
