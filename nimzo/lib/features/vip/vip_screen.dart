import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/master_ui.dart';
import '../../core/utils/formatters.dart';
import 'vip_repository.dart';
import 'vip_progress.dart';
import 'vip_tiers.dart';
import 'vip_presentation.dart';
import 'membership_motion.dart';
import '../../core/providers/supabase_provider.dart';
import '../profile/profile_repository.dart';

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
  @override
  Widget build(BuildContext context) {
    final name = ref.watch(membershipNameProvider).valueOrNull;
    final initial = name?.trim().characters.firstOrNull ?? 'N';
    final status = ref.watch(vipStatusProvider);
    final progress =
        widget.svip ? ref.watch(svipProgressProvider).valueOrNull : null;
    final active =
        status.valueOrNull?[widget.svip ? 'svip_level' : 'vip_level'];
    final c = vipPalette[tier - 1];
    final statusLabel = status.isLoading
        ? 'Loading status…'
        : status.hasError
            ? 'Status unavailable'
            : active is num && active > 0
                ? 'Active · ${widget.svip ? 'SVIP' : 'VIP'} $active'
                : 'Status: not active';
    return Theme(
        data: Theme.of(context).copyWith(
            iconTheme: const IconThemeData(color: Colors.white),
            textTheme: Theme.of(context).textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
                fontFamily: 'Poppins')),
        child: Scaffold(
          backgroundColor: const Color(0xff0b0813),
          appBar: AppBar(
              backgroundColor: const Color(0xff24103f),
              foregroundColor: Colors.white,
              title: Text(widget.svip ? 'SVIP' : 'Nimzo VIP',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 16))),
          body: Container(
              decoration: const BoxDecoration(
                  gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.1,
                      colors: [Color(0xff3d1b73), Color(0xff0b0813)])),
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  children: widget.svip
                      ? _svip(statusLabel,
                          active is num ? active.toInt() : null, progress)
                      : [
                          MembershipHero(
                              emblem: MembershipEmblem(level: tier, size: 200),
                              title: 'VIP $tier',
                              subtitle:
                                  'Be seen. Be heard. Stand out in every room.',
                              color: c.first,
                              status: _pill(statusLabel)),
                          SizedBox(
                              height: 104,
                              child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16, horizontal: 10),
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 10),
                                  itemCount: 10,
                                  itemBuilder: (_, i) => Semantics(
                                      label: 'VIP ${i + 1}',
                                      selected: tier == i + 1,
                                      child: InkWell(
                                          key: ValueKey('vip-tier-${i + 1}'),
                                          onTap: () =>
                                              setState(() => tier = i + 1),
                                          child: AnimatedScale(
                                              scale: tier == i + 1 ? 1.22 : 1,
                                              duration: const Duration(
                                                  milliseconds: 250),
                                              child: Opacity(
                                                  opacity:
                                                      tier == i + 1 ? 1 : .6,
                                                  child: MembershipEmblem(
                                                      level: i + 1,
                                                      small: true,
                                                      size: 66))))))),
                          MembershipHeading('Your VIP $tier look'),
                          MembershipBenefit(
                              preview:
                                  MembershipFrame(colors: c, initial: initial),
                              title: 'Profile frame',
                              subtitle: 'A glowing frame around your photo'),
                          MembershipBenefit(
                              preview: MembershipAura(color: c.first),
                              title: 'Mic seat effect',
                              subtitle: 'An animated aura on your mic seat'),
                          MembershipBenefit(
                              preview: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 8),
                                  decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: c),
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                              left: Radius.circular(6),
                                              right: Radius.circular(16))),
                                  child: FittedBox(
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                        const ReferenceIcon('crown',
                                            size: 12, color: Color(0xff22112e)),
                                        Text(' VIP$tier',
                                            style: const TextStyle(
                                                color: Color(0xff22112e),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800))
                                      ]))),
                              title: 'VIP tag',
                              subtitle: 'Shown beside your name'),
                          MembershipBenefit(
                              preview: GradientText(name ?? 'Name unavailable',
                                  gradient: LinearGradient(colors: c),
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800)),
                              title: 'Nickname color',
                              subtitle: 'Your name in VIP colors'),
                          MembershipBenefit(
                              preview: Container(
                                  width: 64,
                                  height: 26,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: LinearGradient(colors: [
                                        c.last,
                                        c.first.withValues(alpha: .4)
                                      ]))),
                              title: 'List background',
                              subtitle: 'A colored row in member lists'),
                          MembershipBenefit(
                              preview: Container(
                                  width: 60,
                                  height: 44,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      gradient: RadialGradient(
                                          center: const Alignment(-.4, -.4),
                                          colors: [
                                            c.first,
                                            c.last,
                                            const Color(0xff0b0813)
                                          ]))),
                              title: 'Room theme',
                              subtitle: 'A VIP theme for your room'),
                          const MembershipBenefit(
                              preview:
                                  ReferenceIcon('up', color: Color(0xfff5c451)),
                              title: 'Rank at front',
                              subtitle: 'VIP members are listed first'),
                          if (tier >= 3)
                            const MembershipBenefit(
                                preview: ReferenceIcon('film',
                                    color: Color(0xfff5c451)),
                                title: 'Animated room theme',
                                subtitle:
                                    'Upload your own animated theme (VIP 3 and above)'),
                          const MembershipHeading('All frames'),
                          SizedBox(
                              height: 86,
                              child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: 10,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 12),
                                  itemBuilder: (_, i) => InkWell(
                                      onTap: () => setState(() => tier = i + 1),
                                      child: Column(children: [
                                        MembershipFrame(
                                            colors: vipPalette[i],
                                            initial: initial),
                                        Text('VIP${i + 1}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xffb4a6c6)))
                                      ])))),
                        ])),
          bottomNavigationBar: Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x000b0813), Color(0xff0b0813)],
                      stops: [0, .38])),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: SafeArea(
                  top: false,
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              widget.svip
                                  ? 'Recharge to upgrade'
                                  : 'Price unavailable',
                              style: const TextStyle(
                                  color: Color(0xffaa9fbc), fontSize: 12)),
                          Text(widget.svip ? 'SVIP' : 'VIP $tier',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700))
                        ])),
                    MembershipGoldButton(
                        onPressed: widget.svip
                            ? () => context.push('/recharge')
                            : () => showUiUnavailable(context, 'VIP purchase'),
                        child: Text(widget.svip
                            ? 'Recharge to upgrade'
                            : 'Get VIP $tier'))
                  ]))),
        ));
  }

  Widget _pill(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xff8d633e)),
          gradient: const LinearGradient(
              colors: [Color(0xff4a2e42), Color(0xff402039)])),
      child: Text(label, style: const TextStyle(fontSize: 12)));
  String _usd(int cents) =>
      '\$${referenceNumber(cents ~/ 100)}.${(cents % 100).toString().padLeft(2, '0')}';
  List<Widget> _svip(String status, int? level, SvipProgress? progress) => [
        MembershipHero(
            emblem: const MembershipEmblem(
                level: 10, svip: true, hero: true, size: 220),
            title: 'SVIP Privileges',
            subtitle: 'More recharge, higher level, more privileges',
            color: const Color(0xfffbbf24)),
        _features(const [
          ('bolt', 'Instant upgrade'),
          ('gift', 'Weekly coins'),
          ('clock', '90 days validity'),
          ('crown', '10 sections')
        ], 4),
        Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xff21182e),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xff675139))),
            child: Column(children: [
              Row(children: [
                const Expanded(child: Text('Your SVIP')),
                _pill(status)
              ]),
              const SizedBox(height: 10),
              Semantics(
                  label: progress == null
                      ? 'Recharge progress unavailable'
                      : 'Recorded recharge ${_usd(progress.cycleCents)}',
                  child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                          color: const Color(0xff3a3047),
                          borderRadius: BorderRadius.circular(4)),
                      child: progress == null
                          ? null
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                  widthFactor: progress.fraction ?? 0,
                                  child: Container(
                                      decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                              colors: [
                                                Color(0xfff59e0b),
                                                Color(0xffec4899)
                                              ]),
                                          borderRadius:
                                              BorderRadius.circular(4))))))),
              const SizedBox(height: 8),
              Text(
                  progress == null
                      ? 'Recharge progress unavailable · your level comes from the backend'
                      : 'Recorded cycle recharge: ${_usd(progress.cycleCents)} · ${progress.nextThresholdCents == null ? 'highest configured threshold reached' : 'next SVIP ${progress.nextLevel}: ${_usd(progress.nextThresholdCents!)}'}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xffaa9fbc)))
            ])),
        const MembershipHeading('Privileges'),
        _features(const [
          ('crown', 'SVIP Level'),
          ('star', 'Exclusive Icon'),
          ('gift', 'Gift Banner'),
          ('user', 'Channel Admin'),
          ('medal', 'Customized Medal'),
          ('spark', 'Shining Title'),
          ('idc', 'Letter ID'),
          ('mount', 'Exclusive Mounts'),
          ('shield', 'Unban Account')
        ], 3),
        const MembershipHeading('Levels'),
        for (var i = 0; i < 10; i++)
          Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: svipPalette[i].first),
                  gradient: RadialGradient(
                      center: const Alignment(-.8, 0),
                      radius: 1.4,
                      colors: [
                        svipPalette[i].last.withValues(alpha: .5),
                        const Color(0xff120b24)
                      ])),
              child: Stack(children: [
                Row(children: [
                  MembershipEmblem(level: i + 1, svip: true, size: 90),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        MembershipGoldText('SVIP ${i + 1}',
                            style: const TextStyle(
                                fontFamily: 'Cinzel',
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(
                            'Total recharge  \$${NimzoVipTiers.svipRechargeUsd[i]}',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xfffcd34d))),
                        Text(
                            '${compactNumber(NimzoVipTiers.svipRechargeUsd[i] * 500000)} coins',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xffb4a6c6))),
                        Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                gradient: membershipGold,
                                borderRadius: BorderRadius.circular(14)),
                            child: Text(
                                'Weekly +${compactNumber(NimzoVipTiers.svipWeeklyCoins[i])} coins',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xff2a1100),
                                    fontWeight: FontWeight.w800))),
                        Text(
                            'All SVIP1${i == 0 ? '' : '-${i + 1}'} privileges · 90 days',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xffb4a6c6)))
                      ]))
                ]),
                if (level != null && i == level)
                  Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 2),
                          decoration: BoxDecoration(
                              color: const Color(0xfff5c451),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text('NEXT',
                              style: TextStyle(
                                  color: Color(0xff2a1100),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800))))
              ])),
        const MembershipHeading('Important rules'),
        for (final rule in const [
          (
            'bolt',
            'Instant upgrade',
            'Upgrade as soon as total recharge reaches the next level.'
          ),
          (
            'clock',
            '90 days validity',
            'Each level is valid for 90 days from activation.'
          ),
          (
            'gift',
            'Weekly coins reward',
            'Every Sunday at 9:00 PM (Saudi Arabia time).'
          ),
          (
            'up',
            'Level maintenance',
            'Your level is based on your total recharge.'
          )
        ])
          MembershipBenefit(
              preview: ReferenceIcon(rule.$1, color: const Color(0xfff5c451)),
              title: rule.$2,
              subtitle: rule.$3),
      ];
  Widget _features(List<(String, String)> items, int columns) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: .95,
          children: [
            for (final item in items)
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xff21182e),
                      border: Border.all(color: const Color(0xff3c3049)),
                      borderRadius: BorderRadius.circular(14)),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ReferenceIcon(item.$1,
                            color: const Color(0xfff5c451), size: 22),
                        const SizedBox(height: 6),
                        Text(item.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11))
                      ]))
          ]));
}
