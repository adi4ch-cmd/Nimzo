import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/nimzo_button.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Nimzo', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700))));
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _S();
}

class _S extends State<OnboardingScreen> {
  final _c = PageController();
  int i = 0;
  static const pages = [
    ('Talk in voice rooms', 'Join rooms, take a mic seat and chat live.'),
    ('Meet people', 'Follow, add friends and share moments.'),
    ('Send gifts', 'Show support with gifts during live rooms.'),
  ];
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: Column(children: [
          Expanded(child: PageView(controller: _c, onPageChanged: (v) => setState(() => i = v), children: [
            for (final p in pages) Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(p.$1, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 12), Text(p.$2, textAlign: TextAlign.center),
            ])),
          ])),
          Padding(padding: const EdgeInsets.all(24), child: NimzoButton(
            label: i == pages.length - 1 ? 'Get started' : 'Next',
            onPressed: () => i == pages.length - 1 ? context.go('/login') : _c.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
          )),
        ])),
      );
}
