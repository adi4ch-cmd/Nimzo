import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/presentation/auth_controller.dart';
import '../voice/voice_controller.dart';
import '../../core/widgets/reference_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final label in [
              'Account',
              'Privacy',
              'Language',
              'Help and feedback',
              'About',
            ])
              ListTile(
                title: Text(label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push('/info/${Uri.encodeComponent(label)}'),
              ),
            FilledButton(
              onPressed: ref.watch(authControllerProvider).isLoading
                  ? null
                  : () async {
                      try {
                        await ref.read(voiceServiceProvider).leave();
                        await ref
                            .read(authControllerProvider.notifier)
                            .signOut();
                        if (ref.read(authControllerProvider).hasError &&
                            context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Logout could not be completed. Retry.',
                              ),
                            ),
                          );
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
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: title == 'About'
              ? const ReferenceCard(
                  child:
                      Text('NIMZO · 1.0.5\nVoice rooms and social connections'),
                )
              : const EmptyContent('This service is not available yet.'),
        ),
      );
}
