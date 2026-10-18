import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/social/cp_relationship_clock.dart';

void main() {
  test('CP duration comes from persisted binding timestamp', () {
    expect(
        cpClockParts(
            '2026-10-16T10:00:00Z', DateTime.utc(2026, 10, 18, 13, 4, 5)),
        ['02', '03', '04', '05']);
  });
  test('unlinked or invalid relationship has no invented timer', () {
    expect(cpClockParts(null, DateTime.utc(2026)), ['—', '—', '—', '—']);
    expect(cpClockParts('bad date', DateTime.utc(2026)), ['—', '—', '—', '—']);
  });
  test('future timestamp never creates negative CP time', () {
    expect(cpClockParts('2027-01-01T00:00:00Z', DateTime.utc(2026)),
        ['00', '00', '00', '00']);
  });
}
