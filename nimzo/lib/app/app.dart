import '../core/services/approved_media_bytes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/providers/ui_language_provider.dart';
import '../core/providers/supabase_provider.dart';
import '../features/profile/profile_repository.dart';
import 'router.dart';
import '../core/services/presence_service.dart';
import '../core/services/firebase_push_service.dart';
import '../core/services/nimzo_content_sync.dart';
import '../features/gifts/gift_repository.dart';
import '../features/store/store_live_catalog.dart';
import '../features/store/store_visual_equipment.dart';
import '../features/events/dynamic_event_banners.dart';
import '../features/games/dynamic_game_catalog.dart';

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
    ref.watch(pushLifecycleProvider);
    ref.watch(nimzoContentResumeProvider);
    // Keep catalogs synchronized without restarting the app or rebuilding APKs.
    // A failed optional content stream must not block authentication or routing.
    ref.listen(nimzoContentRevisionsProvider, (previous, next) {
      final rows = next.valueOrNull;
      if (rows == null) return;
      final changed =
          ref.read(nimzoContentRevisionTrackerProvider).accept(rows);
      if (changed.contains('gifts')) ref.invalidate(giftCatalogProvider);
      if (changed.contains('store')) {
        ref.invalidate(nimzoStoreProvider);
        ref.invalidate(storeVisualEquipmentProvider);
      }
      if (changed.contains('settings'))
        ref.invalidate(nimzoRemoteSettingsProvider);
      if (changed.contains('banners'))
        ref.invalidate(nimzoEventBannersProvider);
      if (changed.contains('games')) ref.invalidate(nimzoLiveGameFlagsProvider);
    });
    ref.listen(currentUserIdProvider, (previous, next) {
      if (previous != next) ApprovedMediaBytes.clearCache();
    });
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
