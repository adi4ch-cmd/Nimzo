import 'package:nimzo/features/voice/vivox_voice_service.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:nimzo/features/premium/membership_identity.dart';
import 'package:nimzo/features/premium/membership_status.dart';
import 'package:nimzo/features/premium/membership_catalog.dart';
import 'package:nimzo/core/services/nimzo_content_sync.dart';
import 'package:nimzo/features/store/store_visual_equipment.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'package:nimzo/features/rooms/domain/room.dart';
import 'package:nimzo/features/rooms/data/room_chat_repository.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';
import 'package:nimzo/features/rooms/presentation/room_screen.dart';
import 'package:nimzo/features/voice/voice_service.dart';
import 'package:nimzo/features/voice/voice_controller.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/rooms/diamond/room_diamond_repository.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';
import 'tingle_video_ui_test.dart' show capture, loadReviewFonts;
import 'room_reconnect_test.dart' show ReconnectRepository, room;

class PreviewVoice implements VoiceService {
  PreviewVoice({this.unavailable = false});
  final bool unavailable;
  @override
  Stream<bool> get connected => Stream.value(!unavailable);
  @override
  Stream<Set<String>> get speaking => const Stream.empty();
  @override
  Future<void> join(String id, String token) async {
    if (unavailable) throw VoiceUnavailableFailure();
  }

  @override
  Future<void> leave() async {}
  @override
  Future<void> setMicEnabled(bool enabled) async {}
  @override
  Future<void> setSpeakerEnabled(bool enabled) async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  for (final mode in [
    (320.0, false),
    (360.0, false),
    (390.0, false),
    (360.0, true)
  ]) {
    final width = mode.$1;
    final unavailable = mode.$2;
    testWidgets(
        'audio room sheets and fifteen seats fit ${width}dp voice deferred=$unavailable',
        (tester) async {
      tester.view.physicalSize = Size(width, width * 2400 / 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadReviewFonts();
      final db = (await tester.runAsync(() async => SupabaseClient(
          'https://example.invalid', 'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
      addTearDown(() => tester.runAsync(db.dispose));
      final key = GlobalKey();
      await tester.pumpWidget(ProviderScope(
          overrides: [
            supabaseProvider.overrideWithValue(db),
            nimzoContentRevisionsProvider
                .overrideWith((_) => const Stream.empty()),
            verifiedGiftAnimationProvider
                .overrideWith((ref, args) => const Stream.empty()),
            roomDiamondStatusProvider('room').overrideWith(
                (_) async => throw StateError('No room stats fixture')),
            roomDiamondEventsProvider('room')
                .overrideWith((_) => const Stream.empty()),
            currentUserIdProvider.overrideWithValue('viewer'),
            membershipPresentationsProvider.overrideWith((_) async => []),
            effectiveMembershipProvider
                .overrideWith((_, id) async => id == 'victor'
                    ? MembershipStatus.fromJson({
                        'vip_level': 2,
                        'pack_kind': 'vip',
                        'pack_tier': 2,
                        'pack_slots': [
                          'Avatar Frame',
                          'ID Frame',
                          'Royal Badge',
                          'Profile Card'
                        ]
                      })
                    : null),
            profileProvider('victor').overrideWith((_) async => const Profile(
                id: 'victor',
                nimzoId: 100005,
                displayName: 'Victor long member name',
                bio: 'Test profile')),
            storeVisualEquipmentProvider.overrideWith((_, id) async => {}),
            roomMemberIdsProvider('room')
                .overrideWith((_) => const Stream.empty()),
            roomRepositoryProvider.overrideWithValue(ReconnectRepository(db)),
            roomProvider('room').overrideWith((_) async => room),
            seatsProvider('room').overrideWith((_) => Stream.value(
                List.generate(
                    15,
                    (i) => MicSeat(
                        seatNo: i + 1,
                        userId: i == 7 ? 'victor' : null,
                        muted: i == 7)))),
            roomSeatProfilesProvider('room').overrideWith((_) async => {
                  'victor': const Profile(
                      id: 'victor',
                      nimzoId: 100005,
                      displayName: 'Victor long member name')
                }),
            onlineCountProvider('room')
                .overrideWith((_) => const Stream.empty()),
            roomChatProvider('room').overrideWith((_) => Stream.value([])),
            giftCatalogProvider.overrideWith((_) async => []),
            walletProvider.overrideWith(
                (_) async => throw StateError('No balance fixture')),
            voiceServiceProvider
                .overrideWithValue(PreviewVoice(unavailable: unavailable)),
          ],
          child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.light().copyWith(
                      textTheme: AppTheme.light()
                          .textTheme
                          .apply(fontFamily: 'Roboto')),
                  home: const RoomScreen(roomId: 'room')))));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text('Room').first).style?.color,
          const Color(0xfff7ebff),
          reason: 'Room title contrasts with Royal Plum');
      if (unavailable) {
        final notice = find.byKey(const ValueKey('room-voice-unavailable'));
        expect(notice, findsOneWidget);
        expect(find.descendant(of: notice, matching: find.text('Retry')),
            findsNothing);
      }
      final toolsContext = tester.element(find.byTooltip('Party Tools'));
      expect(
          IconButtonTheme.of(toolsContext).style?.foregroundColor?.resolve({}),
          const Color(0xfff7ebff),
          reason: 'Room controls contrast with Royal Plum');
      for (var n = 1; n <= 15; n++) {
        expect(find.byKey(ValueKey('room-mic-seat-$n')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await capture(tester,
          'room-${width.toInt()}${unavailable ? '-voice-deferred' : ''}', key);
      final seat =
          tester.getRect(find.byKey(const ValueKey('room-mic-seat-8')));
      final name = tester.getRect(
          find.byKey(const ValueKey('membership-pack-nameplate-vip-2')));
      expect(name.bottom, lessThanOrEqualTo(seat.bottom));
      await tester.tap(find.byKey(const ValueKey('room-mic-seat-8')));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('room-mini-profile-card')), findsOneWidget);
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await capture(tester, 'room-member-card-${width.toInt()}', key);
      await tester.tap(find.byTooltip('Close profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('room-mic-seat-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('room-seat-here')), findsOneWidget);
      await capture(tester, 'room-seat-sheet-${width.toInt()}', key);
      await tester.tap(find.byKey(const ValueKey('room-seat-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reactions'));
      await tester.pumpAndSettle();
      await capture(tester, 'room-reactions-${width.toInt()}', key);
      await tester.tap(find.byKey(const ValueKey('room-reaction-0')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '😆');
      await tester.tap(find.byTooltip('Party Tools'));
      await tester.pumpAndSettle();
      await capture(tester, 'room-tools-${width.toInt()}', key);
      expect(find.text('Video'), findsNothing);
      // The modal route consumes back without leaving the audio room.
      await tester.tap(find.text('Music').last);
      await tester.pumpAndSettle();
      await capture(tester, 'room-music-${width.toInt()}', key);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Gift'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Myself'));
      await tester.pumpAndSettle();
      await capture(tester, 'room-gifts-empty-${width.toInt()}', key);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Leave audio room'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('confirm-audio-room-exit-question')),
          findsOneWidget);
      await capture(tester, 'room-exit-${width.toInt()}', key);
      await tester.tap(find.byKey(const ValueKey('cancel-room-exit')));
      await tester.pumpAndSettle();
      expect(find.byType(RoomScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
