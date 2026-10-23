import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimzo/features/premium/membership_pack_inventory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('VIP/SVIP levels all have the same eight named slots', () {
    for (final kind in ['vip', 'svip']) {
      for (var tier = 1; tier <= 12; tier++) {
        final parts = MembershipPackInventory.forTier(kind, tier);
        expect(parts.length, MembershipPackInventory.slots.length);
        expect(parts.map((part) => part.title).toList(),
            MembershipPackInventory.slots);
        expect(parts.every((part) => part.available), isTrue,
            reason: '$kind $tier must be assembled from sourced image files');
        expect(parts.every((part) => part.source.isNotEmpty), isTrue);
      }
    }
  });

  test('mixed-source pack keeps target identity, not borrowed source level', () {
    final vip5 = MembershipPackInventory.forTier('vip', 5);
    final svip5 = MembershipPackInventory.forTier('svip', 5);
    expect(vip5.map((p) => p.source).toSet().length, greaterThan(4));
    expect(svip5.map((p) => p.source).toSet().length, greaterThan(4));
    expect(svip5[1].source, startsWith('WillChill VIP'));
    expect(svip5[2].source, contains('SVIP'));
    expect(svip5[7].source, startsWith('DangLive'));
    expect(svip5[1].isTierSpecific, isFalse);
    expect(svip5[3].source, contains('static banner'),
        reason: 'A static image must not be represented as animated VAP');
  });

  test('all 20 bundled mixed packs reference declared Flutter assets', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest.listAssets().toSet();
    for (final kind in ['vip', 'svip']) {
      for (var tier = 1; tier <= 10; tier++) {
        for (final artwork in MembershipPackInventory.forTier(kind, tier)) {
          if (artwork.path != null) {
            expect(paths, contains(artwork.path),
                reason: '$kind $tier missing ${artwork.title}: ${artwork.source}');
          }
          if (artwork.otherSide != null) {
            expect(paths, contains(artwork.otherSide),
                reason: '$kind $tier missing second nameplate ornament');
          }
        }
      }
    }
  });

  test('invalid tiers and membership categories fail safely', () {
    expect(() => MembershipPackInventory.forTier('admin', 1),
        throwsArgumentError);
    expect(() => MembershipPackInventory.forTier('svip', 0),
        throwsRangeError);
  });
}
