import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/providers/ui_language_provider.dart';
import '../core/providers/supabase_provider.dart';
import '../features/profile/profile_repository.dart';
import 'router.dart';
import '../core/services/presence_service.dart';

/// Tingle-reference rebuild entry point.
///
/// The blank UI reset is intentionally lifted only for the Flutter presentation.
/// Supabase, auth, ID allocation, coins and existing room data are not migrated
/// or cleared. GoRouter continues to enforce the existing auth/profile guards.
class NimzoApp extends ConsumerWidget {
  const NimzoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(presenceLifecycleProvider);
    final id = ref.watch(currentUserIdProvider);
    if (id != null) {
      ref.listen(profileProvider(id), (_, next) {
        if (next.hasValue) {
          final language = next.valueOrNull?.language;
          ref.read(uiLanguageProvider.notifier).state =
              language == 'ar' ? 'ar' : 'en';
        }
      });
    }

    final arabic = ref.watch(uiLanguageProvider) == 'ar';
    return MaterialApp.router(
      title: 'NIMZO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.clamp(0.0, 480.0);
          return ColoredBox(
            color: Colors.white,
            child: Center(
              child: SizedBox(
                width: width,
                height: constraints.maxHeight,
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(size: Size(width, constraints.maxHeight)),
                  child: Directionality(
                    textDirection:
                        arabic ? TextDirection.rtl : TextDirection.ltr,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
