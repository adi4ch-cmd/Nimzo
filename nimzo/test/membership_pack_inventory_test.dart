import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/premium/membership_pack_inventory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all existing and prospective levels keep the same pack slot structure',
      () {
    for (final kind in ['vip', 'svip']) {
      for (var tier = 1; tier <= 12; tier++) {
        final parts = MembershipPackInventory.forTier(kind, tier);
        expect(parts.map((part) => part.title).toList(),
            MembershipPackInventory.slots);
        expect(parts.length, 8);
        expect(parts.every((part) => part.matchesTarget(kind, tier)), isTrue,
            reason: '$kind $tier must never use borrowed levels or categories');
      }
    }
  });

  test('reject cross-level and VIP vs SVIP art even with correct UI labels',
      () {
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
      expect(vip[1].available, isTrue);
      expect(vip[2].available, isTrue);
      expect(vip[3].animated, tier <= 6);
      expect(vip[4].available, tier <= 6);
      expect(vip[5].animated, tier <= 6);
      expect(MembershipPackInventory.profileCard('vip', tier).available,
          tier <= 6);
      expect(MembershipPackInventory.medal('vip', tier).available, isTrue);
      expect(vip[6].available, isFalse);
      expect(vip[7].available, tier == 6);
      expect(svip[0].available, isTrue);
      expect(svip[1].available, isTrue);
      expect(svip[2].available, isTrue);
      expect(svip[3].animated, tier <= 6);
      expect(svip[5].animated, tier >= 3);
      expect(svip[6].animated, tier <= 6);
      expect(
          MembershipPackInventory.profileCard('svip', tier).available, isFalse);
      expect(MembershipPackInventory.medal('svip', tier).available, isTrue);
      for (final i in [4, 7]) {
        expect(svip[i].available, isFalse);
      }
    }
  });

  test('all selected genuine assets resolve in Flutter asset manifest',
      () async {
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
                reason:
                    '$kind $tier: missing ${part.title} from ${part.source}');
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
    expect(
        () => MembershipPackInventory.forTier('admin', 1), throwsArgumentError);
    expect(() => MembershipPackInventory.forTier('svip', 0), throwsRangeError);
  });
  test('wide YoHo original canvases position the actual frame over the avatar', () {
    for(final tier in [6,7,8,9,10]) {
      final crop=MembershipPackInventory.forTier('vip',tier)[1].crop!;
      expect(crop[2],lessThan(300),reason:'Transparent canvas artifacts must not shift frame away from real avatar');
      expect(crop[0],greaterThan(200));
    }
  });
}
