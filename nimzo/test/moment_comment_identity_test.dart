import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/moments/moment_repository.dart';
import 'package:nimzo/features/moments/moments_screen.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';

void main() {
  testWidgets('Moment comments show real author identity on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('viewer'),
          momentDetailProvider('post').overrideWith(
            (_) async => Moment(
              id: 'post',
              authorId: 'author',
              text: 'Post',
              likes: 0,
              comments: 1,
              liked: false,
              createdAt: DateTime(2026),
            ),
          ),
          commentsProvider('post').overrideWith(
            (_) async => [
              {'author_id': 'commenter', 'body': 'Real comment'},
            ],
          ),
          profileProvider('author').overrideWith(
            (_) async =>
                const Profile(id: 'author', nimzoId: 1, displayName: 'Author'),
          ),
          profileProvider('commenter').overrideWith(
            (_) async => const Profile(
              id: 'commenter',
              nimzoId: 2,
              displayName: 'Commenter Name',
            ),
          ),
        ],
        child: const MaterialApp(home: MomentDetailScreen(id: 'post')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Commenter Name'), findsOneWidget);
    expect(find.text('Real comment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
