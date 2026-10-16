import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/ui_language_provider.dart';
import '../core/widgets/master_ui.dart';

import '../core/theme/app_theme.dart';

class MainShell extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const MainShell({super.key, required this.shell});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: SafeArea(bottom: false, child: shell),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: NimzoStyle.line)),
            boxShadow: [BoxShadow(
              color: Color(0x126628cf),
              offset: Offset(0, -2),
              blurRadius: 14,
            )],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                for (var i = 0; i < 5; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => shell.goBranch(
                        i,
                        initialLocation: i == shell.currentIndex,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 19, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: i == shell.currentIndex
                                    ? NimzoStyle.heroGradient
                                    : null,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: ReferenceIcon(
                                ['home', 'game', 'moments', 'msg', 'user'][i],
                                size: 21,
                                color: i == shell.currentIndex
                                    ? Colors.white
                                    : NimzoStyle.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (ref.watch(uiLanguageProvider) == 'ar'
                                  ? referenceArabicTabs
                                  : [
                                      'Home',
                                      'Games',
                                      'Moments',
                                      'Messages',
                                      'Me',
                                    ])[i],
                              style: TextStyle(
                                fontSize: 11,
                                color: i == shell.currentIndex
                                    ? NimzoStyle.primary
                                    : NimzoStyle.muted,
                                fontWeight: i == shell.currentIndex
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}
