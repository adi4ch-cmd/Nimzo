import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/nimzo_logo.dart';
import 'auth_controller.dart';

/// Registration follows the supplied lavender/white login reference while
/// retaining actual NIMZO Supabase account creation and email verification.
class TingleRegisterScreen extends ConsumerStatefulWidget {
  const TingleRegisterScreen({super.key});

  @override
  ConsumerState<TingleRegisterScreen> createState() =>
      _TingleRegisterScreenState();
}

class _TingleRegisterScreenState extends ConsumerState<TingleRegisterScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool showPassword = false;
  bool accepted = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  void notify(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> register() async {
    if (!accepted) {
      notify('Accept the terms and privacy policy to create an account.');
      return;
    }
    if (form.currentState?.validate() != true) return;
    await ref
        .read(authControllerProvider.notifier)
        .signUp(email.text.trim(), password.text);
  }

  InputDecoration field(String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 16, color: Color(0xffada5c8)),
        suffixIcon: suffix,
        fillColor: Colors.white,
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 21, horizontal: 20),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(19),
            borderSide: const BorderSide(color: Color(0xffe4dff2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(19),
            borderSide:
                const BorderSide(color: NimzoStyle.primary, width: 1.8)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(19),
            borderSide: const BorderSide(color: Colors.redAccent)),
      );

  Widget title(String value) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Text(value,
            style: const TextStyle(
                color: Color(0xff7f76a3),
                fontWeight: FontWeight.w600,
                fontSize: 15)),
      );

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;
    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError) {
        notify('Registration could not be completed. '
            'Please check your details and try again.');
      }
    });
    return Scaffold(
      backgroundColor: const Color(0xfff4f2ff),
      body: DecoratedBox(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xffc5c3ff),
            Color(0xffeeebff),
            Color(0xfffaf9ff),
            Color(0xfff0edff),
          ],
        )),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    IconButton(
                        tooltip: 'Back to login',
                        onPressed: () => context.go('/login'),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Log in',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800)),
                    ),
                  ]),
                  const SizedBox(height: 22),
                  const Row(children: [
                    NimzoLogo(size: 85),
                    SizedBox(width: 17),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NIMZO',
                            style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Colors.black)),
                        SizedBox(height: 3),
                        Text('Create your account to connect',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xff71678b))),
                      ],
                    )),
                  ]),
                  const SizedBox(height: 43),
                  title('Enter your email id'),
                  TextFormField(
                    key: const ValueKey('tingle-register-email'),
                    controller: email,
                    enabled: !loading,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: field('Enter your email id'),
                    validator: (v) =>
                        RegExp(r'^\S+@\S+\.\S+$').hasMatch(v?.trim() ?? '')
                            ? null
                            : 'Enter a valid email address',
                  ),
                  const SizedBox(height: 20),
                  title('Create password'),
                  TextFormField(
                    key: const ValueKey('tingle-register-password'),
                    controller: password,
                    enabled: !loading,
                    obscureText: !showPassword,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: field('Enter a strong password',
                        suffix: IconButton(
                          tooltip:
                              showPassword ? 'Hide password' : 'Show password',
                          onPressed: () =>
                              setState(() => showPassword = !showPassword),
                          icon: Icon(
                              showPassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: const Color(0xffaaa1c8)),
                        )),
                    validator: (v) => (v?.length ?? 0) >= 8
                        ? null
                        : 'Use at least 8 characters',
                  ),
                  const SizedBox(height: 20),
                  title('Confirm password'),
                  TextFormField(
                    key: const ValueKey('tingle-register-confirm'),
                    controller: confirm,
                    enabled: !loading,
                    obscureText: !showPassword,
                    decoration: field('Re-enter your password'),
                    validator: (v) =>
                        v == password.text ? null : 'Passwords do not match',
                  ),
                  const SizedBox(height: 23),
                  InkWell(
                    onTap: loading
                        ? null
                        : () => setState(() => accepted = !accepted),
                    child: Row(children: [
                      Checkbox(
                        activeColor: NimzoStyle.primary,
                        value: accepted,
                        onChanged: loading
                            ? null
                            : (v) => setState(() => accepted = v ?? false),
                      ),
                      const Expanded(
                        child: Text(
                            'I accept the Terms of Use and Privacy Policy',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xff534968))),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 17),
                  Container(
                    height: 65,
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xffa243f5), Color(0xff7439d4)]),
                        borderRadius: BorderRadius.circular(22)),
                    child: TextButton(
                        onPressed: loading ? null : register,
                        child: Text(loading ? 'Creating account…' : 'Register',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white))),
                  ),
                  const SizedBox(height: 24),
                  Center(
                      child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Already have an account?  Log in',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xff5e438a))),
                  )),
                  const SizedBox(height: 19),
                  const Divider(color: Color(0xffd8d2ef)),
                  const SizedBox(height: 13),
                  OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () {
                            if (!accepted) {
                              notify('Accept terms and privacy policy first.');
                              return;
                            }
                            ref.read(authControllerProvider.notifier).google();
                          },
                    icon: const Icon(Icons.g_mobiledata_rounded,
                        color: NimzoStyle.primary, size: 31),
                    label: const Text('Continue with Google',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xffdcd7ed)),
                      minimumSize: const Size.fromHeight(58),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
