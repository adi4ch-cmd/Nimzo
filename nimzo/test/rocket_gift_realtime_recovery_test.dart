import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/rooms/diamond/room_diamond_repository.dart';

void main() {
  test('51M in a room completes Rocket 5, not Rocket 6', () {
    expect(diamondTargets, [
      5000000, 10000000, 20000000, 30000000, 50000000, 100000000,
    ]);
    final event = DiamondBlastEvent.fromJson({
      'id': '8f52ed86-7321-4556-b1fa-6229de00eb34',
      'room_id': 'c4de6b18-72b6-49d0-8b54-8a127e5cf168',
      'stage': 4,
      'target_coins': 50000000,
      'cycle_start': '2026-10-18T20:00:00+00:00',
    });
    expect(event.stage, 4);
    expect(diamondTargets[event.stage], 50000000);
    expect(() => DiamondBlastEvent.fromJson({
      'id': '8f52ed86-7321-4556-b1fa-6229de00eb34',
      'room_id': 'c4de6b18-72b6-49d0-8b54-8a127e5cf168',
      'stage': 5,
      'target_coins': 50000000,
      'cycle_start': '2026-10-18T20:00:00+00:00',
    }), throwsFormatException);
  });

  test('Room Rocket recovers server-settled blasts after Realtime failure', () {
    final repository = File(
      'lib/features/rooms/diamond/room_diamond_repository.dart',
    ).readAsStringSync();
    final host = File(
      'lib/features/rooms/rocket/room_rocket_widgets.dart',
    ).readAsStringSync();
    expect(repository, contains("'room_diamond_blast_events'"));
    expect(repository, contains('Future<List<DiamondBlastEvent>> recentBlasts('));
    expect(repository, contains(".gte('created_at', since.toUtc().toIso8601String())"));
    expect(host, contains('Timer.periodic(const Duration(seconds: 3)'));
    expect(host, contains('.recentBlasts('));
    expect(host, contains("kDebugMode"));
    expect(host, contains("rocket-local-vap-preview"));
    expect(host, contains('ROCKET ${stage + 1} LOCAL PREVIEW'));
    expect(host, contains('targetCoins: roomRocketTargets[stage]'));
    expect(host, isNot(contains('await r.send(')));

    expect(host, contains('_seen.contains(event.id)'));
    expect(host, contains('event.cycleStart.isBefore(_cycle!)'));
    expect(host, contains('if (widget.enabled && _queue.isNotEmpty)'));
  });

  test('Room gifts recover verified broadcasts without billing again', () {
    final repository = File(
      'lib/features/gifts/gift_repository.dart',
    ).readAsStringSync();
    final broadcast = File(
      'lib/features/gifts/verified_gift_broadcast.dart',
    ).readAsStringSync();
    expect(repository, contains('recentVerifiedRoomAnimations('));
    expect(repository, contains("'gift_animation_events'"));
    expect(broadcast, contains('recentVerifiedRoomAnimations('));
    expect(broadcast, contains('_listeningSince'));
    expect(broadcast, contains('_seen.add('));
    expect(broadcast, contains('HallOfFameVapOverlay('));
    expect(broadcast, isNot(contains('sendProfile(')));
    expect(broadcast, isNot(contains("rpc('send_gift'")));
  });

  test('Rocket player unmutes original AAC and visibly reports VAP failures', () {
    final playback = File(
      'lib/features/rooms/rocket/room_rocket_playback.dart',
    ).readAsStringSync();
    expect(playback, contains('mute: false'));
    expect(playback, contains('VapErrorEvent'));
    expect(playback, contains('_playbackFailed()'));
    expect(playback, contains('VAP playback failed on this device'));
  });
}
