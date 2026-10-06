import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/nimzo_button.dart';
import '../../../core/widgets/nimzo_text_field.dart';
import 'auth_controller.dart';

class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});
  @override
  ConsumerState<UpdatePasswordScreen> createState() => _UpdatePasswordState();
}

class _UpdatePasswordState extends ConsumerState<UpdatePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _password.text),
      );
      if (mounted) ref.read(passwordRecoveryProvider.notifier).state = false;
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to update password. Please try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose a new password')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            children: [
              NimzoTextField(
                controller: _password,
                label: 'New password',
                obscure: true,
                validator: (v) =>
                    (v?.length ?? 0) < 8 ? 'Use at least 8 characters' : null,
              ),
              const SizedBox(height: 20),
              NimzoButton(
                label: 'Save password',
                loading: _busy,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
