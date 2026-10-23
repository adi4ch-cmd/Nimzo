import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/services/nimzo_content_sync.dart';
import 'membership_catalog.dart';
import 'membership_pack_gallery.dart';
import 'membership_media_view.dart';
import 'membership_status.dart';
import 'membership_purchase_keys.dart';
import '../wallet/wallet_screen.dart';
import '../profile/profile_repository.dart';

final membershipStatusProvider =
    FutureProvider.autoDispose<MembershipStatus?>((ref) async {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return null;
  final result = await session.client
      .rpc('vip_status')
      .timeout(const Duration(seconds: 6));
  return result is Map
      ? MembershipStatus.fromJson(Map<String, dynamic>.from(result))
      : null;
});

final membershipOffersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return [];
  ref.watch(nimzoContentRevisionsProvider);
  final rows = await session.client
      .from('normal_vip_catalog')
      .select('tier,coin_price,duration_days')
      .order('tier');
  return rows.map((row) => Map<String, dynamic>.from(row)).toList();
});
final membershipThresholdsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(sessionSupabaseProvider);
  if (session.userId == null) return [];
  ref.watch(nimzoContentRevisionsProvider);
  final rows = await session.client
      .from('svip_thresholds')
      .select('level,usd_cents')
      .order('level');
  return rows.map((row) => Map<String, dynamic>.from(row)).toList();
});

/// A new server-driven membership destination. The historical route/class name
/// remains for navigation compatibility; no legacy privilege tiles are used.
class WillChillPremiumScreen extends ConsumerStatefulWidget {
  const WillChillPremiumScreen({super.key, this.initialGroup = 'svip'});
  final String initialGroup;
  @override
  ConsumerState<WillChillPremiumScreen> createState() =>
      _WillChillPremiumScreenState();
}

