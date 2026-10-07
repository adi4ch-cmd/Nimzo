import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/theme/app_theme.dart';
import 'package:nimzo/core/widgets/reference_widgets.dart';

void main() {
  test('theme follows current approved purple reference', () {
    expect(AppTheme.light().colorScheme.primary, const Color(0xff9333ea));
    expect(AppTheme.light().scaffoldBackgroundColor, Colors.white);
  });
  testWidgets('long avatar labels and unavailable image remain bounded', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 64,
            child: NimzoAvatar(name: 'An exceptionally long display name'),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('unavailable data offers an actual retry action', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DataFailure(
            onRetry: () {
              retries++;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });
}
