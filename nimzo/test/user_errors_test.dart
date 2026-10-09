import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimzo/core/errors/error_handler.dart';

void main() {
  test('permission errors do not disclose table or policy names', () {
    final error = mapError(
      const PostgrestException(
        message: 'permission denied for table profiles',
        code: '42501',
      ),
    );
    expect(error.message, isNot(contains('profiles')));
    expect(error.message, isNot(contains('permission denied')));
  });
}
