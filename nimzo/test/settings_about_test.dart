import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:nimzo/features/settings/settings_screen.dart';

void main() {
  testWidgets('About reports the installed version and build', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Nimzo',
      packageName: 'com.nimzo.app',
      version: '2.3.4',
      buildNumber: '234',
      buildSignature: '',
    );
    await tester.pumpWidget(
      const MaterialApp(home: InfoScreen(title: 'About')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'NIMZO · 2.3.4 (build 234)\nVoice rooms and social connections',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('1.0.5'), findsNothing);
  });
}
