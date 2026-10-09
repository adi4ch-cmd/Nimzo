import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/recharge/purchase_controller.dart';
import 'package:nimzo/features/recharge/recharge_repository.dart';

class TestStore {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('store pending and canceled events never claim coins were credited',
      () async {
    final store = TestStore();
    final container = ProviderContainer(overrides: [
      purchaseUpdatesProvider.overrideWithValue(store.updates.stream)
    ]);
    final checkout = container.read(purchaseControllerProvider);
    final purchase = PurchaseDetails(
        productID: 'coins',
        verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: '',
            source: 'google_play'),
        transactionDate: null,
        status: PurchaseStatus.pending);
    store.updates.add([purchase]);
    await Future<void>.delayed(Duration.zero);
    expect(checkout.busy, true);
    expect(checkout.message, contains('Coins have not been added'));
    purchase.status = PurchaseStatus.canceled;
    store.updates.add([purchase]);
    await Future<void>.delayed(Duration.zero);
    expect(checkout.busy, false);
    expect(checkout.message, 'Checkout canceled.');
    container.dispose();
    await store.updates.close();
  });

  test('requires server account binding and supported store', () {
    expect(
        checkoutReady({
          'ready_stores': ['google_play']
        }, 'google_play'),
        false);
    expect(
        checkoutReady({
          'account_binding': true,
          'ready_stores': ['google_play']
        }, 'google_play'),
        true);
    expect(
        checkoutReady({
          'account_binding': true,
          'ready_stores': ['google_play']
        }, 'app_store'),
        false);
  });
  test('failed verification never finishes; retry settles before finishing',
      () async {
    var settled = false;
    final actions = <String>[];
    final settlement = PurchaseSettlement(verify: () async {
      actions.add('verify');
      if (!settled) throw StateError('offline');
    }, finish: () async {
      actions.add('finish');
    }, refresh: () {
      actions.add('refresh');
    });
    await expectLater(settlement.run(), throwsStateError);
    expect(actions, ['verify']);
    settled = true;
    await settlement.run();
    expect(actions, ['verify', 'verify', 'refresh', 'finish']);
  });
  test('settlement requires matching server-confirmed production credit', () {
    final data = <String, dynamic>{
      'ok': true,
      'status': 'credited',
      'store': 'google_play',
      'product_id': 'coins',
      'transaction_id': 'token',
      'coins': 500,
      'environment': 'production'
    };
    expect(
        confirmedPurchase(data,
            store: 'google_play', productId: 'coins', transactionId: 'token'),
        true);
    data['environment'] = 'sandbox';
    expect(
        confirmedPurchase(data,
            store: 'google_play', productId: 'coins', transactionId: 'token'),
        false);
    data['environment'] = 'production';
    data['product_id'] = 'different';
    expect(
        confirmedPurchase(data,
            store: 'google_play', productId: 'coins', transactionId: 'token'),
        false);
  });
  test('credit followed by store finish failure safely re-verifies on retry',
      () async {
    final actions = <String>[];
    var failFinish = true;
    final settlement = PurchaseSettlement(
      verify: () async {
        actions.add('confirmed-credit-or-replay');
      },
      refresh: () {
        actions.add('refresh');
      },
      finish: () async {
        actions.add('finish');
        if (failFinish) throw StateError('store offline');
      },
    );
    await expectLater(settlement.run(), throwsStateError);
    failFinish = false;
    await settlement.run();
    expect(actions, [
      'confirmed-credit-or-replay',
      'refresh',
      'finish',
      'confirmed-credit-or-replay',
      'refresh',
      'finish'
    ]);
  });
  test('payment errors hide raw provider and receipt details', () {
    expect(safePurchaseError(StateError('receipt secret-token')),
        'The store request could not be completed.');
    expect(safePurchaseError(StateError('Sign in to purchase coins.')),
        'Sign in to purchase coins.');
  });
}
