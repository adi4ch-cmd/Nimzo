import 'package:integration_test/integration_test_driver.dart';

// The documented integration driver avoids Flutter test's DDS-only golden
// stream. Results still fail the command when any native assertion fails.
Future<void> main() => integrationDriver(timeout: const Duration(minutes: 55));
