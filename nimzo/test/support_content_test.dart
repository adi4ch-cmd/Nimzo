import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/support/support_repository.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/support/legal_content.dart';
import 'package:nimzo/features/support/support_screen.dart';

class FakeSupportRepository extends SupportRepository {
  FakeSupportRepository()
    : super(
        SupabaseClient(
          'https://fixture.invalid',
          'fixture-public-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        'fixture-user',
      );
  final submitted = <List<String>>[];
  @override
  Future<void> submit(String category, String subject, String body) async {
    submitted.add([category, subject.trim(), body.trim()]);
  }

  @override
  Future<List<Map<String, dynamic>>> tickets() async => [
    for (final ticket in submitted)
      {
        'subject': ticket[1],
        'body': ticket[2],
        'status': 'submitted',
        'created_at': 'fixture date',
        'response': 'Please update and try again.',
        'responded_at': 'fixture reply date',
      },
  ];
}

void main() {
  testWidgets('valid feedback submits and refreshes owner tickets', (
    tester,
  ) async {
    final repository = FakeSupportRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('fixture-user'),
          supportRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: SupportHelpContent()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      ' A useful subject ',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      ' Reproduction details ',
    );
    await tester.ensureVisible(find.text('Submit ticket'));
    await tester.tap(find.text('Submit ticket'));
    await tester.pumpAndSettle();
    expect(repository.submitted.single, [
      'feedback',
      'A useful subject',
      'Reproduction details',
    ]);
    expect(find.text('A useful subject'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('A useful subject'));
    await tester.tap(find.text('A useful subject'));
    await tester.pumpAndSettle();
    expect(find.text('Support reply'), findsOneWidget);
    expect(find.text('Please update and try again.'), findsOneWidget);
    expect(find.text('fixture reply date'), findsOneWidget);
  });
  testWidgets('signed-out help explains FAQs without accessing backend', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUserIdProvider.overrideWithValue(null)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: SupportHelpContent()),
          ),
        ),
      ),
    );
    expect(
      find.text('Sign in to submit and view your tickets.'),
      findsOneWidget,
    );
    expect(find.text('Submit ticket'), findsNothing);
    await tester.tap(find.text('Does a deletion request delete my account?'));
    await tester.pumpAndSettle();
    expect(
      find.text(supportFaqs['Does a deletion request delete my account?']!),
      findsOneWidget,
    );
  });
  testWidgets('signed-out deletion is request-only and disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUserIdProvider.overrideWithValue(null)],
        child: const MaterialApp(
          home: Scaffold(body: AccountDeletionRequestContent()),
        ),
      ),
    );
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
    expect(find.text('Sign in to request account deletion.'), findsOneWidget);
  });
  test('all five legal documents remain explicitly draft', () {
    expect(legalPolicies.length, 5);
    expect(legalDraftNotice, contains('requires owner and legal review'));
    expect(
      legalPolicies['Account Deletion Policy'],
      contains('does not delete your account'),
    );
    expect(legalPolicies['Refund Policy'], contains('does not issue a refund'));
  });
}
