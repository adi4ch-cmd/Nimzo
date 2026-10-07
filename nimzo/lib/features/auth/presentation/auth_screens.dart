import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool register;
  const LoginScreen({super.key, this.register = false});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign-in could not be completed. Please retry.'),
          ),
        );
    });
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: NimzoStyle.gradient),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 36, 24, 24),
                child: Column(
                  children: [
                    Text(
                      'N',
                      style: TextStyle(
                        fontSize: 42,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'NIMZO',
                      style: TextStyle(
                        fontSize: 26,
                        letterSpacing: 2,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Connect · Chat · Belong',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => context.go('/login'),
                              child: const Text('Login'),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: () => context.go('/register'),
                              child: const Text('Sign up'),
                            ),
                          ),
                        ],
                      ),
                      Form(
                        key: form,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                              ),
                              validator: (s) => s != null &&
                                      RegExp(r'^\S+@\S+\.\S+$')
                                          .hasMatch(s.trim())
                                  ? null
                                  : 'Enter a valid email',
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: password,
                              obscureText: true,
                              autofillHints: const [AutofillHints.password],
                              decoration: const InputDecoration(
                                labelText: 'Password',
                              ),
                              validator: (s) => s != null && s.length >= 6
                                  ? null
                                  : 'Password needs 6+ characters',
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/forgot'),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      FilledButton(
                        onPressed: state.isLoading
                            ? null
                            : () {
                                if (form.currentState!.validate()) {
                                  final c = ref.read(
                                    authControllerProvider.notifier,
                                  );
                                  widget.register
                                      ? c.signUp(
                                          email.text.trim(),
                                          password.text,
                                        )
                                      : c.signIn(
                                          email.text.trim(),
                                          password.text,
                                        );
                                }
                              },
                        child: Text(
                          state.isLoading
                              ? 'Please wait…'
                              : widget.register
                                  ? 'Create account'
                                  : 'Login',
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'or continue with',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: state.isLoading
                                  ? null
                                  : () => ref
                                      .read(authControllerProvider.notifier)
                                      .google(),
                              child: const Text('Google'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: state.isLoading
                                  ? null
                                  : () => ref
                                      .read(authControllerProvider.notifier)
                                      .facebook(),
                              child: const Text('Facebook'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends LoginScreen {
  const RegisterScreen({super.key}) : super(register: true);
}

class ForgotScreen extends ConsumerStatefulWidget {
  const ForgotScreen({super.key});
  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  final email = TextEditingController();
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Forgot password')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email address'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: ref.watch(authControllerProvider).isLoading
                  ? null
                  : () async {
                      if (!RegExp(r'^\S+@\S+\.\S+$')
                          .hasMatch(email.text.trim())) return;
                      await ref
                          .read(authControllerProvider.notifier)
                          .reset(email.text.trim());
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ref.read(authControllerProvider).hasError
                                  ? 'Unable to send reset link. Retry.'
                                  : 'Check your email for the reset link.',
                            ),
                          ),
                        );
                    },
              child: const Text('Send reset link'),
            ),
          ],
        ),
      );
}

class VerifyScreen extends ConsumerWidget {
  const VerifyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Verify your email')),
        body: Center(
          child: FilledButton(
            onPressed: () async {
              await ref.read(authRepositoryProvider).verifyEmail();
            },
            child: const Text('I verified my email'),
          ),
        ),
      );
}
