import '../../../core/widgets/nimzo_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/nimzo_button.dart';
import '../../../core/widgets/nimzo_text_field.dart';
import 'auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _S();
}

class _S extends ConsumerState<RegisterScreen> {
  final _f = GlobalKey<FormState>();
  final _e = TextEditingController(), _p = TextEditingController();
  @override
  void dispose() { _e.dispose(); _p.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext c) {
    final st = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (_, s) {
      if (s.hasError) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('${s.error}')));
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Form(key: _f, child: Column(children: [
        NimzoTextField(controller: _e, label: 'Email', validator: Validators.email, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        NimzoTextField(controller: _p, label: 'Password', obscure: true, validator: Validators.password),
        const SizedBox(height: 16),
        NimzoButton(label: 'Sign up', loading: st.isLoading, onPressed: () {
          if (_f.currentState!.validate()) ref.read(authControllerProvider.notifier).signUp(_e.text.trim(), _p.text);
        }),
      ])))),
    );
  }
}
