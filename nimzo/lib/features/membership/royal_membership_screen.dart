import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/providers/supabase_provider.dart';
import 'royal_membership_repository.dart';

/// Original NIMZO free-royalty presentation inspired by the user's VIP/SVIP
/// reference videos. The animated crest is native Flutter vector artwork;
/// cinematic animals, vehicles and entry VAP files are NOT bundled yet.
class RoyalMembershipScreen extends ConsumerStatefulWidget {
  final RoyalKind kind;
  const RoyalMembershipScreen({super.key, required this.kind});

  @override
  ConsumerState<RoyalMembershipScreen> createState() =>
      _RoyalMembershipScreenState();
}

class _RoyalMembershipScreenState extends ConsumerState<RoyalMembershipScreen> {
  int tier = 1;
  bool saving = false;

  static const _svipEffects = <(String, IconData)>[
    ('SVIP Tag', Icons.bookmark_outline),
    ('SVIP Badge', Icons.workspace_premium_outlined),
    ('Entry Tag', Icons.verified_outlined),
    ('Profile Card', Icons.credit_card_outlined),
    ('SVIP Frame', Icons.crop_square_outlined),
    ('Chat Bubble', Icons.chat_bubble_outline),
    ('Mic Voice Wave', Icons.graphic_eq),
    ('SVIP Entry', Icons.login),
    ('Room Theme', Icons.castle_outlined),
  ];
  static const _vipEffects = <(String, IconData)>[
    ('Avatar Frame', Icons.crop_square_outlined),
    ('Chat Bubble', Icons.chat_bubble_outline),
    ('Profile Card', Icons.credit_card_outlined),
    ('VIP Title', Icons.workspace_premium_outlined),
    ('Mic Halo', Icons.graphic_eq),
    ('Room Entrance', Icons.login),
    ('Royal Vehicle', Icons.directions_car_outlined),
    ('Nameplate', Icons.badge_outlined),
    ('Room Decor', Icons.auto_awesome_outlined),
  ];

