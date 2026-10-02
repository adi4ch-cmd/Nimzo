import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/core/utils/formatters.dart';

// Client-side unit tests. Server rules (coins/VIP/admin/ownership) are
// enforced and tested in Postgres: see supabase/tests/security.sql.
void main() {
  test('compactNumber', () {
    expect(compactNumber(1500), '1.5K');
    expect(compactNumber(9600000), '9.6M');
  });
}
