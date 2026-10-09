import 'package:flutter/material.dart';

class AuthBackdrop extends StatelessWidget {
  final Widget child;
  const AuthBackdrop({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment(-.34, -1),
        end: Alignment(.34, 1),
        colors: [Color(0xff5b21b6), Color(0xffc026d3), Color(0xffec4899)],
        stops: [0, .65, 1],
      ),
    ),
    child: Stack(
      children: [
        Positioned(right: -90, top: -70, child: _circle(260)),
        Positioned(left: -60, top: 150, child: _circle(180)),
        child,
      ],
    ),
  );
  Widget _circle(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: .12),
    ),
  );
}
