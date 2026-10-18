import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VAP-only gifts preflight approved media before every paid RPC', () {
    final source = File('lib/features/gifts/gift_sheet.dart').readAsStringSync();
    final preflight = source.indexOf('await r.approvedAnimationUrl(g.id)');
    final roomPayment = source.indexOf('await r.send(');
    final profilePayment = source.indexOf('await r.sendProfile(');
    final momentPayment = source.indexOf(
      'await ref.read(momentRepositoryProvider).sendGift(',
    );
    expect(preflight, greaterThan(0));
    expect(preflight, lessThan(roomPayment));
    expect(preflight, lessThan(profilePayment));
    expect(preflight, lessThan(momentPayment));
    expect(source, contains('throw const _GiftMediaNotReady();'));
    expect(source, contains('No coins were charged'));
    expect(source, contains('showSettledPersonalVapGiftOverlay('));
  });

  test('VAP original movement and sound are used without a price overlay', () {
    final overlay = File(
      'lib/features/gifts/hall_of_fame_vap_overlay.dart',
    ).readAsStringSync();
    expect(overlay, contains('VapPlayerController.networkUrl('));
    expect(overlay, contains('VapPlayer(_controller!)'));
    expect(overlay, contains('VapCompletedEvent'));
    expect(overlay, contains('widget.giftName'));
    expect(overlay.toLowerCase(), isNot(contains('100,000 coins')));
    expect(overlay.toLowerCase(), isNot(contains('500,000 coins')));
    final broadcast = File(
      'lib/features/gifts/verified_gift_broadcast.dart',
    ).readAsStringSync();
    expect(broadcast, contains('zodiacVapGiftIds.contains('));
    expect(broadcast, contains('HallOfFameVapOverlay('));
  });

  test('Server guard protects both activation and paid settlement', () {
    final sql = File(
      '../supabase/migrations/'
      '20261019003000_guard_zodiac_paid_gifts_until_media_ready.sql',
    ).readAsStringSync();
    expect(sql, contains('zodiac_gift_purchase_requires_media'));
    expect(sql, contains('zodiac_gift_activation_requires_media'));
    expect(sql, contains('m.approved is true'));
    expect(sql, contains('no coins charged'));
  });
}
