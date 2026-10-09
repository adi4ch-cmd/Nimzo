import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import '../../core/providers/supabase_provider.dart';
import '../wallet/wallet_screen.dart';
import 'recharge_repository.dart';

bool checkoutReady(Map<dynamic, dynamic> configuration, String store) =>
    configuration['account_binding'] == true &&
    configuration['ready_stores'] is List &&
    (configuration['ready_stores'] as List).contains(store);

class PurchaseSettlement {
  PurchaseSettlement(
      {required this.verify, required this.finish, required this.refresh});
  final Future<void> Function() verify;
  final Future<void> Function() finish;
  final VoidCallback refresh;
  Future<void> run() async {
    await verify();
    refresh();
    await finish();
  }
}

// Allow the stream to be supplied by a platform adapter without starting native
// billing during construction. Native billing starts only after the server gate.
final purchaseUpdatesProvider =
    Provider<Stream<List<PurchaseDetails>>?>((ref) => null);

String safePurchaseError(Object error) {
  const messages = {
    'Sign in to purchase coins.',
    'Coin purchases require the Android or iOS app.',
    'Secure purchases are not configured for this store.',
    'The device store is unavailable.',
    'No active coin packages are available.',
    'Account changed. Reload the store.',
    'Sign in to retry verification.',
    'Account changed during verification. Retry after signing in.',
    'Store consumption failed; retry safely.',
  };
  final message = error is StateError ? error.message.toString() : '';
  return messages.contains(message)
      ? message
      : 'The store request could not be completed.';
}

class PurchaseController extends ChangeNotifier {
  PurchaseController(this.ref) {
    final updates = ref.read(purchaseUpdatesProvider);
    if (updates != null) _listen(updates);
  }
  final Ref ref;
  InAppPurchase? _connection;
  InAppPurchase get _iap => _connection ??= InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  void _listen(Stream<List<PurchaseDetails>> updates) {
    _subscription = updates.listen(_receive, onError: (Object error) {
      busy = false;
      message = 'Store connection failed. Retry loading the store.';
      notifyListeners();
    });
  }

