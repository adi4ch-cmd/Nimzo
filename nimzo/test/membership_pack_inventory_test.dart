import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/premium/membership_pack_inventory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all existing and prospective levels keep the same pack slot structure', () {
    for (final kind in ['vip', 'svip']) {
      for (var tier = 1; tier <= 12; tier++) {
        final parts = MembershipPackInventory.forTier(kind, tier);
        expect(parts.map((part) => part.title).toList(), MembershipPackInventory.slots);
        expect(parts.length, 8);
        expect(parts.every((part) => part.matchesTarget(kind, tier)), isTrue,
            reason: '$kind $tier must never use borrowed levels or categories');
      }
    }
  });

  test('reject cross-level and VIP vs SVIP art even with correct UI labels', () {
    MembershipPackArtwork asset(String targetKind, int targetTier,
            String sourceKind, int sourceTier) =>
        MembershipPackArtwork.matching(
          title: 'Avatar frame',
          targetKind: targetKind,
          targetTier: targetTier,
          sourceKind: sourceKind,
          sourceTier: sourceTier,
          path: 'assets/example.png',
          source: 'Another APK',
        );
    expect(() => asset('svip', 5, 'vip', 5), throwsStateError);
    expect(() => asset('svip', 6, 'svip', 2), throwsStateError);
    expect(() => asset('vip', 6, 'vip', 5), throwsStateError);
    expect(() => asset('vip', 6, 'vip', 6).available, returnsNormally);
    final sameTier = asset('svip', 6, 'svip', 6);
    expect(sameTier.matchesTarget('svip', 6), isTrue);
  });

  test('missing tier pieces remain unavailable rather than borrowed', () {
    for (var tier = 1; tier <= 10; tier++) {
      final vip = MembershipPackInventory.forTier('vip', tier);
      final svip = MembershipPackInventory.forTier('svip', tier);
      expect(vip[0].available, tier <= 7);
      expect(vip[1].available, tier <= 5);
      expect(vip[2].available, tier <= 7);
      expect(vip[3].available, tier <= 5);
      expect(vip[4].available, tier <= 5);
      expect(vip[5].available, tier <= 5);
      expect(vip[6].available, tier <= 5);
      expect(vip[7].available, tier == 6,
          reason: 'Tana supplies the genuine VIP6 room wallpaper only');
      expect(svip[0].available, tier <= 8);
      if (tier == 6) {
        expect(vip[7].path, 'assets/membership/tana-vip6-room-bg.webp');
        expect(vip[7].sourceTier, 6);
        expect(vip[7].sourceKind, 'vip');
      }
      expect(svip[1].available, isFalse,
          reason: 'SVIP frames must be SVIP frames from an actual source');
      expect(svip[2].available, isFalse);
      expect(svip[3].available, tier <= 8,
          reason: 'Available image is a static same-tier entry icon');
      expect(svip[5].available, tier >= 3 && tier <= 6,
          reason: 'Orii offers original same-tier animated mic waves for SVIP 3–6');
      if (svip[5].available) {
        expect(svip[5].animated, isTrue);
        expect(svip[5].sourceTier, tier);
        expect(svip[5].sourceKind, 'svip');
        expect(svip[5].thumbnail, isNotNull);
      }
      for (final i in [4, 6, 7]) {
        expect(svip[i].available, isFalse);
      }
    }
  });

  test('all selected genuine assets resolve in Flutter asset manifest', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest.listAssets().toSet();
    expect(paths, contains('assets/membership/tana-vip6-locked-seat.png'));
    expect(paths, contains('assets/membership/tana-vip6-open-seat.png'));
    expect(paths, contains('assets/membership/tana-vip6-room-bg.webp'));
    for (final kind in ['vip', 'svip']) {
      for (var tier = 1; tier <= 10; tier++) {
        for (final part in MembershipPackInventory.forTier(kind, tier)) {
          if (part.path != null) {
            expect(paths, contains(part.path),
                reason: '$kind $tier: missing ${part.title} from ${part.source}');
          }
          if (part.otherSide != null) {
            expect(paths, contains(part.otherSide),
                reason: '$kind $tier: missing second nameplate image');
          }
          if (part.thumbnail != null) {
            expect(paths, contains(part.thumbnail),
                reason: '$kind $tier: missing original media thumbnail');
          }
        }
      }
    }
  });

  test('unrecognized category and tier are rejected', () {
    expect(() => MembershipPackInventory.forTier('admin', 1), throwsArgumentError);
    expect(() => MembershipPackInventory.forTier('svip', 0), throwsRangeError);
  });
}
