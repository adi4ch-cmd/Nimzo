import 'package:flutter/material.dart';
import '../theme/colors.dart';

class NimzoBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const NimzoBottomNav({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) => NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 68,
          backgroundColor: NimzoColors.background,
          indicatorColor: NimzoColors.primaryLight,
          indicatorShape: const StadiumBorder(),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: onTap,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.sports_esports_outlined), selectedIcon: Icon(Icons.sports_esports_rounded), label: 'Games'),
            NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome_rounded), label: 'Moments'),
            NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble_rounded), label: 'Messages'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      );
}
