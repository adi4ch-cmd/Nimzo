import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';

/// Five visible destinations, with each branch retaining its own scroll state.
class MainShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const MainShell({super.key, required this.shell});

  static const _labels = ['Room', 'Events', 'Square', 'Message', 'Me'];
  static const _icons = [
    Icons.home_rounded,
    Icons.emoji_events_rounded,
    Icons.explore_rounded,
    Icons.chat_rounded,
    Icons.account_circle_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final roomOrEvent = shell.currentIndex < 2;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          roomOrEvent ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: roomOrEvent ? const Color(0xffc340f8) : Colors.white,
        body: SafeArea(bottom: false, child: shell),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: NimzoStyle.line)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                for (var i = 0; i < _labels.length; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: shell.currentIndex == i,
                      child: InkWell(
                        key: ValueKey('tingle-navigation-$i'),
                        onTap: () => shell.goBranch(i,
                            initialLocation: i == shell.currentIndex),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            if (shell.currentIndex == i)
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xffdc4cf6),
                                    Color(0xff7757ff)
                                  ],
                                ).createShader(bounds),
                                child: Icon(_icons[i],
                                    size: 28, color: Colors.white),
                              )
                            else
                              Icon(_icons[i],
                                  size: 28, color: const Color(0xffd1cddc)),
                            const SizedBox(height: 3),
                            Text(_labels[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: shell.currentIndex == i
                                      ? NimzoStyle.primary
                                      : const Color(0xffa5a0b2),
                                )),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
