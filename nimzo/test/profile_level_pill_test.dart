import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/profile/profile_level_pills.dart';
import 'package:nimzo/features/profile/profile_level_scale.dart';

void main() {
  testWidgets('room and Me use distinct verified wealth/charm/active pills',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              ProfileLevelPill(kind: 0, level: 24),
              ProfileLevelPill(kind: 1, level: 37),
              ProfileLevelPill(kind: 2, level: 22),
            ],
          ),
        ),
      ),
    );

    for (final (kind, level) in [(0, 24), (1, 37), (2, 22)]) {
      expect(find.text('$level'), findsOneWidget);
      final pill = tester.widget<Container>(
        find.byKey(ValueKey('profile-level-pill-$kind')),
      );
      final decoration = pill.decoration! as BoxDecoration;
      expect(decoration.color, ProfileLevelScale.color(kind, level));
      expect(tester.getSize(find.byKey(ValueKey('profile-level-pill-$kind'))).width,
          lessThan(75), reason: 'levels must stay compact, not full-width cards');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing levels never look earned', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProfileLevelPill(kind: 0, level: 0)),
      ),
    );
    expect(find.text('—'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
