import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keep the original checked-in media actually available to Flutter runtime.
/// This catches missing pubspec registrations, empty assets and CI packaging
/// regressions before an Android build can be considered.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('room, games, levels and gift assets load from Flutter bundle', () async {
    const samples = <String>[
      'assets/reference/chest/0.jpg',
      'assets/reference/game/0.jpg',
      'assets/reference/fruit/0.jpg',
      'assets/room_rocket/posters/rocket_stage_1.png',
      'assets/hilo/game_levels/level_0.webp',
      'assets/gifts/free/sports_car.png',
      'assets/gifts/hall_of_fame.svg',
    ];
    for (final path in samples) {
      final bytes = await rootBundle.load(path);
      expect(bytes.lengthInBytes, greaterThan(100),
        reason: 'Bundled reference media is missing or empty: $path');
    }
  });
}
