import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/moments/moment_repository.dart';

void main() {
  Map<String, dynamic> row() => {
        'id': 'post',
        'author_id': 'author',
        'body': 'hello',
        'created_at': '2026-10-18T00:00:00Z',
      };
  test('legacy single-photo Moments remain visible', () {
    final moment = Moment.fromJson({...row(), 'image_path': 'author/old.jpg'});
    expect(moment.imagePaths, ['author/old.jpg']);
  });
  test('multi-photo Moments retain order without repeating legacy cover', () {
    final moment = Moment.fromJson({
      ...row(),
      'image_path': 'author/one.jpg',
      'image_paths': ['author/one.jpg', 'author/two.jpg'],
    });
    expect(moment.imagePaths, ['author/one.jpg', 'author/two.jpg']);
  });
}
