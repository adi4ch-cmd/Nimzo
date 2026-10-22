import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('free premium VAP preview is gated on test account at Edge Function', () {
    final server = File('../supabase/functions/gift-media/index.ts')
        .readAsStringSync();
    expect(server, contains("body.kind==='qa_animation'"));
    expect(server, contains("user.id !== '15e10a70-e8fe-4a1f-afd0-1292ffde3978'"));
    expect(server, contains("return json(403,{error:'QA playback not authorized'})"));
    expect(server, contains("'video.mp4':'thumbnail.png'"));
  });

  test('gift QA preview cannot charge and uses original native VAP', () {
    final repo = File('lib/features/gifts/gift_repository.dart')
        .readAsStringSync();
    final sheet = File('lib/features/gifts/gift_sheet.dart')
        .readAsStringSync();
    expect(repo, contains('qaGiftAnimationUrl(String giftId)'));
    expect(repo, contains("'kind': 'qa_animation'"));
    final preview = sheet.substring(
      sheet.indexOf('Future<void> _testGiftAnimation() async'),
      sheet.indexOf('Future<void> send() async'),
    );
    expect(preview, contains('HallOfFameVapOverlay('));
    expect(preview, contains('FreeGiftSvgaOverlay('));
    expect(preview, isNot(contains('.send(')));
    expect(preview, isNot(contains('send_gift')));
    expect(preview, contains('FREE PLAYBACK TEST · 0 COINS'));
    expect(sheet, contains('gift-playback-free-qa'));
    expect(sheet, contains('kDebugMode'));
  });

  test('failed VAP decoder stays visible instead of silently completing', () {
    final overlay = File('lib/features/gifts/hall_of_fame_vap_overlay.dart')
        .readAsStringSync();
    expect(overlay, contains('void _fail(String reason)'));
    expect(overlay, contains('Gift animation could not play'));
    expect(overlay, contains('VapErrorEvent'));
    expect(overlay, contains('mute: widget.muted'));
    expect(overlay, contains('this.muted = false'));
    expect(overlay, contains('Duration(seconds: 8)'));
    expect(overlay, contains('VapPlayer(_controller!)'));
  });
}
