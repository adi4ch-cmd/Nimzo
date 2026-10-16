import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/store/store_badge.dart';
import 'package:nimzo/features/store/store_repository.dart';

void main() {
  const actual = RoyalBagItem(
    id: 'verified-royal-4',
    name: 'Royal Crest IV',
    image: 'assets/hilo/store/royal_4.webp',
    equipped: true,
  );

  testWidgets('server equipped Royal Crest IV is visible on profile ID and room',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        equippedRoyalMedalProvider('u').overrideWith((_) async => actual),
      ],
      child: const MaterialApp(
        home: Scaffold(body: Column(
          children: [
            EquippedRoyalMedal(userId: 'u'),
            EquippedRoyalMedal(userId: 'u', compact: true, onDark: true),
          ],
        )),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('equipped-medal-u')), findsNWidgets(2));
    expect(find.byKey(const ValueKey('equipped-medal-art-u')), findsNWidgets(2));
    expect(find.text('Royal Crest IV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('users without server equipped medals never show fake badges',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        equippedRoyalMedalProvider('unawarded')
            .overrideWith((_) async => null),
      ],
      child: const MaterialApp(
        home: Scaffold(body:
          EquippedRoyalMedal(userId: 'unawarded', compact: true)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('equipped-medal-unawarded')), findsNothing);
    expect(find.byIcon(Icons.workspace_premium), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
