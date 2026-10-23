import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/premium/membership_pack_inventory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every current and future VIP/SVIP tier has identical pack slots', () {
    for (final kind in ['vip', 'svip']) {
      for (var tier = 1; tier <= 12; tier++) {
        final parts = MembershipPackInventory.forTier(kind, tier);
        expect(parts.length, MembershipPackInventory.slots.length);
        expect(parts.map((part) => part.title).toList(),
            MembershipPackInventory.slots);
        expect(parts.map((part) => part.title).toSet().length, parts.length);
      }
    }
  });

  test('original art is available only in the tiers it was actually supplied for', () {
    for (var tier = 1; tier <= 10; tier++) {
      final vip = MembershipPackInventory.forTier('vip', tier);
      final svip = MembershipPackInventory.forTier('svip', tier);
      expect(vip[1].available, tier <= 5,
          reason: 'VIP avatar frames 6-10 must not be invented');
      expect(vip[4].available, tier <= 5,
          reason: 'VIP chat bubbles 6-10 must not be invented');
      expect(vip[2].available, tier <= 7,
          reason: 'VIP nameplates 8-10 are not supplied');
      expect(svip[0].available, tier <= 8,
          reason: 'SVIP themed backgrounds 9-10 are not supplied');
      expect(svip[2].available, tier <= 8,
          reason: 'SVIP nameplate ornaments 9-10 are not supplied');
      expect(svip[1].available, isFalse,
          reason: 'SVIP avatar frames are not supplied');
      expect(svip[7].available, isFalse,
          reason: 'Room backgrounds are not proven');
    }
  });

  test('all offered bundled WillChill pack images resolve in the asset bundle',
      () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest.listAssets().toSet();
    for (final kind in ['vip', 'svip']) {
      for (var tier = 1; tier <= 10; tier++) {
        for (final artwork
            in MembershipPackInventory.forTier(kind, tier)) {
          if (artwork.path != null) {
            expect(paths, contains(artwork.path),
                reason: '$kind $tier missing ${artwork.title}');
          }
          if (artwork.otherSide != null) {
            expect(paths, contains(artwork.otherSide),
                reason: '$kind $tier missing other ID ornament');
          }
        }
      }
    }
  });

  test('invalid kinds and tiers cannot masquerade as a membership pack', () {
    expect(() => MembershipPackInventory.forTier('admin', 1),
        throwsArgumentError);
    expect(() => MembershipPackInventory.forTier('svip', 0),
        throwsRangeError);
  });
}