  Future<void> activateFreeTheme(String userId) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await ref.read(freeRoyalActivationProvider).activate(widget.kind, tier);
      ref.invalidate(freeRoyalSelectionProvider(userId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${widget.kind.title}$tier selected for free'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save free membership. Check connection and update your app database.'),
        ));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = royalTheme(widget.kind, tier);
    final userId = ref.watch(currentUserIdProvider);
    final selected = userId == null
        ? null
        : ref.watch(freeRoyalSelectionProvider(userId));
    final owned = selected?.valueOrNull?.tierFor(widget.kind);
    final active = selected?.valueOrNull?.visibleTheme;
    final alreadyActive = active?.kind == widget.kind && active?.tier == tier;
    final benefits =
        widget.kind == RoyalKind.vip ? _vipEffects : _svipEffects;
    return Scaffold(
      backgroundColor: const Color(0xff0a0b12),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
              child: Row(children: [
                IconButton(
                  onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
                ),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('N I M Z O', style: TextStyle(color: Color(0xffc6b59c), fontSize: 11, letterSpacing: 4, fontWeight: FontWeight.w700)),
                    Text('ROYAL MEMBERSHIP', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                  ],
                )),
                const SizedBox(width: 48),
              ]),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(children: [
                for (final kind in RoyalKind.values)
                  Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: OutlinedButton(
                      onPressed: kind == widget.kind ? null : () => context.go(kind == RoyalKind.vip ? '/vip' : '/svip'),
                      style: OutlinedButton.styleFrom(
                        disabledForegroundColor: theme.accent,
                        foregroundColor: const Color(0xffe3d7cd),
                        side: BorderSide(color: kind == widget.kind ? theme.accent : const Color(0xff39323a)),
                        backgroundColor: kind == widget.kind ? theme.accent.withValues(alpha: .12) : const Color(0xff16151e),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(kind.title, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
                    ),
                  )),
              ]),
            )),
            SliverToBoxAdapter(child: Center(
              child: Text(theme.subtitle.toUpperCase(),
                style: TextStyle(color: theme.accent.withValues(alpha: .85), letterSpacing: 2.2, fontSize: 10, fontWeight: FontWeight.w700)),
            )),
            SliverToBoxAdapter(child: _RoyalStage(theme: theme)),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(children: [
                Text(theme.name.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 1.6, fontFamily: 'Cinzel', fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text('Select any ${widget.kind.title} theme — always free',
                    style: const TextStyle(fontSize: 12, color: Color(0xffb5a9a6))),
                const SizedBox(height: 16),
                SizedBox(
                  height: 53,
                  child: ListView.separated(
                    key: ValueKey('royal-${widget.kind.code}-selector'),
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.kind.count,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final number = index + 1;
                      final t = royalTheme(widget.kind, number);
                      return InkWell(
                        key: ValueKey('royal-theme-${widget.kind.code}-$number'),
                        onTap: () => setState(() => tier = number),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: tier == number ? t.shadow : const Color(0xff181820),
                            border: Border.all(
                              color: tier == number ? t.accent : const Color(0xff33333e),
                              width: tier == number ? 1.7 : .8,
                            ),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('${widget.kind.title}$number',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tier == number ? t.accent : const Color(0xffaaa7b3))),
                            if (owned == number)
                              const Text('OWNED', style: TextStyle(fontSize: 8, letterSpacing: 1, color: Colors.white70)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xff13131d),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: theme.accent.withValues(alpha: .35)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.diamond_outlined, color: theme.accent, size: 20),
                    const SizedBox(width: 9),
                    Text('${widget.kind.title} · ROYAL COLLECTION',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1, color: theme.accent)),
                    const Spacer(),
                    const Text('FREE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white)),
                  ]),
                  const SizedBox(height: 6),
                  const Text(
                    'Royal identity is available now. Decorative effects below are design previews; animated creature/vehicle media requires original licensed assets.',
                    style: TextStyle(color: Color(0xffa9a8b1), fontSize: 11, height: 1.5),
                  ),
                  const SizedBox(height: 15),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, mainAxisSpacing: 9, crossAxisSpacing: 9, childAspectRatio: 1.13),
                    itemCount: benefits.length,
                    itemBuilder: (_, index) {
                      final item = benefits[index];
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
                            theme.shadow.withValues(alpha: .68), const Color(0xff11121e),
                          ]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.accent.withValues(alpha: .23)),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(item.$2, size: 27, color: theme.accent),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Text(item.$1, maxLines: 2, overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text('Effects gallery · concept artwork, not installed room effects',
                    style: TextStyle(color: Color(0xff85838f), fontSize: 10)),
                ]),
              ),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(children: [
                if (selected?.hasError == true)
                  const Padding(padding: EdgeInsets.only(bottom: 8),
                    child: Text('Membership service unavailable. Database migration may be pending.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xffffab9b), fontSize: 12))),
                SizedBox(width: double.infinity, height: 53,
                  child: FilledButton(
                    key: const ValueKey('activate-free-royal'),
                    onPressed: userId == null || saving || selected?.isLoading == true || selected?.hasError == true || alreadyActive
                        ? null : () => activateFreeTheme(userId),
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor: const Color(0xff55505a),
                      backgroundColor: theme.accent,
                      foregroundColor: const Color(0xff201514),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: saving
                        ? const SizedBox(width: 23, height: 23, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(userId == null ? 'SIGN IN TO ACTIVATE'
                          : alreadyActive ? 'ACTIVE · ${widget.kind.title}$tier'
                          : 'ACTIVATE ${widget.kind.title}$tier · FREE',
                          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                  )),
                const SizedBox(height: 9),
                const Text('No coins · No diamonds · No subscription · No expiry',
                  style: TextStyle(color: Color(0xffaaa4ae), fontSize: 11)),
              ]),
            )),
          ],
        ),
      ),
    );
  }
}

class _RoyalStage extends StatefulWidget {
  final RoyalTheme theme;
  const _RoyalStage({required this.theme});

  @override
  State<_RoyalStage> createState() => _RoyalStageState();
}

