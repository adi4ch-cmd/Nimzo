import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/providers/supabase_provider.dart';
import 'package:nimzo/features/premium/membership_catalog.dart';
import 'package:nimzo/features/premium/membership_status.dart';
import 'package:nimzo/features/premium/membership_media_view.dart';
import 'package:nimzo/features/premium/willchill_premium_screen.dart';
import 'tingle_video_ui_test.dart' show capture, loadReviewFonts;

void main() {
  for (final width in [280.0, 360.0]) {
    for (final group in ['vip', 'svip']) {
      testWidgets(
          'real matched $group catalog fits $width dp and retains tier 10',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = (await tester.runAsync(() async => SupabaseClient(
            'https://example.supabase.co', 'test',
            authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
        addTearDown(() => tester.runAsync(db.dispose));
        final actualTiers = (await tester.runAsync(() async {
          final container = ProviderContainer();
          try {
            return await container
                .read(membershipBundledPresentationsProvider.future);
          } finally {
            container.dispose();
          }
        }))!;
        await loadReviewFonts();
        final boundary = GlobalKey();
        await tester.pumpWidget(ProviderScope(
            overrides: [
              sessionSupabaseProvider
                  .overrideWithValue((client: db, userId: 'viewer')),
              membershipStatusProvider
                  .overrideWith((_) async => MembershipStatus.fromJson({
                        'retired': false,
                        'purchases_enabled': true,
                        'claims_enabled': true,
                        'vip_level': 0,
                        'svip_level': 0
                      })),
              membershipPresentationsProvider.overrideWith((_) async => []),
              membershipOffersProvider.overrideWith((_) async => [
                    for (var t = 1; t <= 10; t++)
                      {
                        'tier': t,
                        'coin_price': t * 1000000,
                        'duration_days': 30
                      }
                  ]),
              membershipThresholdsProvider.overrideWith((_) async => [
                    for (var t = 1; t <= 10; t++)
                      {'level': t, 'usd_cents': t * 5000}
                  ]),
            ],
            child: MaterialApp(
                theme: ThemeData(fontFamily: 'Roboto'),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(1.2)),
                    child: child!),
                home: RepaintBoundary(
                    key: boundary,
                    child: WillChillPremiumScreen(initialGroup: group)))));
        await tester.pump();
        await tester.pump();
        await tester.ensureVisible(
            find.widgetWithText(ChoiceChip, '${group.toUpperCase()} 10'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester
            .tap(find.widgetWithText(ChoiceChip, '${group.toUpperCase()} 10'));
        await tester.pump();
        for (var frame = 0; frame < 20; frame++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(find.widgetWithText(ChoiceChip, '${group.toUpperCase()} 10'),
            findsOneWidget);
        expect(
            tester
                .widget<ChoiceChip>(find.widgetWithText(
                    ChoiceChip, '${group.toUpperCase()} 10'))
                .selected,
            isTrue);
        expect(find.byKey(const ValueKey('membership-fixed-status')),
            findsOneWidget);
        expect(find.byType(MembershipMediaView), findsNWidgets(2));
        expect(find.byType(Image), findsNWidgets(2));
        expect(
            find.text('Tier artwork is currently unavailable.'), findsNothing);
        if (group == 'vip')
          expect(
              tester
                  .widget<FilledButton>(
                      find.widgetWithText(FilledButton, 'Purchase VIP 10'))
                  .onPressed,
              isNotNull);
        expect(tester.takeException(), isNull);
        await capture(tester, 'v3-$group-${width.toInt()}', boundary);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }
}
