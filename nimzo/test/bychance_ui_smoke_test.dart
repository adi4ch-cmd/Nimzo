import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/games/games_catalog_screen.dart';
import 'package:nimzo/features/rooms/presentation/room_themes_screen.dart';
import 'package:nimzo/features/rooms/domain/room_theme.dart';

void main() {
  testWidgets('Tingle-reference Games gallery keeps approved catalog visible', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: GamesCatalogScreen(),
    ));
    expect(find.text('Games'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Grady Lion'), findsOneWidget);
  });

  testWidgets('Room theme gallery preserves included free themes', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RoomThemesScreen(currentTheme: RoomTheme.all.first.id),
    ));
    expect(find.text('Room Themes'), findsOneWidget);
    expect(find.text('NIMZO Original Themes'), findsOneWidget);
    expect(find.byKey(const ValueKey('original-room-theme-gallery')), findsOneWidget);
  });
}
