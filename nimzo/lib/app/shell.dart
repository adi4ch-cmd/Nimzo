import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/nimzo_bottom_nav.dart';

/// Keeps each tab's state alive via StatefulShellRoute.indexedStack.
class MainShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const MainShell({super.key, required this.shell});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        bottomNavigationBar: NimzoBottomNav(
          index: shell.currentIndex,
          onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        ),
      );
}
