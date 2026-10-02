import 'package:flutter/material.dart';
import '../theme/colors.dart';

class NimzoBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const NimzoBottomNav({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onTap,
        backgroundColor: NimzoColors.background,
        indicatorColor: NimzoColors.primaryLight,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.sports_esports_outlined), label: 'Games'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'Moments'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      );
}
