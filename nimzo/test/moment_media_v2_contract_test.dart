import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nimzo/features/moments/moment_repository.dart';

import 'profile_repository_test.dart' show signedClient;

void main() {
  test('Moment model supports old single image and new image_paths', () {
    final original = {
      'id': 'moment', 'author_id': 'me',
      'body': 'Hi', 'image_path': 'me/old.png',
      'created_at': '2026-10-18T00:00:00Z',
    };
    final old = Moment.fromJson(original);
    expect(old.imagePath, 'me/old.png');
    expect(old.imagePaths, ['me/old.png']);
    final gallery = Moment.fromJson({
      ...original,
      'image_paths': ['me/one.jpg','me/two.jpg'],
    });
    expect(gallery.imagePaths, ['me/one.jpg','me/two.jpg']);
    expect(gallery.authorId, 'me');
  });

  test('Moments feed uses live v2 RPC with image paths', () async {
    final db = await signedClient((request) {
      expect(request.url.path, '/rest/v1/rpc/moments_feed_v2');
      return http.Response(
        '[{"id":"m","author_id":"me","body":"ok",'
        '"image_path":"me/one.jpg","image_paths":["me/one.jpg","me/two.jpg"],'
        '"created_at":"2026-10-18T00:00:00Z"}]', 200,
      );
    });
    final feed = await MomentRepository(db).feed();
    expect(feed, hasLength(1));
    expect(feed.single.imagePaths, hasLength(2));
  });

  test('multi-photo create sends owned paths to Supabase, not wallet', () async {
    final db = await signedClient((request) {
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/moments');
      final payload = jsonDecode(request.body) as Map;
      expect(payload['author_id'], 'me');
      expect(payload['image_path'], 'me/a.jpg');
      expect(payload['image_paths'], ['me/a.jpg', 'me/b.jpg']);
      return http.Response('', 201);
    });
    await MomentRepository(db).createMany(
      text: 'Two photos',
      imagePaths: ['me/a.jpg', 'me/b.jpg'],
    );
  });

  test('multi-photo create rejects more than nine images', () async {
    final db = await signedClient((request) {
      throw StateError('Oversized request must not reach server');
    });
    await expectLater(
      MomentRepository(db).createMany(
        imagePaths: List.generate(10, (i) => 'me/photo_$i.jpg'),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('multi-photo create rejects photos owned by another account', () async {
    final db = await signedClient((request) {
      throw StateError('Must reject paths before network request');
    });
    await expectLater(
      MomentRepository(db).createMany(
        imagePaths: ['other-user/secret.jpg'],
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
