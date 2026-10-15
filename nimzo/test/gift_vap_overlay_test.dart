import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vap_player_platform_interface/vap_player_platform_interface.dart';
import 'package:nimzo/features/gifts/gift_vap_overlay.dart';

// Tests callback/lifecycle contracts, never actual Android video decoding.
class NativeVap extends VapPlayerPlatform {
  final events = StreamController<VapEvent>.broadcast();
  VapCreationOptions? creation;
  VapPlayOptions? played;
  final ready = Completer<void>();
  final creationRequested = Completer<void>();
  Completer<int>? pendingCreation;
  int disposed = 0;
  @override
  Future<int> create(VapCreationOptions options) async {
    creation = options;
    creationRequested.complete();
    return pendingCreation == null ? 1 : await pendingCreation!.future;
  }

  @override
  Stream<VapEvent> vapEventsFor(int id) => events.stream;
  @override
  Future<void> play(int id, VapPlayOptions options) async {
    played = options;
    ready.complete();
  }

  @override
  Future<void> stop(int id) async {}
  @override
  Future<void> dispose(int id) async {
    disposed++;
  }

  @override
  void setResourceDelegate(int id, VapResourceDelegate? delegate) {}
  @override
  Widget buildViewWithOptions(VapViewOptions options) =>
      const SizedBox(key: ValueKey('native-vap'));
}

void main() {
  late NativeVap native;
  late VapPlayerPlatform previous;
  var serial = DateTime.now().microsecondsSinceEpoch;
  setUp(() {
    previous = VapPlayerPlatform.instance;
    native = NativeVap();
    VapPlayerPlatform.instance = native;
    final payload = utf8.encode(jsonEncode({
      'info': {
        'v': 2,
        'w': 540,
        'h': 960,
        'videoW': 1088,
        'videoH': 960,
        'fps': 30,
        'f': 300,
        'isVapx': 0
      }
    }));
    final bytes = ByteData(8 + payload.length)
      ..setUint32(0, 8 + payload.length, Endian.big);
    bytes.buffer.asUint8List().setRange(4, 8, ascii.encode('vapc'));
    bytes.buffer.asUint8List().setRange(8, 8 + payload.length, payload);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (_) async => bytes);
  });
  tearDown(() async {
    VapPlayerPlatform.instance = previous;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    await native.events.close();
  });
  Future<void> show(WidgetTester tester, VoidCallback finish,
      {VoidCallback? fallback,
      String? source,
      bool waitForReady = true}) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: GiftVapOverlay(
                  key: ValueKey(++serial),
                  eventId: 'event_$serial',
                  assetPath: source ?? 'assets/gifts/test_$serial.mp4',
                  sender: 'Sender',
                  recipient: 'Recipient',
                  giftName: 'Royal Lion',
                  quantity: 2,
                  settledCoins: 1000000,
                  onFinished: finish,
                  onUnavailable: fallback))));
      if (source == null && waitForReady) {
        await native.ready.future.timeout(const Duration(seconds: 2));
      } else {
        await Future<void>.delayed(Duration.zero);
      }
    });
    await tester.pump();
  }

  testWidgets(
      'native playback is muted, once-only and carries settled metadata',
      (tester) async {
    await show(tester, () {});
    expect(native.creation?.viewType, VapViewType.textureView);
    expect(native.played?.mute, isTrue);
    expect(native.played?.repeatCount, 0);
    expect(find.text('Sender sent Royal Lion × 2 to Recipient · 1000000 coins'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(native.disposed, 1);
  });
  testWidgets('completion and error callbacks are deduplicated',
      (tester) async {
    var finished = 0;
    await show(tester, () => finished++);
    native.events.add(const VapCompletedEvent());
    native.events.add(const VapErrorEvent(code: 10005));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(finished, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('native failure selects fallback and adds no opaque backdrop',
      (tester) async {
    var fallback = 0, finished = 0;
    await show(tester, () => finished++, fallback: () => fallback++);
    expect(
        tester
            .widgetList<ColoredBox>(find.byType(ColoredBox))
            .every((box) => box.color.a == 0),
        isTrue);
    native.events.add(const VapErrorEvent(code: 10005));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(fallback, 1);
    expect(finished, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('skip releases native player once', (tester) async {
    var finished = 0;
    await show(tester, () => finished++);
    await tester.tap(find.byTooltip('Skip gift animation'));
    await tester.pump();
    expect(finished, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(native.disposed, 1);
  });
  testWidgets('backgrounding dismisses once and releases the decoder',
      (tester) async {
    var finished = 0;
    await show(tester, () => finished++);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(finished, 1);
    expect(native.disposed, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('unmount during delayed initialize never starts playback',
      (tester) async {
    native.pendingCreation = Completer<int>();
    var finished = 0;
    await show(tester, () => finished++, waitForReady: false);
    await tester.runAsync(() =>
        native.creationRequested.future.timeout(const Duration(seconds: 2)));
    await tester.pumpWidget(const SizedBox());
    native.pendingCreation!.complete(1);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(native.played, isNull);
    expect(native.disposed, 1);
    expect(finished, 0);
  });
  testWidgets('stalled playback watchdog selects fallback once',
      (tester) async {
    var fallback = 0;
    await show(tester, () {}, fallback: () => fallback++);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 16)));
    await tester.pump();
    expect(fallback, 1);
    expect(native.disposed, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('invalid sources never reach native playback', (tester) async {
    var fallback = 0;
    await show(tester, () {},
        fallback: () => fallback++, source: 'http://invalid/clip.mp4');
    expect(fallback, 1);
    expect(native.played, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
