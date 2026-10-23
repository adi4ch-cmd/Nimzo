import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/widgets/master_ui.dart';
import '../../core/theme/app_theme.dart';
import 'profile_repository.dart';
import 'profile_screen.dart';
import 'profile_level_scale.dart';
import 'verified_level_up_tracker.dart';

/// Tingle-reference wealth/charm/activity presentation with NIMZO data.
/// Level, earned progress and the next threshold remain server-derived.
class LevelsScreen extends ConsumerStatefulWidget {
  final int initialKind;
  final String? userId;
  const LevelsScreen({super.key, this.initialKind = 0, this.userId})
      : assert(initialKind >= 0 && initialKind < 3);

  @override
  ConsumerState<LevelsScreen> createState() => _LevelState();
}

class _LevelState extends ConsumerState<LevelsScreen> {
  late int selected;
  Timer? _refreshTimer;
  final _verifiedUpdates = VerifiedLevelUpTracker();

  @override
  void initState() {
    super.initState();
    selected = widget.initialKind;
    // The existing profile provider is a FutureProvider, not a live stream.
    // Poll only while this screen is visible; every response is read from
    // authoritative Supabase counters and never grants XP from the client.
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      final id = widget.userId ?? ref.read(currentUserIdProvider);
      if (id != null) ref.invalidate(profileProvider(id));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _showVerifiedIncrease(VerifiedLevelIncrease upgrade) {
    if (!mounted) return;
    final title = tabs[upgrade.kind];
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xff152143),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('LEVEL UP!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xffffda72),
                fontSize: 26, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: LevelBadge(kind: upgrade.kind, level: upgrade.to)),
            const SizedBox(height: 18),
            Text('$title Level ${upgrade.to}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white,
                    fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text('Level ${upgrade.from} → ${upgrade.to}',
                style: const TextStyle(color: Color(0xffd1d9eb))),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continue',
                  style: TextStyle(color: Color(0xffffda72)))),
        ],
      ),
    );
  }

  static const bands = <({int from, int to, String label, Color color})>[
    (from: 1, to: 20, label: 'Brown', color: Color(0xffa16207)),
    (from: 21, to: 39, label: 'Green', color: Color(0xff16a34a)),
    (from: 40, to: 59, label: 'Blue', color: Color(0xff2563eb)),
    (from: 60, to: 79, label: 'Pink', color: Color(0xffdb2777)),
    (from: 80, to: 99, label: 'Red', color: Color(0xffdc2626)),
    (from: 100, to: 270, label: 'Gold', color: Color(0xffd4a017)),
  ];
  static const tabs = <String>['Wealth', 'Charm', 'Active'];
  static const icons = <IconData>[
    Icons.workspace_premium_rounded,
    Icons.favorite_rounded,
    Icons.flash_on_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final id = widget.userId ?? ref.watch(currentUserIdProvider);
    final label = tabs[selected];
    return Scaffold(
      backgroundColor: const Color(0xfff7f5ff),
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Level',
            style: TextStyle(
                color: Color(0xff2e233c),
                fontSize: 14,
                fontWeight: FontWeight.w900)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (id == null) return;
          ref.invalidate(profileProvider(id));
          await ref.read(profileProvider(id).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(23)),
              child: Row(children: [
                for (var tab = 0; tab < 3; tab++)
                  Expanded(
                      child: InkWell(
                    key: ValueKey('level-tab-$tab'),
                    onTap: () => setState(() => selected = tab),
                    borderRadius: BorderRadius.circular(19),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          gradient: selected == tab
                              ? const LinearGradient(colors: [
                                  Color(0xffa546f0),
                                  Color(0xff7236c8)
                                ])
                              : null,
                          borderRadius: BorderRadius.circular(19)),
                      child: Text(tabs[tab],
                          style: TextStyle(
                              fontSize: 12,
                              color: selected == tab
                                  ? Colors.white
                                  : const Color(0xff8e829f),
                              fontWeight: FontWeight.w800)),
                    ),
                  )),
              ]),
            ),
            const SizedBox(height: 16),
            if (id == null)
              const EmptyContent('Please sign in to see your level.')
            else
              AsyncContent(
                value: ref.watch(profileProvider(id)),
                onRetry: () => ref.invalidate(profileProvider(id)),
                builder: (p) {
                  final verifiedLevels = [
                    p.wealthLevel, p.charmLevel, p.activeLevel,
                  ];
                  final verifiedIncreases = _verifiedUpdates.observe(
                    id, verifiedLevels,
                  );
                  if (id == ref.read(currentUserIdProvider) &&
                      verifiedIncreases.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _showVerifiedIncrease(verifiedIncreases.first);
                    });
                  }
                  final level = [
                    p.wealthLevel,
                    p.charmLevel,
                    p.activeLevel,
                  ][selected];
                  final earned = [
                    p.wealthCoins,
                    p.charmDiamonds,
                    p.activePoints,
                  ][selected];
                  final progress = earned == null || level <= 0
                      ? null
                      : ProfileLevelScale.fraction(selected, level, earned);
                  final next = earned == null || level < 0 || level >= ProfileLevelScale.maxLevels[selected]
                      ? null
                      : (ProfileLevelScale.nextRequirement(selected, level) -
                              earned)
                          .clamp(0, 1 << 62);
                  final band = bands
                      .where((b) => level >= b.from && level <= b.to)
                      .firstOrNull;
                  return Column(children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 18),
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xff101b3c),
                                Color(0xff203769),
                                Color(0xff344978),
                              ]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x285b2a99),
                                blurRadius: 18,
                                offset: Offset(0, 7)),
                          ]),
                      child: Column(children: [
                        Container(
                          height: 99,
                          width: 99,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: const Color(0x24ffffff),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0x88ffffff), width: 2)),
                          child: LevelBadge(kind: selected, level: level),
                        ),
                        const SizedBox(height: 10),
                        Text('$label Level',
                            style: const TextStyle(
                                color: Color(0xfff2deff),
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(level > 0 ? 'Lv. $level' : 'Level unavailable',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 7),
                        Text(band?.label ?? 'Tier unavailable',
                            style: const TextStyle(
                                color: Color(0xffffe6ab),
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 23),
                        if (progress != null)
                          LinearProgressIndicator(
                              key: const ValueKey('verified-level-progress'),
                              value: progress,
                              minHeight: 9,
                              borderRadius: BorderRadius.circular(20),
                              backgroundColor: const Color(0x57ffffff),
                              color: const Color(0xffffd95f)),
                        const SizedBox(height: 13),
                        Text(
                            earned == null
                                ? 'Verified progress unavailable'
                                : '${referenceNumber(earned)} '
                                    '${ProfileLevelScale.units[selected]}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                        if (progress == null)
                          const Text('Maximum tier or unavailable',
                              style: TextStyle(
                                  color: Color(0xffefdeff), fontSize: 12)),
                        if (next != null)
                          Text('${referenceNumber(next)} to the next level',
                              style: const TextStyle(
                                  color: Color(0xffefdeff), fontSize: 12)),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ]);
                },
              ),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(23),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                leading: const Icon(Icons.sports_esports_rounded,
                    color: NimzoStyle.primary, size: 29),
                title: const Text('Game Level',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Verified settled-game experience',
                    style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/game-level'),
              ),
            ),
            const SizedBox(height: 24),
            Text('$label level collection',
                style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xff2b243c),
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
              'Original Falla level tags: Wealth/Charm 0–270, Active 0–140. Unlocked from verified progress.',
              style: TextStyle(color: Color(0xff84798e), fontSize: 12),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selected == 2 ? 141 : 271,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.18,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
              ),
              itemBuilder: (context, index) => Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(child: LevelBadge(kind: selected, level: index)),
                      const SizedBox(height: 5),
                      Text('Lv. $index',
                        style: const TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Level color bands',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            for (final band in bands)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xffede8f5))),
                child: Row(children: [
                  Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: band.color.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(15)),
                      child:
                          Icon(icons[selected], color: band.color, size: 27)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Text(band.label,
                          key: ValueKey('level-band-${band.label}'),
                          style: const TextStyle(
                              color: Color(0xff433850),
                              fontWeight: FontWeight.w800,
                              fontSize: 14))),
                  Text('Lv. ${band.from}–${band.to > ProfileLevelScale.maxLevels[selected] ? ProfileLevelScale.maxLevels[selected] : band.to}',
                      style: const TextStyle(
                          color: Color(0xff83798e),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            const SizedBox(height: 15),
            Container(
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.all(18),
              child: Text(
                [
                  'Wealth grows from coins sent in verified gifts.',
                  'Charm grows from diamonds received in verified gifts.',
                  'Active grows from recorded activity points.',
                ][selected],
                style: const TextStyle(color: Color(0xff84798e), height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
