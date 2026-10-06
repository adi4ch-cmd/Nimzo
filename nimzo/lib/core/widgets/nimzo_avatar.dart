import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'nimzo_icon.dart';

class NimzoAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final bool online;
  const NimzoAvatar({
    super.key,
    this.url,
    this.radius = 22,
    this.online = false,
  });
  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: NimzoColors.primaryLight,
      child: Center(
        child: NimzoIcon(
          Icons.person_rounded,
          size: radius * .85,
          color: NimzoColors.primaryDark,
        ),
      ),
    );
    return Stack(
      children: [
        ClipOval(
          child: SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: url?.trim().isNotEmpty == true
                ? Image.network(
                    url!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback,
                    loadingBuilder: (_, child, progress) =>
                        progress == null ? child : fallback,
                  )
                : fallback,
          ),
        ),
        if (online)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius / 2.4,
              height: radius / 2.4,
              decoration: BoxDecoration(
                color: NimzoColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
