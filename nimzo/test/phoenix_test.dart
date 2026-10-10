import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/vip/phoenix_entitlement.dart';
import 'package:nimzo/features/vip/phoenix_widgets.dart';

void main() {
  test('Phoenix requires server level six and unexpired server time', () {
    final now = DateTime.utc(2026);
    final active = PhoenixEntitlement.fromJson({
      'vip_level': 6,
      'server_now': now.toIso8601String(),
      'vip_expires_at': now.add(const Duration(seconds: 10)).toIso8601String(),
    });
    expect(active.isPhoenix, isTrue);
    expect(active.activeAt(const Duration(seconds: 10)), isFalse);
    for (final level in [0, 5, 7, 10]) {
      expect(
        PhoenixEntitlement.fromJson({
          'vip_level': level,
          'server_now': now.toIso8601String(),
          'vip_expires_at': now.add(const Duration(days: 1)).toIso8601String(),
        }).isPhoenix,
        isFalse,
      );
    }
    expect(PhoenixEntitlement.fromJson({'vip_level': 6}).isPhoenix, isFalse);
    expect(
      PhoenixEntitlement.fromJson({
        'vip_level': 6,
        'server_now': now.toIso8601String(),
        'vip_expires_at': now.toIso8601String(),
      }).isPhoenix,
      isFalse,
    );
  });

  testWidgets('reduced motion frame is static and keeps avatar content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: PhoenixFrame(child: Text('Avatar'))),
        ),
      ),
    );
    expect(find.text('Avatar'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('entry announces VIP six accessibly at large text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: PhoenixEntry(name: 'A long Phoenix member name'),
          ),
        ),
      ),
    );
    expect(find.textContaining('VIP 6 Royal Lion'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
