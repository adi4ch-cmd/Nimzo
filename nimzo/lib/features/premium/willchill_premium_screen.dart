import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import 'willchill_membership_showcase.dart';
import 'membership_status.dart';
import 'membership_purchase_keys.dart';
import 'dynamic_membership_media.dart';
import '../store/cosmetic_media_view.dart';
import '../wallet/wallet_screen.dart';
import '../profile/profile_repository.dart';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:flutter_vap_player/flutter_vap_player.dart';

/// Membership destination; source artwork is composed in the tier layout.
class WillChillPremiumScreen extends ConsumerStatefulWidget {
  const WillChillPremiumScreen({super.key, this.initialGroup = 'svip'});
  final String initialGroup;

  @override
  ConsumerState<WillChillPremiumScreen> createState() =>
      _WillChillPremiumScreenState();
}

class _PremiumAsset {
  _PremiumAsset(Map<String, dynamic> json)
      : group = json['group'] as String,
        name = json['name'] as String,
        asset = json['asset'] as String,
        mediaType = json['type'] as String,
        tier = json['tier'] as int?;
  final String group, name, asset, mediaType;
  final int? tier;
  bool get isImage => mediaType == 'image';
  bool get canPlay => mediaType == 'vap' || mediaType == 'svga';
  String get displayName => group == 'entrances' &&
          name.startsWith('voiceroom_crown_orb_')
      ? 'SVIP ${RegExp(r'\d+').firstMatch(name)?.group(0) ?? ''} room entrance'
      : name
          .replaceAll(RegExp(r'\.(png|webp|jpg|svga|mp4)$'), '')
          .replaceAll('_', ' ');
}

final membershipStatusProvider = FutureProvider.autoDispose<MembershipStatus?>((
  ref,
) async {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return null;
  final result = await session.client
      .rpc('vip_status')
      .timeout(const Duration(seconds: 6));
  if (result == null) return null;
  return MembershipStatus.fromJson(Map<String, dynamic>.from(result as Map));
});

final vipOffersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return [];
  final rows = await session.client
      .from('normal_vip_catalog')
      .select('tier,coin_price,duration_days')
      .order('tier');
  return rows.map((row) => Map<String, dynamic>.from(row)).toList();
});

final svipThresholdsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return [];
  final rows = await session.client
      .from('svip_thresholds')
      .select('level,usd_cents')
      .order('level');
  return rows.map((row) => Map<String, dynamic>.from(row)).toList();
});

