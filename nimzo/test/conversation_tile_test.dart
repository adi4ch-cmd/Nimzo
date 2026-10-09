import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/messages/messages_screen.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';

void main() {
  testWidgets(
    'conversation uses current profile identity and real message preview',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider('other').overrideWith(
              (_) async => const Profile(
                id: 'other',
                nimzoId: 123,
                displayName: 'Updated name',
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConversationTile(
                row: {
                  'other_id': 'other',
                  'display_name': 'Old name',
                  'last_body': 'Actual message',
                  'unread': 4,
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Updated name'), findsOneWidget);
      expect(find.text('Actual message'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Old name'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