  final Map<String, PurchaseDetails> _retry = {};
  final Set<String> _processing = {};
  final Set<String> _completed = {};
  List<ProductDetails> products = [];
  Map<String, dynamic> packages = {};
  String message = 'Loading store…';
  String environment = 'Unverified';
  bool ready = false;
  bool busy = false;
  bool loading = false;
  String? _catalogAccount;
  String? get store => kIsWeb
      ? null
      : defaultTargetPlatform == TargetPlatform.android
          ? 'google_play'
          : defaultTargetPlatform == TargetPlatform.iOS
              ? 'app_store'
              : null;
  bool get canRetry => _retry.isNotEmpty;
  Future<void> load() async {
    if (loading) return;
    loading = true;
    ready = false;
    notifyListeners();
    try {
      final client = ref.read(supabaseProvider);
      final account = client.auth.currentUser?.id;
      if (account == null) throw StateError('Sign in to purchase coins.');
      if (store == null)
        throw StateError('Coin purchases require the Android or iOS app.');
      final configResponse = await client.functions
          .invoke('verify-purchase', body: {'action': 'configuration'});
      final config = configResponse.data;
      if (configResponse.status != 200 ||
          config is! Map ||
          !checkoutReady(config, store!)) {
        throw StateError('Secure purchases are not configured for this store.');
      }
      environment = config['environment'] == 'store-managed'
          ? 'Store-managed; live payment not yet verified'
          : 'Unverified';
      if (_subscription == null) _listen(_iap.purchaseStream);
      if (!await _iap.isAvailable())
        throw StateError('The device store is unavailable.');
      final rows = await ref.read(rechargeRepositoryProvider).packages();
      packages = {
        for (final row in rows)
          if (row['product_id'] is String) row['product_id'] as String: row
      };
      if (packages.isEmpty)
        throw StateError('No active coin packages are available.');
      final result = await _iap.queryProductDetails(packages.keys.toSet());
      if (result.error != null) throw StateError(result.error!.message);
      if (client.auth.currentUser?.id != account)
        throw StateError('Account changed. Reload the store.');
      _catalogAccount = account;
      products = result.productDetails;
      ready = products.isNotEmpty;
      message = ready
          ? 'Prices are supplied by your device store. Coins arrive after server verification.'
          : 'Coin products are not available in this store.';
      if (result.notFoundIDs.isNotEmpty)
        message += ' Some packages are unavailable.';
    } catch (error) {
      message = safePurchaseError(error);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> buy(ProductDetails product) async {
    if (!ready || busy || loading || canRetry) return;
    final account = ref.read(supabaseProvider).auth.currentUser?.id;
    if (account == null || account != _catalogAccount) {
      ready = false;
      message = 'Account changed. Reload the store.';
      notifyListeners();
      return;
    }
    busy = true;
    message = 'Opening the store checkout…';
    notifyListeners();
    try {
      final started = await _iap.buyConsumable(
          purchaseParam: PurchaseParam(
              productDetails: product, applicationUserName: account),
          autoConsume: store != 'google_play');
      if (!started) {
        busy = false;
        message = 'Store checkout did not start. Please retry.';
      }
    } catch (error) {
      busy = false;
      message = 'Checkout failed. Please retry.';
    }
    notifyListeners();
  }

  String _key(PurchaseDetails purchase) =>
      '${purchase.productID}:${purchase.purchaseID ?? purchase.verificationData.serverVerificationData}';
  Future<void> _receive(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        busy = true;
        message = 'Payment pending in the store. Coins have not been added.';
        notifyListeners();
      } else if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        busy = false;
        message = purchase.status == PurchaseStatus.canceled
            ? 'Checkout canceled.'
            : 'Store payment failed: Please retry.';
        notifyListeners();
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _settle(purchase);
      }
    }
  }

  Future<void> _settle(PurchaseDetails purchase) async {
    final key = _key(purchase);
    if (_completed.contains(key) || !_processing.add(key)) return;
    busy = true;
    message = 'Verifying payment with the server…';
    notifyListeners();
    final account = ref.read(supabaseProvider).auth.currentUser?.id;
    try {
      if (account == null || store == null)
        throw StateError('Sign in to retry verification.');
      // The server binds the store receipt to its original account, including
      // purchases recovered from the store after this controller was recreated.
      await PurchaseSettlement(
        verify: () async {
          await ref.read(rechargeRepositoryProvider).verify(
              store: store!,
              productId: purchase.productID,
              receipt: purchase.verificationData.serverVerificationData,
              transactionId: purchase.purchaseID);
          if (ref.read(supabaseProvider).auth.currentUser?.id != account)
            throw StateError(
                'Account changed during verification. Retry after signing in.');
        },
        refresh: () => ref.invalidate(walletProvider),
        finish: () async {
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          if (store == 'google_play') {
            final result = await _iap
                .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
                .consumePurchase(purchase);
            if (result.responseCode != BillingResponse.ok &&
                result.responseCode != BillingResponse.itemNotOwned)
              throw StateError('Store consumption failed; retry safely.');
          }
        },
      ).run();
      _retry.remove(key);
      _completed.add(key);
      environment = 'Production payment verified by the store and server';
      message = 'Payment verified. Your wallet has been refreshed.';
    } catch (error) {
      _retry[key] = purchase;
      message =
          'Payment not finalized: ${safePurchaseError(error)} Retry verification; do not purchase again.';
    } finally {
      _processing.remove(key);
      busy = false;
      notifyListeners();
    }
  }

  Future<void> retry() async {
    if (busy) return;
    if (_connection == null) {
      message = 'Reload the store before checking unfinished purchases.';
      notifyListeners();
      return;
    }
    try {
      for (final purchase in _retry.values.toList()) {
        await _settle(purchase);
      }
      if (store == 'google_play' && _retry.isEmpty) {
        final result = await _iap
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
            .queryPastPurchases();
        if (result.error != null) throw StateError(result.error!.message);
        for (final purchase in result.pastPurchases) {
          await _settle(purchase);
        }
      }
    } catch (error) {
      message = 'Could not check unfinished purchases. Please retry.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// Keep the purchase stream alive across screen navigation so a late store
// callback is verified rather than lost when the checkout page is closed.
final purchaseControllerProvider =
    ChangeNotifierProvider((ref) => PurchaseController(ref));
