import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/errors/error_handler.dart';
import 'package:nimzo/features/auth/presentation/auth_controller.dart';
import 'package:nimzo/features/auth/presentation/tingle_login_screen.dart';

class FailedGoogleController extends AuthController {
  @override
  Future<void> google() async {
    state = AsyncError(
      mapError(PlatformException(
        code: 'channel-error',
        message: 'PRIVATE_SESSION_VALUE',
        details: 'PRIVATE_PKCE_VALUE',
      )),
      StackTrace.empty,
    );
  }
}

void main() {
  test('Android channel failure keeps a safe actionable code', () {
    final error = mapError(PlatformException(
      code: 'channel-error',
      message: 'PRIVATE_SESSION_VALUE',
      details: 'PRIVATE_PKCE_VALUE',
    ));
    expect(error.code, 'channel-error');
    expect(error.message, contains('Android service unavailable'));
    expect(error.message, isNot(contains('PRIVATE_')));
  });

  test('missing plugin has a separate diagnosis', () {
    final error = mapError(MissingPluginException('PRIVATE_NATIVE_MESSAGE'));
    expect(error.code, 'missing-plugin');
    expect(error.message, isNot(contains('PRIVATE_')));
  });

  test('unrecognized native codes cannot leak private SDK text', () {
    final error = mapError(PlatformException(
      code: 'PRIVATE_SESSION_VALUE',
      message: 'PRIVATE_NATIVE_MESSAGE',
    ));
    expect(error.code, 'android-platform');
    expect(error.message, isNot(contains('PRIVATE_')));
  });

  testWidgets('Google failure displays the mapped cause on login', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(FailedGoogleController.new),
      ],
      child: const MaterialApp(home: TingleLoginScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Google'));
    await tester.tap(find.text('Google'));
    await tester.pump();
    expect(find.textContaining('Android service unavailable'), findsOneWidget);
    expect(find.textContaining('PRIVATE_'), findsNothing);
    expect(find.text('Login failed. Check your details and retry.'), findsNothing);
  });
}
