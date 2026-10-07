import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class NimzoApp extends ConsumerWidget {
  const NimzoApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Nimzo',
        theme: AppTheme.light(),
        routerConfig: ref.watch(routerProvider),
        debugShowCheckedModeBanner: false,
      );
}
