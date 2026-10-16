import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/app/app.dart';

void main() {
  testWidgets('new NIMZO app starts with a completely blank UI', (tester) async {
    await tester.pumpWidget(const NimzoApp());

    expect(find.byKey(const ValueKey('nimzo-ui-reset-blank')), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Games'), findsNothing);
    expect(find.text('Profile'), findsNothing);
    expect(find.text('NIMZO'), findsNothing);
  });
}
