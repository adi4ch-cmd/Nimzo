import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/moments/moments_screen.dart';
import 'package:nimzo/features/store/store_screen.dart';
import 'package:nimzo/core/widgets/art/nimzo_identity_art.dart';

void main() {
  testWidgets('composer uses the compact header Post action', (tester) async {
    final db = (await tester.runAsync(() async => SupabaseClient(
        'https://example.invalid', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    addTearDown(() => tester.runAsync(db.dispose));
    await tester.pumpWidget(ProviderScope(
        overrides: [supabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: CreateMomentScreen())));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('moment-top-post')), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets('entrance preview replay and reduced motion at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
          home: StoreCategoryPreview(
        category: 'Rides',
        icon: Icons.directions_car_rounded,
        accent: Colors.purple,
      )));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Replay entrance preview'), findsOneWidget);
      await tester.tap(find.byTooltip('Replay entrance preview'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Preview only'), findsOneWidget);
      expect(find.text('Buy'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: StoreCategoryPreview(
            category: 'Rides',
            icon: Icons.directions_car_rounded,
            accent: Colors.purple),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Replay entrance preview'));
      await tester.pump();
      expect(
          tester
              .widgetList<NimzoIdentityArt>(find.byType(NimzoIdentityArt))
              .first
              .progress,
          1);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
