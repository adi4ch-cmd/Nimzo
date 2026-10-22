import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimzo/core/services/approved_media_bytes.dart';
import 'package:nimzo/features/premium/membership_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all 20 VIP/SVIP tiers have matched, checksum-valid, decodable PNGs', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tiers = await container.read(membershipBundledPresentationsProvider.future);
    expect(tiers.length, 20);
    for (final kind in ['vip', 'svip']) {
      expect(tiers.where((r) => r.kind == kind).map((r) => r.tier).toSet(),
        {1,2,3,4,5,6,7,8,9,10});
    }
    for (final tier in tiers) {
      expect(tier.entrance, isNull, reason: 'unproved native effects must stay inactive');
      for (final media in [tier.hero!, tier.badge!]) {
        final raw = await rootBundle.load(media.url);
        final bytes = raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
        ApprovedMediaPublication(sha256Hex: media.sha256, byteLength: media.bytes,
          mimeType: 'image/png', codec: 'png').validate(bytes, 'image/png');
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        expect(frame.image.height, greaterThan(0));
        frame.image.dispose(); codec.dispose();
      }
    }
  });

  test('remote artwork requires supported format, bounded size and immutable hash URL', () {
    final hash = List.filled(64, 'a').join();
    final valid = {'url':'https://cdn.example/$hash.png','sha256':hash,'bytes':128,'format':'png'};
    expect(MembershipMedia.parse(valid), isNotNull);
    for (final bad in [
      {...valid,'url':'https://cdn.example/latest.png'},
      {...valid,'url':'http://cdn.example/$hash.png'},
      {...valid,'bytes':4194305},
      {...valid,'format':'pag'},
      {...valid,'sha256':'invalid'},
    ]) { expect(MembershipMedia.parse(bad), isNull); }
    expect(MembershipMedia.parse({...valid,'format':'svga'}), isNull);
    expect(MembershipMedia.parse({...valid,'format':'svga'}, entrance:true), isNotNull);
  });

  test('unknown remote benefits cannot invent executable entitlements', () {
    final row = MembershipPresentation.fromJson({'kind':'vip','tier':10,'title':'VIP 10',
      'benefit_keys':['badge','moderation_immunity','admin','free_coins','daily_reward']});
    expect(row.benefits, {'badge','daily_reward'});
    expect(row.hero, isNull);
  });

  test('bundled manifest is the full provenance map rather than an asset guess', () async {
    final manifest = jsonDecode(await rootBundle.loadString('assets/membership/voku/manifest.json')) as Map;
    final rows = manifest['records'] as List;
    expect(rows.length, 40);
    expect(rows.every((r) => (r['source'] as String).contains('Voku-1.1.7.apks')), isTrue);
  });
}
