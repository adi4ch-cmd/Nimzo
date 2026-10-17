import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/social/tingle_friends_screen.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';

void main() {
  testWidgets('Friends, Following and Followers tabs never invent people',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        tinglePeopleProvider(0).overrideWith((_) async => const <String>[]),
        tinglePeopleProvider(1).overrideWith((_) async => const <String>[]),
        tinglePeopleProvider(2).overrideWith((_) async => const <String>[]),
      ],
      child: const MaterialApp(home: TingleFriendsScreen()),
    ));
    await tester.pumpAndSettle();

    for (final tab in const [
      (1, 'Following'),
      (2, 'Followers'),
      (0, 'Friends'),
    ]) {
      await tester.tap(find.byKey(ValueKey('friends-tab-${tab.$1}')));
      await tester.pumpAndSettle();
      expect(find.text('No people here yet'), findsOneWidget,
          reason: 'Empty categories must not display synthetic profiles');
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('Friends search matches the displayed numeric NIMZO ID',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      tinglePeopleProvider(0).overrideWith((_) async => ['internal-user-uuid']),
      profileProvider('internal-user-uuid').overrideWith((_) async =>
          const Profile(
              id: 'internal-user-uuid',
              nimzoId: 123456,
              displayName: 'Known friend')),
    ], child: const MaterialApp(home: TingleFriendsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search friends'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('friends-search')), '123456');
    await tester.pumpAndSettle();
    expect(find.text('Known friend'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
