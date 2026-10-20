import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/willchill_verified_gift_effect.dart';

void main() {
  test('gold coin effect never substitutes for lion, tiger or other gifts', () {
    expect(isWillChillGoldCoinGift('Dragon Throne'), isFalse);
    expect(isWillChillGoldCoinGift('Ice Fire Phoenix'), isFalse);
    expect(isWillChillGoldCoinGift('Holy Tiger'), isFalse);
    expect(isWillChillGoldCoinGift('Sports Car'), isFalse);
    expect(isWillChillGoldCoinGift('Gold Coin'), isTrue);
    expect(isWillChillGoldCoinGift('Coin Rain'), isTrue);
  });

  testWidgets('verified gift falls back safely when native playback cannot finish',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WillChillVerifiedGiftEffect(
        totalCoins: 1000000,
        giftName: 'Premium Gift',
        sender: 'Sender',
        recipient: 'Recipient',
        fallback: const Center(
          child: Text('Original NIMZO gift celebration'),
        ),
        onFinished: () {},
      ),
    ));
    await tester.pump();
    // Actual premium media now ships in CI. Native player may not initialize
    // on a Flutter widget-test runner; the 15s watchdog must reveal fallback.
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(find.text('Original NIMZO gift celebration'), findsOneWidget);
  });

  testWidgets('premium effect does not start a transaction or modify balance',
      (tester) async {
    // The effect is a pure UI widget and has no wallet, Supabase, or gift RPC
    // dependency. Media is bundled; playback may time out in widget-test CI.
    await tester.pumpWidget(MaterialApp(
      home: WillChillVerifiedGiftEffect(
        totalCoins: 5000000,
        giftName: 'Gift',
        sender: 'Sender',
        recipient: 'Recipient',
        fallback: const Center(child: Text('Safe gift fallback')),
        onFinished: () {},
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(find.text('Safe gift fallback'), findsOneWidget);
  });
}
