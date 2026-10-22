import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimzo/core/services/approved_media_bytes.dart';
import 'package:nimzo/features/rooms/diamond/room_diamond_repository.dart';
import 'package:nimzo/features/rooms/rocket/room_rocket_config.dart';
import 'package:nimzo/features/rooms/rocket/room_rocket_leaderboard.dart';
import 'package:nimzo/features/rooms/rocket/room_rocket_media.dart';
import 'package:nimzo/features/rooms/rocket/room_rocket_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> configRow() => {
      'version': 2,
      'title': 'ORBIT CLUB',
      'subtitle': 'Launch together',
      'thresholds': [100, 300, 600],
      'artwork_stages': [2, 4, 6],
      'stage_labels': ['Spark', 'Orbit', 'Nova'],
      'fly_media': [null, null, null],
      'reward_media': [null, null, null],
      'active': false,
      'published_at': '2026-10-21T10:00:00Z',
    };
Map<String, dynamic> statusRow() => {
      ...configRow()..remove('version'),
      'config_version': 2,
      'total_coins': 450,
      'completed_stages': 2,
      'active_stage': 2,
      'progress': .5,
      'cycle_start': '2026-10-21T20:00:00Z',
      'reset_at': '2026-10-22T20:00:00Z',
      'server_now': '2026-10-21T21:00:00Z',
    };
Map<String, dynamic> mediaRow(Uint8List bytes, {String sound = 'embedded'}) => {
      'url': 'https://approved.example/${sha256.convert(bytes)}.mp4',
      'sha256': sha256.convert(bytes).toString(),
      'byte_size': bytes.length,
      'mime_type': 'video/mp4',
      'codec': 'vap',
      'sound_mode': sound,
      'rights_reference': 'Owner-authorized original Haza test fixture',
      'verified_at': '2026-10-21T10:00:00Z',
      'device_verified_at': '2026-10-21T10:00:00Z',
    };

class _Headers extends Fake implements HttpHeaders {
  @override
  ContentType? get contentType => ContentType('video', 'mp4');
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpHeaders get headers => _Headers();
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.bytes);
  final Uint8List bytes;
  @override
  set followRedirects(bool value) {
    expect(value, isFalse);
  }

  @override
  Future<HttpClientResponse> close() async => _Response(bytes);
}

class _Client extends Fake implements HttpClient {
  _Client(this.bytes);
  final Uint8List bytes;
  @override
  set connectionTimeout(Duration? value) {}
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(bytes);
  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(ApprovedMediaBytes.clearCache);
  test('v3 status accepts only bounded ordered server configuration', () {
    final status = RoomDiamondStatus.fromJson(statusRow());
    expect(status.thresholds, [100, 300, 600]);
    expect(status.configVersion, 2);
    expect(status.config.artworkStages, [2, 4, 6]);
    expect(status.activeStage, 2);
    for (final bad in [
      {
        'thresholds': [100, 90, 600]
      },
      {
        'thresholds': [0, 300, 600]
      },
      {
        'artwork_stages': [1, 2, 7]
      },
      {
        'stage_labels': ['One']
      },
      {'config_version': 0},
      {
        'fly_media': [null]
      },
      {'completed_stages': 4},
    ]) {
      expect(() => RoomDiamondStatus.fromJson({...statusRow(), ...bad}),
          throwsFormatException);
    }
    final event = DiamondBlastEvent.fromJson({
      'id': 'settled',
      'room_id': 'room',
      'stage': 1,
      'target_coins': 300,
      'config_version': 2,
      'artwork_stage': 4,
      'cycle_start': statusRow()['cycle_start'],
    });
    expect(event.targetCoins, 300);
    expect(event.artworkStage, 4);
    expect(event.configVersion, 2);
  });

  test(
      'status uses v3 and event fetch stays on its exact published old version',
      () async {
    final paths = <String>[];
    final client = SupabaseClient('https://example.supabase.co', 'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/rpc/room_rocket_status_v3')) {
        expect(jsonDecode(request.body), {'p_room': 'room'});
        return http.Response(jsonEncode(statusRow()), 200,
            request: request, headers: {'content-type': 'application/json'});
      }
      expect(request.url.path, '/rest/v1/room_rocket_configs');
      expect(request.url.queryParameters['version'], 'eq.2');
      expect(request.url.queryParameters['published_at'], 'not.is.null');
      expect(request.url.queryParameters.containsKey('active'), isFalse);
      return http.Response(jsonEncode(configRow()), 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    final repo = RoomDiamondRepository(client);
    expect((await repo.status('room')).thresholds, [100, 300, 600]);
    final event = DiamondBlastEvent(
        id: 'old-event',
        roomId: 'room',
        stage: 1,
        cycleStart: DateTime.utc(2026, 10, 21, 20),
        configVersion: 2,
        targetCoins: 300,
        artworkStage: 4);
    final pinned = await repo.eventConfig(event);
    expect(pinned.version, 2);
    expect(pinned.artworkStages[event.stage], 4);
    expect(paths.where((path) => path.contains('/rpc/')).length, 1);
    await expectLater(
        repo.eventConfig(DiamondBlastEvent(
            id: 'forged',
            roomId: 'room',
            stage: 1,
            cycleStart: event.cycleStart,
            configVersion: 2,
            targetCoins: 999,
            artworkStage: 4)),
        throwsFormatException);
    await client.dispose();
  });

