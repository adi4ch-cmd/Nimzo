import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/services/app_update_service.dart';
import 'router.dart';
import '../core/providers/ui_language_provider.dart';
import '../core/providers/supabase_provider.dart';
import '../features/profile/profile_repository.dart';

class NimzoApp extends ConsumerStatefulWidget {
  const NimzoApp({super.key});
  @override
  ConsumerState<NimzoApp> createState() => _NimzoAppState();
}

class _NimzoAppState extends ConsumerState<NimzoApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigatorContext =
          ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
      if (navigatorContext != null)
        NimzoAppUpdateService.prompt(navigatorContext);
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(currentUserIdProvider);
    if (id != null)
      ref.listen(profileProvider(id), (_, next) {
        final language = next.valueOrNull?.language;
        if (next.hasValue)
          ref.read(uiLanguageProvider.notifier).state =
              language == 'ar' ? 'ar' : 'en';
      });
    final arabic = ref.watch(uiLanguageProvider) == 'ar';
    return MaterialApp.router(
      title: 'Nimzo',
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
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
