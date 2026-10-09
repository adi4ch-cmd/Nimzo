import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'phoenix_entitlement.dart';

const phoenixRed = Color(0xffb91c32);
const phoenixGold = Color(0xffffd778);
const phoenixGradient = LinearGradient(
  colors: [Color(0xff521321), Color(0xff982039), Color(0xff381322)],
);

/// Original vector artwork; no external images or media.
class PhoenixMark extends StatelessWidget {
  final double size, spread;
  const PhoenixMark({super.key, this.size = 32, this.spread = 1});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _PhoenixPainter(spread)),
      );
}

class _PhoenixPainter extends CustomPainter {
  final double spread;
  _PhoenixPainter(this.spread);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xffffefb0), phoenixGold, Color(0xffe96332)],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
    for (final side in [-1.0, 1.0]) {
      final wing = Path()..moveTo(50, 54);
      wing.cubicTo(
        50 + side * 16,
        40,
        50 + side * 35,
        20 + 8 * (1 - spread),
        50 + side * 46,
        9 + 15 * (1 - spread),
      );
      wing.lineTo(50 + side * 37, 48);
      wing.lineTo(50 + side * 28, 37);
      wing.lineTo(50 + side * 25, 59);
      wing.lineTo(50 + side * 17, 50);
      wing.quadraticBezierTo(50 + side * 15, 72, 50, 68);
      wing.close();
      canvas.drawPath(wing, paint);
    }
    final body = Path()
      ..moveTo(47, 32)
      ..quadraticBezierTo(53, 20, 58, 34)
      ..lineTo(67, 37)
      ..lineTo(55, 42)
      ..lineTo(55, 64)
      ..quadraticBezierTo(67, 79, 62, 95)
      ..lineTo(51, 76)
      ..lineTo(40, 96)
      ..quadraticBezierTo(39, 78, 45, 63)
      ..close();
    canvas.drawPath(body, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PhoenixPainter old) => old.spread != spread;
}

class PhoenixFrame extends StatefulWidget {
  final Widget child;
  const PhoenixFrame({super.key, required this.child});
  @override
  State<PhoenixFrame> createState() => _PhoenixFrameState();
}

class _PhoenixFrameState extends State<PhoenixFrame>
    with SingleTickerProviderStateMixin {
  late final motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
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
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: motion,
          child: widget.child,
          builder: (_, child) => Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: phoenixGold),
              gradient: SweepGradient(
                transform: GradientRotation(motion.value * 2 * math.pi),
                colors: const [
                  phoenixGold,
                  phoenixRed,
                  phoenixGold,
                  Color(0xfffff1bd),
                  phoenixRed,
                  phoenixGold,
                ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                child!,
                const Positioned(
                  right: -3,
                  bottom: -3,
                  child: PhoenixMark(size: 20),
                ),
              ],
            ),
          ),
        ),
      );
}

class PhoenixBadge extends StatelessWidget {
  const PhoenixBadge({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'VIP 6 Phoenix',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: phoenixGradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: phoenixGold),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhoenixMark(size: 20),
              SizedBox(width: 4),
              Text(
                'VIP 6',
                style: TextStyle(
                  color: phoenixGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Decorates existing content only after a successful server verification.
class PhoenixDecoration extends ConsumerWidget {
  final String? userId;
  final Widget child;
  final bool avatar;
  const PhoenixDecoration({
    super.key,
    required this.userId,
    required this.child,
    this.avatar = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = userId != null &&
        ref
                .watch(phoenixEntitlementProvider(userId!))
                .asData
                ?.value
                ?.isPhoenix ==
            true;
    if (!active) return child;
    if (avatar) return PhoenixFrame(child: child);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: phoenixGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: phoenixGold),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: phoenixGold),
        child: child,
      ),
    );
  }
}

class PhoenixNameplate extends ConsumerWidget {
  final String userId, name;
  final TextStyle? style;
  const PhoenixNameplate({
    super.key,
    required this.userId,
    required this.name,
    this.style,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref
            .watch(phoenixEntitlementProvider(userId))
            .asData
            ?.value
            ?.isPhoenix ==
        true;
    if (!active)
      return Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    return Semantics(
      label: 'VIP 6 Phoenix, $name',
      child: PhoenixDecoration(
        userId: userId,
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (constraints.maxWidth <
                  180 * MediaQuery.textScalerOf(context).scale(1))
                const PhoenixMark(size: 20)
              else
                const PhoenixBadge(),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (style ?? const TextStyle()).copyWith(
                    color: phoenixGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PhoenixEntry extends StatefulWidget {
  final String name;
  const PhoenixEntry({super.key, required this.name});
  @override
  State<PhoenixEntry> createState() => _PhoenixEntryState();
}

class _PhoenixEntryState extends State<PhoenixEntry>
    with SingleTickerProviderStateMixin {
  late final motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      motion.stop();
      motion.value = .5;
    } else if (!motion.isAnimating) {
      motion.forward();
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Semantics(
          liveRegion: true,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: motion,
              builder: (_, __) {
                final reduced = MediaQuery.disableAnimationsOf(context);
                final phase = reduced ? .5 : motion.value;
                return Opacity(
                  opacity:
                      reduced ? 1 : (math.sin(phase * math.pi) * 2).clamp(0, 1),
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: phoenixGradient,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: phoenixGold),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhoenixMark(
                          size: reduced ? 56 : 72,
                          spread: .7 + .3 * math.sin(phase * math.pi),
                        ),
                        Text(
                          '${widget.name} entered · VIP 6 Phoenix',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: phoenixGold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
}
