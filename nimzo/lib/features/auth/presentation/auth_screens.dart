import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import '../../../core/widgets/master_ui.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

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
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
              Color(0xff5b21b6),
              Color(0xffc026d3),
              Color(0xffec4899)
            ],
                stops: [
              0,
              .65,
              1
            ])),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 46, 24, 28),
                child: Column(
                  children: [
                    Container(
                        width: 70,
                        height: 70,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .2),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: .5)),
                            borderRadius: BorderRadius.circular(22)),
                        child: const Center(
                            child: Text('N',
                                style: TextStyle(
                                    fontSize: 34,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800)))),
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
                      Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: NimzoStyle.surface,
                              borderRadius: BorderRadius.circular(14)),
                          child: Row(children: [
                            for (final register in [false, true])
                              Expanded(
                                  child: Container(
                                      decoration: BoxDecoration(
                                          color: widget.register == register
                                              ? Colors.white
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(11),
                                          boxShadow: widget.register == register
                                              ? [
                                                  const BoxShadow(
                                                      color: Color(0x267828c8),
                                                      blurRadius: 8)
                                                ]
                                              : null),
                                      child: TextButton(
                                          onPressed: () => context.go(register
                                              ? '/register'
                                              : '/login'),
                                          child: Text(
                                              register ? 'Sign up' : 'Login',
                                              style: TextStyle(
                                                  color: widget.register ==
                                                          register
                                                      ? NimzoStyle.primary
                                                      : NimzoStyle.muted,
                                                  fontWeight:
                                                      FontWeight.w600))))),
                          ])),
                      Form(
                        key: form,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                hintText: 'Email address',
                                prefixIcon: Icon(LucideIcons.mail, size: 22),
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
                                hintText: 'Password',
                                prefixIcon: Icon(LucideIcons.lock, size: 22),
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
                      GradientButton(
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
                              child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('G',
                                        style: TextStyle(
                                            color: Color(0xff1976d2),
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800)),
                                    SizedBox(width: 10),
                                    Text('Google')
                                  ]),
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
                              child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.facebook,
                                        color: Color(0xff1877f2), size: 22),
                                    SizedBox(width: 10),
                                    Flexible(child: Text('Facebook'))
                                  ]),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                          padding: EdgeInsets.only(top: 18),
                          child: Text(
                              'By continuing you agree to the Terms and Privacy Policy',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: NimzoStyle.muted, fontSize: 12))),
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
