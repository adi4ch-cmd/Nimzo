import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'profile_repository_test.dart' show signedClient;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('malformed publication never overwrites the last-good account snapshot',
      () async {
    final valid = {
      'id': 'gift',
      'name': 'Coffee',
      'category': 'Classic',
      'coin_price': 100,
      'asset_path': null,
      'requires_approved_media': false,
      'gift_animation_media': []
    };
    var invalid = false;
    final db = await signedClient((request) => http.Response(
        jsonEncode([
          if (invalid) {...valid, 'thumbnail_sha256': 'invalid'} else valid
        ]),
        200));
    final repo = GiftRepository(db);
    expect((await repo.catalog()).single.offline, isFalse);
    invalid = true;
    final fallback = (await repo.catalog()).single;
    expect(fallback.id, 'gift');
    expect(fallback.offline, isTrue);
    expect(fallback.thumbnailPublication, isNull);
  });
}