  test('all remote sound modes choose exactly one soundtrack', () {
    final bytes =
        Uint8List.fromList([0, 0, 0, 12, 102, 116, 121, 112, 0, 0, 0, 0]);
    for (final mode in RocketSoundMode.values) {
      final media =
          RocketMediaDescriptor.fromJson(mediaRow(bytes, sound: mode.name));
      expect(rocketNativeMuted(media), mode != RocketSoundMode.embedded);
      expect(
          rocketSegmentSound(5, reward: true, media: media),
          mode == RocketSoundMode.synthesized
              ? endsWith('nimzo_rocket_reward.wav')
              : isNull);
    }
    expect(rocketNativeMuted(null), isFalse);
    expect(rocketSegmentSound(5, reward: true), isNull);
    expect(rocketSegmentSound(0, reward: false),
        endsWith('nimzo_rocket_launch.wav'));
    for (final bad in [
      {'codec': 'javascript'},
      {'mime_type': 'text/html'},
      {'device_verified_at': null},
      {'sound_mode': 'both'},
      {'url': 'http://unsafe.example/movie.mp4'},
      {'byte_size': 0},
    ]) {
      expect(() => RocketMediaDescriptor.fromJson({...mediaRow(bytes), ...bad}),
          throwsFormatException);
    }
  });

  test('real Haza VAP remote bytes are pinned to a file and cleaned after use',
      () async {
    final bytes =
        await File('assets/room_rocket/vap_rocket_fly_2.mp4').readAsBytes();
    final media = RocketMediaDescriptor.fromJson(mediaRow(bytes));
    await HttpOverrides.runZoned(() async {
      final file = await prepareRocketMediaFile(media);
      expect(await file.file.readAsBytes(), bytes);
      final path = file.file.path;
      await file.dispose();
      expect(await File(path).exists(), isFalse);
    }, createHttpClient: (_) => _Client(bytes));
    ApprovedMediaBytes.clearCache();
    final corrupt = Uint8List.fromList(bytes)..[bytes.length - 1] ^= 1;
    await HttpOverrides.runZoned(() async {
      await expectLater(prepareRocketMediaFile(media), throwsFormatException);
    }, createHttpClient: (_) => _Client(corrupt));
  });

  testWidgets(
      'three dynamic tiers render server labels thresholds artwork and actual history',
      (tester) async {
    tester.view.physicalSize = const Size(280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final status = RoomDiamondStatus.fromJson(statusRow());
    await tester.pumpWidget(ProviderScope(
        overrides: [
          roomDiamondStatusProvider('room').overrideWith((_) async => status),
          roomRocketLeaderboardProvider('room').overrideWith((_) async => []),
          roomRocketHistoryProvider('room').overrideWith((_) async => [
                DiamondBlastEvent(
                    id: 'dynamic-history',
                    roomId: 'room',
                    stage: 1,
                    targetCoins: 300,
                    configVersion: 2,
                    artworkStage: 4,
                    cycleStart: status.cycleStart),
              ]),
        ],
        child: const MaterialApp(
            home: Scaffold(body: RoomRocketSheet(roomId: 'room')))));
    await tester.pumpAndSettle();
    expect(find.text('ORBIT CLUB'), findsOneWidget);
    expect(find.byKey(const ValueKey('rocket-stage-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('rocket-stage-3')), findsNothing);
    expect(find.text('NOVA'), findsOneWidget);
    final image = tester
        .widget<Image>(find.byKey(const ValueKey('selected-rocket-artwork')));
    expect(
        (image.image as AssetImage).assetName, endsWith('rocket_stage_6.png'));
    expect(find.text('600 cumulative coins'), findsOneWidget);
    await tester
        .ensureVisible(find.byKey(const ValueKey('rocket-history-toggle')));
    await tester.tap(find.byKey(const ValueKey('rocket-history-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Rocket 2 · 300 coins'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
