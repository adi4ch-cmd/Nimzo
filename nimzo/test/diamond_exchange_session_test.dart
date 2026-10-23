import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/wallet/diamond_exchange_session.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'an older declined attempt cannot clear a newer uncertain retry of the same key',
      () async {
    final old = DiamondExchangeSession('account-a');
    final entered = Completer<void>(),
        reply = Completer<Map<String, dynamic>>();
    final inFlight = old.submit(100, (_) {
      entered.complete();
      return reply.future;
    });
    final rejected = expectLater(inFlight, throwsA(isA<PostgrestException>()));
    await entered.future;
    final reopened = DiamondExchangeSession('account-a');
    await expectLater(
        reopened.submit(100,
            (_) async => throw StateError('newer successful response lost')),
        throwsStateError);
    reply.completeError(const PostgrestException(
        message: 'insufficient diamonds', code: 'P0001'));
    await rejected;
    final finalOpen = DiamondExchangeSession('account-a');
    await finalOpen.restore();
    expect(finalOpen.pendingAmount, 100);
  });
  test('late response from closed wallet cannot erase a newer exchange',
      () async {
    final old = DiamondExchangeSession('account-a');
    final entered = Completer<void>(),
        reply = Completer<Map<String, dynamic>>();
    final inFlight = old.submit(100, (_) {
      entered.complete();
      return reply.future;
    });
    await entered.future;
    final reopened = DiamondExchangeSession('account-a');
    await reopened.submit(
        100, (_) async => {'status': 'replayed', 'amount': 100});
    await expectLater(
        reopened.submit(
            200, (_) async => throw StateError('new response lost')),
        throwsStateError);
    reply.complete({'status': 'exchanged', 'amount': 100});
    await inFlight;
    final finalOpen = DiamondExchangeSession('account-a');
    await finalOpen.restore();
    expect(finalOpen.pendingAmount, 200);
  });
  test('stale wallet cannot overwrite a newer pending confirmation', () async {
    final old = DiamondExchangeSession('account-a');
    await expectLater(
        old.submit(100, (_) async => throw StateError('old response lost')),
        throwsStateError);
    final reopened = DiamondExchangeSession('account-a');
    await reopened.submit(
        100, (_) async => {'status': 'replayed', 'amount': 100});
    await expectLater(
        reopened.submit(
            200, (_) async => throw StateError('new response lost')),
        throwsStateError);
    var submitted = false;
    await expectLater(
        old.submit(100, (_) async {
          submitted = true;
          return {'status': 'replayed', 'amount': 100};
        }),
        throwsStateError);
    expect(submitted, isFalse);
    final finalOpen = DiamondExchangeSession('account-a');
    await finalOpen.restore();
    expect(finalOpen.pendingAmount, 200);
  });
  test('exchange restart retains original amount/key and confirming account',
      () async {
    Map<String, dynamic>? first;
    await expectLater(
        DiamondExchangeSession('account-a').submit(100, (p) async {
          first = p;
          throw StateError('response lost');
        }),
        throwsStateError);
    final reopened = DiamondExchangeSession('account-a');
    await reopened.restore();
    expect(reopened.pendingAmount, 100);
    await reopened.submit(900, (p) async {
      expect(p, first);
      expect(p['p_expected_user'], 'account-a');
      return {'status': 'replayed', 'amount': 100};
    });
    final settled = DiamondExchangeSession('account-a');
    await settled.restore();
    expect(settled.pendingAmount, isNull);
  });
  test(
      'pending exchange does not cross accounts and corrupt state fails closed',
      () async {
    final original = DiamondExchangeSession('account-a');
    await expectLater(
        original.submit(100, (_) async => throw StateError('offline')),
        throwsStateError);
    final other = DiamondExchangeSession('account-b');
    await other.restore();
    expect(other.pendingAmount, isNull);
    await (await SharedPreferences.getInstance())
        .setString(other.storageKey, 'invalid');
    final corrupt = DiamondExchangeSession('account-b');
    await expectLater(
        corrupt.submit(100, (_) async => fail('corrupt exchange submitted')),
        throwsFormatException);
  });
}
