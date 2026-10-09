import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_controller.dart';

class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});
  @override
  ConsumerState<UpdatePasswordScreen> createState() => _State();
}

class _State extends ConsumerState<UpdatePasswordScreen> {
  final password = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New password')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (password.text.length < 6) return;
                    setState(() => busy = true);
                    try {
                      await ref
                          .read(supabaseProvider)
                          .auth
                          .updateUser(UserAttributes(password: password.text));
                      ref.read(passwordRecoveryProvider.notifier).state = false;
                    } catch (_) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Unable to update password. Retry.'),
                          ),
                        );
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: const Text('Save password'),
          ),
        ],
      ),
    ),
  );
}
