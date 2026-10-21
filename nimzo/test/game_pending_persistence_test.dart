import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/features/games/game_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const scope = GameRequestScope(userId:'account-a',roomId:'room-a',game:'fruit_party');
  test('restart restores original request persisted before uncertain RPC', () async {
    final session = GameRetrySession(scope:scope);
    ({int bet,String key})? sent;
    await expectLater(session.play(100,(bet,key) async {
      final reopened = GameRetrySession(scope:scope);
      await reopened.restore();
      expect(reopened.pending,isTrue);
      expect(reopened.pendingBet,100);
      sent=(bet:bet,key:key);
      throw StateError('response lost');
    }),throwsStateError);
    final restarted = GameRetrySession(scope:scope);
    await restarted.restore();
    expect(restarted.pendingBet,100);
    await restarted.play(500,(bet,key) async {
      expect((bet:bet,key:key),sent);
      return {'status':'won','payout':200,'bet_id':'receipt'};
    });
    final afterSettlement=GameRetrySession(scope:scope);
    await afterSettlement.restore();
    expect(afterSettlement.pending,isFalse);
  });
  test('pending requests are isolated by account room and game', () async {
    final session=GameRetrySession(scope:scope);
    await expectLater(session.play(100,(_,__) async => throw StateError('offline')),throwsStateError);
    for(final other in [
      const GameRequestScope(userId:'account-b',roomId:'room-a',game:'fruit_party'),
      const GameRequestScope(userId:'account-a',roomId:'room-b',game:'fruit_party'),
      const GameRequestScope(userId:'account-a',roomId:'room-a',game:'fruit_wheel'),
    ]) {
      final alternate=GameRetrySession(scope:other);
      await alternate.restore();
      expect(alternate.pending,isFalse);
    }
    final original=GameRetrySession(scope:scope);
    await original.restore();
    expect(original.pendingBet,100);
  });
  test('definitive database rollback clears durable pending request', () async {
    final session=GameRetrySession(scope:scope);
    await expectLater(session.play(100,(_,__) async {
      throw const PostgrestException(message:'INSUFFICIENT_COINS',code:'P0001');
    }),throwsA(isA<PostgrestException>()));
    final restarted=GameRetrySession(scope:scope);
    await restarted.restore();
    expect(restarted.pending,isFalse);
  });
}
