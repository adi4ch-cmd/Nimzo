import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimzo/features/events/dynamic_event_banners.dart';
import 'package:nimzo/features/events/events_screen.dart';
import 'package:nimzo/features/games/dynamic_game_catalog.dart';
import 'package:nimzo/features/games/games_catalog_screen.dart';
import 'package:nimzo/features/moments/moment_repository.dart';
import 'package:nimzo/features/moments/moments_screen.dart';

void main() {
  void narrow(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget scaled(Widget child) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.8),
          ),
          child: child!,
        ),
        home: child,
      );

  testWidgets('catalog searches at narrow large text size', (tester) async {
    narrow(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [nimzoLiveGameFlagsProvider.overrideWith((_) async => {})],
      child: scaled(const GamesCatalogScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('game-search-field')), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byType(TextField), 'Teen');
    await tester.pumpAndSettle();
    expect(find.text('1 games'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Teen Patti'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Room coins'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category filter honors remotely disabled games', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        nimzoLiveGameFlagsProvider
            .overrideWith((_) async => {'teen_patti': false})
      ],
      child: const MaterialApp(home: GamesCatalogScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-category-Cards')));
    await tester.pumpAndSettle();
    expect(find.text('0 games'), findsOneWidget);
    expect(find.text('No games match your search.'), findsOneWidget);
    expect(find.byKey(const ValueKey('game-catalog-teen_patti')), findsNothing);
  });

  test('campaign destinations accept only compiled local screens', () {
    expect(supportedEventTarget('/games'), '/games');
    for (final target in [
      '/room/unknown',
      '/games?game=unknown',
      '//example.com',
      'https://example.com',
      '/wallet/exchange',
      null
    ]) {
      expect(supportedEventTarget(target), isNull);
    }
  });

  testWidgets('active event opens its supported destination', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: EventBannerList())),
      GoRoute(
          path: '/games',
          builder: (_, __) => const Scaffold(body: Text('Game destination'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      nimzoEventBannersProvider.overrideWith((_) async => [
            const NimzoEventBanner(
                id: 'event',
                title: 'Room play',
                subtitle: 'Find a game together',
                imageUrl: 'https://example.com/event.png',
                target: '/games')
          ]),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Explore'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('Game destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty events never show bundled reward campaigns',
      (tester) async {
    narrow(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [nimzoEventBannersProvider.overrideWith((_) async => [])],
      child: scaled(const Scaffold(body: EventBannerList())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('More moments to celebrate soon'), findsOneWidget);
    expect(find.text('Glamour Queen'), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('events distinguish pending and failed refreshes',
      (tester) async {
    final request = Completer<List<NimzoEventBanner>>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        nimzoEventBannersProvider.overrideWith((_) => request.future)
      ],
      child: const MaterialApp(home: Scaffold(body: EventBannerList())),
    ));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('More moments to celebrate soon'), findsNothing);
    request.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Events could not be loaded'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('More moments to celebrate soon'), findsNothing);
  });

  testWidgets('empty Moments remains usable with large text on narrow screens',
      (tester) async {
    narrow(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        momentsFeedProvider.overrideWith((_) async => []),
        followedMomentsAuthorsProvider.overrideWith((_) async => {}),
      ],
      child: scaled(const MomentsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No Moments yet'), findsOneWidget);
    expect(find.byTooltip('Create moment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
