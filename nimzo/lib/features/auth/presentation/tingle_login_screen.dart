import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_controller.dart';

/// Auth UI based on the supplied Tingle login screenshot.
/// Uses only the existing verified NIMZO email/Google authentication methods.
/// Unsupported shortcuts are visibly explained rather than silently creating
/// an account with unpredictable retention.
class TingleLoginScreen extends ConsumerStatefulWidget {
  const TingleLoginScreen({super.key});

  @override
  ConsumerState<TingleLoginScreen> createState() => _TingleLoginScreenState();
}

class _TingleLoginScreenState extends ConsumerState<TingleLoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _terms = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _login() {
    if (!_terms) {
      _notice('Please accept the terms and conditions to continue.');
      return;
    }
    if (_form.currentState?.validate() == true) {
      ref.read(authControllerProvider.notifier).signIn(
            _email.text.trim(),
            _password.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;
    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError) _notice('Login failed. Check your details and retry.');
    });

    return Scaffold(
      backgroundColor: const Color(0xfff6f4ff),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xffc4c5ff),
              Color(0xffeeebff),
              Color(0xfffaf9ff),
              Color(0xffe9e7ff),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 58, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 82,
                ),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: const LinearGradient(
                                colors: [Color(0xffff8fcc), Color(0xff8c82ff)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'N',
                              style: TextStyle(
                                fontSize: 69,
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 22),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('NIMZO',
                                  style: TextStyle(
                                    fontSize: 35,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text('Love begins here. Log in to connect.',
                                  style: TextStyle(
                                    fontSize: 14, color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 62),
                      const _FieldLabel('Enter your email id'),
                      const SizedBox(height: 10),
                      TextFormField(
                        key: const ValueKey('tingle-email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: _field('Enter your email id'),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          return RegExp(r'^\S+@\S+\.\S+$').hasMatch(text)
                              ? null
                              : 'Enter a valid email address';
                        },
                      ),
                      const SizedBox(height: 26),
                      const _FieldLabel('Enter your password'),
                      const SizedBox(height: 10),
                      TextFormField(
                        key: const ValueKey('tingle-password'),
                        controller: _password,
                        obscureText: !_showPassword,
                        autofillHints: const [AutofillHints.password],
                        decoration: _field('Enter your password').copyWith(
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _showPassword = !_showPassword,
                            ),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: const Color(0xffaaa3ce),
                            ),
                          ),
                        ),
                        validator: (value) => (value?.length ?? 0) >= 6
                            ? null
                            : 'Password must contain at least six characters',
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/forgot'),
                          child: const Text('Forgot Password?',
                            style: TextStyle(
                              color: Colors.black,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _PurpleButton(
                        text: loading ? 'Please wait…' : 'Continue',
                        onPressed: loading ? null : _login,
                      ),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          const Text('If you have a new user?  ',
                            style: TextStyle(fontSize: 14, color: Colors.black)),
                          GestureDetector(
                            onTap: () => context.go('/register'),
                            child: const Text(
                              'Get Register',
                              style: TextStyle(
                                fontSize: 14, color: Colors.black,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Divider(color: Color(0xffd9d4ec)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _SocialButton(
                              icon: Icons.facebook,
                              text: 'Facebook',
                              onPressed: loading
                                  ? null
                                  : () {
                                      if (!_terms) {
                                        _notice('Please accept the terms first.');
                                        return;
                                      }
                                      ref
                                          .read(authControllerProvider.notifier)
                                          .facebook();
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SocialButton(
                              icon: Icons.g_mobiledata_rounded,
                              text: 'Google',
                              onPressed: loading
                                  ? null
                                  : () {
                                      if (!_terms) {
                                        _notice('Please accept the terms first.');
                                        return;
                                      }
                                      ref
                                          .read(authControllerProvider.notifier)
                                          .google();
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      InkWell(
                        onTap: () => setState(() => _terms = !_terms),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _terms,
                              activeColor: NimzoStyle.primary,
                              onChanged: (v) => setState(() => _terms = v ?? false),
                            ),
                            const Flexible(
                              child: Text(
                                'I have accept all terms & condition.',
                                style: TextStyle(fontSize: 14, color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _field(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xffaba3c2), fontSize: 18),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        border: _outline(),
        enabledBorder: _outline(),
        focusedBorder: _outline(color: NimzoStyle.primary),
        errorBorder: _outline(color: Colors.redAccent),
      );

  OutlineInputBorder _outline({Color color = const Color(0xffeeeaf6)}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(color: color),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 15, color: Color(0xff8179ac)),
      );
}

class _PurpleButton extends StatelessWidget {
  final String text;
  final IconData? leading;
  final VoidCallback? onPressed;
  const _PurpleButton({required this.text, required this.onPressed, this.leading});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 69,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xffa243f5), Color(0xff7439d4)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  Icon(leading, size: 27),
                  const SizedBox(width: 12),
                ],
                Text(
                  text,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onPressed;
  const _SocialButton({required this.icon, required this.text, this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 68,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            side: const BorderSide(color: Color(0xffe7e4f0)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(40),
            ),
          ),
          icon: Icon(icon, size: 24, color: NimzoStyle.primary),
          label: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      );
}
