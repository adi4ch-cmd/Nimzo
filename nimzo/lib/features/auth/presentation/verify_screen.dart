import '../../core/widgets/nimzo_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/nimzo_button.dart';
import 'auth_controller.dart';

class VerifyScreen extends ConsumerWidget {
  const VerifyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(authRepositoryProvider);
    final email = repo.getCurrentUser()?.email;
    return Scaffold(
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Verify your email', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('We sent a link to ${email ?? 'your email'}. Open it, then tap the button below.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        NimzoButton(label: 'I have verified', onPressed: () async {
          final ok = await repo.verifyEmail();
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email not verified yet.')));
          }
        }),
        const SizedBox(height: 12),
        NimzoButton(label: 'Resend link', outlined: true, onPressed: () => repo.verifyEmail(resendTo: email)),
        TextButton(onPressed: () => ref.read(authControllerProvider.notifier).signOut(), child: const Text('Sign out')),
      ]))),
    );
  }
}
