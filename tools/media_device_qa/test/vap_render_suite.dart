import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vap_player/flutter_vap_player.dart';

/// Real native VAP decode/render/completion and GPU-texture samples. This does
/// not label sampled pixel checks as every-frame pixel verification.
void vapRenderSuite() {
  testWidgets('premium VAP gifts play complete native animations', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    final manifest = jsonDecode(
      (await tester.runAsync(
        () =>
            rootBundle.loadString('assets/drive_catalog_premium/manifest.json'),
      ))!,
    );
    final allItems = (manifest['items'] as List).cast<Map>();
    expect(allItems.length, manifest['selected_count']);
    expect(allItems.length + (manifest['remaining_count'] as int), 20);
    final items = allItems.where((r) => r['media_kind'] == 'vap').toList();
    expect(items, isNotEmpty);
    for (final r in items) {
      final raw = (await tester.runAsync(() => rootBundle.load(r['asset'])))!;
      final bytes = raw.buffer.asUint8List(
        raw.offsetInBytes,
        raw.lengthInBytes,
      );
      expect(bytes.length, r['bytes']);
      expect(sha256.convert(bytes).toString(), r['sha256']);
      final file = File('${Directory.systemTemp.path}/${r['sha256']}.mp4');
      await tester.runAsync(() => file.writeAsBytes(bytes, flush: true));
      final controller = VapPlayerController.file(
        file,
        options: const VapPlayerOptions(
          viewType: VapViewType.textureView,
          scaleType: VapScaleType.fitCenter,
          repeatCount: 0,
          mute: true,
          enableFrameEvents: true,
        ),
      );
      final rendered = <int>{};
      final errors = <VapErrorEvent>[];
      var completed = false;
      final sub = controller.events.listen((event) {
        if (event is VapFrameEvent) rendered.add(event.frameIndex);
        if (event is VapErrorEvent) errors.add(event);
        if (event is VapCompletedEvent) completed = true;
      });
      final boundary = GlobalKey();
      final hashes = <String>{};
      var visible = 0;
      var samples = 0;
      var saved = false;
      try {
        await tester.runAsync(controller.initialize);
        expect(controller.value.size.width, r['width']);
        expect(controller.value.size.height, r['height']);
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: boundary,
                child: SizedBox(
                  width: 320,
                  height: 400,
                  child: VapPlayer(controller),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.runAsync(controller.play);
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (!completed &&
            errors.isEmpty &&
            DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 150));
          if (rendered.isEmpty) continue;
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: .5);
            final rgba = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            samples++;
            hashes.add(sha256.convert(rgba).toString());
            if (Iterable<int>.generate(
              rgba.length ~/ 4,
              (i) => rgba[i * 4 + 3],
            ).any((a) => a > 0))
              visible++;
            if (!saved &&
                controller.value.currentFrame >= (r['frames'] as int) ~/ 2) {
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final out = Directory(
                '${Directory.systemTemp.path}/nimzo-drive-rendered',
              )..createSync(recursive: true);
              File('${out.path}/${r['id']}.png')
                  .writeAsBytesSync(png!.buffer.asUint8List());
              saved = true;
            }
            image.dispose();
          });
        }
        expect(errors, isEmpty, reason: r['name']);
        expect(completed, isTrue, reason: 'Native completion: ${r['name']}');
        expect(
          rendered.length,
          greaterThanOrEqualTo(((r['frames'] as int) * .9).floor()),
        );
        final ordered = rendered.toList()..sort();
        expect(ordered.first, lessThanOrEqualTo(1));
        expect(ordered.last, greaterThanOrEqualTo((r['frames'] as int) - 1));
        expect(
          hashes.length,
          greaterThan(2),
          reason: 'GPU texture must contain real moving pixels',
        );
        expect(visible, greaterThan(samples ~/ 2));
        expect(saved, isTrue);
        debugPrint(
          'VERIFIED_VAP ${r['id']} sha256=${r['sha256']} declared=${r['frames']} rendered=${rendered.length} first=${ordered.first} last=${ordered.last} samples=$samples distinct=${hashes.length} visible=$visible completed=true android=true',
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await sub.cancel();
        await tester.runAsync(controller.dispose);
        await tester.runAsync(() => file.delete());
      }
      expect(tester.takeException(), isNull);
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
