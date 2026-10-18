import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/store/store_screen.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('reference store preview stays within phone width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(
        home: StoreCategoryPreview(
          category: 'Avatar Frame',
          icon: Icons.filter_frames_rounded,
          accent: Color(0xffa546e7),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Avatar Frame'), findsWidgets);
      expect(find.byKey(const ValueKey('store-category-preview')), findsOneWidget);
      expect(find.byKey(const ValueKey('store-category-preview-only')),
        findsOneWidget);
      expect(find.textContaining('Purchase'), findsNothing,
        reason: 'No fake catalog price or checkout can be invented');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('store-preview-style-4')),
        120, scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('store-preview-style-4')));
      await tester.pumpAndSettle();
      expect(find.text('Floral'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
