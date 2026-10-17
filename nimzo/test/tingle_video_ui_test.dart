import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'package:nimzo/features/auth/presentation/tingle_login_screen.dart';
import 'package:nimzo/features/home/home_screen.dart';
import 'package:nimzo/features/home/party_screen.dart';
import 'package:nimzo/features/messages/message_repository.dart';
import 'package:nimzo/features/messages/messages_screen.dart';
import 'package:nimzo/features/moments/moment_repository.dart';
import 'package:nimzo/features/moments/moments_screen.dart';
import 'package:nimzo/features/profile/profile.dart';
import 'package:nimzo/features/profile/profile_repository.dart';
import 'package:nimzo/features/profile/profile_setup_screen.dart';
import 'package:nimzo/features/profile/tingle_me_screen.dart';
import 'package:nimzo/features/profile/tingle_membership_screen.dart';
import 'package:nimzo/features/rooms/presentation/create_room_screen.dart';
import 'package:nimzo/features/rooms/presentation/room_controller.dart';
import 'package:nimzo/features/social/tingle_friends_screen.dart';
import 'package:nimzo/features/social/family_screen.dart';
import 'package:nimzo/features/store/store_screen.dart';
import 'package:nimzo/features/wallet/wallet_screen.dart';

const account = Profile(
    id: 'review',
    nimzoId: 100001,
    displayName: 'Review account',
    username: 'review',
    gender: 'Male',
    countryCode: 'SA',
    countryName: 'Saudi Arabia');

Future<void> capture(WidgetTester tester, String name, GlobalKey key) async {
  const directory = String.fromEnvironment('NIMZO_CAPTURE_DIR');
  if (directory.isEmpty) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets('walkthrough surfaces and privilege navigation fit ${width}dp',
        (tester) async {
      tester.view.physicalSize = Size(width, width * 2400 / 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final font in [
        ('Roboto', 'test/fonts/Roboto-Regular.ttf'),
        (
          'MaterialIcons',
          '../flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
        ),
      ]) {
        final data = font.$1 == 'MaterialIcons'
            ? await rootBundle.load('fonts/MaterialIcons-Regular.otf')
            : ByteData.sublistView(File(font.$2).readAsBytesSync());
        await (FontLoader(font.$1)..addFont(Future.value(data))).load();
      }
      final db = (await tester.runAsync(() async => SupabaseClient(
          'https://example.invalid', 'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
      addTearDown(() => tester.runAsync(db.dispose));
      final screens = <String, Widget>{
        'login': const TingleLoginScreen(),
        'home': const HomeScreen(),
        'party': const PartyScreen(),
        'moments': const MomentsScreen(),
        'messages': const MessagesScreen(),
        'profile': const TingleMeScreen(),
        'profile-details': const ProfileSetupScreen(edit: true),
        'create-room': const CreateRoomScreen(),
        'friends': const TingleFriendsScreen(),
        'family': const FamilyScreen(),
        'membership': const TingleMembershipScreen(svip: true),
        'store-preview': const StoreCategoryPreview(
            category: 'Avatar Frame',
            icon: Icons.filter_frames_rounded,
            accent: NimzoStyle.primary),
      };
      for (final entry in screens.entries) {
        // ignore: avoid_print
        print('Rendering ${entry.key} at $width');
        final boundary = GlobalKey();
        await tester.pumpWidget(ProviderScope(
            key: ValueKey(entry.key),
            overrides: [
              supabaseProvider.overrideWithValue(db),
              currentUserIdProvider.overrideWithValue('review'),
              profileProvider('review').overrideWith((_) async => account),
              profileStatsProvider('review')
                  .overrideWith((_) async => {'following': 0, 'followers': 0}),
              walletProvider.overrideWith(
                  (_) async => throw StateError('No balance fixture')),
              popularRoomsProvider(null).overrideWith((_) async => []),
              momentsFeedProvider.overrideWith((_) async => []),
              followedMomentsAuthorsProvider.overrideWith((_) async => {}),
              conversationsProvider.overrideWith((_) async => []),
              for (var tab = 0; tab < 3; tab++)
                tinglePeopleProvider(tab).overrideWith((_) async => []),
              membershipSnapshotProvider(true).overrideWith((_) async =>
                  const MembershipSnapshot(level: 0, expiry: null, tiers: [])),
            ],
            child: RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.light(),
                    home: entry.value))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${entry.key} $width');
        await capture(tester, '${entry.key}-${width.toInt()}', boundary);
        // ignore: avoid_print
        print('Captured ${entry.key} at $width');
        if (entry.key == 'profile') {
          await tester.scrollUntilVisible(find.text('VIP'), 160,
              scrollable: find.byType(Scrollable).first);
          expect(find.text('VIP'), findsOneWidget);
        }
        if (entry.key == 'profile-details') {
          final save = find.byKey(const ValueKey('modify-profile-save'));
          expect(tester.getBottomRight(save).dy,
              lessThanOrEqualTo(tester.view.physicalSize.height));
          final before = tester.getTopLeft(save);
          await tester.drag(
              find.byKey(const ValueKey('modify-profile-clean-list')),
              const Offset(0, -250));
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(save), before,
              reason: 'Save remains visible while details scroll');
        }
        if (entry.key == 'login') {
          await tester
              .ensureVisible(find.byKey(const ValueKey('login-terms-link')));
          await tester.tap(find.byKey(const ValueKey('login-terms-link')));
          await tester.pumpAndSettle();
          expect(find.text('Terms & Conditions'), findsOneWidget);
          expect(find.text('Terms of Service'), findsOneWidget);
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.byType(TingleLoginScreen), findsOneWidget);
        }
        if (entry.key == 'membership') {
          await tester.scrollUntilVisible(
              find.byKey(const ValueKey('membership-tier-6')), 160,
              scrollable: find.byType(Scrollable).at(1));
          await tester.tap(find.byKey(const ValueKey('membership-tier-6')));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
              find.byKey(const ValueKey('membership-perk-0')), 180,
              scrollable: find.byType(Scrollable).first);
          await tester.tap(find.byKey(const ValueKey('membership-perk-0')));
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsOneWidget);
          await capture(tester, 'membership-dialog-${width.toInt()}', boundary);
          await tester.tap(find.byTooltip('Next privilege'));
          await tester.pumpAndSettle();
          expect(find.text('Exclusive Avatar Frame'), findsWidgets);
          await tester.tap(find.byTooltip('Close privilege preview'));
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
          expect(tester.takeException(), isNull);
        }
        if (entry.key == 'messages') {
          await tester.tap(find.byTooltip('Search conversations'));
          await tester.pumpAndSettle();
          await tester.enterText(
              find.byKey(const ValueKey('inbox-search')), 'No such person');
          await tester.pumpAndSettle();
          expect(find.text('No matching conversations'), findsOneWidget);
          await tester.tap(find.byTooltip('Search conversations'));
          await tester.pumpAndSettle();
          expect(find.text('No conversations yet'), findsOneWidget);
          expect(find.byKey(const ValueKey('inbox-search')), findsNothing);
        }
        if (entry.key == 'friends') {
          await tester.tap(find.byTooltip('Search friends'));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('friends-search')), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}
