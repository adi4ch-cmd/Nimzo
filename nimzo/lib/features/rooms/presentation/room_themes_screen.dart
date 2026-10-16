import 'package:flutter/material.dart';

import '../domain/room_theme.dart';
import '../../../core/theme/app_theme.dart';

/// Built-in NIMZO themes. No invented premium prices or ownership state.
class RoomThemesScreen extends StatelessWidget {
  const RoomThemesScreen({super.key, required this.currentTheme});
  final String currentTheme;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: NimzoStyle.surface,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Room Themes'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 17, 20, 10),
              child: Text('NIMZO Original Themes',
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800,
                  color: NimzoStyle.royal,
                )),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 14),
              child: Text('Eight included room backgrounds. Tap to preview and apply. '
                  'No coin purchase required.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: NimzoStyle.muted)),
            ),
            Expanded(
              child: GridView.builder(
                key: const ValueKey('original-room-theme-gallery'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15, vertical: 7),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: .86,
                  mainAxisSpacing: 13,
                  crossAxisSpacing: 13,
                ),
                itemCount: RoomTheme.all.length,
                itemBuilder: (context, index) {
                  final theme = RoomTheme.all[index];
                  final isCurrent = currentTheme == theme.id;
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('room-theme-${theme.id}'),
                      onTap: () => Navigator.of(context).pop(theme.id),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: theme.gradient,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: -18, right: -28,
                                      child: Container(
                                        width: 115, height: 115,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: theme.text.withValues(alpha: .18),
                                            width: 2),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: -52, left: -36,
                                      child: Container(
                                        width: 175, height: 175,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: theme.text.withValues(alpha: .09),
                                        ),
                                      ),
                                    ),
                                    Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.graphic_eq_rounded,
                                            color: theme.text, size: 42),
                                          const SizedBox(height: 6),
                                          Text('NIMZO',
                                            style: TextStyle(
                                              color: theme.text,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 2,
                                            )),
                                        ],
                                      ),
                                    ),
                                    if (isCurrent)
                                      const Positioned(
                                        top: 8, right: 8,
                                        child: Icon(Icons.check_circle,
                                          color: NimzoStyle.primary, size: 23),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(theme.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                  ),
                                  Text(isCurrent ? 'Active' : 'Free',
                                    style: const TextStyle(
                                      color: NimzoStyle.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
}
