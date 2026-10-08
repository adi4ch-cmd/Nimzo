import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/presentation/auth_controller.dart';
import '../voice/voice_controller.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/theme/app_theme.dart';
import 'reference_info_content.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Material(
                color: NimzoStyle.surface,
                borderRadius: BorderRadius.circular(14),
                child: Column(children: [
                  for (final label in [
                    'Account',
                    'Privacy',
                    'Language',
                    'Help and feedback',
                    'About',
                  ])
                    ListTile(
                      title: Text(label),
                      minTileHeight: 46,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      shape: const Border(
                          bottom: BorderSide(color: NimzoStyle.line)),
                      onTap: () =>
                          context.push('/info/${Uri.encodeComponent(label)}'),
                    ),
                  const SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14),
                      title: Text('Message notifications'),
                      value: true,
                      onChanged: null),
                  const SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14),
                      title: Text('Gift notifications'),
                      value: true,
                      onChanged: null),
                ])),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: ref.watch(authControllerProvider).isLoading
                  ? null
                  : () async {
                      final auth = ref.read(authControllerProvider.notifier);
                      final voice = ref.read(voiceServiceProvider);
                      final container =
                          ProviderScope.containerOf(context, listen: false);
                      try {
                        try {
                          await voice.leave();
                        } catch (_) {/* Session logout must still run. */}
                        await auth.signOut();
                        if (container.read(authControllerProvider).hasError &&
                            context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content:
                                Text('Logout could not be completed. Retry.'),
                          ));
                        }
                      } catch (_) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Logout could not be completed. Retry.',
                              ),
                            ),
                          );
                      }
                    },
              child: const Text('Logout'),
            ),
          ],
        ),
      );
}

class InfoScreen extends StatelessWidget {
  final String title;
  const InfoScreen({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SingleChildScrollView(
            child: Padding(
          padding: const EdgeInsets.all(16),
          child: title == 'About'
              ? const ReferenceCard(
                  child:
                      Text('NIMZO · 1.0.5\nVoice rooms and social connections'),
                )
              : ReferenceInfoContent(title: title),
        )),
      );
}
