import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';

void main() {
  testWidgets('wallet shows server diamonds and provides one-to-one exchange',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(null),
        walletProvider
            .overrideWith((ref) async => (coins: 7300000, diamonds: 45000)),
      ],
      child: const MaterialApp(home: WalletScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wallet-diamonds')), findsOneWidget);
    expect(find.text('45,000'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('exchange-diamond-amount')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('exchange-diamonds-1-to-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exchange disabled on zero diamonds', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(null),
        walletProvider.overrideWith(
          (ref) async => (coins: 100, diamonds: 0),
        )
      ],
      child: const MaterialApp(home: WalletScreen()),
    ));
    await tester.pumpAndSettle();
    final action = tester.widget<FilledButton>(
      find.byKey(const ValueKey('exchange-diamonds-1-to-1')),
    );
    expect(action.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
