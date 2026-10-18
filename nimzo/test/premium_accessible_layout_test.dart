import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'package:nimzo/features/profile/tingle_membership_screen.dart';
import 'package:nimzo/features/store/store_screen.dart';
import 'tingle_video_ui_test.dart' show loadReviewFonts;

void main() {
  for (final width in [320.0, 390.0, 480.0]) {
    testWidgets('premium previews fit large text at $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadReviewFonts();
      for (final screen in [
        const TingleMembershipScreen(svip: true),
        const StoreCategoryPreview(
            category: 'Avatar Frame',
            icon: Icons.filter_frames_rounded,
            accent: Colors.purple)
      ]) {
        await tester.pumpWidget(ProviderScope(
            overrides: [
              membershipSnapshotProvider(true).overrideWith((_) async =>
                  const MembershipSnapshot(level: 0, expiry: null, tiers: [])),
            ],
            child: MaterialApp(
                theme: AppTheme.light().copyWith(
                    textTheme:
                        AppTheme.light().textTheme.apply(fontFamily: 'Roboto')),
                home: MediaQuery(
                    data: MediaQueryData(
                        size: Size(width, 800),
                        textScaler: const TextScaler.linear(1.8)),
                    child: screen))));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView).first, const Offset(0, -1600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}
