import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

AppException mapError(Object e) {
  if (e is AppException) return e;
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
