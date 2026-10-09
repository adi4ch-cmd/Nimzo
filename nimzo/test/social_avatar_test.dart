import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/core/widgets/reference_widgets.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/social/social_screens.dart';

void main() {
  testWidgets('social lists display actual stored avatar path', (tester) async {
    final db = (await tester.runAsync(
      () async => SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    ))!;
    addTearDown(() => tester.runAsync(db.dispose));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(db),
          socialListProvider(('followers', 'me')).overrideWith(
            (_) async => [
              const Profile(
                id: 'other',
                nimzoId: 123,
                displayName: 'Person',
                avatarPath: 'other/avatar.jpg',
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: SocialListScreen(kind: 'followers', userId: 'me'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<NimzoAvatar>(find.byType(NimzoAvatar)).url,
      'https://example.supabase.co/storage/v1/object/public/avatars/other/avatar.jpg',
    );
  });
}
