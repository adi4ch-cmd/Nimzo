import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/art/nimzo_navigation_art.dart';

/// Five-section bottom navigation following the Tingle screenshot layout.
/// Branches retain the existing NIMZO routing contracts so linked data and
/// services continue to function. No third-party artwork is bundled.
class MainShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const MainShell({super.key, required this.shell});

  static const _labels = <String>[
    'Live',
    'Party',
    'Moments',
    'Messages',
    'My Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: shell),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: NimzoStyle.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                for (var i = 0; i < _labels.length; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: _labels[i],
                      selected: shell.currentIndex == i,
                      child: InkWell(
                        key: ValueKey('tingle-navigation-$i'),
                        onTap: () => shell.goBranch(
                          i,
                          initialLocation: i == shell.currentIndex,
                        ),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 170),
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: shell.currentIndex == i
                                  ? const Color(0xfff0e3ff)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: NimzoNavigationArt(
                              index: i,
                              size: 24,
                              color: shell.currentIndex == i
                                  ? NimzoStyle.primary
                                  : const Color(0xff9d99b0),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