class _WillChillPremiumScreenState
    extends ConsumerState<WillChillPremiumScreen> {
  List<_PremiumAsset>? _assets;
  Object? _error;
  late final String _group = widget.initialGroup == 'vip' ? 'vip' : 'svip';
  int _tier = 1;
  bool _buying = false;
  Timer? _statusRefresh;
  bool _claiming = false;

  @override
  void dispose() {
    _statusRefresh?.cancel();
    super.dispose();
  }

  Future<void> _purchase(Map<String, dynamic> offer) async {
    if (_buying) return;
    final session = ref.read(sessionSupabaseProvider);
    final status = ref.read(membershipStatusProvider).valueOrNull;
    if (session.userId == null || status?.canPurchase != true) return;
    final tier = (offer['tier'] as num).toInt();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Purchase VIP $tier?'),
        content: Text(
          '${offer['coin_price']} coins for ${offer['duration_days']} days. '
          'Same-tier renewal extends your expiry; changing tier starts a new cycle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Purchase'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        ref.read(sessionSupabaseProvider).userId != session.userId) return;
    setState(() => _buying = true);
    // Preserve the same key after an uncertain response, preventing a retry
    // from charging again when the server already committed the purchase.
    try {
      final preferences = await SharedPreferences.getInstance();
      final keys = MembershipPurchaseKeys(preferences);
      final key = await keys.prepare(session.userId!, tier);
      if (!mounted ||
          ref.read(sessionSupabaseProvider).userId != session.userId) return;
      final result = await session.client.rpc(
        'purchase_normal_vip',
        params: {'p_tier': tier, 'p_key': key},
      );
      if (result is! Map || !['ok', 'replayed'].contains(result['status'])) {
        throw StateError('Purchase was not confirmed');
      }
      await keys.complete(session.userId!, tier, key);
      if (!mounted ||
          ref.read(sessionSupabaseProvider).userId != session.userId) return;
      ref.invalidate(membershipStatusProvider);
      ref.invalidate(walletProvider);
      ref.invalidate(profileProvider(session.userId!));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('VIP purchase confirmed')));
    } catch (_) {
      if (mounted &&
          ref.read(sessionSupabaseProvider).userId == session.userId) {
        ref.invalidate(membershipStatusProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Purchase not confirmed. Refresh your membership or retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _claimReward() async {
    if (_claiming) return;
    final session = ref.read(sessionSupabaseProvider);
    final status = ref.read(membershipStatusProvider).valueOrNull;
    if (session.userId == null || status?.canClaim != true) return;
    if (_group == 'vip' && (status!.vipLevel == 0 || status.vipDailyClaimed))
      return;
    if (_group == 'svip' && !status!.svipWeeklyClaimable) return;
    setState(() => _claiming = true);
    try {
      await session.client
          .rpc(_group == 'vip' ? 'claim_vip_daily' : 'claim_svip_friday');
      if (!mounted ||
          ref.read(sessionSupabaseProvider).userId != session.userId) return;
      ref.invalidate(membershipStatusProvider);
      ref.invalidate(walletProvider);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membership reward confirmed')));
    } catch (_) {
      if (mounted &&
          ref.read(sessionSupabaseProvider).userId == session.userId) {
        ref.invalidate(membershipStatusProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Reward not confirmed. Refresh to check your membership.')));
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _statusRefresh = Timer.periodic(const Duration(minutes: 1), (_) {
      ref.invalidate(membershipStatusProvider);
    });
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/willchill_premium/catalog.json',
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final records = decoded['records'] as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _assets = records
            .map((item) => _PremiumAsset(item as Map<String, dynamic>))
            .toList(growable: false);
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Widget _svipOverview(int owned, double? progress,
      Map<String, NimzoMembershipMedia> liveMedia) {
    final possible = _assets
        ?.where(
          (item) =>
              item.group == 'entrances' &&
              item.name == 'voiceroom_crown_orb_$_tier.mp4',
        )
        .toList();
    final crown = possible == null || possible.isEmpty ? null : possible.first;
    final liveEntry = liveMedia['entry'];
    return WillChillMembershipShowcase(
      kind: 'svip',
      growthProgress: progress,
      tier: _tier,
      ownedLevel: owned,
      dynamicMedia: liveMedia,
      onTierChanged: (tier) => setState(() => _tier = tier),
      onPreviewEntrance: liveEntry == null && crown == null
          ? null
          : () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => FractionallySizedBox(
                  heightFactor: .85,
                  child: liveEntry == null
                      ? _PremiumAssetPreview(asset: crown!)
                      : _LiveMembershipMediaPreview(media: liveEntry),
                ),
              ),
    );
  }

  Widget _vipOverview(int owned,
      Map<String, NimzoMembershipMedia> liveMedia) =>
      WillChillMembershipShowcase(
        kind: 'vip',
        tier: _tier,
        ownedLevel: owned,
        dynamicMedia: liveMedia,
        onTierChanged: (tier) => setState(() => _tier = tier),
      );

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(membershipStatusProvider);
    final approvedMedia = ref.watch(nimzoMembershipMediaProvider)
        .valueOrNull ?? const <NimzoMembershipMedia>[];
    final liveTierMedia =
        membershipTierMedia(approvedMedia, _group, _tier);
    final profile = membership.valueOrNull;
    final svip = profile?.svipLevel ?? 0;
    final activeVip = profile?.vipLevel ?? 0;
    final status = membership.isLoading
        ? 'Checking membership…'
        : membership.hasError
            ? 'Membership unavailable · tap to retry'
            : profile == null
                ? 'Sign in to view your membership'
                : profile.retired
                    ? 'Membership purchases and rewards are unavailable'
                    : 'Your account · SVIP $svip · ${activeVip > 0 ? 'VIP $activeVip' : 'VIP inactive'}';
    final offers = ref.watch(vipOffersProvider).valueOrNull ?? const [];
    final thresholds =
        ref.watch(svipThresholdsProvider).valueOrNull ?? const [];
    final selectedOffers = offers.where((row) => row['tier'] == _tier);
    final offer = selectedOffers.isEmpty ? null : selectedOffers.first;
    final selectedThresholds = thresholds.where((row) => row['level'] == _tier);
    final threshold = selectedThresholds.isEmpty
        ? null
        : (selectedThresholds.first['usd_cents'] as num?)?.toDouble();
    final cents = profile?.cycleCents.toDouble();
    final progress = threshold != null && threshold > 0 && cents != null
        ? (cents / threshold).clamp(0.0, 1.0)
        : null;
    return Scaffold(
      backgroundColor: const Color(0xff090a10),
      appBar: AppBar(
        title: Text(_group == 'svip' ? 'NIMZO SVIP' : 'NIMZO VIP'),
        centerTitle: true,
        backgroundColor: const Color(0xff100e12),
        foregroundColor: const Color(0xffead8a1),
        actions: [
          IconButton(
            tooltip: 'Membership information',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: const Color(0xff17131c),
              showDragHandle: true,
              builder: (_) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '$status\n\nArtwork previews do not grant benefits. VIP artwork covers tiers 1–7 and SVIP artwork covers tiers 1–8; the server catalog has 10 tiers. Purchases require an enabled server contract.',
                    style: const TextStyle(
                      color: Color(0xffead8a1),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          key: const ValueKey('membership-fixed-status'),
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xff100e12),
            border: const Border(top: BorderSide(color: Color(0xff806943))),
            image: _group == 'svip' && _tier <= 8
                ? DecorationImage(
                    image: AssetImage(
                      'assets/willchill_premium/svip/svip${_tier}_expiration_container.webp',
                    ),
                    fit: BoxFit.fill,
                  )
                : null,
          ),
          child: _group == 'svip'
              ? Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_outlined,
                      color: Color(0xffead8a1),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        membership.isLoading ||
                                membership.hasError ||
                                profile == null
                            ? status
                            : profile.retired
                                ? 'SVIP currently unavailable'
                                : svip > 0
                                    ? 'SVIP $svip active'
                                    : 'SVIP Not Unlocked Yet',
                        style: const TextStyle(
                          color: Color(0xffead8a1),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        offer == null
                            ? 'Price unavailable'
                            : '${offer['coin_price']} coins / ${offer['duration_days']} days',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Tooltip(
                      message: profile?.canPurchase == true
                          ? 'Purchase the selected VIP tier with coins'
                          : 'VIP purchases are currently unavailable',
                      child: FilledButton(
                        onPressed: profile?.canPurchase == true &&
                                !membership.isLoading &&
                                !membership.hasError &&
                                offer != null &&
                                !_buying
                            ? () => _purchase(offer)
                            : null,
                        style: FilledButton.styleFrom(
                          disabledBackgroundColor: const Color(0xff988352),
                          disabledForegroundColor: const Color(0xff292018),
                        ),
                        child: Text(
                          _buying
                              ? 'Purchasing…'
                              : profile?.canPurchase == true
                                  ? 'Purchase'
                                  : 'Unavailable',
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _error != null
            ? Center(
                child: TextButton(
                  onPressed: _load,
                  child: const Text('Unable to load membership · Retry'),
                ),
              )
            : _assets == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(membershipStatusProvider);
                      ref.invalidate(vipOffersProvider);
                      ref.invalidate(svipThresholdsProvider);
                      ref.invalidate(nimzoMembershipMediaProvider);
                      await ref.read(membershipStatusProvider.future);
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        if (membership.hasError)
                          TextButton(
                            key: const ValueKey('willchill-membership-status'),
                            onPressed: () =>
                                ref.invalidate(membershipStatusProvider),
                            child: Text(status),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            '$status\nAppearance previews only · ${_group == 'vip' ? 'VIP artwork 1–7' : 'SVIP artwork 1–8'}; server tiers 1–10',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xffead8a1)),
                          ),
                        ),
                        if (!membership.hasError &&
                            profile != null &&
                            !profile.retired &&
                            (_group == 'vip'
                                    ? profile.vipExpiresAt
                                    : profile.svipExpiresAt) !=
                                null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Expires: ${(_group == 'vip' ? profile.vipExpiresAt : profile.svipExpiresAt)!.toUtc().toIso8601String()} UTC',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        if (profile?.canClaim == true && !membership.hasError)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(children: [
                              if (_group == 'vip' &&
                                  activeVip > 0 &&
                                  profile!.vipDailyReward != null)
                                Text(
                                    'Daily reward: ${profile.vipDailyReward} coins · Saudi time',
                                    textAlign: TextAlign.center,
                                    style:
                                        const TextStyle(color: Colors.white70)),
                              if (_group == 'svip' &&
                                  svip > 0 &&
                                  profile!.svipWeeklyReward != null)
                                Text(
                                    'Weekly reward: ${profile.svipWeeklyReward} coins · Sunday 21:00 Saudi time',
                                    textAlign: TextAlign.center,
                                    style:
                                        const TextStyle(color: Colors.white70)),
                              if (_group == 'svip' &&
                                  profile!.svipAutoEnabled &&
                                  profile.nextSvipPayout != null)
                                Text(
                                    'Next payout: ${profile.nextSvipPayout!.toUtc().toIso8601String()} UTC',
                                    textAlign: TextAlign.center,
                                    style:
                                        const TextStyle(color: Colors.white70)),
                              if (_group == 'vip' && activeVip > 0 ||
                                  _group == 'svip' &&
                                      profile!.svipWeeklyClaimable)
                                TextButton(
                                  onPressed: _claiming ||
                                          membership.isLoading ||
                                          (_group == 'vip' &&
                                              profile!.vipDailyClaimed)
                                      ? null
                                      : _claimReward,
                                  child: Text(_claiming
                                      ? 'Claiming…'
                                      : _group == 'vip' &&
                                              profile!.vipDailyClaimed
                                          ? 'Claimed today'
                                          : 'Claim reward'),
                                ),
                            ]),
                          ),
                        if (_group == 'svip' && threshold != null)
                          Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                  'SVIP $_tier threshold: USD ${(threshold / 100).toStringAsFixed(0)} in verified recharge per 90-day cycle',
                                  textAlign: TextAlign.center,
                                  style:
                                      const TextStyle(color: Colors.white70))),
                        if (_group == 'svip')
                          _svipOverview(svip, progress, liveTierMedia),
                        if (_group == 'vip')
                          _vipOverview(activeVip, liveTierMedia),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _PremiumAssetPreview extends StatefulWidget {
  const _PremiumAssetPreview({required this.asset});
  final _PremiumAsset asset;
  @override
  State<_PremiumAssetPreview> createState() => _PremiumAssetPreviewState();
}

class _PremiumAssetPreviewState extends State<_PremiumAssetPreview> {
  VapPlayerController? _vap;
  StreamSubscription<VapEvent>? _events;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.asset.mediaType == 'vap') unawaited(_startVap());
  }

  Future<void> _startVap() async {
    try {
      final controller = VapPlayerController.asset(
        widget.asset.asset,
        options: const VapPlayerOptions(
          viewType: VapViewType.textureView,
          scaleType: VapScaleType.fitCenter,
          repeatCount: 0,
          mute: false,
        ),
      );
      _vap = controller;
      _events = controller.events.listen(
        (event) {
          if (event is VapErrorEvent && mounted) {
            setState(() => _error = 'Native VAP playback failed');
          }
        },
        onError: (Object _) {
          if (mounted) setState(() => _error = 'VAP event stream failed');
        },
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() => _initialized = true);
      await controller.play();
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Unable to initialize native player');
    }
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    final controller = _vap;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff111a17),
        appBar: AppBar(
          title: Text(
            widget.asset.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: const Color(0xff192e26),
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_error != null)
                Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.white)),
                )
              else if (widget.asset.isImage)
                InteractiveViewer(
                  child: Center(
                    child: Image.asset(widget.asset.asset, fit: BoxFit.contain),
                  ),
                )
              else if (widget.asset.mediaType == 'svga')
                SVGAEasyPlayer(
                    assetsName: widget.asset.asset, fit: BoxFit.contain)
              else if (widget.asset.mediaType == 'vap' &&
                  _initialized &&
                  _vap != null)
                VapPlayer(_vap!)
              else if (widget.asset.mediaType == 'vap')
                const Center(child: CircularProgressIndicator())
              else
                const Center(
                  child: Text(
                    'Preview not available for this format',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              Positioned(
                bottom: 20,
                left: 14,
                right: 14,
                child: Text(
                  'Room entrance preview',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      );
}

class _LiveMembershipMediaPreview extends StatelessWidget {
  const _LiveMembershipMediaPreview({required this.media});
  final NimzoMembershipMedia media;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff101a15),
    appBar: AppBar(title: Text('${media.kind.toUpperCase()} ${media.tier} preview')),
    body: SafeArea(
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: CosmeticMediaView(
              key: ValueKey('live-tier-preview-${media.kind}-${media.tier}'),
              media: media.toCosmetic(),
              animate: true,
            ),
          ),
        ),
      ),
    ),
  );
}
