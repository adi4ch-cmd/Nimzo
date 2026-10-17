import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Genuine Supabase SMS sign-in. Whether SMS can be delivered depends on
/// the server phone-auth provider. Never show success when it rejects OTP.
bool validE164Phone(String text) =>
  RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(text.trim());

class MobileOtpLoginScreen extends ConsumerStatefulWidget {
  const MobileOtpLoginScreen({super.key});
  @override
  ConsumerState<MobileOtpLoginScreen> createState() =>
    _MobileOtpLoginState();
}

class _MobileOtpLoginState extends ConsumerState<MobileOtpLoginScreen> {
  final phone = TextEditingController();
  final code = TextEditingController();
  bool accepted = false;
  bool sent = false;
  bool busy = false;

  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  void message(String value) {
    if (mounted) ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> sendOtp() async {
    if (busy) return;
    if (!accepted) {
      message('Accept the terms and privacy policy to continue.');
      return;
    }
    if (!validE164Phone(phone.text)) {
      message('Enter your phone with country code, e.g. +9665XXXXXXXX');
      return;
    }
    setState(() => busy = true);
    try {
      await ref.read(supabaseProvider).auth.signInWithOtp(
        phone: phone.text.trim(),
        shouldCreateUser: true,
      );
      if (!mounted) return;
      setState(() => sent = true);
      message('Code requested. Enter the SMS code if it arrives.');
    } catch (error) {
      message('SMS login unavailable: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verify() async {
    if (busy) return;
    final token = code.text.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(token)) {
      message('Enter the code sent to your phone.');
      return;
    }
    setState(() => busy = true);
    try {
      final result = await ref.read(supabaseProvider).auth.verifyOTP(
        type: OtpType.sms,
        phone: phone.text.trim(),
        token: token,
      );
      if (!mounted) return;
      if (result.session == null) {
        message('SMS verification pending. Please retry.');
        return;
      }
      // Existing global auth redirect handles onboarding for new profiles.
      context.go('/home');
    } catch (error) {
      message('Code could not be verified: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff1eeff),
    appBar: AppBar(
      backgroundColor: const Color(0xffd5d0ff),
      centerTitle: true,
      title: const Text('Mobile Login',
        style: TextStyle(fontWeight: FontWeight.w900)),
    ),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            Color(0xffc9c7ff), Color(0xffeeebff), Color(0xfffaf9ff),
          ])),
      child: SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(23, 38, 23, 32),
        children: [
          Center(child: Container(
            width: 105, height: 105,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xffef82c1), Color(0xff825df1)]),
              borderRadius: BorderRadius.circular(28)),
            child: const Icon(Icons.phone_android_rounded,
              color: Colors.white, size: 61),
          )),
          const SizedBox(height: 26),
          const Text('Login with your number',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w900,
              color: Color(0xff221a34))),
          const SizedBox(height: 9),
          const Text('A real SMS code will be sent by the '
            'configured Supabase authentication provider.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xff7d718f),
              fontSize: 13, height: 1.5)),
          const SizedBox(height: 27),
          const Text('Phone with country code',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xff72668f))),
          const SizedBox(height: 9),
          TextField(
            key: const ValueKey('mobile-e164-input'),
            controller: phone,
            enabled: !busy && !sent,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: InputDecoration(
              hintText: '+9665XXXXXXXX',
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.phone_outlined,
                color: NimzoStyle.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20)),
            ),
          ),
          if (sent) ...[
            const SizedBox(height: 19),
            const Text('SMS verification code',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xff72668f))),
            const SizedBox(height: 9),
            TextField(
              key: const ValueKey('mobile-otp-input'),
              controller: code,
              enabled: !busy,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 8,
              decoration: InputDecoration(
                hintText: 'Enter your SMS code',
                filled: true,
                fillColor: Colors.white,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          InkWell(
            onTap: busy || sent ? null
              : () => setState(() => accepted = !accepted),
            child: Row(children: [
              Checkbox(
                activeColor: NimzoStyle.primary,
                value: accepted,
                onChanged: busy || sent ? null
                  : (v) => setState(() => accepted = v ?? false),
              ),
              const Expanded(child: Text(
                'I accept the Terms of Use and Privacy Policy',
                style: TextStyle(
                  fontSize: 13, color: Color(0xff645777)))),
            ]),
          ),
          const SizedBox(height: 19),
          SizedBox(
            height: 63,
            child: FilledButton(
              onPressed: busy ? null : sent ? verify : sendOtp,
              style: FilledButton.styleFrom(
                backgroundColor: NimzoStyle.primary,
                shape: const StadiumBorder()),
              child: Text(busy ? 'Please wait…'
                  : sent ? 'Verify and Continue' : 'Send SMS Code',
                style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w800)),
            ),
          ),
          if (sent) ...[
            const SizedBox(height: 17),
            TextButton(
              onPressed: busy ? null : () => setState(() {
                sent = false;
                code.clear();
              }),
              child: const Text('Change phone number')),
          ],
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Back to email login')),
        ],
      )),
    ),
  );
}
