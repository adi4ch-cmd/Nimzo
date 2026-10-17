import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// The NIMZO mark intentionally stays ours. The reference palette and
/// proportions are rebuilt without redistributing Tingle trademark artwork.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xffeeeaff),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NimzoMark(size: 99),
          SizedBox(height: 20),
          Text('NIMZO', style: TextStyle(
            letterSpacing: 4, color: Color(0xff291548),
            fontSize: 29, fontWeight: FontWeight.w900)),
          SizedBox(height: 25),
          SizedBox(width: 30, height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.5, color: NimzoStyle.primary)),
        ],
      ),
    ),
  );
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xffc5c4ff), Color(0xffeeebff),
            Color(0xfff9f7ff), Color(0xffded6fc),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 35),
          child: Column(children: [
            const Spacer(flex: 3),
            Center(
              child: SizedBox(
                height: 295,
                width: 330,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 12, left: 20,
                      child: _Bubble(
                        size: 102, color: Color(0xffff91c2),
                        icon: Icons.favorite_rounded),
                    ),
                    Positioned(
                      right: 11, top: 5,
                      child: _Bubble(
                        size: 95, color: Color(0xff9e8dfb),
                        icon: Icons.music_note_rounded),
                    ),
                    Positioned(
                      left: 54, bottom: 7,
                      child: _Bubble(
                        size: 88, color: Color(0xff55b9ff),
                        icon: Icons.graphic_eq_rounded),
                    ),
                    Positioned(
                      right: 23, bottom: 3,
                      child: _Bubble(
                        size: 82, color: Color(0xffffd38a),
                        icon: Icons.card_giftcard_rounded),
                    ),
                    const _NimzoMark(size: 130),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'NIMZO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 48, fontWeight: FontWeight.w900,
                color: Color(0xff21162d), letterSpacing: 3),
            ),
            const SizedBox(height: 8),
            const Text(
              'Speak. Connect. Celebrate.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xff605377), fontSize: 18,
                fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 15),
            const Text(
              'Discover live audio rooms, meet friends '
              'and share your moments.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xff837a9d),
                fontSize: 14, height: 1.5),
            ),
            const Spacer(flex: 3),
            Container(
              height: 65,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xffa243f5), Color(0xff7439d4)]),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Log In',
                  style: TextStyle(
                    color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 62, width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/register'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NimzoStyle.primary,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xffd6c8ed)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
                ),
                child: const Text('Create Account',
                  style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    ),
  );
}

class _NimzoMark extends StatelessWidget {
  final double size;
  const _NimzoMark({required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xffff8fc5), Color(0xff8a7dfa)]),
      borderRadius: BorderRadius.circular(size * .28),
      boxShadow: const [
        BoxShadow(color: Color(0x45894dbb),
          blurRadius: 24, offset: Offset(0, 11)),
      ],
    ),
    child: Text('N', style: TextStyle(
      fontSize: size * .70, color: Colors.white,
      height: 1, fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic)),
  );
}

class _Bubble extends StatelessWidget {
  final double size;
  final Color color;
  final IconData icon;
  const _Bubble({required this.size, required this.color,
    required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color, shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 4),
      boxShadow: const [
        BoxShadow(color: Color(0x1f4e3992),
          blurRadius: 14, offset: Offset(0, 6)),
      ],
    ),
    child: Icon(icon, size: size * .42, color: Colors.white),
  );
}
