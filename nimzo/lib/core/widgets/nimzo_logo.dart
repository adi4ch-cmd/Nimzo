import 'package:flutter/material.dart';

/// Owner-approved 01 Purple Gold identity.
class NimzoLogo extends StatelessWidget {
  const NimzoLogo({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .24),
        child: Image.asset('assets/brand/nimzo_purple_gold.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            semanticLabel: 'NIMZO'),
      );
}
