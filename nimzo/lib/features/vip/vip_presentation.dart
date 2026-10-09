import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'membership_motion.dart';

const vipPalette = [
  [Color(0xffbef264), Color(0xff4d7c0f)],
  [Color(0xff6ee7b7), Color(0xff047857)],
  [Color(0xff93c5fd), Color(0xff1d4ed8)],
  [Color(0xffc4b5fd), Color(0xff6d28d9)],
  [Color(0xfff9a8d4), Color(0xffbe185d)],
  [Color(0xfffdba74), Color(0xffc2410c)],
  [Color(0xfffca5a5), Color(0xffb91c1c)],
  [Color(0xff7dd3fc), Color(0xff6d28d9)],
  [Color(0xfff0abfc), Color(0xff7e22ce)],
  [Color(0xfffde68a), Color(0xffd97706)],
];
const svipPalette = [
  [Color(0xfffcd9a0), Color(0xff92400e)],
  [Color(0xff86efac), Color(0xff166534)],
  [Color(0xff93c5fd), Color(0xff1e40af)],
  [Color(0xfff9a8d4), Color(0xff9d174d)],
  [Color(0xfffca5a5), Color(0xff991b1b)],
  [Color(0xffa5b4fc), Color(0xff3730a3)],
  [Color(0xffd8b4fe), Color(0xff6b21a8)],
  [Color(0xfffde68a), Color(0xff92400e)],
  [Color(0xfffb7185), Color(0xff7f1d1d)],
  [Color(0xfffde047), Color(0xffa16207)],
];
const membershipGold = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xfffff4cf),
    Color(0xffe8c277),
    Color(0xffa36a2b),
    Color(0xfff7db9b),
  ],
);

class MembershipEmblem extends StatelessWidget {
  final int level;
  final bool svip, small, hero;
  final double size;
  const MembershipEmblem({
    super.key,
    required this.level,
    this.svip = false,
    this.small = false,
    this.hero = false,
    this.size = 100,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '${svip ? 'SVIP' : 'VIP'} $level official artwork',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .14),
      child: Image.asset(
        svip
            ? 'assets/membership/svip/svip_medal$level.webp'
            : 'assets/reference/vip/${level - 1}.jpg',
        width: size,
        height: size * .915,
        filterQuality: FilterQuality.high,
        fit: BoxFit.contain,
      ),
    ),
  );
}

class MembershipHero extends StatefulWidget {
  final Widget emblem;
  final String title, subtitle;
  final Color color;
  final Widget? status;
  final bool platinum;
  const MembershipHero({
    super.key,
    required this.emblem,
    required this.title,
    required this.subtitle,
    required this.color,
    this.status,
    this.platinum = false,
  });
  @override
  State<MembershipHero> createState() => _HeroState();
}

class _HeroState extends State<MembershipHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      motion.stop();
      motion.value = 0;
    } else if (!motion.isAnimating) {
      motion.repeat();
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        SizedBox(
          height: 210,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                top: -20,
                child: AnimatedBuilder(
                  animation: motion,
                  builder: (_, __) =>
                      MembershipRays(angle: motion.value * math.pi * 2),
                ),
              ),
              AnimatedBuilder(
                animation: motion,
                builder: (_, __) {
                  final pulse =
                      (1 -
                          math.cos(motion.value * math.pi * 2 * 24000 / 3200)) /
                      2;
                  return Transform.scale(
                    scale: 1 + .08 * pulse,
                    child: Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            widget.color.withValues(alpha: .38 + .22 * pulse),
                            Colors.transparent,
                          ],
                          stops: const [0, .68],
                        ),
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: motion,
                builder: (_, child) => Transform.translate(
                  offset: Offset(
                    0,
                    -3 *
                        (1 -
                            math.cos(
                              motion.value * math.pi * 2 * 24000 / 3400,
                            )),
                  ),
                  child: child,
                ),
                child: widget.emblem,
              ),
              for (final pos in [
                const Offset(.10, .30),
                const Offset(.85, .22),
                const Offset(.22, .70),
                const Offset(.78, .64),
                const Offset(.5, .08),
                const Offset(.92, .52),
                const Offset(.06, .56),
              ])
                Positioned(
                  left: pos.dx * constraints.maxWidth,
                  top: pos.dy * 300,
                  child: AnimatedBuilder(
                    animation: motion,
                    builder: (_, __) {
                      final twinkle =
                          (1 -
                              math.cos(
                                (motion.value * 24000 / 2400 + pos.dx) *
                                    math.pi *
                                    2,
                              )) /
                          2;
                      return Opacity(
                        opacity: .1 + .9 * twinkle,
                        child: Transform.scale(
                          scale: .5 + .8 * twinkle,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xfff5c451),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        if (widget.platinum)
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 29,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.8,
              color: Color(0xffe3ddff),
            ),
          )
        else
          MembershipGoldText(
            widget.title,
            style: const TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 29,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.8,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xffc4b5d4), fontSize: 13),
          ),
        ),
        if (widget.status != null) widget.status!,
      ],
    ),
  );
}

class MembershipHeading extends StatelessWidget {
  final String text;
  const MembershipHeading(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Cinzel',
        fontSize: 15,
        letterSpacing: 2,
        fontWeight: FontWeight.w800,
        color: Color(0xfff5d27a),
      ),
    ),
  );
}

class MembershipBenefit extends StatelessWidget {
  final Widget preview;
  final String title, subtitle;
  const MembershipBenefit({
    super.key,
    required this.preview,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff292038), Color(0xff171324)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xff8d7654), width: .8),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        SizedBox(width: 76, child: Center(child: preview)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xffaa9fbc)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class MembershipFrame extends StatelessWidget {
  final List<Color> colors;
  final String initial;
  const MembershipFrame({super.key, required this.colors, this.initial = 'N'});
  @override
  Widget build(BuildContext context) => Container(
    width: 58,
    height: 58,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: SweepGradient(colors: [...colors, ...colors, colors.first]),
      boxShadow: [
        BoxShadow(color: colors.first.withValues(alpha: .3), blurRadius: 14),
      ],
    ),
    child: CircleAvatar(
      backgroundColor: const Color(0xff1b1230),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}
