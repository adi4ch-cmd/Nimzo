import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimzo/app/shell.dart';
import 'package:nimzo/features/home/home_screen.dart';
import 'package:nimzo/features/events/events_screen.dart';
import 'package:nimzo/features/rooms/domain/room.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';

void main() {
  testWidgets('Home opens My and shows a recent room only once',
      (tester) async {
    final room = Room(
        id: 'recent',
        roomNo: 101,
        name: 'My recent room',
        ownerId: 'u',
        theme: 'nimzo_white',
        isPrivate: false,
        status: 'open',
        createdAt: DateTime(2026));
    await tester.pumpWidget(ProviderScope(overrides: [
      popularRoomsProvider(null).overrideWith((_) async => <Room>[]),
      myRoomsProvider.overrideWith((_) async => {
            'recent': [room],
            'followed': [room]
          }),
    ], child: const MaterialApp(home: HomeScreen())));
    await tester.pumpAndSettle();
    expect(find.text('My recent room'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Discover opens the five supplied event banners', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        popularRoomsProvider(null).overrideWith((_) async => <Room>[]),
        myRoomsProvider.overrideWith(
            (_) async => {'recent': <Room>[], 'followed': <Room>[]}),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    expect(find.text('Event'), findsOneWidget);
    expect(find.bySemanticsLabel('Glamour Queen'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.bySemanticsLabel('Recharge To Get Super Rebate'), 250,
        scrollable: find.descendant(
            of: find.byType(ListView), matching: find.byType(Scrollable)));
    await tester.pumpAndSettle();
    expect(
        find.bySemanticsLabel('Recharge To Get Super Rebate'), findsOneWidget);
    expect(find.text('No rooms found.'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Events header can reopen My after Discover was selected',
      (tester) async {
    final router = GoRouter(initialLocation: '/home?tab=0', routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (_, state) => HomeScreen(
                initialTab:
                    int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 1,
              ),
            )
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/events', builder: (_, __) => const EventsScreen())
          ]),
          for (final name in ['moments', 'messages', 'profile'])
            StatefulShellBranch(routes: [
              GoRoute(path: '/$name', builder: (_, __) => const SizedBox())
            ]),
        ],
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        myRoomsProvider.overrideWith(
            (_) async => {'recent': <Room>[], 'followed': <Room>[]}),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    expect(find.text('Event'), findsOneWidget);
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My'));
    await tester.pumpAndSettle();
    expect(find.text('Event'), findsNothing);
    expect(find.text('No rooms found.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom navigation shows reference labels and opens Events',
      (tester) async {
    final router = GoRouter(initialLocation: '/home', routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(shell: shell),
        branches: [
          for (final name in [
            'home',
            'events',
            'moments',
            'messages',
            'profile'
          ])
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/$name',
                  builder: (_, __) => Center(child: Text('$name page')))
            ]),
        ],
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    for (final label in ['Room', 'Events', 'Square', 'Message', 'Me']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    expect(find.text('events page'), findsOneWidget);
    await tester.tap(find.text('Room'));
    await tester.pumpAndSettle();
    expect(find.text('home page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
