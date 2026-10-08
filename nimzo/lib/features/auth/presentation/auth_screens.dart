import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import 'auth_reference_art.dart';
import '../../../core/widgets/master_ui.dart';

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
      body: AuthBackdrop(
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
                    const Text(
                      'NIMZO',
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.2,
                        letterSpacing: 2,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Connect · Chat · Belong',
                      style: TextStyle(color: Colors.white, height: 1.2),
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
                                          style: TextButton.styleFrom(
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize
                                                  .shrinkWrap,
                                              padding: const EdgeInsets.all(9)),
                                          onPressed: () => context.go(register
                                              ? '/register'
                                              : '/login'),
                                          child: Text(register ? 'Sign up' : 'Login',
                                              style: TextStyle(
                                                  color: widget.register == register
                                                      ? NimzoStyle.primary
                                                      : NimzoStyle.muted,
                                                  fontWeight: FontWeight.w600))))),
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
                                isDense: true,
                                hintText: 'Email address',
                                prefixIcon: ReferenceIcon('mail', size: 22),
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
                                isDense: true,
                                hintText: 'Password',
                                prefixIcon: ReferenceIcon('lock', size: 22),
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
                        child: Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 14),
                            child: TextButton(
                              style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.zero,
                                  textStyle: const TextStyle(
                                      fontFamily: 'Roboto', fontSize: 13)),
                              onPressed: () => context.push('/forgot'),
                              child: const Text('Forgot password?'),
                            )),
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
                        child: Row(children: [
                          Expanded(child: Divider()),
                          SizedBox(width: 10),
                          Text('or continue with',
                              style: TextStyle(
                                  fontSize: 12, color: NimzoStyle.muted)),
                          SizedBox(width: 10),
                          Expanded(child: Divider())
                        ]),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: NimzoStyle.ink,
                                  side:
                                      const BorderSide(color: NimzoStyle.line),
                                  padding: const EdgeInsets.all(12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14))),
                              onPressed: state.isLoading
                                  ? null
                                  : () => ref
                                      .read(authControllerProvider.notifier)
                                      .google(),
                              child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ReferenceIcon('google',
                                        originalColors: true),
                                    SizedBox(width: 10),
                                    Text('Google')
                                  ]),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: NimzoStyle.ink,
                                  side:
                                      const BorderSide(color: NimzoStyle.line),
                                  padding: const EdgeInsets.all(12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14))),
                              onPressed: state.isLoading
                                  ? null
                                  : () => ref
                                      .read(authControllerProvider.notifier)
                                      .facebook(),
                              child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ReferenceIcon('facebook',
                                        originalColors: true),
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
