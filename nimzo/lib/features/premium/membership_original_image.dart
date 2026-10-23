import 'package:flutter/material.dart';
import 'membership_pack_inventory.dart';

/// Displays the visible part of a transparent original without modifying its
/// bytes or squeezing a wide source canvas into the avatar's square.
class MembershipOriginalImage extends StatelessWidget {
  const MembershipOriginalImage(
      {super.key, required this.artwork, this.fit = BoxFit.contain});
  final MembershipPackArtwork artwork;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    if (artwork.path == null) return const SizedBox.shrink();
    Widget original() => Image.asset(artwork.path!,
        fit: BoxFit.fill,
        errorBuilder: (_, __, ___) => const SizedBox.shrink());
    final crop = artwork.crop;
    if (crop == null)
      return Image.asset(artwork.path!,
          fit: fit, errorBuilder: (_, __, ___) => const SizedBox.shrink());
    return FittedBox(
        fit: fit,
        child: SizedBox(
            width: crop[2],
            height: crop[3],
            child: ClipRect(
                child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                  left: -crop[0],
                  top: -crop[1],
                  width: crop[4],
                  height: crop[5],
                  child: original()),
            ]))));
  }
}
