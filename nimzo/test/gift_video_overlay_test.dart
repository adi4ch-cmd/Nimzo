import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:nimzo/features/gifts/gift_video_overlay.dart';

// Simulates native callbacks; it does not decode or validate the missing videos.
class NativeVideo extends VideoPlayerPlatform {
  StreamController<VideoEvent>? _events;
  StreamController<VideoEvent> get events =>
      _events ??= StreamController<VideoEvent>();
  bool mix = false;
  double volume = -1;
  bool disposed = false;
  Duration duration = const Duration(seconds: 2);
  bool initialize = true;
  DataSource? source;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    source = options.dataSource;
    if (initialize) {
      events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          size: const Size(1920, 1080),
          duration: duration,
        ),
      );
    }
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Future<void> dispose(int playerId) async => disposed = true;
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async =>
      mix = mixWithOthers;
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double value) async => volume = value;
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

void main() {
  late NativeVideo native;
  late VideoPlayerPlatform previous;
  setUp(() {
    previous = VideoPlayerPlatform.instance;
    native = NativeVideo();
    VideoPlayerPlatform.instance = native;
  });
  tearDown(() {
    VideoPlayerPlatform.instance = previous;
    unawaited(native.events.close());
  });

  Future<void> show(
    WidgetTester tester,
    VoidCallback finish, {
    String source = 'https://example.com/original.mp4',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GiftVideoOverlay(
            source: source,
            sender: 'Sender',
            recipient: 'Receiver',
            giftName: 'Dragon × 3',
            muted: true,
            onFinished: finish,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
  }

  testWidgets('voice-safe sound is muted and can be enabled', (tester) async {
    await show(tester, () {});
    expect(native.mix, isTrue);
    expect(native.volume, 0);
    await tester.tap(find.byTooltip('Enable gift sound'));
    await tester.pump();
    expect(native.volume, 0.65);
    expect(find.byTooltip('Mute gift sound'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    expect(native.disposed, isTrue);
  });

  testWidgets('longer original video is not dismissed at thirty seconds', (
    tester,
  ) async {
    native.duration = const Duration(seconds: 45);
    var finished = 0;
    await show(tester, () => finished++);
    await tester.pump(const Duration(seconds: 31));
    expect(finished, 0);
    native.events.add(VideoEvent(eventType: VideoEventType.completed));
    await tester.pump();
    await tester.pump();
    expect(finished, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('decoder failure dismisses once and releases resources', (
    tester,
  ) async {
    var finished = 0;
    await show(tester, () => finished++);
    native.events.addError(
      PlatformException(code: 'decode-failed', message: 'Decoder failure'),
    );
    await tester.pump();
    expect(finished, 1);
    await tester.pump(const Duration(seconds: 40));
    expect(finished, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    expect(native.disposed, isTrue);
  });

  testWidgets('stalled initialization and insecure URL dismiss safely', (
    tester,
  ) async {
    native.initialize = false;
    var finished = 0;
    await show(tester, () => finished++);
    await tester.pump(const Duration(seconds: 16));
    expect(finished, 1);
    // Let native initialization finish so controller disposal can complete.
    native.events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        size: const Size(100, 100),
        duration: const Duration(seconds: 1),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await show(
      tester,
      () => finished++,
      source: 'http://example.com/unsafe.mp4',
    );
    expect(finished, 2);
    await tester.pumpWidget(const SizedBox());
  });
}
