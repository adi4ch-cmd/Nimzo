import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../auth/presentation/auth_controller.dart';
import '../voice/voice_controller.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../support/legal_content.dart';
import 'reference_info_content.dart';
import 'user_preferences.dart';

/// Settings screen patterned on the provided Tingle screenshot.
/// Only backend-supported settings are mutable.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _notice(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authControllerProvider.notifier);
    final voice = ref.read(voiceServiceProvider);
    try {
      try { await voice.leave(); } catch (_) {}
      await auth.signOut();
      if (ref.read(authControllerProvider).hasError && context.mounted) {
        _notice(context, 'Could not log out. Please retry.');
      }
    } catch (_) {
      if (context.mounted) _notice(context, 'Could not log out. Please retry.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPreferencesProvider);
    final current = prefs.valueOrNull;
    final notifications = current?.messages == true && current?.gifts == true;
    Future<void> setNotifications(bool value) async {
      try {
        await ref.read(userPreferencesProvider.notifier)
            .change(messages: value, gifts: value);
      } catch (_) {
        if (context.mounted) _notice(context, 'Failed to save setting.');
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xfff8f8f8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Settings',
          style: TextStyle(color: Colors.black, fontSize: 20,
            fontWeight: FontWeight.w800)),
      ),
      body: ListView(children: [
        const SizedBox(height: 22),
        Material(color: Colors.white, child: Column(children: [
          _SettingRow(
            title: 'Notify Me',
            trailing: current == null
              ? const Icon(Icons.hourglass_empty, color: Colors.grey)
              : Switch(
                  value: notifications,
                  onChanged: prefs.isLoading ? null : setNotifications,
                  activeTrackColor: NimzoStyle.primary,
                ),
          ),
          _SettingRow(
            title: 'Audio Calls',
            trailing: const Icon(Icons.chevron_right, color: Color(0xffc5c2d5)),
            onTap: () => _notice(context,
              'NIMZO supports voice rooms; private calls are not available.'),
          ),
          _SettingRow(
            title: 'Video Calls',
            trailing: const Icon(Icons.chevron_right, color: Color(0xffc5c2d5)),
            onTap: () => _notice(context,
              'NIMZO is an audio-only application.'),
          ),
          _SettingRow(
            title: 'Blocked Users',
            onTap: () => context.push('/settings/blocked'),
          ),
          for (final title in const [
            'Verification Request', 'Private Call Charges',
          ]) _SettingRow(
            title: title,
            onTap: () => _notice(context,
              'This setting needs a verified backend workflow.'),
          ),
          _SettingRow(
            title: 'Languages',
            onTap: () => context.push('/info/Language'),
          ),
          _SettingRow(
            title: 'Privacy Policy',
            onTap: () => context.push('/info/Privacy Policy'),
          ),
          _SettingRow(
            title: 'Terms Of Use',
            onTap: () => context.push('/info/Terms Of Use'),
          ),
        ])),
        const SizedBox(height: 22),
        Material(color: Colors.white, child: Column(children: [
          _SettingRow(
            title: 'Logout',
            titleColor: Colors.red,
            trailing: const SizedBox.shrink(),
            onTap: ref.watch(authControllerProvider).isLoading
              ? null : () => _logout(context, ref),
          ),
          _SettingRow(
            title: 'Delete Account',
            titleColor: Colors.red,
            trailing: const SizedBox.shrink(),
            onTap: () => context.push('/info/Account'),
          ),
        ])),
      ]),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color titleColor;
  const _SettingRow({
    required this.title, this.trailing, this.onTap,
    this.titleColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
    ListTile(
      minTileHeight: 67,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(title,
        style: TextStyle(fontSize: 16, color: titleColor,
          fontWeight: FontWeight.w500)),
      trailing: trailing ?? const Icon(Icons.chevron_right,
        color: Color(0xffd0cddb)),
      onTap: onTap,
    ),
    const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Divider(height: 1, color: Color(0xffeeeeee)),
    ),
  ]);
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
            child: ['About', 'Privacy Policy', 'Terms Of Use'].contains(title)
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
  late final Future<PackageInfo> _installed =
      PackageInfo.fromPlatform().timeout(const Duration(seconds: 5));

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
