import 'package:flutter/material.dart';
import '../theme/colors.dart';

class NimzoAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final bool online;
  const NimzoAvatar({super.key, this.url, this.radius = 22, this.online = false});
  @override
  Widget build(BuildContext context) => Stack(children: [
        CircleAvatar(
            radius: radius,
            backgroundColor: NimzoColors.primaryLight,
            backgroundImage: url == null ? null : NetworkImage(url!),
            child: url == null ? const Icon(Icons.person, color: NimzoColors.primaryDark) : null),
        if (online)
          Positioned(right: 0, bottom: 0, child: Container(width: radius / 2.4, height: radius / 2.4,
              decoration: BoxDecoration(color: NimzoColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
      ]);
}
