import '../../core/widgets/nimzo_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/nimzo_button.dart';
import '../../../core/widgets/nimzo_text_field.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final ctrl = ref.read(authControllerProvider.notifier);
    ref.listen(authControllerProvider, (_, s) {
      if (s.hasError) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${s.error}')));
      }
    });
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: EdgeInsets.all(Responsive.gutter(context)),
              children: [
                const SizedBox(height: 32),
                Text('Welcome to Nimzo',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),
                Form(
                  key: _form,
                  child: Column(children: [
                    NimzoTextField(
                        controller: _email,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email),
                    const SizedBox(height: 12),
                    NimzoTextField(
                        controller: _pass,
                        label: 'Password',
                        obscure: true,
                        validator: Validators.password),
                  ]),
                ),
                const SizedBox(height: 16),
                NimzoButton(
                  label: 'Sign in',
                  loading: auth.isLoading,
                  onPressed: () {
                    if (_form.currentState!.validate()) {
                      ctrl.signIn(_email.text.trim(), _pass.text);
                    }
                  },
                ),
                TextButton(
                    onPressed: () => context.push('/forgot'),
                    child: const Text('Forgot password?')),
                const SizedBox(height: 8),
                NimzoButton(
                    label: 'Continue with Google',
                    outlined: true,
                    onPressed: auth.isLoading ? null : ctrl.google),
                const SizedBox(height: 12),
                NimzoButton(
                    label: 'Continue with Facebook',
                    outlined: true,
                    onPressed: auth.isLoading ? null : ctrl.facebook),
                const SizedBox(height: 16),
                TextButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('Create an account')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
