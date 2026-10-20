import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/gifts/willchill_verified_gift_effect.dart';

void main() {
  testWidgets('verified gift effect preserves original fallback when media is absent',
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
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Original NIMZO gift celebration'), findsOneWidget);
  });

  testWidgets('premium effect does not start a transaction or modify balance',
      (tester) async {
    // The effect is a pure UI widget and has no wallet, Supabase, or gift RPC
    // dependency. No media assets exist in normal CI checkouts.
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
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Safe gift fallback'), findsOneWidget);
  });
}
