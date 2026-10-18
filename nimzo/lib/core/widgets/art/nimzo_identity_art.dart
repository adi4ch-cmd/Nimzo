import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Original NIMZO vector illustrations. No downloaded premium artwork, glyphs,
/// ownership state or entitlement behavior is embedded in these decorations.
enum NimzoArt {
  crest,
  frame,
  card,
  bubble,
  entrance,
  gift,
  live,
  party,
  privacy,
  reward,
  mascot,
  discount,
  contact,
  invisible,
  vehicle,
  portrait,
  theme,
  shield,
  defense,
  nickname,
  heart,
  family
}

class NimzoIdentityArt extends StatelessWidget {
  const NimzoIdentityArt(
      {super.key,
      required this.kind,
      this.color = const Color(0xffc9a4ff),
      this.variant = 0,
      this.size = 64,
      this.progress = 1});
  final NimzoArt kind;
  final Color color;
  final int variant;
  final double size, progress;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
              painter: _IdentityPainter(kind, color, variant, progress))));
}

class _IdentityPainter extends CustomPainter {
  const _IdentityPainter(this.kind, this.color, this.variant, this.progress);
  final NimzoArt kind;
  final Color color;
  final int variant;
  final double progress;
  static const gold = Color(0xffffd98e);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final ink = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void shape(Path path,
        {Color? fill, bool stroke = false, double width = 2}) {
      ink
        ..shader = null
        ..color = fill ?? color
        ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = width;
      canvas.drawPath(path, ink);
    }

    void line(List<Offset> points, Color c, [double width = 2]) {
      final p = Path()..addPolygon(points, false);
      shape(p, fill: c, stroke: true, width: width);
    }

    void oval(Rect rect, Color c, {bool stroke = false, double width = 2}) {
      ink
        ..shader = null
        ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = width
        ..color = c;
      canvas.drawOval(rect, ink);
    }

