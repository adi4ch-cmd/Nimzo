import 'package:flutter/material.dart';

/// Intentional blank UI canvas.
///
/// The previous NIMZO navigation, login/home/room/profile/game/store layouts,
/// dialogs and theme are not mounted by this application entry point.
/// The Supabase initialization in main.dart and all server records remain intact.
/// Restore/rebuild screens only after a separately approved new design.
class NimzoApp extends StatelessWidget {
  const NimzoApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        title: 'NIMZO',
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          key: ValueKey('nimzo-ui-reset-blank'),
          backgroundColor: Colors.white,
          body: SizedBox.expand(),
        ),
      );
}
