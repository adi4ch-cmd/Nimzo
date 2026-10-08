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
        builder: (context, child) =>
            LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth.clamp(0.0, 480.0);
          return ColoredBox(
              color: Colors.white,
              child: Center(
                  child: SizedBox(
                      width: width,
                      height: constraints.maxHeight,
                      child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                              size: Size(width, constraints.maxHeight)),
                          child: child ?? const SizedBox.shrink()))));
        }),
      );
}
