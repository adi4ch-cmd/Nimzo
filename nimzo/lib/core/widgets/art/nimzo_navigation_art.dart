import 'package:flutter/material.dart';

/// NIMZO's five hand-drawn navigation marks and open microphone chair.
class NimzoNavigationArt extends StatelessWidget {
  const NimzoNavigationArt(
      {super.key, required this.index, required this.color, this.size = 25});
  final int index;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: SizedBox.square(
          dimension: size, child: CustomPaint(painter: _Mark(index, color))));
}

class _Mark extends CustomPainter {
  const _Mark(this.index, this.color);
  final int index;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    void path(List<Offset> points, {bool close = false, bool fill = false}) {
      final p = Path()..addPolygon(points, close);
      paint.style = fill ? PaintingStyle.fill : PaintingStyle.stroke;
      canvas.drawPath(p, paint);
    }

    void line(double x, double y, double a, double b) =>
        path([Offset(x, y), Offset(a, b)]);
    void rect(Rect r, double radius, {bool fill = false}) {
      paint.style = fill ? PaintingStyle.fill : PaintingStyle.stroke;
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(radius)), paint);
    }

    switch (index) {
      case 0:
        path([
          const Offset(6, 10),
          const Offset(10, 13),
          const Offset(16, 5),
          const Offset(22, 13),
          const Offset(26, 10),
          const Offset(24, 21),
          const Offset(8, 21)
        ], close: true, fill: true);
        rect(const Rect.fromLTWH(5, 23, 22, 4), 2, fill: true);
        paint
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(const Offset(16, 15), 2, paint);
      case 1:
        path([const Offset(3, 24), const Offset(11, 7), const Offset(15, 25)],
            close: true);
        path([const Offset(17, 25), const Offset(22, 7), const Offset(29, 24)],
            close: true);
        line(8, 21, 12, 19);
        line(20, 19, 26, 21);
        canvas.drawCircle(const Offset(18, 4), 1.2, paint);
        line(3, 7, 6, 5);
        line(27, 5, 29, 8);
      case 2:
        paint.style = PaintingStyle.fill;
        canvas.drawOval(const Rect.fromLTWH(9, 6, 16, 20), paint);
        paint
          ..color = Colors.white
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        final orbit = Path()
          ..moveTo(5, 23)
          ..cubicTo(4, 13, 30, 7, 29, 13)
          ..cubicTo(28, 18, 11, 28, 5, 23);
        canvas.drawPath(orbit, paint);
        paint
          ..color = color
          ..strokeWidth = 1.5;
        canvas.drawPath(orbit, paint);
        line(4, 6, 4, 10);
        line(2, 8, 6, 8);
        line(27, 25, 27, 29);
        line(25, 27, 29, 27);
      case 3:
        rect(const Rect.fromLTWH(4, 6, 24, 19), 7, fill: true);
        path([const Offset(8, 23), const Offset(7, 29), const Offset(16, 24)],
            close: true, fill: true);
        paint
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        for (final x in [10.0, 16.0, 22.0]) {
          canvas.drawCircle(Offset(x, 15), 1.4, paint);
        }
      case 4:
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(const Offset(16, 9), 5, paint);
        canvas.drawPath(
            Path()
              ..moveTo(6, 26)
              ..cubicTo(6, 13, 26, 13, 26, 26)
              ..close(),
            paint);
        rect(const Rect.fromLTWH(8, 28, 16, 2), 1, fill: true);
      case 5:
        rect(const Rect.fromLTWH(8, 7, 16, 16), 5, fill: true);
        rect(const Rect.fromLTWH(4, 17, 24, 9), 3, fill: true);
        line(7, 26, 7, 29);
        line(25, 26, 25, 29);
        paint
          ..color = const Color(0xff513064)
          ..strokeWidth = 1.7;
        line(16, 11, 16, 17);
        line(13, 14, 19, 14);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Mark old) => old.index != index || old.color != color;
}
