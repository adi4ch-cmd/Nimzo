import 'package:flutter/material.dart';
import '../../core/widgets/art/nimzo_identity_art.dart';

/// UI-only unavailable state; never invents family records or membership.
class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff1b062c),
        body: DecoratedBox(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                Color(0xff270b40),
                Color(0xff541078),
                Color(0xff1b062c)
              ])),
          child: CustomPaint(
              painter: const _FamilyBackdrop(),
              child: SafeArea(
                  child: Column(children: [
                Row(children: [
                  IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.chevron_left_rounded,
                          color: Colors.white)),
                  const Expanded(
                      child: Text('Family',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xffead2ff),
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1))),
                  const SizedBox(width: 48),
                ]),
                const SizedBox(height: 36),
                const NimzoIdentityArt(
                    kind: NimzoArt.family, size: 130, color: Color(0xffc9a2e2)),
                const SizedBox(height: 20),
                const Text('All Family',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Expanded(
                    child: Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 32, horizontal: 20),
                                decoration: BoxDecoration(
                                    color: const Color(0xaa35104e),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: const Color(0xffbb8b56))),
                                child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      NimzoIdentityArt(
                                          kind: NimzoArt.mascot,
                                          size: 90,
                                          color: Color(0xffe8c6ff)),
                                      SizedBox(height: 14),
                                      Text(
                                          'Family directory is not available yet.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13)),
                                    ]))))),
                Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                    child: Tooltip(
                        message: 'Family creation is not available yet.',
                        child: OutlinedButton(
                            key: const ValueKey('family-create-unavailable'),
                            onPressed: null,
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                disabledForegroundColor:
                                    const Color(0xffc29cdd),
                                side:
                                    const BorderSide(color: Color(0xff9865bb)),
                                shape: const StadiumBorder()),
                            child: const Text('Create Family')))),
              ]))),
        ),
      );
}

class _FamilyBackdrop extends CustomPainter {
  const _FamilyBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    // Original palace silhouettes and draped curtains frame the empty state.
    for (final mirrored in [false, true]) {
      canvas.save();
      if (mirrored) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      final curtain = Path()
        ..moveTo(0, 0)
        ..lineTo(size.width * .37, 0)
        ..cubicTo(size.width * .30, size.height * .12, size.width * .13,
            size.height * .10, size.width * .08, size.height * .37)
        ..lineTo(0, size.height * .52)
        ..close();
      paint.shader = const LinearGradient(colors: [
        Color(0xff170526),
        Color(0xff762c8c),
        Color(0xff2a073a)
      ]).createShader(Rect.fromLTWH(0, 0, size.width * .37, size.height * .52));
      canvas.drawPath(curtain, paint);
      paint.shader = null;
      paint
        ..color = const Color(0xffb88c54)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(curtain, paint);
      for (var i = 0; i < 3; i++) {
        final x = 8.0 + i * 12;
        final h = size.height * (.56 + i * .05);
        final tower = Path()
          ..moveTo(x, size.height)
          ..lineTo(x, h)
          ..lineTo(x + 5, h - 17)
          ..lineTo(x + 10, h)
          ..lineTo(x + 10, size.height)
          ..close();
        paint
          ..color = const Color(0xff2c0a40)
          ..style = PaintingStyle.fill;
        canvas.drawPath(tower, paint);
        paint
          ..color = const Color(0x668b599e)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8;
        canvas.drawPath(tower, paint);
      }
      canvas.restore();
    }
    paint.style = PaintingStyle.stroke;
    for (var i = 0; i < 6; i++) {
      paint
        ..strokeWidth = 1.5
        ..color = const Color(0xffbb6ef0).withValues(alpha: .12);
      final inset = 12.0 + i * 15;
      canvas.drawPath(
          Path()
            ..moveTo(inset, 0)
            ..quadraticBezierTo(
                size.width * .5, size.height * .32, size.width - inset, 0),
          paint);
    }
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0x33dfbfff);
    for (var i = 0; i < 24; i++) {
      canvas.drawCircle(
          Offset((i * 47.0 + 17) % size.width, (i * 113.0 + 30) % size.height),
          i.isEven ? 1.5 : 1,
          paint);
    }
  }

  @override
  bool shouldRepaint(_FamilyBackdrop oldDelegate) => false;
}
