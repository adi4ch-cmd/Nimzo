import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/moments/moment_photo_grid.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    for (final count in [1, 2, 3, 9]) {
      testWidgets('$count Moment photos form a fitted grid at ${width}dp',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = (await tester.runAsync(() async => SupabaseClient(
              'https://example.supabase.co',
              'key',
              authOptions: const AuthClientOptions(autoRefreshToken: false),
            )))!;
        addTearDown(() => tester.runAsync(db.dispose));
        await tester.pumpWidget(ProviderScope(
          overrides: [supabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
              home: Scaffold(
                  body: Padding(
            padding: const EdgeInsets.all(16),
            child: MomentPhotoGrid(
                paths: List.generate(count, (i) => 'user/$i.jpg')),
          ))),
        ));
        await tester.pumpAndSettle();
        final first =
            tester.getRect(find.byKey(const ValueKey('moment-photo-tile-0')));
        expect(first.width, lessThanOrEqualTo(width - 32));
        if (count == 1) {
          expect(first.width / first.height, closeTo(4 / 3, .01));
        } else {
          final second =
              tester.getRect(find.byKey(const ValueKey('moment-photo-tile-1')));
          expect(second.top, first.top);
          expect(second.left - first.right, closeTo(6, .01));
          expect(second.width, closeTo(first.width, .01));
          expect(first.width, closeTo(first.height, .01));
        }
        expect(find.byType(GridView), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'photo tap opens selected full image and swipes without losing feed',
      (tester) async {
    final db = (await tester.runAsync(() async => SupabaseClient(
          'https://example.supabase.co',
          'key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        )))!;
    addTearDown(() => tester.runAsync(db.dispose));
    await tester.pumpWidget(ProviderScope(
      overrides: [supabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
          home: Scaffold(
              body: MomentPhotoGrid(
        paths: ['user/one.jpg', 'user/two.jpg'],
      ))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('moment-photo-tile-1')));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);
    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Close photo'));
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsNothing);
    expect(find.byKey(const ValueKey('moment-photo-tile-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
