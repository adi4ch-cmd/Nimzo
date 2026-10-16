import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';

enum RoyalKind { vip, svip }

extension RoyalKindLabel on RoyalKind {
  String get code => name;
  String get title => this == RoyalKind.vip ? 'VIP' : 'SVIP';
  int get count => this == RoyalKind.vip ? 8 : 9;
}

@immutable
class RoyalTheme {
  final RoyalKind kind;
  final int tier;
  final String name;
  final String subtitle;
  final Color accent;
  final Color shadow;
  final IconData crest;

  const RoyalTheme({
    required this.kind,
    required this.tier,
    required this.name,
    required this.subtitle,
    required this.accent,
    required this.shadow,
    required this.crest,
  });

  String get label => '${kind.title}$tier';
}

const royalThemes = <RoyalTheme>[
  RoyalTheme(kind: RoyalKind.vip, tier: 1, name: 'Royal Lion', subtitle: 'Bronze and champagne', accent: Color(0xffefbd75), shadow: Color(0xff583019), crest: Icons.shield_outlined),
  RoyalTheme(kind: RoyalKind.vip, tier: 2, name: 'Jade Sovereign', subtitle: 'Emerald and golden light', accent: Color(0xffbcf08e), shadow: Color(0xff174c32), crest: Icons.diamond_outlined),
  RoyalTheme(kind: RoyalKind.vip, tier: 3, name: 'Emerald Guardian', subtitle: 'Deep forest and antique gold', accent: Color(0xff65dda4), shadow: Color(0xff0d4939), crest: Icons.shield_moon_outlined),
  RoyalTheme(kind: RoyalKind.vip, tier: 4, name: 'Sky Monarch', subtitle: 'Icy sapphire and silver', accent: Color(0xff78def5), shadow: Color(0xff124f77), crest: Icons.flight_outlined),
  RoyalTheme(kind: RoyalKind.vip, tier: 5, name: 'Blue Dynasty', subtitle: 'Royal cobalt and platinum', accent: Color(0xff90b7ff), shadow: Color(0xff152c70), crest: Icons.stars_outlined),
  RoyalTheme(kind: RoyalKind.vip, tier: 6, name: 'Amethyst King', subtitle: 'Imperial violet and gold', accent: Color(0xffd4a5ff), shadow: Color(0xff57347c), crest: Icons.workspace_premium_outlined),
  RoyalTheme(kind: RoyalKind.vip, tier: 7, name: 'Crimson Phoenix', subtitle: 'Ruby flame and molten gold', accent: Color(0xffff9a69), shadow: Color(0xff942619), crest: Icons.local_fire_department_outlined),
  RoyalTheme(kind: RoyalKind.vip, tier: 8, name: 'Golden Dragon', subtitle: 'Supreme imperial gold', accent: Color(0xffffdc82), shadow: Color(0xff986122), crest: Icons.auto_awesome),
  RoyalTheme(kind: RoyalKind.svip, tier: 1, name: 'Silver Moon', subtitle: 'Moonstone and midnight blue', accent: Color(0xffc4d8ff), shadow: Color(0xff283f7c), crest: Icons.nights_stay_outlined),
  RoyalTheme(kind: RoyalKind.svip, tier: 2, name: 'Ice Monarch', subtitle: 'Frosted silver and sapphire', accent: Color(0xffa9cfff), shadow: Color(0xff244a7d), crest: Icons.ac_unit_outlined),
  RoyalTheme(kind: RoyalKind.svip, tier: 3, name: 'Rose Emperor', subtitle: 'Rose gold and copper', accent: Color(0xffffb9a8), shadow: Color(0xff99445a), crest: Icons.shield_outlined),
  RoyalTheme(kind: RoyalKind.svip, tier: 4, name: 'Crystal Crown', subtitle: 'Glacial turquoise and pearl', accent: Color(0xff93eff6), shadow: Color(0xff205779), crest: Icons.diamond_outlined),
  RoyalTheme(kind: RoyalKind.svip, tier: 5, name: 'Azure Guardian', subtitle: 'Deep ocean and azure', accent: Color(0xff85baff), shadow: Color(0xff28479a), crest: Icons.stars_outlined),
  RoyalTheme(kind: RoyalKind.svip, tier: 6, name: 'Emerald Throne', subtitle: 'Imperial green and gold', accent: Color(0xff9cfa99), shadow: Color(0xff1f6c35), crest: Icons.shield_moon_outlined),
  RoyalTheme(kind: RoyalKind.svip, tier: 7, name: 'Amethyst Crown', subtitle: 'Mystic violet and lilac', accent: Color(0xffd4a2ff), shadow: Color(0xff6e2e98), crest: Icons.workspace_premium_outlined),
  RoyalTheme(kind: RoyalKind.svip, tier: 8, name: 'Solar Dynasty', subtitle: 'Burnished gold and amber', accent: Color(0xffffdf95), shadow: Color(0xff926422), crest: Icons.wb_sunny_outlined),
  RoyalTheme(kind: RoyalKind.svip, tier: 9, name: 'Dragon Sovereign', subtitle: 'Fire, gold and obsidian', accent: Color(0xffffc263), shadow: Color(0xffa3431b), crest: Icons.local_fire_department_outlined),
];

