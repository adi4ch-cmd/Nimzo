import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/widgets/master_ui.dart';
import 'vip_presentation.dart';

class MembershipRays extends StatelessWidget {
  final double angle;
  const MembershipRays({super.key, required this.angle});
  @override
  Widget build(BuildContext context) => Transform.rotate(
      angle: angle,
      child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const RadialGradient(
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, .18, .68]).createShader(rect),
          child: const SizedBox.square(
              dimension: 320, child: CustomPaint(painter: _RayPainter()))));
}

class _RayPainter extends CustomPainter {
  const _RayPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..color = const Color(0x3df5c451);
    for (var i = 0; i < 18; i++)
      canvas.drawArc(rect, i * math.pi / 9, 7 * math.pi / 180, true, paint);
  }

  @override
  bool shouldRepaint(_RayPainter oldDelegate) => false;
}

class MembershipAura extends StatefulWidget {
  final Color color;
  const MembershipAura({super.key, required this.color});
  @override
  State<MembershipAura> createState() => _AuraState();
}

class _AuraState extends State<MembershipAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat();
  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: motion,
      builder: (_, __) {
        final pulse = (1 - math.cos(motion.value * math.pi * 2)) / 2;
        return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff1b1230),
                boxShadow: [
                  BoxShadow(color: widget.color, spreadRadius: 3 + 3 * pulse),
                  BoxShadow(color: widget.color, blurRadius: 16 + 12 * pulse)
                ]),
            child: const ReferenceIcon('mic', color: Colors.white));
      });
}

class MembershipGoldText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const MembershipGoldText(this.text, {super.key, required this.style});
  @override
  State<MembershipGoldText> createState() => _GoldTextState();
}

class _GoldTextState extends State<MembershipGoldText>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();
  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: motion,
      builder: (_, __) => ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
                      colors: const [
                    Color(0xffb97a14),
                    Color(0xfffff7c2),
                    Color(0xfff5c451),
                    Color(0xffb97a14)
                  ],
                      stops: const [
                    .15,
                    .4,
                    .5,
                    .8
                  ],
                      begin: Alignment(-1 + motion.value * 4.4, -.34),
                      end: Alignment(3.4 + motion.value * 4.4, .34),
                      tileMode: TileMode.repeated)
                  .createShader(rect),
          child: Text(widget.text,
              style: widget.style.copyWith(color: Colors.white))));
}

class MembershipGoldButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const MembershipGoldButton(
      {super.key, required this.onPressed, required this.child});
  @override
  State<MembershipGoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<MembershipGoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800))
    ..repeat();
  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration:
          BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [
        BoxShadow(
            color: const Color(0xfff5c451).withValues(alpha: .35),
            blurRadius: 24,
            offset: const Offset(0, 8))
      ]),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(children: [
            GradientButton(
                gradient: membershipGold,
                foreground: const Color(0xff3b2200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                onPressed: widget.onPressed,
                child: widget.child),
            Positioned.fill(
                child: IgnorePointer(
                    child: AnimatedBuilder(
                        animation: motion,
                        builder: (_, __) =>
                            CustomPaint(painter: _SheenPainter(motion.value)))))
          ])));
}

class _SheenPainter extends CustomPainter {
  final double phase;
  const _SheenPainter(this.phase);
  @override
  void paint(Canvas canvas, Size size) {
    final left = (-.6 + phase * 1.9) * size.width;
    final rect = Rect.fromLTWH(left, 0, size.width * .4, size.height);
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment(-1, -.2),
              end: Alignment(1, .2),
              colors: [
                Colors.transparent,
                Color(0xbfffffff),
                Colors.transparent
              ]).createShader(rect));
  }

  @override
  bool shouldRepaint(_SheenPainter old) => old.phase != phase;
}
