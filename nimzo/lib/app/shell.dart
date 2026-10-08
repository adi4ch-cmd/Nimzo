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
            border: Border(top: BorderSide(color: NimzoStyle.line)),
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
                            ReferenceIcon(
                              ['home', 'game', 'moments', 'msg', 'user'][i],
                              size: 22,
                              color: i == shell.currentIndex
                                  ? NimzoStyle.primary
                                  : NimzoStyle.muted,
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
                                      'Me'
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
