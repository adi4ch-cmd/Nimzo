import 'package:flutter/material.dart';

/// Retired: medal entitlements and the former Honor Wall were removed.
/// Kept as a compatibility widget for old deep links; no medal data or
/// store RPCs are fetched and no medal controls are rendered.
class HonorWallContent extends StatelessWidget {
  const HonorWallContent({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
