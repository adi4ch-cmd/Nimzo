import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimzo/app/shell.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'tingle_video_ui_test.dart' show capture, loadReviewFonts;

void main() {
  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets(
        'all five navigation branches retain their scroll position at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadReviewFonts();
      final paths = ['live', 'party', 'moments', 'messages', 'profile'];
      final router = GoRouter(initialLocation: '/live', routes: [
        StatefulShellRoute.indexedStack(
            builder: (_, __, shell) => MainShell(shell: shell),
            branches: [
              for (final path in paths)
                StatefulShellBranch(routes: [
                  GoRoute(
                      path: '/$path',
                      builder: (_, __) => Scaffold(
                            body: ListView(
                                key: PageStorageKey(path),
                                children: [
                                  for (var i = 0; i < 40; i++)
                                    SizedBox(
                                        height: 60, child: Text('$path row $i'))
                                ]),
                          ))
                ]),
            ]),
      ]);
      addTearDown(router.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              routerConfig: router)));
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();
      final original = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      expect(original, greaterThan(0));
      for (var index = 1; index < 5; index++) {
        await tester.tap(find.byKey(ValueKey('tingle-navigation-$index')));
        await tester.pumpAndSettle();
        expect(
            router.routeInformationProvider.value.uri.path, '/${paths[index]}');
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byKey(const ValueKey('tingle-navigation-0')));
      await tester.pumpAndSettle();
      expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .pixels,
          original);
      await capture(tester, 'navigation-${width.toInt()}', key);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
