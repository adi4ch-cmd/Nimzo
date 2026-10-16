import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AuthBackdrop extends StatelessWidget {
  final Widget child;
  const AuthBackdrop({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: NimzoStyle.heroGradient,
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
