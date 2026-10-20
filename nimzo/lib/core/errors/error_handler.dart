import 'dart:io';

import 'package:flutter/services.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

AppException mapError(Object e) {
  if (e is AppException) return e;
  if (e is MissingPluginException) {
    return const AppException(
      'Android service unavailable (missing-plugin). Restart the app and retry.',
      code: 'missing-plugin',
    );
  }
  if (e is PlatformException) {
    // Preserve only known diagnostic codes. Native messages/details may
    // contain URLs, session values or PKCE material and must stay private.
    const allowedCodes = {
      'channel-error', 'PlatformException', 'ACTIVITY_NOT_FOUND',
      'STORAGE_KEY_INVALID', 'STORAGE_VALUE_INVALID',
      'STORAGE_WRITE_FAILED', 'STORAGE_REMOVE_FAILED',
      'NATIVE_STORAGE_FAILED', 'NATIVE_STORAGE_UNAVAILABLE',
      'SESSION_WRITE_FAILED', 'SESSION_REMOVE_FAILED',
      'PKCE_WRITE_FAILED', 'PKCE_REMOVE_FAILED',
    };
    final code = allowedCodes.contains(e.code) ? e.code : 'android-platform';
    return AppException(
      'Android service unavailable ($code). Restart the app and retry.',
      code: code,
    );
  }
  if (e is SocketException) return const OfflineException();
  if (e is AuthException) return AppException(e.message, code: e.statusCode);
  if (e is PostgrestException) {
    return AppException(
      e.code == '42501'
          ? 'This action is unavailable for your account. Please retry or contact support.'
          : 'Unable to complete this action. Please retry.',
      code: e.code,
    );
  }
  return const AppException('Something went wrong. Try again.');
}
