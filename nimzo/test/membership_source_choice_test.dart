import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimzo/features/premium/membership_catalog.dart';
import 'package:nimzo/features/premium/membership_pack_inventory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('bundled Hafla VIP identity is used on membership pages too', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final presentations =
        await container.read(membershipBundledPresentationsProvider.future);
    for (var tier = 1; tier <= 8; tier++) {
      final row =
          presentations.firstWhere((p) => p.kind == 'vip' && p.tier == tier);
      expect(
          row.hero!.url,
          MembershipPackInventory.original(
                  'vip', tier, 'membership_hero', 'Hero')
              .path);
      expect(row.hero!.isBundled, isTrue);
      expect(
          row.badge!.url,
          MembershipPackInventory.original(
                  'vip', tier, 'membership_badge', 'Badge')
              .path);
    }
    expect(
        presentations
            .where((p) => p.kind == 'svip')
            .every((p) => p.hero!.format == 'svga'),
        isTrue);
  });
  test('full-pack wording is limited to source-complete core media', () {
    final complete = <String>[];
    for (final kind in ['vip', 'svip']) {
      for (var tier = 1; tier <= 10; tier++) {
        if (MembershipPackInventory.hasCompleteCoreMedia(kind, tier))
          complete.add('$kind$tier');
      }
    }
    expect(complete, ['vip6']);
  });
  test(
      'source identity preference preserves remote entrance and benefit policy',
      () {
    final base = MembershipPresentation.fromJson({
      'kind': 'vip',
      'tier': 5,
      'entrance': {
        'url': 'https://cdn.example/media/${'a' * 64}.svga',
        'sha256': 'a' * 64,
        'bytes': 100,
        'format': 'svga'
      },
      'benefit_keys': ['badge', 'room_entry', 'daily_reward'],
    });
    expect(base.entrance, isNotNull);
    final chosen = MembershipPresentation.preferred(base);
    expect(chosen.entrance, same(base.entrance));
    expect(chosen.benefits, equals(base.benefits));
    expect(chosen.kind, base.kind);
    expect(chosen.tier, base.tier);
    expect(chosen.hero!.isBundled, isTrue);
  });
  test('SVIP 1–10 use genuine matching Falla frames, medals and nameplates',
      () {
    for (var tier = 1; tier <= 10; tier++) {
      for (final slot in ['avatar_frame', 'medal', 'nameplate']) {
        final art = MembershipPackInventory.original('svip', tier, slot, slot);
        expect(art.source, startsWith('Falla-V9.23.0.apks!/'),
            reason: 'SVIP $tier $slot');
        expect(art.matchesTarget('svip', tier), isTrue);
      }
    }
  });
  test(
      'available Hafla VIP 1–8 identities and VIP 1–5 bubbles replace mixed sources',
      () {
    for (var tier = 1; tier <= 8; tier++) {
      for (final slot in [
        'medal',
        'nameplate',
        'membership_hero',
        'membership_badge'
      ]) {
        final art = MembershipPackInventory.original('vip', tier, slot, slot);
        expect(art.source, startsWith('Hafla-1.7.2.apks!/'),
            reason: 'VIP $tier $slot');
        expect(art.matchesTarget('vip', tier), isTrue);
      }
      if (tier <= 5) {
        expect(MembershipPackInventory.forTier('vip', tier)[4].source,
            startsWith('Hafla-1.7.2.apks!/'));
      }
    }
  });
  test('unavailable Hafla VIP 9–10 are not relabeled from lower tiers', () {
    for (final tier in [9, 10]) {
      expect(
          MembershipPackInventory.original(
                  'vip', tier, 'membership_hero', 'Hero')
              .available,
          isFalse);
      expect(MembershipPackInventory.medal('vip', tier).source,
          startsWith('YoHo-'));
    }
  });
}
