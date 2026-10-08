import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'package:nimzo/features/rooms/presentation/room_overlays.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';
import 'package:nimzo/features/settings/reference_info_content.dart';

void main() {
  for (final title in [
    'Broadcast',
    'Gathering',
    'Wheel',
    'Mora',
    'Prize',
    'Calculator',
    'Vote',
    'Video',
    'Clean'
  ]) {
    testWidgets('$title reference form scrolls on a small phone with keyboard',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: RoomToolForm(tool: title))))));
      await tester.pumpAndSettle();
      if (find.byType(TextField).evaluate().isNotEmpty) {
        await tester.tap(find.byType(TextField).first);
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'treasure selection changes world conditions without spending coins',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          walletProvider.overrideWith((_) async => (coins: 123, diamonds: 0))
        ],
        child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
                body: Padding(
                    padding: EdgeInsets.all(16), child: TreasureSheet())))));
    await tester.pumpAndSettle();
    expect(find.text('On mic'), findsOneWidget);
    await tester.tap(find.text('World'));
    await tester.pump();
    expect(find.text('On mic'), findsNothing);
    expect(find.text('123 coins'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Send'))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
  for (final title in [
    'Task',
    'Store',
    'Honor Wall',
    'Help and feedback',
    'Privacy',
    'Language'
  ]) {
    testWidgets('$title stays bounded with larger text', (tester) async {
      await tester.pumpWidget(ProviderScope(
          overrides: [currentUserIdProvider.overrideWithValue(null)],
          child: MaterialApp(
              theme: AppTheme.light(),
              home: MediaQuery(
                  data: const MediaQueryData(
                      size: Size(320, 640), textScaler: TextScaler.linear(1.3)),
                  child: Scaffold(
                      body: SizedBox(
                          width: 320,
                          child: SingleChildScrollView(
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: ReferenceInfoContent(
                                      title: title)))))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
