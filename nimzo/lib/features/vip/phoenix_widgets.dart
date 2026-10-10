import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'phoenix_entitlement.dart';

const phoenixRed = Color(0xff0d8967);
const phoenixGold = Color(0xffffd778);
const phoenixGradient = LinearGradient(
  colors: [Color(0xff08362a), Color(0xff136149), Color(0xff082c24)],
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

/// The retired red-wing VIP artwork has been replaced with a NIMZO crown.
class _PhoenixPainter extends CustomPainter {
  final double spread;
  _PhoenixPainter(this.spread);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final crown = Path()
      ..moveTo(12, 37)
      ..lineTo(12, 14 + 6 * (1 - spread))
      ..lineTo(34, 32)
      ..lineTo(50, 7)
      ..lineTo(66, 32)
      ..lineTo(88, 14 + 6 * (1 - spread))
      ..lineTo(88, 69)
      ..lineTo(12, 69)
      ..close();
    const bounds = Rect.fromLTWH(10, 8, 80, 63);
    canvas.drawPath(crown, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors:[Color(0xffab6c23),Color(0xffffe9a7),Color(0xffc88730)],
      ).createShader(bounds));
    canvas.drawPath(crown, Paint()
      ..color = const Color(0xffffeac0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12,67,76,15),
        const Radius.circular(6)),
      Paint()..color = const Color(0xff0e583e));
    canvas.drawCircle(const Offset(50,48),10,
      Paint()..color = const Color(0xff35dfa9));
    canvas.drawCircle(const Offset(50,46),4,
      Paint()..color = Colors.white);
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
        label: 'VIP 6 Royal Lion',
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
      label: 'VIP 6 Royal Lion, $name',
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
                          '${widget.name} entered · VIP 6 Royal Lion',
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
