import 'package:flutter/material.dart';
import 'language_choices.dart';
import 'user_preferences.dart';
import 'honor_wall_content.dart';
import '../support/support_screen.dart';
import '../social/blocked_users_screen.dart';
import '../profile/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/widgets/master_ui.dart';
import '../../core/widgets/reference_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

class ReferenceInfoContent extends ConsumerWidget {
  final String title;
  const ReferenceInfoContent({super.key, required this.title});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (title == 'Account') {
      final id = ref.watch(currentUserIdProvider);
      final profile =
          id == null ? null : ref.watch(profileProvider(id)).valueOrNull;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ReferenceCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nimzo ID', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(profile?.nimzoId.toString() ?? 'ID unavailable',
              style: const TextStyle(color: NimzoStyle.muted)),
          const Text('Permanent, cannot be changed',
              style: TextStyle(color: NimzoStyle.muted, fontSize: 12)),
        ])),
        const SizedBox(height: 14),
        GradientButton(
            onPressed: () => context.push('/forgot'),
            child: const Text('Change password')),
        const SizedBox(height: 20),
        const AccountDeletionRequestContent(),
      ]);
    }
    if (title == 'Task')
      return Column(children: [
        for (final task in [
          ('Daily check-in', 'Rewards unavailable'),
          ('Send a gift', 'Rewards unavailable'),
          ('Stay in a room 10 min', 'Rewards unavailable')
        ])
          ReferenceCard(
              child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(task.$1,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(task.$2,
                      style: const TextStyle(
                          color: NimzoStyle.muted, fontSize: 12))
                ])),
            const GradientButton(onPressed: null, child: Text('Unavailable'))
          ]))
      ]);
    if (title == 'Store')
      return Center(child: FilledButton(
        onPressed: () => context.push('/store'),
        child: const Text('Open NIMZO Store'),
      ));
    if (title == 'Honor Wall') return const HonorWallContent();
    if (title == 'Help and feedback') return const SupportHelpContent();
    if (title == 'Privacy')
      return Column(children: [
        ListTile(
            title: const Text('Blocked users'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BlockedUsersScreen()))),
        const PreferenceControls(privacy: true),
        const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
                'Visitor visibility and online-status privacy are not supported by the current server contracts.')),
      ]);
    if (title == 'Language') return const LanguageChoices();
    return const EmptyContent('This service is not available yet.');
  }
}
