import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'package:nimzo/features/moments/moment_photo.dart';
import 'package:nimzo/features/moments/moment_repository.dart';
import 'package:nimzo/features/moments/moments_screen.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/image_http_client.dart';

void main() {
  testWidgets(
      'two decoded Moment photos are aligned equal squares with original viewer',
      (tester) async {
    final font = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.sublistView(
          File('test/fonts/Roboto-Regular.ttf').readAsBytesSync())));
    await font.load();
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    final http = FixtureImageHttpClient({
      'weekend-car-a.jpg': File('assets/reference/car/0.jpg').readAsBytesSync(),
      'weekend-car-b.jpg': File('assets/reference/car/1.jpg').readAsBytesSync(),
    });
    debugNetworkImageHttpClientProvider = () => http;
    addTearDown(() {
      debugNetworkImageHttpClientProvider = null;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
    final db = (await tester.runAsync(() async => SupabaseClient(
        'https://fixture.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        supabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue('viewer'),
        profileProvider('author').overrideWith((_) async => const Profile(
            id: 'author', nimzoId: 12345, displayName: 'Alex Morgan')),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: RepaintBoundary(
          key: const ValueKey('moment-layout-preview'),
          child: Scaffold(
            backgroundColor: const Color(0xfff7f5fb),
            appBar: AppBar(title: const Text('Moments')),
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                MomentCard(
                    moment: Moment(
                  id: 'fixture-moment',
                  authorId: 'author',
                  text: 'A little inspiration for the weekend.',
                  images: const ['weekend-car-a.jpg', 'weekend-car-b.jpg'],
                  likes: 24,
                  comments: 3,
                  liked: false,
                  createdAt: DateTime(2026, 10, 19),
                )),
              ]),
            ),
          ),
        ),
      ),
    ));
    await tester.runAsync(() async {
      final context = tester.element(find.byType(MomentCard));
      for (final path in http.fixtures.keys) {
        await precacheImage(
            NetworkImage(db.storage.from('moments').getPublicUrl(path)),
            context);
      }
    });
    await tester.pumpAndSettle();
    final first =
        tester.getRect(find.byKey(const ValueKey('moment-photo-tile-0')));
    final second =
        tester.getRect(find.byKey(const ValueKey('moment-photo-tile-1')));
    expect(tester.getRect(find.text('Alex Morgan')).left, first.left,
        reason: 'Author title and photo grid share the same content inset');
    expect(first.width, first.height);
    expect(second.size, first.size);
    expect(second.top, first.top);
    expect(second.left - first.right, 6);
    expect(find.byType(RawImage), findsAtLeastNWidgets(2));
    final decoded = tester
        .widgetList<RawImage>(find.byType(RawImage))
        .where((image) => image.image != null)
        .toList();
    expect(decoded.length, greaterThanOrEqualTo(2));
    expect(find.text('Image unavailable'), findsNothing);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('moment-layout-preview')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('/tmp/nimzo-moment-layout-preview.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.byKey(const ValueKey('moment-photo-tile-1')));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    final viewer = find.descendant(
        of: find.byType(Dialog), matching: find.byType(MomentPhoto));
    expect(
        tester
            .widgetList<MomentPhoto>(viewer)
            .every((p) => p.fit == BoxFit.contain),
        isTrue);
    expect(
        tester
            .widgetList<MomentPhoto>(viewer)
            .any((p) => p.path == 'weekend-car-b.jpg'),
        isTrue);
    expect(find.byType(InteractiveViewer), findsWidgets);
    expect(tester.takeException(), isNull);
    debugNetworkImageHttpClientProvider = null;
  });
}
