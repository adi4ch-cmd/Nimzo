import 'dart:convert';
import 'membership_original_assets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/services/approved_media_bytes.dart';
import '../../core/services/nimzo_content_sync.dart';

/// Presentation metadata never establishes ownership or monetary authority.
class MembershipMedia {
  const MembershipMedia(
      {required this.url,
      required this.sha256,
      required this.bytes,
      required this.format});
  final String url, sha256, format;
  final int bytes;
  bool get isBundled =>
      url.startsWith('assets/membership/packs/') ||
      url.startsWith('assets/membership/remix/') ||
      url.startsWith('assets/membership/voku/');

  static MembershipMedia? parse(dynamic value,
      {bool entrance = false, bool animatedHero = false}) {
    if (value is! Map) return null;
    final url = value['url'];
    final hash = value['sha256'];
    final size = value['bytes'];
    final format = value['format'];
    if (url is! String ||
        !ApprovedMediaBytes.isSafeUrl(url) ||
        hash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        !Uri.parse(url).path.contains(hash) ||
        size is! int ||
        size < 1 ||
        size > (entrance ? 16 * 1024 * 1024 : 4 * 1024 * 1024) ||
        !(entrance
                ? ['svga', 'vap']
                : animatedHero
                    ? ['png', 'webp', 'jpeg', 'svga']
                    : ['png', 'webp', 'jpeg'])
            .contains(format)) {
      return null;
    }
    return MembershipMedia(url: url, sha256: hash, bytes: size, format: format);
  }
}

class MembershipPresentation {
  MembershipPresentation.fromJson(Map<String, dynamic> row)
      : kind = row['kind'] as String,
        tier = (row['tier'] as num).toInt(),
        title = (row['title'] as String?) ?? '',
        hero = MembershipMedia.parse(
                row['hero'] is Map ? (row['hero'] as Map)['animation'] : null,
                animatedHero: true) ??
            MembershipMedia.parse(row['hero'], animatedHero: true),
        card = MembershipMedia.parse(row['card']),
        badge = MembershipMedia.parse(row['badge']),
        entrance = MembershipMedia.parse(row['entrance'], entrance: true),
        benefits = (row['benefit_keys'] as List? ?? const [])
            .whereType<String>()
            .where(supportedBenefits.contains)
            .toSet();
  MembershipPresentation.bundled(
      this.kind, this.tier, Map heroRow, Map badgeRow,
      {Map? cardRow})
      : title = '${kind.toUpperCase()} $tier',
        hero = _bundledMedia(heroRow),
        badge = _bundledMedia(badgeRow),
        card = cardRow == null ? null : _bundledMedia(cardRow),
        entrance = null,
        benefits = const {'badge', 'room_entry'};

  /// Explicit owner-selected original identity; entitlement and remote entrance
  /// are unchanged. Missing exact-tier choices retain the approved presentation.
  MembershipPresentation.preferred(MembershipPresentation base)
      : kind = base.kind,
        tier = base.tier,
        title = base.title,
        hero = _preferred(base.kind, base.tier, 'membership_hero') ?? base.hero,
        badge =
            _preferred(base.kind, base.tier, 'membership_badge') ?? base.badge,
        card = base.card,
        entrance = base.entrance,
        benefits = base.benefits;

  static MembershipMedia? _preferred(String kind, int tier, String slot) {
    final row = membershipOriginalAssets['$kind$tier']?[slot];
    if (row == null) return null;
    final path = row['path'] as String;
    return MembershipMedia(
        url: path,
        sha256: row['sha256'] as String,
        bytes: row['bytes'] as int,
        format: path.split('.').last);
  }

  static MembershipMedia _bundledMedia(Map row) => MembershipMedia(
      url: row['asset'] as String,
      sha256: row['sha256'] as String,
      bytes: row['bytes'] as int,
      format: (row['codec'] ?? row['format'] ?? 'png') as String);
  static const supportedBenefits = {
    'badge',
    'room_entry',
    'daily_reward',
    'weekly_reward',
  };
  final String kind, title;
  final int tier;
  final MembershipMedia? hero, badge, card, entrance;
  final Set<String> benefits;
}

/// Auth-scoped and revision-driven: deactivation/removal replaces, never merges,
/// the last snapshot. An unavailable catalog cannot authorize a purchase.
final membershipPresentationsProvider =
    FutureProvider.autoDispose<List<MembershipPresentation>>((ref) async {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return [];
  ref.watch(nimzoContentRevisionsProvider.select((snapshot) {
    final rows = snapshot.valueOrNull ?? const <Map<String, dynamic>>[];
    return [
      for (final row in rows)
        if (row['channel'] == 'settings' || row['channel'] == 'membership')
          '${row['channel']}:${row['revision']}'
    ].join('|');
  }));
  final rows = await session.client
      .from('nimzo_membership_presentations')
      .select('kind,tier,title,hero,badge,card,entrance,benefit_keys')
      .eq('active', true)
      .eq('approved', true)
      .order('kind')
      .order('tier')
      .timeout(const Duration(seconds: 8));
  return rows
      .map((row) => MembershipPresentation.preferred(
          MembershipPresentation.fromJson(row)))
      .toList();
});

/// Bundled equivalent artwork is independent of publication/entitlement status.
/// Explicit owner-selected source identities override the corresponding visuals;
/// other approved remote artwork and effects continue to update normally.
final membershipBundledPresentationsProvider =
    FutureProvider<List<MembershipPresentation>>((ref) async {
  final manifest = jsonDecode(
          await rootBundle.loadString('assets/membership/remix/manifest.json'))
      as Map;
  final rows = (manifest['items'] as List).cast<Map>();
  return [
    for (final kind in ['vip', 'svip'])
      for (var tier = 1; tier <= 10; tier++)
        MembershipPresentation.bundled(
            kind,
            tier,
            rows.firstWhere((r) =>
                r['kind'] == kind && r['tier'] == tier && r['role'] == 'hero'),
            rows.firstWhere((r) =>
                r['kind'] == kind && r['tier'] == tier && r['role'] == 'badge'),
            cardRow: rows.firstWhere((r) =>
                r['kind'] == kind && r['tier'] == tier && r['role'] == 'card'))
  ].map(MembershipPresentation.preferred).toList();
});
