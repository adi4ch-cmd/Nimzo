import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/widgets/master_ui.dart';

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
    colors: [Color(0xfffff3b0), Color(0xfff5c451), Color(0xffd9951b)]);

class MembershipEmblem extends StatelessWidget {
  final int level;
  final bool svip, small, hero;
  final double size;
  const MembershipEmblem(
      {super.key,
      required this.level,
      this.svip = false,
      this.small = false,
      this.hero = false,
      this.size = 100});
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
      'assets/reference/emblems/${hero ? 'svip_hero' : '${svip ? 'svip' : 'vip'}_$level${small ? '_small' : ''}'}.svg',
      width: size,
      height: size * .915);
}

class MembershipHero extends StatefulWidget {
  final Widget emblem;
  final String title, subtitle;
  final Color color;
  final Widget? status;
  const MembershipHero(
      {super.key,
      required this.emblem,
      required this.title,
      required this.subtitle,
      required this.color,
      this.status});
  @override
  State<MembershipHero> createState() => _HeroState();
}

class _HeroState extends State<MembershipHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3400))
    ..repeat(reverse: true);
  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
            height: 210,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        widget.color.withValues(alpha: .4),
                        Colors.transparent
                      ]))),
              AnimatedBuilder(
                  animation: motion,
                  builder: (_, child) => Transform.translate(
                      offset: Offset(0, -6 * motion.value), child: child),
                  child: widget.emblem),
              for (final pos in [
                const Offset(.10, .30),
                const Offset(.85, .22),
                const Offset(.22, .70),
                const Offset(.78, .64),
                const Offset(.5, .08)
              ])
                Positioned(
                    left: pos.dx * 280,
                    top: pos.dy * 190,
                    child:
                        Icon(Icons.auto_awesome, size: 8, color: widget.color)),
            ])),
        GradientText(widget.title,
            gradient: membershipGold,
            style: const TextStyle(
                fontFamily: 'Cinzel',
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 2)),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(widget.subtitle,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Color(0xffc4b5d4), fontSize: 13))),
        if (widget.status != null) widget.status!,
      ]);
}

class MembershipHeading extends StatelessWidget {
  final String text;
  const MembershipHeading(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 15,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
              color: Color(0xfff5d27a))));
}

class MembershipBenefit extends StatelessWidget {
  final Widget preview;
  final String title, subtitle;
  const MembershipBenefit(
      {super.key,
      required this.preview,
      required this.title,
      required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: const Color(0xff150d29),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xff73513b))),
      child: Row(children: [
        SizedBox(width: 76, child: Center(child: preview)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xffaa9fbc)))
        ]))
      ]));
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
            BoxShadow(color: colors.first.withValues(alpha: .3), blurRadius: 14)
          ]),
      child: CircleAvatar(
          backgroundColor: const Color(0xff1b1230),
          child: Text(initial,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800))));
}
