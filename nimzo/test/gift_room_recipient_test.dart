import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/gifts/gift_sheet.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';

class RecordingRoomGiftRepository extends GiftRepository {
  RecordingRoomGiftRepository(super.db);
  String? receiver;
  @override
  Future<void> send(
      {required String roomId,
      required String receiverId,
      required String giftId,
      required int qty,
      required String key}) async {
    receiver = receiverId;
  }
}

void main() {
  for (final seated in [true, false]) {
    testWidgets(
        'room gift recipient can switch to Myself ${seated ? 'on mic' : 'off mic'}',
        (tester) async {
      final db = (await tester.runAsync(() async => SupabaseClient(
            'https://example.supabase.co',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          )))!;
      addTearDown(() => tester.runAsync(db.dispose));
      final repo = RecordingRoomGiftRepository(db);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            supabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWithValue('sender'),
            giftRepositoryProvider.overrideWithValue(repo),
            giftCatalogProvider.overrideWith((_) async => [
                  const Gift('gift', 'Coffee', 'Classic', 500, null),
                ]),
            walletProvider
                .overrideWith((_) async => (coins: 10000, diamonds: 0)),
            roomSeatProfilesProvider('room').overrideWith((_) async => {
                  if (seated)
                    'sender': const Profile(
                        id: 'sender', nimzoId: 1, displayName: 'Sender'),
                  'receiver': const Profile(
                      id: 'receiver', nimzoId: 2, displayName: 'Receiver'),
                }),
          ],
          child: const MaterialApp(
              home: Scaffold(
                  body: GiftSheet(
            receiverId: 'receiver',
            roomId: 'room',
          )))));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Myself'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Myself'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Coffee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coffee'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Send'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Send').last);
      await tester.pumpAndSettle();
      expect(repo.receiver, 'sender');
      expect(tester.takeException(), isNull);
    });
  }
}
