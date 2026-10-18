import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/social/family_repository.dart';
import 'package:nimzo/features/social/family_screen.dart';

void main() {
  testWidgets('Family directory shows real membership and an actionable join',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserIdProvider.overrideWithValue('me'),
      familyDirectoryProvider.overrideWith((_) async => [
            const NimzoFamily(
                id: 'one',
                ownerId: 'owner',
                name: 'Voice friends',
                description: 'Welcome',
                memberIds: ['other']),
          ]),
    ], child: const MaterialApp(home: FamilyScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Voice friends'), findsOneWidget);
    expect(find.text('Create Family · 1,000,000 coins'), findsOneWidget);
    expect(find.text('2 members'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Join'))
            .onPressed,
        isNotNull);
    expect(find.text('Family directory is not available yet.'), findsNothing);
  });
}
