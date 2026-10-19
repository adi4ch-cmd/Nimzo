import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Premium VAP gift fills room instead of a fixed small center box', () {
    final source = File('lib/features/gifts/hall_of_fame_vap_overlay.dart')
        .readAsStringSync();
    expect(source, contains('scaleType: VapScaleType.centerCrop'));
    expect(source, contains('fit: StackFit.expand'));
    expect(source, contains('Positioned.fill('));
    expect(source, contains('SizedBox.expand(child: VapPlayer(_controller!))'));
    expect(source, isNot(contains('size.width * .92')));
    expect(source, isNot(contains('size.height * .75')));
    expect(source, isNot(contains('VapScaleType.fitCenter')));
  });

  test('Verified gifts use full-screen VAP for all four private originals', () {
    final code = File('lib/features/gifts/verified_gift_broadcast.dart')
        .readAsStringSync();
    expect(code, contains('privateAnimalVapGiftIds.contains('));
    expect(code, contains('HallOfFameVapOverlay('));
    final room = File('lib/features/rooms/presentation/room_screen.dart')
        .readAsStringSync();
    expect(room, contains('Positioned.fill('));
    expect(room, contains('VerifiedGiftBroadcast('));
  });

  test('Only live active gifts enter sendable catalog', () {
    final source = File('lib/features/gifts/gift_repository.dart')
        .readAsStringSync();
    expect(source, contains(".eq('active', true)"));
    expect(source, contains("'gift-media'"));
  });
}
