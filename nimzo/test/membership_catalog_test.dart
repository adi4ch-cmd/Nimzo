import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimzo/core/services/approved_media_bytes.dart';
import 'package:nimzo/features/premium/membership_catalog.dart';
import 'package:nimzo/core/services/renderable_media.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'all 20 VIP/SVIP tiers have matched original images and SVGA with valid checksums',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tiers =
        await container.read(membershipBundledPresentationsProvider.future);
    expect(tiers.length, 20);
    expect(
        tiers.every((tier) =>
            !tier.hero!.url.contains('/voku/') &&
            !tier.badge!.url.contains('/voku/')),
        isTrue,
        reason: 'Rejected Voku artwork must no longer be selected');
    for (final kind in ['vip', 'svip']) {
      expect(tiers.where((r) => r.kind == kind).map((r) => r.tier).toSet(),
          {1, 2, 3, 4, 5, 6, 7, 8, 9, 10});
    }
    for (final tier in tiers) {
      expect(tier.entrance, isNull,
          reason: 'unproved native effects must stay inactive');
      for (final media in [tier.hero!, tier.badge!, tier.card!]) {
        final raw = await rootBundle.load(media.url);
        final bytes =
            raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
        ApprovedMediaPublication(
                sha256Hex: media.sha256,
                byteLength: media.bytes,
                mimeType: {
                  'png': 'image/png',
                  'webp': 'image/webp',
                  'jpeg': 'image/jpeg',
                  'svga': 'application/x-svga'
                }[media.format]!,
                codec: media.format)
            .validate(
                bytes,
                {
                  'png': 'image/png',
                  'webp': 'image/webp',
                  'jpeg': 'image/jpeg',
                  'svga': 'application/x-svga'
                }[media.format]);
        if (media.format == 'svga') {
          await validateRenderableMedia(
              bytes,
              ApprovedMediaPublication(
                  sha256Hex: media.sha256,
                  byteLength: media.bytes,
                  mimeType: 'application/x-svga',
                  codec: 'svga'));
          continue;
        }
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        expect(frame.image.height, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      }
    }
  });

  test(
      'remote artwork requires supported format, bounded size and immutable hash URL',
      () {
    final hash = List.filled(64, 'a').join();
    final valid = {
      'url': 'https://cdn.example/$hash.png',
      'sha256': hash,
      'bytes': 128,
      'format': 'png'
    };
    expect(MembershipMedia.parse(valid), isNotNull);
    for (final bad in [
      {...valid, 'url': 'https://cdn.example/latest.png'},
      {...valid, 'url': 'http://cdn.example/$hash.png'},
      {...valid, 'bytes': 4194305},
      {...valid, 'format': 'pag'},
      {...valid, 'sha256': 'invalid'},
    ]) {
      expect(MembershipMedia.parse(bad), isNull);
    }
    expect(MembershipMedia.parse({...valid, 'format': 'svga'}), isNull);
    expect(MembershipMedia.parse({...valid, 'format': 'svga'}, entrance: true),
        isNotNull);
  });

  test('approved SVGA hero remains distinct from static badge media', () {
    final hash = List.filled(64, 'b').join();
    final media = {
      'url': 'https://cdn.example/$hash.svga',
      'sha256': hash,
      'bytes': 512,
      'format': 'svga'
    };
    final row = MembershipPresentation.fromJson({
      'kind': 'svip',
      'tier': 10,
      'title': 'SVIP 10',
      'hero': media,
      'badge': media
    });
    expect(row.hero, isNotNull);
    expect(row.hero!.format, 'svga');
    expect(row.badge, isNull,
        reason: 'Badge publication remains a static format');
  });

  test('nested animation uses a static hero envelope compatible with older clients', () {
    final hash=List.filled(64,'c').join();
    final image={'url':'https://cdn.example/$hash.webp','sha256':hash,'bytes':100,'format':'webp'};
    final motion={'url':'https://cdn.example/$hash.svga','sha256':hash,'bytes':100,'format':'svga'};
    final envelope={...image,'animation':motion};
    expect(MembershipMedia.parse(envelope)!.format,'webp');
    final presentation=MembershipPresentation.fromJson({'kind':'svip','tier':1,'hero':envelope});
    expect(presentation.hero!.format,'svga');
  });

  test('unknown remote benefits cannot invent executable entitlements', () {
    final row = MembershipPresentation.fromJson({
      'kind': 'vip',
      'tier': 10,
      'title': 'VIP 10',
      'benefit_keys': [
        'badge',
        'moderation_immunity',
        'admin',
        'free_coins',
        'daily_reward'
      ]
    });
    expect(row.benefits, {'badge', 'daily_reward'});
    expect(row.hero, isNull);
  });

  test('bundled manifest is the full provenance map rather than an asset guess',
      () async {
    final manifest = jsonDecode(await rootBundle
        .loadString('assets/membership/remix/manifest.json')) as Map;
    final rows = manifest['items'] as List;
    expect(rows.length, 70);
    expect(rows.any((r) => r['source_package'].toString().contains('Voku')),
        isFalse);
    expect(rows.map((r) => r['source_package']).toSet(),
        {'YoHo-5.48.40.apks', 'Falla-V9.23.0.apks', 'Mizah-0.5.2.apks'});
  });
}
