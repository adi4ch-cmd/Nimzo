import 'package:flutter/material.dart';
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
      final email = ref.watch(supabaseProvider).auth.currentUser?.email;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ReferenceCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Email', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(email ?? 'No email linked',
              style: const TextStyle(color: NimzoStyle.muted)),
        ])),
        const SizedBox(height: 14),
        GradientButton(
            onPressed: () => context.push('/forgot'),
            child: const Text('Reset password')),
      ]);
    }
    if (title == 'Task')
      return Column(children: [
        for (final task in [
          ('Daily check-in', '+100 coins'),
          ('Send a gift', '+50 coins'),
          ('Stay in a room 10 min', '+30 coins')
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
            const GradientButton(onPressed: null, child: Text('Claim'))
          ]))
      ]);
    if (title == 'Store')
      return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 0.6 / MediaQuery.textScalerOf(context).scale(1),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            for (final item in [
              ('Gold Frame', 50000, 'frame', 0),
              ('VIP Frame', 500000, 'frame', 1),
              ('Eagle Car', 200000, 'car', 0),
              ('Jeep Car', 100000, 'car', 1)
            ])
              Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: NimzoStyle.surface,
                      borderRadius: BorderRadius.circular(14)),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ReferenceArtwork(item.$3, item.$4, size: 58),
                        const SizedBox(height: 6),
                        Text(item.$1,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${compactNumber(item.$2)} coins',
                            style: const TextStyle(
                                color: NimzoStyle.primary, fontSize: 12)),
                        const Text('Unavailable',
                            style: TextStyle(
                                color: NimzoStyle.muted, fontSize: 11))
                      ]))
          ]);
    if (title == 'Honor Wall')
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 16, runSpacing: 16, children: [
          for (var i = 0; i < 5; i++) ReferenceArtwork('med', i, size: 84)
        ]),
        const SizedBox(height: 20),
        const Text('Room medals',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        const Row(children: [
          ReferenceArtwork('rmed', 0, size: 90),
          SizedBox(width: 10),
          ReferenceArtwork('rmed', 1, size: 90)
        ])
      ]);
    if (title == 'Help and feedback')
      return Column(children: [
        for (final question in [
          'How do I recharge?',
          'How do VIP and SVIP work?',
          'Report a problem'
        ])
          ListTile(
              title: Text(question),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showUiUnavailable(context, 'Help service'))
      ]);
    if (title == 'Privacy')
      return Column(children: [
        for (final label in [
          'Show me in visitors',
          'Allow messages from everyone',
          'Show my online status'
        ])
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              value: true,
              onChanged: null)
      ]);
    if (title == 'Language')
      return const Column(children: [
        ListTile(
            title: Text('English'),
            trailing: Icon(Icons.check, color: NimzoStyle.primary)),
        ListTile(title: Text('العربية'))
      ]);
    return const EmptyContent('This service is not available yet.');
  }
}
