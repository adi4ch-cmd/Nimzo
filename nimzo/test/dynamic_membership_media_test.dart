import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/premium/dynamic_membership_media.dart';
import 'package:nimzo/features/store/premium_cosmetics.dart';

void main() {
  Map<String, dynamic> row({
    String kind = 'vip',
    int tier = 1,
    String slot = 'badge',
    String url = 'https://cdn.example.com/badge.png',
    String format = 'image',
    String? thumbnail,
  }) => {
    'kind': kind,
    'tier': tier,
    'slot': slot,
    'asset_url': url,
    'media_kind': format,
    'thumbnail_url': thumbnail,
  };

  test('only authenticated approved HTTPS membership records are usable', () {
    final approved = NimzoMembershipMedia.fromRow(row());
    expect(approved?.tier, 1);
    expect(approved?.toCosmetic().kind, CosmeticMediaKind.image);
    expect(NimzoMembershipMedia.fromRow(row(url: 'http://unsafe/a.png')), isNull);
    expect(NimzoMembershipMedia.fromRow(row(url: 'file:///etc/passwd')), isNull);
    expect(NimzoMembershipMedia.fromRow(
      row(url: 'https://user:secret@cdn.example/a.png')), isNull);
    expect(NimzoMembershipMedia.fromRow(
      row(url: 'https://cdn.example/a.png#fragment')), isNull);
    expect(NimzoMembershipMedia.fromRow(row(kind: 'admin')), isNull);
    expect(NimzoMembershipMedia.fromRow(row(tier: 11)), isNull);
    expect(NimzoMembershipMedia.fromRow(row(tier: 0)), isNull);
    expect(NimzoMembershipMedia.fromRow(row(slot: 'wallet')), isNull);
  });

  test('new live entrance allows only playable transparent effects', () {
    expect(NimzoMembershipMedia.fromRow(row(
      kind: 'svip', tier: 10, slot: 'entry',
      url: 'https://cdn.example.com/entry.svga', format: 'svga')), isNotNull);
    expect(NimzoMembershipMedia.fromRow(row(
      kind: 'svip', tier: 9, slot: 'entry',
      url: 'https://cdn.example.com/entry.mp4', format: 'vap')), isNotNull);
    expect(NimzoMembershipMedia.fromRow(row(slot: 'entry')), isNull);
    expect(NimzoMembershipMedia.fromRow(row(slot: 'badge',format: 'vap')), isNull);
    expect(NimzoMembershipMedia.fromRow(row(format: 'unknown')), isNull);
  });

  test('only exact purchased/earned tier media are presented', () {
    final artwork = <NimzoMembershipMedia>[
      NimzoMembershipMedia.fromRow(row(kind: 'vip',tier: 1))!,
      NimzoMembershipMedia.fromRow(row(kind: 'vip',tier: 2))!,
      NimzoMembershipMedia.fromRow(row(kind: 'svip',tier: 1))!,
    ];
    final selected = membershipTierMedia(artwork, 'vip', 1);
    expect(selected.keys, {'badge'});
    expect(selected['badge']!.kind, 'vip');
    expect(selected['badge']!.tier, 1);
    expect(membershipTierMedia(artwork,'admin',1), isEmpty);
    expect(membershipTierMedia(artwork,'vip',11), isEmpty);
    expect(membershipTierMedia(artwork,'vip',3), isEmpty);
  });
}
