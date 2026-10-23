import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/services/nimzo_content_sync.dart';
import 'package:nimzo/features/profile/profile_level_pills.dart';
import 'package:nimzo/features/profile/profile_level_scale.dart';

Map<String, Map<String, dynamic>> settings() => {
      'progression.styles': {
        'version': 1,
        'styles': [
          for (final kind in ['wealth', 'charm', 'active'])
            {
              'kind': kind,
              'min_level': 1,
              'max_level': 120,
              'color': 'emerald',
              'glyph': 'shield',
              'shape': 'rounded',
            },
        ],
      },
    };

void main() {
  testWidgets(
      'published styles preserve actual levels semantics and narrow layout',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            nimzoRemoteSettingsProvider.overrideWith((_) async => settings()),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.8)),
                child: child!),
            home: const Scaffold(
                body: Row(children: [
              ProfileLevelPill(kind: 0, level: 120),
              ProfileLevelPill(kind: 1, level: 37),
              ProfileLevelPill(kind: 2, level: 22),
            ])),
          )));
      await tester.pumpAndSettle();
      for (final (kind, level) in [(0, 120), (1, 37), (2, 22)]) {
        expect(find.text('$level'), findsOneWidget);
        expect(
            find.bySemanticsLabel(
                '${ProfileLevelScale.labels[kind]} level $level'),
            findsOneWidget);
        final decoration = tester
            .widget<Container>(find.byKey(ValueKey('profile-level-pill-$kind')))
            .decoration! as BoxDecoration;
        expect(decoration.color, const Color(0xff087f5b));
        expect(decoration.borderRadius, BorderRadius.circular(7));
      }
      expect(find.byIcon(Icons.shield_rounded), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('deactivation reverts artwork while level stays unchanged',
      (tester) async {
    var remote = settings();
    final container = ProviderContainer(overrides: [
      nimzoRemoteSettingsProvider.overrideWith((_) async => remote),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: Scaffold(body: ProfileLevelPill(kind: 0, level: 24)))));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
    remote = {};
    container.invalidate(nimzoRemoteSettingsProvider);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.diamond), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    final decoration = tester
        .widget<Container>(find.byKey(const ValueKey('profile-level-pill-0')))
        .decoration! as BoxDecoration;
    expect(decoration.color, ProfileLevelScale.color(0, 24));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable level does not acquire a published earned badge',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          nimzoRemoteSettingsProvider.overrideWith((_) async => settings()),
        ],
        child: const MaterialApp(
            home: Scaffold(body: ProfileLevelPill(kind: 0, level: 0)))));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);
    expect(find.byIcon(Icons.diamond), findsOneWidget);
    expect(find.byIcon(Icons.shield_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
