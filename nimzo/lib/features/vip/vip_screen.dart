import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/master_ui.dart';
import '../../core/utils/formatters.dart';
import '../../core/providers/supabase_provider.dart';
import '../profile/profile_repository.dart';
import 'vip_repository.dart';
import 'vip_tiers.dart';
import 'vip_presentation.dart';
import 'phoenix_widgets.dart';
import 'membership_motion.dart';

final membershipNameProvider = FutureProvider<String?>((ref) async {
  final id = ref.watch(currentUserIdProvider);
  if (id == null) return null;
  final profile = await ref.watch(profileProvider(id).future);
  return profile.displayName ?? profile.username;
});

class VipScreen extends ConsumerStatefulWidget {
  final bool svip;
  const VipScreen({super.key, this.svip = false});
  @override
  ConsumerState<VipScreen> createState() => _VipState();
}

class _VipState extends ConsumerState<VipScreen> {
  int tier = 5;
  bool _selectedFromMembership = false;
  Color get accent =>
      widget.svip ? const Color(0xffdedaff) : const Color(0xffe8c277);
  String get family => widget.svip ? 'SVIP' : 'VIP';
  @override
  Widget build(BuildContext context) {
    final status = ref.watch(vipStatusProvider);
    final progress =
        widget.svip ? ref.watch(svipProgressProvider).valueOrNull : null;
    final active =
        status.valueOrNull?[widget.svip ? 'svip_level' : 'vip_level'];
    // Default to the verified live membership once, without overriding
    // the user's subsequent manual selection of preview tiers.
    if (!_selectedFromMembership &&
        active is num &&
        active >= 1 &&
        active <= 10) {
      _selectedFromMembership = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => tier = active.toInt());
      });
    }
    final statusLabel = status.isLoading
        ? 'Loading membership…'
        : status.hasError
            ? 'Membership unavailable'
            : active is num && active > 0
                ? 'Active · $family $active'
                : 'No active $family membership';
    final threshold = progress?.thresholdFor(tier);
    final configured = widget.svip && threshold != null;
    final name = ref.watch(membershipNameProvider).valueOrNull;
    return Theme(
        data: Theme.of(context).copyWith(
            iconTheme: const IconThemeData(color: Colors.white),
            textTheme: Theme.of(context).textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
                fontFamily: 'Poppins')),
        child: Scaffold(
          backgroundColor:
              widget.svip ? const Color(0xff0d0919) : const Color(0xff0e0c09),
          appBar: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: accent,
              title: Text(
                  widget.svip
                      ? 'SVIP · Diamond collection'
                      : 'VIP · Royal collection',
                  style: TextStyle(fontSize: 15, color: accent)),
              centerTitle: true),
          body: Container(
              decoration: BoxDecoration(
                  gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.1,
                      colors: widget.svip
                          ? const [
                              Color(0xff372349),
                              Color(0xff160e24),
                              Color(0xff0d0919)
                            ]
                          : const [
                              Color(0xff49351a),
                              Color(0xff21190e),
                              Color(0xff0e0c09)
                            ])),
              child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          children: [
                            MembershipHero(
                                platinum: widget.svip,
                                emblem: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: MembershipEmblem(
                                        key: ValueKey('$family-$tier'),
                                        level: tier,
                                        svip: widget.svip,
                                        size: 176)),
                                title: '$family $tier',
                                subtitle: widget.svip
                                    ? 'THE DIAMOND COLLECTION'
                                    : 'THE ROYAL COLLECTION',
                                color: accent,
                                status: _pill(statusLabel)),
                            const SizedBox(height: 22),
                            _selector(),
                            const SizedBox(height: 18),
                            _panel(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(
                                            '$family $tier · Collection preview',
                                            style: TextStyle(
                                                color: accent,
                                                fontWeight: FontWeight.w600))),
                                    _pill(configured
                                        ? 'Configured tier'
                                        : 'Preview')
                                  ]),
                                  const SizedBox(height: 12),
                                  Text(
                                      widget.svip
                                          ? configured
                                              ? 'Recorded threshold: ${_usd(threshold)}'
                                              : 'Reference recharge: ${_usd(NimzoVipTiers.svipRechargeUsd[tier - 1] * 100)}'
                                          : 'Reference price: ${compactNumber(NimzoVipTiers.normalVipCoins[tier - 1])} coins',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Text(
                                      widget.svip
                                          ? 'Artwork is available for all 10 tiers. Live membership supports 8 tiers; tiers 9–10 are design previews.'
                                          : 'Reference pricing and appearance only. Purchase and cosmetic activation are not enabled here.',
                                      style: const TextStyle(
                                          color: Color(0xffbcb2c4),
                                          fontSize: 12)),
                                ])),
                            if (widget.svip) ...[
                              const MembershipHeading('Your recharge progress'),
                              _panel(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(
                                        progress == null
                                            ? 'Recharge progress unavailable'
                                            : 'Recorded cycle · ${_usd(progress.cycleCents)}',
                                        style: TextStyle(color: accent)),
                                    const SizedBox(height: 14),
                                    ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: LinearProgressIndicator(
                                            value: progress?.fraction ?? 0,
                                            minHeight: 7,
                                            color: accent,
                                            backgroundColor:
                                                const Color(0xff35283e))),
                                    const SizedBox(height: 12),
                                    Text(
                                        progress == null
                                            ? 'Sign in and connect to retrieve your server membership.'
                                            : progress.nextLevel == null
                                                ? 'Highest configured threshold reached.'
                                                : 'Next configured level: SVIP ${progress.nextLevel} · ${_usd(progress.nextThresholdCents!)}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xffbcb2c4))),
                                  ])),
                            ],
                            MembershipHeading('Your $family $tier look'),
                            _panel(
                                child: Row(children: [
                              MembershipEmblem(
                                  level: tier, svip: widget.svip, size: 80),
                              const SizedBox(width: 18),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(name ?? 'Your membership identity',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    Text('Original $family $tier artwork',
                                        style: TextStyle(color: accent)),
                                    const SizedBox(height: 6),
                                    Text(
                                        active is num &&
                                                active == tier &&
                                                !widget.svip
                                            ? 'Active VIP identity · server verified'
                                            : 'Visual preview · cosmetics are not activated',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xffbcb2c4)))
                                  ]))
                            ])),
                            if (!widget.svip && tier == 6) ...[
                              const MembershipHeading('Phoenix · VIP 6'),
                              const MembershipBenefit(
                                  preview: PhoenixFrame(
                                      child: CircleAvatar(child: Text('N'))),
                                  title: 'Phoenix identity',
                                  subtitle:
                                      'Animated red and gold frame, VIP badge and premium nameplate.'),
                              const MembershipBenefit(
                                  preview: PhoenixMark(size: 58),
                                  title: 'Phoenix room entrance',
                                  subtitle:
                                      'Original animated wings and a VIP 6 entry announcement.'),
                              const MembershipBenefit(
                                  preview: PhoenixBadge(),
                                  title: 'Premium conversations',
                                  subtitle:
                                      'Phoenix chat bubbles and gift tray with active membership.'),
                            ],
                            const MembershipHeading('Membership details'),
                            MembershipBenefit(
                                preview: MembershipEmblem(
                                    level: tier,
                                    svip: widget.svip,
                                    small: true,
                                    size: 54),
                                title: 'Exclusive identity',
                                subtitle:
                                    'Explore the supplied collection. Previewing does not change your membership.'),
                            if (widget.svip)
                              const MembershipBenefit(
                                  preview: ReferenceIcon('gift',
                                      color: Color(0xffdedaff)),
                                  title: 'Friday rewards',
                                  subtitle:
                                      'Rewards and eligibility come from the live server. Reference weekly amounts are not guaranteed payouts.'),
                            MembershipBenefit(
                                preview: ReferenceIcon('shield', color: accent),
                                title: 'Server verified membership',
                                subtitle:
                                    'Your active level, expiry and enabled benefits are decided by the server.'),
                          ])))),
          bottomNavigationBar: SafeArea(
              top: false,
              child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                          child: SizedBox(
                              width: double.infinity,
                              child: widget.svip
                                  ? FilledButton(
                                      style: FilledButton.styleFrom(
                                          backgroundColor: accent,
                                          foregroundColor:
                                              const Color(0xff20132f),
                                          padding: const EdgeInsets.all(17)),
                                      onPressed: () =>
                                          context.push('/recharge'),
                                      child:
                                          const Text('View recharge options'))
                                  : MembershipGoldButton(
                                      onPressed: () => showUiUnavailable(
                                          context, 'VIP purchase'),
                                      child: Text(
                                          'Preview VIP $tier · Purchase unavailable'))))))),
        ));
  }

  Widget _selector() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('EXPLORE THE COLLECTION',
                  style: TextStyle(
                      color: accent, fontSize: 11, letterSpacing: 1.7))),
          Text('01 — 10', style: TextStyle(color: accent, fontSize: 11))
        ]),
        const SizedBox(height: 12),
        SizedBox(
            height: 108,
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 10,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => Semantics(
                    label: '$family ${i + 1}',
                    selected: tier == i + 1,
                    button: true,
                    child: InkWell(
                        key: ValueKey(
                            '${widget.svip ? 'svip' : 'vip'}-tier-${i + 1}'),
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() {
                              _selectedFromMembership = true;
                              tier = i + 1;
                            }),
                        child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: 84,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: tier == i + 1
                                    ? accent.withValues(alpha: .13)
                                    : Colors.black26,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: tier == i + 1
                                        ? accent
                                        : accent.withValues(alpha: .15))),
                            child: Column(children: [
                              MembershipEmblem(
                                  level: i + 1,
                                  svip: widget.svip,
                                  small: true,
                                  size: 59),
                              const SizedBox(height: 5),
                              Text('$family ${i + 1}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: tier == i + 1
                                          ? accent
                                          : const Color(0xffbcb2c4)))
                            ])))))),
      ]);
  Widget _panel({required Widget child}) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: .25))),
      child: child);
  Widget _pill(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: accent.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: .3))),
      child: Text(label, style: TextStyle(color: accent, fontSize: 10)));
  String _usd(int cents) =>
      '\$${referenceNumber(cents ~/ 100)}.${(cents % 100).toString().padLeft(2, '0')}';
}
