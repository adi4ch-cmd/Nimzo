import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/providers/ui_language_provider.dart';
import '../../core/theme/app_theme.dart';
import '../profile/profile_repository.dart';

class LanguageChoices extends ConsumerStatefulWidget {
  const LanguageChoices({super.key});
  @override
  ConsumerState<LanguageChoices> createState() => _LanguageState();
}

class _LanguageState extends ConsumerState<LanguageChoices> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final choice in [('en', 'English'), ('ar', 'العربية')])
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(choice.$2),
              trailing: ref.watch(uiLanguageProvider) == choice.$1
                  ? const Icon(Icons.check, color: NimzoStyle.primary)
                  : null,
              onTap: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final container = ProviderScope.containerOf(
                        context,
                        listen: false,
                      );
                      try {
                        final id = ref.read(currentUserIdProvider);
                        if (id == null) throw StateError('Sign in required');
                        await ref
                            .read(profileRepositoryProvider)
                            .update(language: choice.$1);
                        container.invalidate(profileProvider(id));
                        if (container.read(currentUserIdProvider) == id)
                          container.read(uiLanguageProvider.notifier).state =
                              choice.$1;
                        if (!context.mounted) return;
                        if (Navigator.of(context).canPop())
                          Navigator.pop(context);
                      } catch (_) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Language could not be saved. Retry.'),
                            ),
                          );
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
            ),
          if (busy) const LinearProgressIndicator(),
        ],
      );
}