    void box(Rect rect, double radius, Color c, {bool stroke = false}) {
      ink
        ..shader = null
        ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 2
        ..color = c;
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radius)), ink);
    }

    void star(double x, double y, double r, {Color c = gold, int rays = 4}) {
      final p = Path();
      for (var i = 0; i < rays * 2; i++) {
        final a = i * math.pi / rays - math.pi / 2;
        final d = i.isEven ? r : r * .32;
        final o = Offset(x + math.cos(a) * d, y + math.sin(a) * d);
        if (i == 0) {
          p.moveTo(o.dx, o.dy);
        } else {
          p.lineTo(o.dx, o.dy);
        }
      }
      shape(p..close(), fill: c);
    }

    void gem(double x, double y, double r) {
      shape(
          Path()
            ..moveTo(x, y - r)
            ..lineTo(x + r * .75, y - r * .25)
            ..lineTo(x + r * .55, y + r * .55)
            ..lineTo(x, y + r)
            ..lineTo(x - r * .55, y + r * .55)
            ..lineTo(x - r * .75, y - r * .25)
            ..close(),
          fill: color);
      line([
        Offset(x, y - r),
        Offset(x - r * .24, y),
        Offset(x, y + r),
        Offset(x + r * .3, y),
        Offset(x, y - r)
      ], Colors.white.withValues(alpha: .6), 1);
      line([
        Offset(x - r * .75, y - r * .25),
        Offset(x - r * .24, y),
        Offset(x + r * .3, y),
        Offset(x + r * .75, y - r * .25)
      ], gold, .8);
    }

    void heart(double x, double y, double r) {
      final p = Path()
        ..moveTo(x, y + r)
        ..cubicTo(x - r * 2, y - r * .1, x - r * .8, y - r * 1.7, x, y - r * .5)
        ..cubicTo(x + r * .8, y - r * 1.7, x + r * 2, y - r * .1, x, y + r)
        ..close();
      shape(p, fill: color);
      shape(p, fill: gold, stroke: true, width: 1.3);
      line([Offset(x - r * .7, y - r * .15), Offset(x - r * .4, y - r * .48)],
          Colors.white70, 2.5);
    }

    void crown(double y) {
      shape(
          Path()
            ..moveTo(28, y)
            ..lineTo(32, y + 17)
            ..lineTo(68, y + 17)
            ..lineTo(72, y)
            ..lineTo(59, y + 8)
            ..lineTo(50, y - 6)
            ..lineTo(41, y + 8)
            ..close(),
          fill: gold);
      box(Rect.fromLTWH(33, y + 18, 34, 5), 2, color);
      for (final x in [28.0, 50.0, 72.0]) {
        oval(
            Rect.fromCircle(
                center: Offset(x, y + (x == 50 ? -6 : 0)), radius: 2.5),
            Colors.white);
      }
      gem(50, y + 8, 5);
    }

    void wings() {
      for (final mirror in [-1, 1]) {
        canvas.save();
        canvas.translate(50, 50);
        canvas.scale(mirror.toDouble(), 1);
        for (var i = 0; i < 5; i++) {
          final p = Path()
            ..moveTo(12, 8 + i * 3)
            ..quadraticBezierTo(32, 2 - i * 4, 47 - i * 3, -22 + i * 6)
            ..quadraticBezierTo(44 - i * 3, 4 + i * 5, 20, 24 - i * 2)
            ..close();
          shape(p, fill: Color.lerp(gold, color, i / 6));
          shape(p,
              fill: Colors.white.withValues(alpha: .35),
              stroke: true,
              width: .7);
        }
        canvas.restore();
      }
    }

    void crest({bool frame = false}) {
      final themed = frame && variant % 7 != 0 && variant % 7 != 6;
      if (!themed) wings();
      final ring = Rect.fromCircle(center: const Offset(50, 52), radius: 28);
      ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..shader = SweepGradient(
                colors: [gold, color, Colors.white, gold, color, gold],
                transform: GradientRotation(variant * .45))
            .createShader(ring);
      canvas.drawOval(ring, ink);
      ink.shader = null;
      oval(Rect.fromCircle(center: const Offset(50, 52), radius: 23),
          const Color(0xff281337));
      oval(Rect.fromCircle(center: const Offset(50, 52), radius: 21), gold,
          stroke: true, width: .8);
      if (!frame) {
        gem(50, 53, 17);
      }
      if (themed) {
        for (var i = 0; i < 10; i++) {
          final a = i * math.pi / 5 - math.pi / 2;
          final x = 50 + math.cos(a) * 32;
          final y = 52 + math.sin(a) * 32;
          switch (variant % 7) {
            case 1:
            case 5:
              heart(x, y, i.isEven ? 5 : 3);
            case 2:
              for (var petal = 0; petal < 5; petal++) {
                final angle = petal * math.pi * 2 / 5;
                oval(
                    Rect.fromCircle(
                        center: Offset(
                            x + math.cos(angle) * 3, y + math.sin(angle) * 3),
                        radius: 2.8),
                    color);
              }
              oval(Rect.fromCircle(center: Offset(x, y), radius: 1.7), gold);
            case 4:
              canvas.save();
              canvas.translate(x, y);
              canvas.rotate(a);
              shape(
                  Path()
                    ..moveTo(-5, 0)
                    ..quadraticBezierTo(0, -9, 6, 0)
                    ..quadraticBezierTo(0, 5, -5, 0)
                    ..close(),
                  fill: color);
              line([const Offset(-4, 0), const Offset(4, 0)], gold, .7);
              canvas.restore();
            default:
              star(x, y, i.isEven ? 5 : 2, c: color);
          }
        }
        star(50, 15, 7);
      } else {
        crown(15);
        shape(
            Path()
              ..moveTo(27, 78)
              ..lineTo(50, 71)
              ..lineTo(73, 78)
              ..lineTo(67, 88)
              ..lineTo(50, 84)
              ..lineTo(33, 88)
              ..close(),
            fill: gold);
        for (var i = 0; i < 3; i++) {
          star(42 + i * 8, 79, 2, c: color);
        }
        star(18, 23, 3);
        star(83, 67, 4);
        star(13, 66, 2, c: color);
      }
    }

    void mascot() {
      oval(const Rect.fromLTWH(20, 77, 62, 9), color.withValues(alpha: .15));
      oval(const Rect.fromLTWH(24, 17, 17, 30), color);
      oval(const Rect.fromLTWH(58, 17, 17, 30), color);
      oval(const Rect.fromLTWH(27, 21, 10, 20), gold);
      oval(const Rect.fromLTWH(61, 21, 10, 20), gold);
      ink
        ..shader = RadialGradient(
                colors: [Colors.white, color],
                center: const Alignment(-.3, -.5))
            .createShader(const Rect.fromLTWH(17, 31, 67, 48))
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(17, 31, 67, 48), const Radius.circular(23)),
          ink);
      ink.shader = null;
      for (final x in [38.0, 63.0]) {
        oval(Rect.fromCircle(center: Offset(x, 52), radius: 3.5),
            const Color(0xff352345));
        oval(Rect.fromCircle(center: Offset(x - 1, 51), radius: 1),
            Colors.white);
        oval(Rect.fromCenter(center: Offset(x - 5, 61), width: 9, height: 4),
            const Color(0xffed94bf));
      }
      shape(
          Path()
            ..moveTo(46, 61)
            ..quadraticBezierTo(50, 67, 55, 61),
          fill: const Color(0xff553064),
          stroke: true);
      star(78, 24, 6);
      star(14, 45, 3);
      heart(51, 78, 9);
    }

    // A soft halo gives the vector the same legibility on light/dark previews.
    ink
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(colors: [
        color.withValues(alpha: .22),
        color.withValues(alpha: 0)
      ]).createShader(const Rect.fromLTWH(0, 0, 100, 100));
    canvas.drawCircle(const Offset(50, 50), 49, ink);
    ink.shader = null;
    switch (kind) {
      case NimzoArt.crest:
      case NimzoArt.reward:
        crest();
      case NimzoArt.frame:
        crest(frame: true);
      case NimzoArt.family:
        wings();
        shape(
            Path()
              ..moveTo(25, 42)
              ..lineTo(50, 24)
              ..lineTo(75, 42)
              ..lineTo(70, 79)
              ..lineTo(30, 79)
              ..close(),
            fill: color);
        shape(
            Path()
              ..moveTo(25, 42)
              ..lineTo(50, 24)
              ..lineTo(75, 42)
              ..lineTo(70, 79)
              ..lineTo(30, 79)
              ..close(),
            fill: gold,
            stroke: true);
        for (final x in [38.0, 50.0, 62.0]) {
          box(Rect.fromLTWH(x - 3, 45, 6, 25), 3, const Color(0xff361147));
        }
        crown(14);
        star(50, 86, 7);
      case NimzoArt.mascot:
      case NimzoArt.portrait:
        mascot();
      case NimzoArt.heart:
        heart(50, 48, 29);
        wings();
        crown(10);
      case NimzoArt.entrance:
      case NimzoArt.vehicle:
        final shift =
            (1 - Curves.easeOutCubic.transform(progress.clamp(0, 1))) * 50;
        canvas.translate(-shift, 0);
        oval(const Rect.fromLTWH(10, 75, 83, 9), color.withValues(alpha: .2));
        for (var i = 0; i < 4; i++) {
          line([Offset(3, 43 + i * 7), Offset(20 + i * 3, 43 + i * 7)],
              color.withValues(alpha: .3), 2);
        }
        shape(
            Path()
              ..moveTo(21, 57)
              ..lineTo(35, 37)
              ..quadraticBezierTo(57, 29, 70, 43)
              ..lineTo(80, 53)
              ..lineTo(91, 59)
              ..lineTo(87, 71)
              ..lineTo(18, 71)
              ..lineTo(14, 61)
              ..close(),
            fill: color);
        shape(
            Path()
              ..moveTo(38, 40)
              ..lineTo(32, 53)
              ..lineTo(72, 53)
              ..lineTo(65, 42)
              ..close(),
            fill: const Color(0xff25203f));
        line([const Offset(51, 39), const Offset(51, 53)], gold, 2);
        line([const Offset(20, 58), const Offset(80, 58)], gold, 1.5);
        for (final x in [32.0, 75.0]) {
          oval(Rect.fromCircle(center: Offset(x, 71), radius: 8),
              const Color(0xff221f32));
          oval(Rect.fromCircle(center: Offset(x, 71), radius: 4), gold);
        }
        star(80, 29, 6);
        star(15, 38, 3);
        gem(54, 22, 9);
      case NimzoArt.card:
      case NimzoArt.contact:
      case NimzoArt.nickname:
        box(const Rect.fromLTWH(12, 25, 77, 53), 9, color);
        box(const Rect.fromLTWH(16, 29, 69, 45), 6, gold, stroke: true);
        oval(Rect.fromCircle(center: const Offset(33, 48), radius: 11),
            const Color(0xff352344));
        gem(33, 48, 7);
        for (var i = 0; i < 3; i++) {
          line([Offset(52, 42 + i * 10), Offset(75 - i * 5, 42 + i * 10)],
              Colors.white70, 2);
        }
        star(79, 22, 7);
        star(18, 81, 4);
      case NimzoArt.bubble:
        final p = Path()
          ..moveTo(18, 28)
          ..lineTo(79, 28)
          ..quadraticBezierTo(90, 28, 90, 40)
          ..lineTo(90, 63)
          ..quadraticBezierTo(90, 73, 79, 73)
          ..lineTo(39, 73)
          ..lineTo(20, 85)
          ..lineTo(23, 73)
          ..quadraticBezierTo(11, 73, 11, 60)
          ..lineTo(11, 40)
          ..quadraticBezierTo(11, 28, 18, 28)
          ..close();
        shape(p, fill: color);
        shape(p, fill: gold, stroke: true);
        for (var i = 0; i < 3; i++) {
          star(33 + i * 18, 50, 5, c: Colors.white);
        }
        crown(9);
      case NimzoArt.gift:
        box(const Rect.fromLTWH(22, 44, 56, 40), 5, color);
        box(const Rect.fromLTWH(17, 36, 66, 14), 4, gold);
        box(const Rect.fromLTWH(46, 36, 9, 48), 1, gold);
        for (final sign in [-1, 1]) {
          shape(
              Path()
                ..moveTo(50, 36)
                ..cubicTo(50 + sign * 45, 20, 50 + sign * 10, 5, 50, 36),
              fill: color,
              stroke: true,
              width: 5);
        }
        star(15, 21, 5);
        star(86, 65, 5);
      case NimzoArt.live:
      case NimzoArt.party:
      case NimzoArt.theme:
        box(const Rect.fromLTWH(13, 20, 75, 62), 8, color);
        box(const Rect.fromLTWH(18, 25, 65, 52), 5, const Color(0xff2c1844));
        for (var i = 0; i < 5; i++) {
          line([Offset(26 + i * 12, 62), Offset(26 + i * 12, 45 - (i % 3) * 7)],
              gold, 4);
        }
        if (kind == NimzoArt.live) {
          crown(12);
        } else {
          gem(51, 32, 13);
        }
        star(13, 19, 7);
        star(89, 81, 6);
      case NimzoArt.invisible:
      case NimzoArt.privacy:
      case NimzoArt.shield:
      case NimzoArt.defense:
        shape(
            Path()
              ..moveTo(50, 13)
              ..lineTo(80, 27)
              ..lineTo(76, 60)
              ..quadraticBezierTo(72, 77, 50, 89)
              ..quadraticBezierTo(28, 77, 24, 60)
              ..lineTo(20, 27)
              ..close(),
            fill: color);
        shape(
            Path()
              ..moveTo(50, 20)
              ..lineTo(73, 31)
              ..lineTo(70, 59)
              ..quadraticBezierTo(66, 72, 50, 80)
              ..quadraticBezierTo(34, 72, 30, 59)
              ..lineTo(27, 31)
              ..close(),
            fill: gold,
            stroke: true);
        if (kind == NimzoArt.invisible) {
          oval(const Rect.fromLTWH(32, 40, 36, 20), const Color(0xff312142));
          gem(50, 50, 7);
        } else if (kind == NimzoArt.privacy) {
          oval(const Rect.fromLTWH(40, 36, 20, 25), gold,
              stroke: true, width: 4);
          box(const Rect.fromLTWH(35, 48, 30, 22), 4, const Color(0xff312142));
          oval(Rect.fromCircle(center: const Offset(50, 58), radius: 3), gold);
        } else {
          line([
            const Offset(36, 51),
            const Offset(46, 61),
            const Offset(65, 40)
          ], Colors.white, 5);
        }
        star(82, 18, 5);
      case NimzoArt.discount:
        shape(
            Path()
              ..moveTo(18, 25)
              ..lineTo(65, 25)
              ..lineTo(88, 50)
              ..lineTo(65, 78)
              ..lineTo(18, 78)
              ..close(),
            fill: color);
        oval(Rect.fromCircle(center: const Offset(32, 41), radius: 6), gold,
            stroke: true, width: 3);
        oval(Rect.fromCircle(center: const Offset(58, 63), radius: 6), gold,
            stroke: true, width: 3);
        line([const Offset(33, 67), const Offset(58, 36)], Colors.white, 4);
        star(83, 22, 5);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IdentityPainter old) =>
      old.kind != kind ||
      old.color != color ||
      old.variant != variant ||
      old.progress != progress;
}
