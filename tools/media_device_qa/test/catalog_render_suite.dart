import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared by the real app's host tests and the isolated Android renderer app.
void catalogRenderSuite({
  String manifestAsset = 'assets/drive_catalog/manifest.json',
  int minimumCount = 9,
  String label = 'Drive catalog',
  Set<String>? mediaKinds,
}) {
  testWidgets('$label contains complete, distinct media', (tester) async {
    final manifest = jsonDecode(
      (await tester.runAsync(() => rootBundle.loadString(manifestAsset)))!,
    ) as Map;
    final records = (manifest['items'] as List)
        .cast<Map>()
        .where(
          (record) =>
              mediaKinds == null || mediaKinds.contains(record['media_kind']),
        )
        .toList();
    expect(records.length, greaterThanOrEqualTo(minimumCount));
    final seen = <String>{};
    for (final record in records.cast<Map>()) {
      debugPrint('RENDERING ${record['id']}');
      final data = (await tester.runAsync(
        () => rootBundle.load(record['asset'] as String),
      ))!;
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      expect(bytes.length, record['bytes'], reason: record['name'] as String);
      expect(sha256.convert(bytes).toString(), record['sha256']);
      expect(seen.add(record['sha256'] as String), isTrue);
      if (record['media_kind'] == 'image') {
        await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(bytes);
          expect(
            codec.frameCount,
            1,
            reason: 'Static cosmetics must be accurately labeled',
          );
          final frame = await codec.getNextFrame();
          expect(frame.image.width, record['width']);
          expect(frame.image.height, record['height']);
          final rgba = (await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          expect(
            Iterable<int>.generate(
              rgba.length ~/ 4,
              (i) => rgba[i * 4 + 3],
            ).any((a) => a > 0),
            isTrue,
          );
          final png = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final base = Platform.isAndroid ? Directory.systemTemp.path : '/tmp';
          final out = Directory('$base/nimzo-drive-rendered')
            ..createSync(recursive: true);
          File('${out.path}/${record['id']}.png')
              .writeAsBytesSync(png!.buffer.asUint8List());
          frame.image.dispose();
          codec.dispose();
        });
        debugPrint(
          'VERIFIED ${record['id']} sha256=${record['sha256']} frames=1 fps=1 distinct=1 visible=1 android=${Platform.isAndroid}',
        );
        continue;
      }
      final movie = await tester.runAsync(
        () => SVGAParser.shared.decodeFromBuffer(bytes),
      );
      expect(movie, isNotNull);
      final params = movie!.params;
      expect(params.frames, greaterThan(1));
      expect(params.fps, inInclusiveRange(1, 60));
      expect(params.viewBoxWidth, inInclusiveRange(1, 4096));
      expect(params.viewBoxHeight, inInclusiveRange(1, 4096));
      expect(movie.sprites, isNotEmpty);
      expect(movie.bitmapCache, isNotEmpty);
      // Missing dynamic text/image slots must not silently become empty art.
      for (final sprite in movie.sprites) {
        final key = sprite.imageKey;
        if (key.isNotEmpty && sprite.frames.every((f) => f.shapes.isEmpty)) {
          expect(
            movie.bitmapCache.containsKey(key) ||
                (key.endsWith('.matte') &&
                    movie.bitmapCache.containsKey(
                      key.substring(0, key.length - 6),
                    )),
            isTrue,
            reason: '${record['name']} missing resource $key',
          );
        }
      }
      final controller = SVGAAnimationController(vsync: tester)..muted = true;
      controller.videoItem = movie;
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: 320,
                height: 320,
                child: SVGAImage(controller, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
      final frameHashes = <String>{};
      var visibleFrames = 0;
      // Capture every frame: catches missing resources late in the movie.
      for (var frame = 0; frame < params.frames; frame++) {
        controller.value = (frame + 0.5) / params.frames;
        expect(controller.currentFrame, frame);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.runAsync(() async {
          final image =
              await (boundaryKey.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 0.5);
          final rgba = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          frameHashes.add(sha256.convert(rgba).toString());
          if (Iterable<int>.generate(
            rgba.length ~/ 4,
            (index) => rgba[index * 4 + 3],
          ).any((alpha) => alpha > 0)) {
            visibleFrames++;
          }
          if (frame == params.frames ~/ 2) {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            {
              final base = Platform.isAndroid
                  ? Directory.systemTemp.path
                  : '/tmp';
              final out = Directory('$base/nimzo-drive-rendered')
                ..createSync(recursive: true);
              File('${out.path}/${record['id']}.png')
                  .writeAsBytesSync(png!.buffer.asUint8List());
            }
          }
          image.dispose();
        });
      }
      expect(
        frameHashes.length,
        greaterThan(2),
        reason: '${record['name']} must animate',
      );
      expect(
        visibleFrames,
        greaterThan(params.frames ~/ 2),
        reason: '${record['name']} must contain visible artwork',
      );
      debugPrint(
        'VERIFIED ${record['id']} sha256=${record['sha256']} '
        'frames=${params.frames} fps=${params.fps} distinct=${frameHashes.length} '
        'visible=$visibleFrames android=${Platform.isAndroid}',
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      expect(tester.takeException(), isNull);
    }
  }, timeout: const Timeout(Duration(minutes: 25)));
}