class _RoyalStageState extends State<_RoyalStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 285,
    child: AnimatedBuilder(
      animation: glow,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(
            painter: _RoyalGlowPainter(
              accent: widget.theme.accent,
              shadow: widget.theme.shadow,
              phase: glow.value * math.pi * 2,
            ),
          )),
          Positioned(
            top: 41 + 5 * math.sin(glow.value * math.pi * 2),
            child: Column(children: [
              SvgPicture.asset(
                'assets/membership/${widget.theme.kind.code}_${widget.theme.tier}.svg',
                width: 135,
                height: 135,
                fit: BoxFit.contain,
                semanticsLabel: '${widget.theme.label} original royal emblem',
              ),
              const SizedBox(height: 10),
              Text(widget.theme.label, style: TextStyle(
                fontFamily: 'Cinzel', fontSize: 29,
                color: widget.theme.accent,
                shadows: [Shadow(color: widget.theme.accent.withValues(alpha: .7), blurRadius: 18)],
                fontWeight: FontWeight.w900,
              )),
              const SizedBox(height: 3),
              const Text('NIMZO ROYAL', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 3)),
            ]),
          ),
          Positioned(bottom: 32, child: Text('✦     FREE  ·  FOREVER     ✦',
            style: TextStyle(color: widget.theme.accent, fontSize: 11, letterSpacing: 2))),
        ],
      ),
    ),
  );
}

/// Animated rings, gilded crown, jewel and floating light particles.
/// This is a real native animation, not a screenshot or a fake 3D animal.
class _RoyalGlowPainter extends CustomPainter {
  final Color accent;
  final Color shadow;
  final double phase;
  const _RoyalGlowPainter({
    required this.accent, required this.shadow, required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final y = size.height * .46;
    final radius = math.min(size.width * .33, size.height * .43);
    canvas.drawCircle(Offset(x, y), radius * 1.33, Paint()
      ..shader = RadialGradient(colors: [
        shadow.withValues(alpha: .6), shadow.withValues(alpha: .12),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: Offset(x, y), radius: radius * 1.33)));
    for (var index = 0; index < 3; index++) {
      final r = radius * (.65 + index * .19);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y + 15), width: r * 2, height: r * 1.67),
        Paint()..color = accent.withValues(alpha: .32 - index * .075)
          ..style = PaintingStyle.stroke..strokeWidth = index == 0 ? 2 : 1);
    }
    for (var index = 0; index < 34; index++) {
      final a = phase * (index.isEven ? 1 : -.4) + index * 2 * math.pi / 34;
      final r = radius * (1.03 + .12 * math.sin(phase * 2 + index));
      final p = Offset(x + math.cos(a) * r, y + math.sin(a) * r * .86);
      canvas.drawCircle(p, index % 5 == 0 ? 2.6 : 1.25, Paint()..color =
          accent.withValues(alpha: .2 + .45 * (1 + math.sin(a + phase)) / 2));
    }
    final base = y - radius * .85;
    final crown = Path()
      ..moveTo(x - 49, base + 45)
      ..lineTo(x - 55, base + 2)
      ..lineTo(x - 27, base + 23)
      ..lineTo(x, base - 15)
      ..lineTo(x + 27, base + 23)
      ..lineTo(x + 55, base + 2)
      ..lineTo(x + 49, base + 45)
      ..close();
    canvas.drawPath(crown, Paint()
      ..color = accent.withValues(alpha: .18)
      ..style = PaintingStyle.fill);
    canvas.drawPath(crown, Paint()
      ..color = accent.withValues(alpha: .72)
      ..style = PaintingStyle.stroke..strokeWidth = 1.7);
    canvas.drawOval(Rect.fromCenter(center: Offset(x, size.height - 39), width: radius * 1.75, height: 33),
      Paint()..color = shadow.withValues(alpha: .8));
    canvas.drawOval(Rect.fromCenter(center: Offset(x, size.height - 42), width: radius * 1.8, height: 32),
      Paint()..color = accent.withValues(alpha: .7)..strokeWidth = 2..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _RoyalGlowPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.accent != accent;
}