class _WillChillPremiumScreenState extends ConsumerState<WillChillPremiumScreen>
    with WidgetsBindingObserver {
  late String _group = widget.initialGroup == 'vip' ? 'vip' : 'svip';
  int _tier = 1;
  bool _buying = false, _claiming = false;
  Timer? _statusRefresh;
  String? _verifiedHero, _verifiedBadge;
  static const emerald = Color(0xff141a30), gold = Color(0xfff6d38a);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _statusRefresh =
        Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusRefresh?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    ref.invalidate(membershipStatusProvider);
    ref.invalidate(membershipPresentationsProvider);
    ref.invalidate(membershipOffersProvider);
    ref.invalidate(membershipThresholdsProvider);
  }

  Future<void> _purchase(Map<String, dynamic> offer) async {
    if (_buying) return;
    final session = ref.read(sessionSupabaseProvider);
    final status = ref.read(membershipStatusProvider).valueOrNull;
    if (session.userId == null || status?.canPurchase != true) return;
    final tier = (offer['tier'] as num).toInt();
    final preferences = await SharedPreferences.getInstance();
    final keys = MembershipPurchaseKeys(preferences);
    final expectedCoins = keys.pendingPrice(session.userId!, tier) ??
        (offer['coin_price'] as num).toInt();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Purchase VIP $tier?'),
        content: Text(
          '$expectedCoins coins for ${offer['duration_days']} days. '
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
      final key =
          await keys.prepareWithPrice(session.userId!, tier, expectedCoins);
      if (!mounted ||
          ref.read(sessionSupabaseProvider).userId != session.userId) return;
      final result = await session.client.rpc(
        'nimzo_purchase_vip_checked',
        params: {
          'p_tier': tier,
          'p_key': key,
          'p_expected_coins': expectedCoins
        },
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
        ref.invalidate(membershipOffersProvider);
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
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(membershipStatusProvider);
    final status = statusAsync.valueOrNull;
    final presentations = ref.watch(membershipPresentationsProvider);
    final bundled = ref.watch(membershipBundledPresentationsProvider);
    final offersAsync = ref.watch(membershipOffersProvider);
    final thresholdsAsync = ref.watch(membershipThresholdsProvider);
    final offers = offersAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final thresholds =
        thresholdsAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final catalog = _group == 'vip' ? offers : thresholds;
    final tiers = catalog
        .map((row) => (row[_group == 'vip' ? 'tier' : 'level'] as num).toInt())
        .toList();
    final matches =
        (presentations.valueOrNull ?? const <MembershipPresentation>[])
            .where((row) => row.kind == _group && row.tier == _tier);
    final fallbacks = (bundled.valueOrNull ?? const <MembershipPresentation>[])
        .where((row) => row.kind == _group && row.tier == _tier);
    final presentation = !presentations.hasError &&
            !presentations.isLoading &&
            matches.isNotEmpty
        ? matches.first
        : fallbacks.isEmpty
            ? null
            : fallbacks.first;
    final offerRows = offers.where((row) => row['tier'] == _tier);
    final offer = offerRows.isEmpty ? null : offerRows.first;
    final thresholdRows = thresholds.where((row) => row['level'] == _tier);
    final threshold = thresholdRows.isEmpty
        ? null
        : (thresholdRows.first['usd_cents'] as num).toInt();
    final owned = (_group == 'vip' ? status?.vipLevel : status?.svipLevel) ?? 0;
    final expiry =
        _group == 'vip' ? status?.vipExpiresAt : status?.svipExpiresAt;
    final ready =
        status != null && !statusAsync.isLoading && !statusAsync.hasError;
    final presentationReady = presentation?.hero != null &&
        presentation?.badge != null &&
        _verifiedHero == presentation!.hero!.sha256 &&
        _verifiedBadge == presentation.badge!.sha256;
    final canBuy = ready &&
        status.canPurchase &&
        presentationReady &&
        !offersAsync.isLoading &&
        !offersAsync.hasError &&
        offer != null &&
        !_buying;
    final label = _group.toUpperCase();
    return Scaffold(
      backgroundColor: const Color(0xff0b1021),
      appBar: AppBar(
          title: const Text('NIMZO Membership'),
          centerTitle: true,
          backgroundColor: emerald,
          foregroundColor: Colors.white),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
              key: const ValueKey('membership-fixed-status'),
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xffdce8df)))),
              child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                        _group == 'vip'
                            ? offer == null
                                ? 'Price unavailable'
                                : '${offer['coin_price']} coins · ${offer['duration_days']} days'
                            : owned > 0
                                ? 'SVIP $owned active'
                                : 'Unlock with verified recharge',
                        style: const TextStyle(
                            color: emerald, fontWeight: FontWeight.w700)),
                    if (_group == 'vip')
                      FilledButton(
                          onPressed: canBuy ? () => _purchase(offer) : null,
                          style:
                              FilledButton.styleFrom(backgroundColor: emerald),
                          child: Text(_buying
                              ? 'Purchasing…'
                              : canBuy
                                  ? 'Purchase VIP $_tier'
                                  : 'Unavailable')),
                    if (_group == 'svip')
                      FilledButton(
                          onPressed: ready && !status.retired
                              ? () => context.push('/recharge')
                              : null,
                          style:
                              FilledButton.styleFrom(backgroundColor: emerald),
                          child: const Text('Recharge')),
                  ]))),
      body: RefreshIndicator(
          onRefresh: () async {
            _refresh();
            await ref.read(membershipStatusProvider.future);
          },
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<String>(
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? emerald
                              : gold),
                      backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? gold
                              : const Color(0xff1a223a)),
                      side: WidgetStateProperty.all(
                          const BorderSide(color: Color(0xff806e49))),
                    ),
                    segments: const [
                      ButtonSegment(
                          value: 'vip',
                          label: Text('VIP'),
                          icon: Icon(Icons.workspace_premium)),
                      ButtonSegment(
                          value: 'svip',
                          label: Text('SVIP'),
                          icon: Icon(Icons.auto_awesome)),
                    ],
                    selected: {_group},
                    onSelectionChanged: (selection) => setState(() {
                          _group = selection.first;
                          _tier = 1;
                        })),
                const SizedBox(height: 18),
                Card(
                    color: emerald,
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('YOUR MEMBERSHIP',
                                  style: TextStyle(
                                      color: gold,
                                      letterSpacing: 2,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              Text(
                                  statusAsync.isLoading
                                      ? 'Checking membership…'
                                      : statusAsync.hasError
                                          ? 'Membership status unavailable'
                                          : status == null
                                              ? 'Sign in to view membership'
                                              : status.retired
                                                  ? 'Membership unavailable'
                                                  : owned == 0
                                                      ? 'Discover $label'
                                                      : '$label $owned',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800)),
                              if (ready && expiry != null && owned > 0)
                                Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text('Expires ${expiry.toLocal()}',
                                        style: const TextStyle(
                                            color: Colors.white70))),
                              if (statusAsync.hasError)
                                TextButton(
                                    onPressed: _refresh,
                                    child: const Text('Retry',
                                        style: TextStyle(color: gold))),
                              if (ready &&
                                  _group == 'svip' &&
                                  threshold != null &&
                                  threshold > 0) ...[
                                const SizedBox(height: 14),
                                LinearProgressIndicator(
                                    value: (status.cycleCents / threshold)
                                        .clamp(0.0, 1.0),
                                    color: gold,
                                    backgroundColor: Colors.white24),
                                const SizedBox(height: 8),
                                Text(
                                    'USD ${(status.cycleCents / 100).toStringAsFixed(2)} / ${(threshold / 100).toStringAsFixed(2)} verified recharge',
                                    style:
                                        const TextStyle(color: Colors.white70)),
                              ],
                            ]))),
                const SizedBox(height: 18),
                Text('Choose your $label tier',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: gold)),
                const SizedBox(height: 10),
                if (tiers.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(20),
                      child:
                          Text('Tier catalog unavailable. Pull to refresh.')),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  for (final tier in tiers)
                    ChoiceChip(
                        label: Text('$label $tier'),
                        selected: tier == _tier,
                        backgroundColor: const Color(0xff1a223a),
                        labelStyle: TextStyle(
                            color: tier == _tier ? emerald : Colors.white,
                            fontWeight: FontWeight.w700),
                        side: BorderSide(
                            color:
                                tier == _tier ? gold : const Color(0xff3c4560)),
                        onSelected: (_) => setState(() => _tier = tier),
                        selectedColor: gold)
                ]),
                const SizedBox(height: 14),
                if (presentation != null)
                  _presentation(presentation, owned)
                else
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(children: [
                            const Icon(Icons.workspace_premium_outlined,
                                color: emerald, size: 56),
                            const SizedBox(height: 10),
                            Text('$label $_tier',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                    color: emerald)),
                            const SizedBox(height: 8),
                            const Text('Tier artwork is currently unavailable.',
                                textAlign: TextAlign.center),
                          ]))),
                if (ready && status.canClaim && owned > 0) _reward(status),
                const SizedBox(height: 14),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                            _group == 'vip'
                                ? 'VIP uses your coin balance. Renewing the same active tier extends its expiry. Changing tier starts a new cycle. The server confirms the final price and entitlement.'
                                : 'SVIP follows verified Google Play or App Store recharge in a 90-day cycle. Only confirmed purchases count; the server determines your tier and expiry.',
                            style: const TextStyle(
                                height: 1.5, color: Color(0xff395448))))),
              ])),
    );
  }

  Widget _presentation(MembershipPresentation row, int owned) {
    final benefits = row.benefits;
    return Card(
        clipBehavior: Clip.antiAlias,
        color: Colors.white,
        child: Column(children: [
          SizedBox(
              height: 280,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                const DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xff10172d), Color(0xff25203b)]))),
                if (row.card != null)
                  MembershipMediaView(
                      key: ValueKey('card:${row.card!.sha256}'),
                      media: row.card!,
                      fit: BoxFit.cover),
                DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                      Colors.black.withValues(alpha: .08),
                      Colors.black.withValues(alpha: .10),
                      Colors.black.withValues(alpha: .28)
                    ]))),
                Center(
                    child: SizedBox(
                        height: 230,
                        width: 230,
                        child: row.hero == null
                            ? const Icon(Icons.workspace_premium,
                                size: 80, color: gold)
                            : MembershipMediaView(
                                key: ValueKey(row.hero!.sha256),
                                media: row.hero!,
                                onReady: () {
                                  if (mounted)
                                    setState(
                                        () => _verifiedHero = row.hero!.sha256);
                                },
                                onUnavailable: () {
                                  if (mounted)
                                    setState(() => _verifiedHero = null);
                                }))),
              ])),
          Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                if (row.badge != null)
                  SizedBox(
                      height: 42,
                      child: MembershipMediaView(
                          key: ValueKey(row.badge!.sha256),
                          media: row.badge!,
                          onReady: () {
                            if (mounted)
                              setState(
                                  () => _verifiedBadge = row.badge!.sha256);
                          },
                          onUnavailable: () {
                            if (mounted) setState(() => _verifiedBadge = null);
                          })),
                const SizedBox(height: 12),
                Text(
                    row.title.isEmpty
                        ? '${row.kind.toUpperCase()} ${row.tier}'
                        : row.title,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: emerald)),
                Text(owned == row.tier ? 'Your active tier' : 'Tier details',
                    style: const TextStyle(color: Color(0xff668273))),
                const SizedBox(height: 10),
                TextButton.icon(
                  key: ValueKey('membership-view-set-${row.kind}-${row.tier}'),
                  icon: const Icon(Icons.grid_view_rounded),
                  label: Text('View ${row.kind.toUpperCase()} ${row.tier} set'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: const Color(0xff0d1430),
                    builder: (_) => SizedBox(
                      height: MediaQuery.sizeOf(context).height * .84,
                      child: MembershipPackGallery(presentation: row),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (benefits.contains('badge') && row.badge != null)
                  _benefit(Icons.verified_outlined, 'Membership badge',
                      'Shown with your server-verified membership.'),
                if (benefits.contains('room_entry'))
                  _benefit(Icons.door_front_door_outlined, 'Room welcome',
                      'Appears after your confirmed room join.'),
                if (benefits.contains('daily_reward') && row.kind == 'vip')
                  _benefit(Icons.savings_outlined, 'Daily coin reward',
                      'Claim amount and eligibility are checked by the server.'),
                if (benefits.contains('weekly_reward') && row.kind == 'svip')
                  _benefit(Icons.savings_outlined, 'Weekly coin reward',
                      'Sunday 21:00 Saudi time, subject to server eligibility.'),
                if (row.entrance != null && benefits.contains('room_entry'))
                  TextButton.icon(
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Preview entrance'),
                      onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => SafeArea(
                              child: SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height * .7,
                                  child: MembershipMediaView(
                                      media: row.entrance!, animate: true))))),
              ])),
        ]));
  }

  Widget _benefit(IconData icon, String title, String description) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: emerald),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(description));

  Widget _reward(MembershipStatus status) {
    final vip = _group == 'vip';
    final amount = vip ? status.vipDailyReward : status.svipWeeklyReward;
    final canClaim = vip ? !status.vipDailyClaimed : status.svipWeeklyClaimable;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              Text(
                  '${vip ? 'Daily' : 'Weekly'} reward${amount == null ? '' : ' · $amount coins'}',
                  style: const TextStyle(
                      color: emerald,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
              if (!vip &&
                  status.svipAutoEnabled &&
                  status.nextSvipPayout != null)
                Text(
                    'Next automatic payout: ${status.nextSvipPayout!.toLocal()}',
                    textAlign: TextAlign.center),
              TextButton(
                  onPressed: !_claiming && canClaim ? _claimReward : null,
                  child: Text(_claiming
                      ? 'Claiming…'
                      : vip && status.vipDailyClaimed
                          ? 'Claimed today'
                          : canClaim
                              ? 'Claim reward'
                              : 'No claim available')),
            ])));
  }
}
