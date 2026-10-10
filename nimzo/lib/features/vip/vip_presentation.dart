// ignore_for_file: prefer_interpolation_to_compose_strings
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
        label: (svip ? 'SVIP ' : 'VIP ') + level.toString() + ' membership medal',
        child: svip
            ? ClipRRect(
                borderRadius: BorderRadius.circular(size * .14),
                child: Image.asset(
                  'assets/membership/svip/svip_medal' + level.toString() + '.webp',
                  width: size,
                  height: size * .915,
                  filterQuality: FilterQuality.high,
                  fit: BoxFit.contain,
                ),
              )
            : NimzoRoyalVipSeal(level: level, size: size),
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
                      final pulse = (1 -
                              math.cos(
                                  motion.value * math.pi * 2 * 24000 / 3200)) /
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
                                widget.color
                                    .withValues(alpha: .38 + .22 * pulse),
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
                          final twinkle = (1 -
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
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xffaa9fbc)),
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
            BoxShadow(
                color: colors.first.withValues(alpha: .3), blurRadius: 14),
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


/// New NIMZO-only vector medal; the obsolete reference VIP JPG is never read.
/// Emerald/metal finish is retained across all ten normal VIP tiers.
class NimzoRoyalVipSeal extends StatelessWidget {
  const NimzoRoyalVipSeal({super.key,required this.level,this.size=100});
  final int level;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width:size,height:size,
    child: Stack(alignment:Alignment.center,children:[
      CustomPaint(
        size:Size.square(size),
        painter:_NimzoRoyalSealPainter(level),
      ),
      Positioned(
        bottom:size*.17,
        child: Text('VIP ' + level.toString(),
          style:TextStyle(
            fontSize:size*.13,
            color:const Color(0xffffebba),
            fontWeight:FontWeight.w800,
            letterSpacing:1,
          ),
        ),
      ),
    ]),
  );
}

class _NimzoRoyalSealPainter extends CustomPainter {
  const _NimzoRoyalSealPainter(this.level);
  final int level;
  @override
  void paint(Canvas canvas,Size size){
    final s=math.min(size.width,size.height);
    canvas.save();
    canvas.translate(size.width/2,size.height/2);
    canvas.scale(s/100);
    final light=Color.lerp(
      const Color(0xff74e8aa),
      const Color(0xffeed28d),
      (level-1)/9,
    )!;
    final outer=Paint()..shader=SweepGradient(
      colors:[const Color(0xff6c4620),light,const Color(0xffffdf98),
        const Color(0xff956025),const Color(0xff6c4620)],
    ).createShader(const Rect.fromLTWH(-48,-48,96,96));
    canvas.drawCircle(Offset.zero,47,outer);
    canvas.drawCircle(Offset.zero,40,Paint()..color=const Color(0xff042c23));
    canvas.drawCircle(Offset.zero,38,Paint()
      ..color=light.withValues(alpha:.5)
      ..style=PaintingStyle.stroke..strokeWidth=1.8);
    for(var i=0;i<12;i++){
      final a=i*math.pi/6;
      canvas.drawCircle(Offset(math.cos(a)*43,math.sin(a)*43),1.15,
        Paint()..color=const Color(0xffffe0a5));
    }
    final crown=Path()
      ..moveTo(-25,-5)..lineTo(-28,-26)..lineTo(-13,-15)
      ..lineTo(0,-34)..lineTo(13,-15)..lineTo(28,-26)
      ..lineTo(25,-5)..close();
    canvas.drawPath(crown,Paint()..shader=const LinearGradient(
      colors:[Color(0xffa86822),Color(0xfffff0b6),Color(0xffe6ad46)],
      begin:Alignment.topLeft,end:Alignment.bottomRight,
    ).createShader(const Rect.fromLTWH(-30,-35,60,33)));
    canvas.drawRect(const Rect.fromLTWH(-25,-4,50,8),
      Paint()..color=const Color(0xffae7225));
    canvas.drawCircle(const Offset(0,-13),4.8,
      Paint()..color=light);
    canvas.drawCircle(const Offset(0,-13),2.2,
      Paint()..color=Colors.white);
    canvas.restore();
  }
  @override
  bool shouldRepaint(_NimzoRoyalSealPainter old)=>old.level!=level;
}
