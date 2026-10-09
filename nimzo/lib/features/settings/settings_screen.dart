import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../auth/presentation/auth_controller.dart';
import '../voice/voice_controller.dart';
import '../../core/services/app_update_service.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/theme/app_theme.dart';
import 'reference_info_content.dart';
import 'user_preferences.dart';
import '../support/legal_content.dart';

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
          child: Column(
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
                  minTileHeight: 46,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const Border(
                    bottom: BorderSide(color: NimzoStyle.line),
                  ),
                  onTap: () =>
                      context.push('/info/${Uri.encodeComponent(label)}'),
                ),
              const PreferenceControls(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ListTile(
          leading: const Icon(Icons.system_update),
          title: const Text('Check for updates'),
          subtitle: const Text('Check NIMZO testing APK releases'),
          onTap: () =>
              NimzoAppUpdateService.prompt(context, showUpToDate: true),
        ),
        OutlinedButton(
          onPressed: ref.watch(authControllerProvider).isLoading
              ? null
              : () async {
                  final auth = ref.read(authControllerProvider.notifier);
                  final voice = ref.read(voiceServiceProvider);
                  final container = ProviderScope.containerOf(
                    context,
                    listen: false,
                  );
                  try {
                    try {
                      await voice.leave();
                    } catch (_) {
                      /* Session logout must still run. */
                    }
                    await auth.signOut();
                    if (container.read(authControllerProvider).hasError &&
                        context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Logout could not be completed. Retry.',
                          ),
                        ),
                      );
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
            ? const Column(
                children: [_InstalledAppAbout(), LegalPoliciesContent()],
              )
            : ReferenceInfoContent(title: title),
      ),
    ),
  );
}

class _InstalledAppAbout extends StatefulWidget {
  const _InstalledAppAbout();

  @override
  State<_InstalledAppAbout> createState() => _InstalledAppAboutState();
}

class _InstalledAppAboutState extends State<_InstalledAppAbout> {
  late final Future<PackageInfo> _installed = PackageInfo.fromPlatform()
      .timeout(const Duration(seconds: 5));

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: _installed,
    builder: (context, snapshot) {
      final info = snapshot.data;
      final version = info != null
          ? ' · ${info.version} (build ${info.buildNumber})'
          : snapshot.hasError
          ? ' · Version unavailable'
          : ' · Loading version…';
      return ReferenceCard(
        child: Text('NIMZO$version\nVoice rooms and social connections'),
      );
    },
  );
}