RoyalTheme royalTheme(RoyalKind kind, int tier) => royalThemes.firstWhere(
  (theme) => theme.kind == kind && theme.tier == tier,
  orElse: () => royalThemes.firstWhere((theme) => theme.kind == kind),
);

class RoyalSelection {
  final int? vipTier;
  final int? svipTier;
  final RoyalKind? displayed;

  const RoyalSelection({this.vipTier, this.svipTier, this.displayed});

  factory RoyalSelection.fromJson(Map<String, dynamic> json) {
    final vip = (json['vip_tier'] as num?)?.toInt();
    final svip = (json['svip_tier'] as num?)?.toInt();
    final kind = switch (json['display_kind']) {
      'vip' => RoyalKind.vip,
      'svip' => RoyalKind.svip,
      _ => null,
    };
    return RoyalSelection(
      vipTier: vip != null && vip >= 1 && vip <= 8 ? vip : null,
      svipTier: svip != null && svip >= 1 && svip <= 9 ? svip : null,
      displayed: kind,
    );
  }

  int? tierFor(RoyalKind kind) =>
      kind == RoyalKind.vip ? vipTier : svipTier;

  RoyalTheme? get visibleTheme {
    final kind = displayed;
    if (kind == null) return null;
    final tier = tierFor(kind);
    return tier == null ? null : royalTheme(kind, tier);
  }
}

/// The new FREE themes never read or restore the old paid membership columns.
final freeRoyalSelectionProvider =
    FutureProvider.family<RoyalSelection?, String>((ref, userId) async {
  final db = ref.watch(sessionSupabaseProvider).client;
  final row = await db
      .from('free_memberships')
      .select('vip_tier,svip_tier,display_kind')
      .eq('user_id', userId)
      .maybeSingle();
  return row == null ? null : RoyalSelection.fromJson(row);
});

final freeRoyalActivationProvider = Provider<FreeRoyalActivation>((ref) =>
    FreeRoyalActivation(ref.watch(sessionSupabaseProvider).client));

class FreeRoyalActivation {
  final dynamic _db;
  FreeRoyalActivation(this._db);

  Future<void> activate(RoyalKind kind, int tier) async {
    if (tier < 1 || tier > kind.count) {
      throw ArgumentError.value(tier, 'tier', 'Invalid membership theme');
    }
    // Security, active-account check and persistence are enforced by the RPC.
    // Absolutely no wallet or payment operation is performed by this client.
    await _db.rpc('activate_free_membership', params: {
      'p_kind': kind.code,
      'p_tier': tier,
    });
  }
}
