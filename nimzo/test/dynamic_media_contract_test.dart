import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/events/dynamic_event_banners.dart';
import 'package:nimzo/features/gifts/gift_repository.dart';
import 'package:nimzo/features/rooms/domain/dynamic_room_backgrounds.dart';

void main() {
  test('Remote VAP/SVGA/MP4 must be approved HTTPS metadata', () {
    GiftPlaybackMedia? parse(String url, String kind) =>
        GiftPlaybackMedia.fromRow({'video_url': url, 'media_kind': kind});
    expect(parse('https://cdn.example.com/x.mp4', 'vap')?.kind, 'vap');
    expect(parse('https://cdn.example.com/x.svga', 'svga')?.kind, 'svga');
    expect(parse('https://cdn.example.com/x.mp4', 'mp4')?.kind, 'mp4');
    expect(parse('http://cdn.example.com/x.mp4', 'vap'), isNull);
    expect(parse('file:///tmp/gift.mp4', 'mp4'), isNull);
    expect(parse('https://user:pass@cdn.example.com/x.mp4', 'mp4'), isNull);
    expect(parse('https://cdn.example.com/x.webp', 'arbitrary'), isNull);
  });

  test('Approved room backgrounds accept only built-in themes and HTTPS', () {
    const settings = <String, Map<String, dynamic>>{
      'room.backgrounds': {
        'themes': {
          'sage': 'https://cdn.example.com/sage.jpg',
          'ocean': 'http://cdn.example.com/ocean.jpg',
          'premium_black': 'https://user:pass@cdn.example.com/dark.jpg',
          'sneaky_theme': 'https://cdn.example.com/unknown.jpg',
        },
      },
    };
    expect(nimzoApprovedRoomBackground(settings, 'sage'),
        'https://cdn.example.com/sage.jpg');
    expect(nimzoApprovedRoomBackground(settings, 'ocean'), isNull);
    expect(nimzoApprovedRoomBackground(settings, 'premium_black'), isNull);
    expect(nimzoApprovedRoomBackground(settings, 'sneaky_theme'), isNull);
  });

  test('Dynamic banner validates date window, active flag and URL path', () {
    final now = DateTime.utc(2026, 10, 21);
    Map<String, dynamic> row(String path) => {
      'id': 'banner-1', 'title': 'Hello', 'image_path': path,
      'active': true, 'start_at': '2026-10-20T00:00:00Z',
      'end_at': '2026-10-22T00:00:00Z',
    };
    NimzoEventBanner? parse(Map<String, dynamic> data) =>
        NimzoEventBanner.fromRow(data,
          resolveStorage: (path) => 'https://cdn.example.com/$path',
          now: now);
    expect(parse(row('campaign.jpg'))?.imageUrl,
        'https://cdn.example.com/campaign.jpg');
    expect(parse(row('https://cdn.example.com/promo.jpg'))?.title, 'Hello');
    expect(parse(row('../../secrets')), isNull);
    expect(parse(row('http://remote.bad/item')), isNull);
    expect(parse({...row('campaign.jpg'), 'active': false}), isNull);
    expect(parse({...row('campaign.jpg'),
      'end_at': '2026-10-20T00:00:00Z'}), isNull);
    expect(parse({...row('campaign.jpg'),
      'start_at': '2026-10-22T00:00:00Z'}), isNull);
  });
}
