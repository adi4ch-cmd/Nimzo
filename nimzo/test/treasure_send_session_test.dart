import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/rooms/treasure/treasure_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const request = TreasureRequest(
      scope: 'room', total: 10000, quantity: 6, eligibility: 'all');
  test('lost funding response restores the exact request after restart',
      () async {
    final first = TreasureSendSession(userId: 'a', roomId: 'r');
    Map<String, dynamic>? sent;
    await expectLater(
        first.send(request, (params) async {
          sent = params;
          throw StateError('response lost');
        }),
        throwsStateError);
    final reopened = TreasureSendSession(userId: 'a', roomId: 'r');
    await reopened.restore();
    expect(reopened.pending, isTrue);
    await reopened.send(
        const TreasureRequest(
            scope: 'world',
            total: 500000,
            quantity: 10,
            eligibility: 'fans'), (params) async {
      expect(params, sent);
      return {'id': 'box-1', 'status': 'replayed'};
    });
    final settled = TreasureSendSession(userId: 'a', roomId: 'r');
    await settled.restore();
    expect(settled.pending, isFalse);
  });
  test('pending funding is isolated by account and room', () async {
    final original = TreasureSendSession(userId: 'a', roomId: 'r');
    await expectLater(
        original.send(request, (_) async => throw StateError('offline')),
        throwsStateError);
    for (final session in [
      TreasureSendSession(userId: 'b', roomId: 'r'),
      TreasureSendSession(userId: 'a', roomId: 'other')
    ]) {
      await session.restore();
      expect(session.pending, isFalse);
    }
  });
  test('invalid funding never writes pending state or calls the backend',
      () async {
    final session = TreasureSendSession(userId: 'a', roomId: 'r');
    await expectLater(
        session.send(
            const TreasureRequest(
                scope: 'world',
                total: 10000,
                quantity: 6,
                eligibility: 'on_mic'),
            (_) async => fail('invalid funding submitted')),
        throwsArgumentError);
    expect(session.pending, isFalse);
  });
  test('definitive insufficient funds clears confirmation for correction',
      () async {
    final session = TreasureSendSession(userId: 'a', roomId: 'r');
    await expectLater(
        session.send(
            request,
            (_) async => throw const PostgrestException(
                message: 'INSUFFICIENT_COINS', code: 'P0001')),
        throwsA(isA<PostgrestException>()));
    final reopened = TreasureSendSession(userId: 'a', roomId: 'r');
    await reopened.restore();
    expect(reopened.pending, isFalse);
  });
  test('corrupt confirmation blocks a replacement debit', () async {
    final session = TreasureSendSession(userId: 'a', roomId: 'r');
    await (await SharedPreferences.getInstance())
        .setString(session.storageKey, '{"p_total":10000}');
    await expectLater(
        session.send(
            request, (_) async => fail('corrupt confirmation submitted')),
        throwsFormatException);
    expect(
        (await SharedPreferences.getInstance()).getString(session.storageKey),
        '{"p_total":10000}');
  });
}
