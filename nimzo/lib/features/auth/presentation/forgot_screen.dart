import '../../../core/widgets/nimzo_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/nimzo_button.dart';
import '../../../core/widgets/nimzo_text_field.dart';
import 'auth_controller.dart';

class ForgotScreen extends ConsumerStatefulWidget {
  const ForgotScreen({super.key});
  @override
  ConsumerState<ForgotScreen> createState() => _S();
}

class _S extends ConsumerState<ForgotScreen> {
  final _f = GlobalKey<FormState>();
  final _e = TextEditingController();
  @override
  void dispose() { _e.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext c) {
    final st = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (p, s) {
      final m = ScaffoldMessenger.of(c);
      if (s.hasError) m.showSnackBar(SnackBar(content: Text('${s.error}')));
      else if (p?.isLoading == true && s.hasValue) m.showSnackBar(const SnackBar(content: Text('Reset link sent. Check your email.')));
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Form(key: _f, child: Column(children: [
        NimzoTextField(controller: _e, label: 'Email', validator: Validators.email),
        const SizedBox(height: 16),
        NimzoButton(label: 'Send reset link', loading: st.isLoading, onPressed: () {
          if (_f.currentState!.validate()) ref.read(authControllerProvider.notifier).reset(_e.text.trim());
        }),
      ])))),
    );
  }
}
