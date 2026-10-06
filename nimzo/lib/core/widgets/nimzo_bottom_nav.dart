import 'nimzo_icon.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';

class NimzoBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const NimzoBottomNav({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) => NavigationBarTheme(
    data: NavigationBarThemeData(
      height: 70,
      backgroundColor: NimzoColors.surface,
      indicatorColor: NimzoColors.primaryLight,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? NimzoColors.primary
              : NimzoColors.textSecondary,
        ),
      ),
    ),
    child: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onTap,
      destinations: [
        NavigationDestination(
          icon: NimzoNavIcon(Icons.home_outlined, active: false),
          selectedIcon: NimzoNavIcon(Icons.home_rounded, active: true),
          label: 'Home',
        ),
        NavigationDestination(
          icon: NimzoNavIcon(Icons.sports_esports_outlined, active: false),
          selectedIcon: NimzoNavIcon(
            Icons.sports_esports_rounded,
            active: true,
          ),
          label: 'Games',
        ),
        NavigationDestination(
          icon: NimzoNavIcon(Icons.auto_awesome_outlined, active: false),
          selectedIcon: NimzoNavIcon(Icons.auto_awesome_rounded, active: true),
          label: 'Moments',
        ),
        NavigationDestination(
          icon: NimzoNavIcon(Icons.chat_bubble_outline_rounded, active: false),
          selectedIcon: NimzoNavIcon(Icons.chat_bubble_rounded, active: true),
          label: 'Messages',
        ),
        NavigationDestination(
          icon: NimzoNavIcon(Icons.person_outline_rounded, active: false),
          selectedIcon: NimzoNavIcon(Icons.person_rounded, active: true),
          label: 'Profile',
        ),
      ],
    ),
  );
}
